function ENT:WheelInit()
    self.wheels = {}
    self.wheelCount = 0
    self.wheelsEnabled = true
    self.steerAngle = Angle()

    -- This was deprecated. Putting values here does nothing.
    -- Wheel parameters are stored on each wheel now.
    -- This will be removed in the future.
    self.wheelParams = {}
end

function ENT:CreateWheel( offset, params )
    params = params or {}

    local pos = self:LocalToWorld( offset )
    local ang = self:LocalToWorldAngles( Angle() )

    local wheel = ents.Create( "glide_wheel" )
    wheel:SetPos( pos )
    wheel:SetAngles( ang )
    wheel:SetOwner( self )
    wheel:SetParent( self )
    wheel:Spawn()
    wheel:SetupWheel( params )

    self:DeleteOnRemove( wheel )

    Glide.CopyEntityCreator( self, wheel )

    local index = self.wheelCount + 1

    self.wheelCount = index
    self.wheels[index] = wheel

    return wheel
end

local EntityPairs = Glide.EntityPairs

function ENT:ChangeWheelRadius( radius )
    if not self.wheels then return end

    for _, w in EntityPairs( self.wheels ) do
        if IsValid( w ) then
            w.params.radius = radius
            w:ChangeRadius( radius )
        end
    end
end

--- The returned value from this function is multiplied with
--- the yaw angle from `ENT.AngularDrag` before appling it to the vehicle.
function ENT:GetYawDragMultiplier()
    return 1
end

-- Wrapper function to wake the entity's PhysObj.
-- Please use this instead of `ent:GetPhysicsObject():Wake()`.
function ENT:AwakePhysics()
    self:PhysWake()
    self.hasSleepingPhysics = false
end

local EntityMeta = FindMetaTable( "Entity" )
local GetTable = EntityMeta.GetTable

function ENT:WheelThink( dt, selfTbl )
    local isAsleep = selfTbl.hasSleepingPhysics

    for _, w in EntityPairs( selfTbl.wheels ) do
        local wheelTbl = GetTable( w )
        wheelTbl.Update( w, self, selfTbl.steerAngle, isAsleep, dt, wheelTbl )
    end
end

local VectorUnpack = FindMetaTable( "Vector" ).Unpack
local VectorSetUnpacked = FindMetaTable( "Vector" ).SetUnpacked

local Abs = math.abs
local Clamp = math.Clamp
local ClampForce = Glide.ClampForce

local linForce, angForce = Vector(), Vector()

function ENT:PhysicsSimulate( phys, dt )
    local selfTbl = GetTable( self )

    -- Prepare output vectors, do angular drag
    local mass = phys:GetMass()

    linForce:Zero()

    local angDragX, angDragY, angDragZ = VectorUnpack( selfTbl.AngularDrag )
    local angVelX, angVelY, angVelZ = VectorUnpack( phys:GetAngleVelocity() )

    VectorSetUnpacked( angForce,
        angVelX * angDragX * mass,
        angVelY * angDragY * mass,
        angVelZ * angDragZ * selfTbl.GetYawDragMultiplier( self ) * mass
    )

    local groundedCount = 0

    -- Do wheel physics
    if selfTbl.wheelCount > 0 and selfTbl.wheelsEnabled then
        local traceFilter = selfTbl.wheelTraceFilter
        local surfaceGrip = selfTbl.surfaceGrip
        local surfaceResistance = selfTbl.surfaceResistance

        local vehPos = phys:GetPos()
        local changedPosCount = 0

        for _, w in EntityPairs( selfTbl.wheels ) do
            local wheelTbl = GetTable( w )

            if wheelTbl.DoPhysics( w, self, phys, traceFilter, linForce, angForce, dt, surfaceGrip, surfaceResistance, vehPos, selfTbl ) then
                changedPosCount = changedPosCount + 1
            end

            if wheelTbl.state.isOnGround then
                groundedCount = groundedCount + 1
            end
        end

        if changedPosCount > 0 then
            local vehVel = phys:GetVelocity()
            local vehAngVel = phys:GetAngleVelocity()

            phys:SetPos( vehPos )
            phys:SetVelocityInstantaneous( vehVel )
            phys:SetAngleVelocityInstantaneous( vehAngVel )
        end
    end

    -- Let children classes do additional physics if they want to
    selfTbl.OnSimulatePhysics( self, phys, dt, linForce, angForce, selfTbl )

    -- At slow speeds, try to prevent slipping sideways on mildly steep slopes
    if groundedCount > 0 then
        local totalSpeed = selfTbl.totalSpeed + Abs( angVelZ )
        local factor = 1 - Clamp( totalSpeed / 30, 0, 1 )

        if factor > 0.1 then
            local rt = self:GetRight()
            linForce:Sub( ( rt:Dot( phys:GetVelocity() ) / dt ) * mass * factor * rt )
        end
    end

    -- Prevent crashes
    ClampForce( angForce )
    ClampForce( linForce )

    return angForce, linForce, 4 -- SIM_GLOBAL_FORCE
end
