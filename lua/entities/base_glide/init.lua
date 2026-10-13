AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "cl_lights.lua" )
AddCSLuaFile( "cl_water.lua" )
AddCSLuaFile( "sh_vehicle_compat.lua" )

include( "shared.lua" )
include( "sv_input.lua" )
include( "sv_damage.lua" )
include( "sv_wheels.lua" )
include( "sv_lights.lua" )
include( "sv_water.lua" )
include( "sh_vehicle_compat.lua" )

local EntityMeta = FindMetaTable( "Entity" )
local GetTable = EntityMeta.GetTable

--- Handle spawning this vehicle from the spawn menu or `gm_spawn` command.
function ENT:SpawnFunction( ply, tr )
    local pos = self.SpawnPositionOffset or Vector( 0, 0, 10 )
    local ang = self.SpawnAngleOffset or Angle( 0, 90, 0 )

    local ray = util.TraceLine( {
        start = tr.StartPos,
        endpos = tr.HitPos,
        mask = MASK_WATER
    } )

    if ray.Hit and ray.HitWorld then
        tr.HitPos = ray.HitPos
    end

    return Glide.VehicleFactory( ply, {
        Pos = tr.HitPos + pos,
        Angle = Angle( 0, ply:EyeAngles().y, 0 ) + ang,
        Class = self.ClassName
    } )
end

function ENT:OnReloaded()
    self.lastBodygroups = {}

    -- Setup water logic again
    self:WaterInit()

    -- Let children classes do their own logic
    self:OnEntityReload()
end

function ENT:Initialize()
    -- Setup variables used on all vehicle types.
    self.seats = {}     -- Keep track of all seats we've created
    self.exitPos = {}   -- Per-seat exit offsets
    self.lastDriver = NULL
    self.lastBodygroups = {}
    self.isEngineEnabled = true

    self.inputBools = {}        -- Per-seat bool inputs
    self.inputFloats = {}       -- Per-seat float inputs
    self.inputFlyMode = 0           -- User mouse flying mode
    self.inputManualShift = false   -- User manual gear shifting setting
    self.autoTurnOffLights = false  -- User "turn off headlights" setting
    self.autoTurnOnEngine = true
    self.inputThrottleModifierMode = 0  -- User throttle modifier setting
    self.inputThrottleModifierToggle = false

    -- Input actions that can be held to run alternative logic.
    self.holdInputActions = {}

    -- Setup collision variables
    self.collisionShakeCooldown = 0

    -- Setup speed variables
    self.localVelocity = Vector()
    self.forwardSpeed = 0
    self.totalSpeed = 0
    self.forwardAcceleration = 0

    -- Setup trace filter used by systems that
    -- need to ignore the vehicle's chassis and seats.
    self.selfTraceFilter = { self }

    -- Setup trace filter used by wheels to
    -- to ignore the vehicle's chassis and seats.
    self.wheelTraceFilter = { self, "player", "npc_*" }

    -- Copy default surface multipliers to this vehicle.
    self.surfaceGrip = table.Copy( Glide.SURFACE_GRIP )
    self.surfaceResistance = table.Copy( Glide.SURFACE_RESISTANCE )

    -- Setup the chassis model and physics
    self:SetModel( self.ChassisModel )
    self:InitializePhysics()
    self:SetUseType( SIMPLE_USE )

    local phys = self:GetPhysicsObject()

    if not IsValid( phys ) then
        self:Remove()
        error( "Failed to setup physics! Vehicle removed!" )
        return
    end

    phys:AddGameFlag( FVPHYSICS_NO_PLAYER_PICKUP )
    phys:SetMaterial( "metalvehicle" )
    phys:SetMass( self.ChassisMass )
    phys:EnableDrag( false )
    phys:SetDamping( 0, 0 )
    phys:SetDragCoefficient( 0 )
    phys:SetAngleDragCoefficient( 0 )
    phys:SetBuoyancyRatio( 0.0 )
    phys:EnableMotion( true )
    phys:Wake()

    self:StartMotionController()

    -- Let NPCs see through this vehicle
    self:AddEFlags( EFL_DONTBLOCKLOS )
    self:AddFlags( FL_OBJECT )

    -- Setup wheel system
    self:WheelInit()

    -- Setup water-related logic
    self:WaterInit()

    -- Set default headlight color
    local headlightColor = Glide.DEFAULT_HEADLIGHT_COLOR
    self:SetHeadlightColor( Vector( headlightColor.r / 255, headlightColor.g / 255, headlightColor.b / 255 ) )

    self:SetColor( self:GetSpawnColor() )

    -- Let child classes add their own features
    self:OnPostInitialize()

    -- Set health back to defaults
    self:Repair()

    -- Let child classes create things like seats, etc.
    self:CreateFeatures()

    -- Allow players to shoot fast-moving vehicles when their ping is high
    self:SetLagCompensated( true )

    -- Only check for PhysObj validity/sleepyness every one in a while instead of every tick.
    -- This may approach might cause errors, but only for a brief time,
    -- until the next PhysObj:IsValid call is made.
    self.hasValidPhysics = true
    self.hasSleepingPhysics = false
    self.nextPhysicsValidCheck = 0
end

function ENT:InitializePhysics()
    self:SetSolid( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
end

function ENT:UpdateTransmitState()
    return 2 -- TRANSMIT_PVS
end

function ENT:Use( activator )
    if not IsValid( activator ) then return end
    if not activator:IsPlayer() then return end

    if not IsValid( self:GetDriver() ) and not activator:KeyDown( IN_WALK ) then
        local seat = self:GetFreeSeat()

        if seat then
            Glide.EnterVehicleSeat( activator, self, seat )
            return
        end
    end

    local freeSeat = self:GetClosestAvailableSeat( activator:GetShootPos() )

    if freeSeat then
        Glide.EnterVehicleSeat( activator, self, freeSeat )
    end
end

function ENT:OnEngineStateChange( _, lastState, state )
    if lastState == 1 and state == 2 then
        self:OnTurnOn()

    elseif state == 0 then
        self:OnTurnOff()
    end

    self:AwakePhysics()
end

function ENT:TurnOn()
    if not self.isEngineEnabled then return end

    local state = self:GetEngineState()

    if state == 3 then
        self:SetEngineState( 2 )

    elseif state ~= 2 then
        self:SetEngineState( 1 )
    end
end

function ENT:TurnOff()
    self:SetEngineState( 3 )

    if self.autoTurnOffLights then
        self:ChangeHeadlightState( 0, true )
    end
end

do
    local data = {}

    --- Utility function to setup trace data that
    --- ignores the vehicle's chassis and seats.
    function ENT:GetTraceData( startPos, endPos )
        data.filter = self.selfTraceFilter
        data.start = startPos
        data.endpos = endPos

        return data
    end
end

--- Makes so only the vehicle creator and prop
--- protection buddies can enter this vehicle.
function ENT:SetLocked( isLocked )
    self:SetIsLocked( isLocked )
end

local IsValid = IsValid

do
    local GetDevMode = Glide.GetDevMode
    local TraceLine = util.TraceLine
    local TraceHull = util.TraceHull

    local ray = {}
    local traceData = {
        mins = Vector( -20, -20, 0 ),
        maxs = Vector( 20, 20, 50 ),
        output = ray, -- Output TraceResult to this table
        mask = MASK_NPCSOLID - MASK_WATER -- Ignore water
    }

    local function ValidateExitPos( vehicle, origin, localPos )
        local exitPos = vehicle:LocalToWorld( localPos )

        -- First, make sure there's nothing in between the vehicle's seat and `exitPos`
        traceData.start = origin
        traceData.endpos = exitPos

        TraceLine( traceData )

        if ray.Hit then
            if GetDevMode() then
                debugoverlay.Line( origin, traceData.endpos, 8, Color( 255, 0, 0 ), true )
                debugoverlay.EntityTextAtPosition( traceData.endpos, 0, "<exit blocked>", 8, Color( 255, 0, 0 ) )
            end

            return true, exitPos
        end

        -- Second, make sure the player's hitbox can fit on the `exitPos`
        traceData.start = exitPos
        traceData.endpos = exitPos

        TraceHull( traceData )

        if ray.StartSolid then
            if GetDevMode() then
                debugoverlay.Line( origin, traceData.endpos, 8, Color( 255, 100, 0 ), true )
                debugoverlay.EntityTextAtPosition( traceData.endpos, 0, "<exit is too small>", 8, Color( 255, 100, 0 ) )
            end

            return true, exitPos
        end

        if GetDevMode() then
            debugoverlay.Line( origin, exitPos, 8, Color( 0, 255, 0 ), true )
            debugoverlay.Box( exitPos, traceData.mins, traceData.maxs, 8, Color( 255, 255, 255, 20 ) )
        end

        return false, exitPos
    end

    --- Gets the exit position from a seat index.
    function ENT:GetSeatExitPos( index )
        local seat = self.seats[index]

        if not IsValid( seat ) then
            return self:GetPos() -- Not much we can do here...
        end

        traceData.filter = {}

        -- Ignore everything that is parented to this vehicle
        for i, ent in ipairs( self:GetChildren() ) do
            traceData.filter[i] = ent
        end

        -- Ignore the vehicle itself and players
        traceData.filter[#traceData.filter + 1] = self
        traceData.filter[#traceData.filter + 1] = "player"

        -- Try the original exit position first
        local origin = self:LocalToWorld( self:OBBCenter() )
        local blocked, pos = ValidateExitPos( self, origin, seat.GlideExitPos )

        if blocked then
            -- Try on the other side
            blocked, pos = ValidateExitPos( self, origin, Vector( seat.GlideExitPos[1], -seat.GlideExitPos[2], seat.GlideExitPos[3] ) )
        end

        if blocked then
            -- Well, let's just try a bunch of positions then
            local obbSize = self:OBBMaxs() - self:OBBMins()

            obbSize[1] = obbSize[1] < 150 and 150 or obbSize[1]
            obbSize[2] = obbSize[2] < 100 and 100 or obbSize[2]

            local offset = Vector()
            local rad

            for ang = 0, 360, 15 do
                rad = math.rad( ang )
                offset[1] = math.sin( rad ) * obbSize[1] * 0.75
                offset[2] = math.cos( rad ) * obbSize[2] * 0.75

                blocked, pos = ValidateExitPos( self, origin, offset )

                if not blocked then
                    break
                end
            end
        end

        if blocked then
            -- We're cooked...
            pos = seat:GetPos()
        else
            -- Put the exit position on the ground
            traceData.start = pos
            traceData.endpos = Vector( pos[1], pos[2], pos[3] - 100 )

            TraceHull( traceData )

            if ray.Hit then
                pos = ray.HitPos
                pos[3] = pos[3] + 5
            end
        end

        if GetDevMode() then
            debugoverlay.EntityTextAtPosition( pos, 0, "<final exit pos>", 8, Color( blocked and 255 or 0, 255, 0 ) )
            debugoverlay.Box( pos, traceData.mins, traceData.maxs, 8, Color( blocked and 255 or 0, 255, 0, 30 ) )
        end

        return pos
    end
end

local EntityPairs = Glide.EntityPairs

--- Returns how many players are inside of this vehicle.
function ENT:GetPlayerCount()
    local count = 0

    for _, seat in EntityPairs( self.seats ) do
        if IsValid( seat:GetDriver() ) then
            count = count + 1
        end
    end

    return count
end

--- Returns all players that are inside of this vehicle.
function ENT:GetAllPlayers()
    local players = {}
    local driver

    for _, seat in EntityPairs( self.seats ) do
        if IsValid( seat ) then
            driver = seat:GetDriver()

            if IsValid( driver ) then
                players[#players + 1] = driver
            end
        end
    end

    return players
end

--- Gets the driver from a seat index.
function ENT:GetSeatDriver( index )
    local seat = self.seats[index]

    if IsValid( seat ) then
        return seat:GetDriver()
    end
end

--- Gets the first free seat entity, or returns `nil` if none are available.
function ENT:GetFreeSeat()
    for i, seat in EntityPairs( self.seats ) do
        if not IsValid( seat:GetDriver() ) then
            return seat, i
        end
    end
end

--- Gets the closest available seat to a position.
function ENT:GetClosestAvailableSeat( pos )
    local closestSeat, closestSeatIndex = nil, nil
    local closestDistance = math.huge

    for i, seat in EntityPairs( self.seats ) do
        local distance = pos:DistToSqr( seat:GetPos() )

        if distance < closestDistance and not IsValid( seat:GetDriver() ) then
            closestSeat = seat
            closestSeatIndex = i
            closestDistance = distance
        end
    end

    return closestSeat, closestSeatIndex
end

--- Create a new seat.
---
--- `offset` is the seat's position relative to the chassis.
--- `angle` is the seat's angles relative to the chassis.
--- Set `isHidden` to `true` to disable drawing this seat.
function ENT:CreateSeat( offset, angle, exitPos, isHidden )
    local index = #self.seats + 1

    if index > Glide.MAX_SEATS then
        error( "Seat limit reached!" )

        return
    end

    local seat = ents.Create( "prop_vehicle_prisoner_pod" )

    if not IsValid( seat ) then
        self:Remove()
        error( "Failed to spawn a seat! Vehicle removed!" )

        return
    end

    seat:SetModel( "models/nova/airboat_seat.mdl" )
    seat:SetPos( self:LocalToWorld( offset or Vector() ) )
    seat:SetAngles( self:LocalToWorldAngles( angle or Angle( 0, 270, 10 ) ) )
    seat:SetMoveType( MOVETYPE_NONE )
    seat:SetOwner( self )
    seat:Spawn()
    seat:Activate()

    Glide.CopyEntityCreator( self, seat )

    seat:SetKeyValue( "limitview", 0 )
    seat:SetNotSolid( true )
    seat:SetParent( self )
    seat:DrawShadow( false )
    seat:PhysicsDestroy()

    seat.PhysgunDisabled = true
    seat.DoNotDuplicate = true
    seat.DisableDuplicator = true

    if isHidden then
        Glide.HideEntity( seat, true )
    end

    -- Let Glide know it should handle this seat differently
    seat.GlideSeatIndex = index
    seat.GlideExitPos = exitPos
    self:DeleteOnRemove( seat )

    self.seats[index] = seat

    -- Setup player inputs for this seat
    self.inputBools[index] = {}
    self.inputFloats[index] = {}

    -- Don't let our traces hit this seat
    self.selfTraceFilter[#self.selfTraceFilter + 1] = seat
    self.wheelTraceFilter[#self.wheelTraceFilter + 1] = seat

    return seat
end

local CurTime = CurTime
local TickInterval = engine.TickInterval
local GetDevMode = Glide.GetDevMode

function ENT:Think()
    local dt = TickInterval()
    local selfTbl = GetTable( self )

    -- Run again next tick
    local time = CurTime()
    self:NextThink( time )

    -- Update speed variables
    local pos = self:GetPos()
    local velocity = self:GetVelocity()
    velocity:Add( pos )

    selfTbl.localVelocity = self:WorldToLocal( velocity )
    selfTbl.totalSpeed = selfTbl.localVelocity:Length()

    local forwardSpeed = selfTbl.localVelocity[1]
    selfTbl.forwardAcceleration = ( forwardSpeed - selfTbl.forwardSpeed ) / dt
    selfTbl.forwardSpeed = forwardSpeed

    -- If we have at least one seat...
    if #selfTbl.seats > 0 then
        -- Use it to check if we have a driver
        local driverSeat = selfTbl.seats[1]
        local driver = IsValid( driverSeat ) and driverSeat:GetDriver() or NULL

        if driver ~= selfTbl.GetDriver( self ) then
            selfTbl.SetDriver( self, driver )

            if IsValid( driver ) then
                selfTbl.OnDriverEnter( self )
                selfTbl.lastDriver = driver
            else
                selfTbl.OnDriverExit( self )
            end
        end
    end

    local phys = self:GetPhysicsObject()

    -- Check physics object every 2 seconds
    if time > selfTbl.nextPhysicsValidCheck then
        selfTbl.nextPhysicsValidCheck = time + 2
        selfTbl.hasValidPhysics = IsValid( phys )
        selfTbl.hasSleepingPhysics = selfTbl.hasValidPhysics and phys:IsAsleep()

        if selfTbl.hasValidPhysics then
            local lin, ang = phys:GetDamping()

            if lin > 0 or ang > 0 then
                phys:SetDamping( 0, 0 )
            end
        end
    end

    -- Update water logic
    selfTbl.WaterThink( self, selfTbl, dt )

    -- Deal engine fire damage over time
    if selfTbl.GetIsEngineOnFire( self ) then
        if self:WaterLevel() > 2 then
            selfTbl.SetIsEngineOnFire( self, false )
        else
            local attacker = IsValid( selfTbl.lastDamageAttacker ) and selfTbl.lastDamageAttacker or self
            local inflictor = IsValid( selfTbl.lastDamageInflictor ) and selfTbl.lastDamageInflictor or self

            local dmg = DamageInfo()
            dmg:SetDamage( selfTbl.MaxChassisHealth * selfTbl.ChassisFireDamageMultiplier * dt )
            dmg:SetAttacker( attacker )
            dmg:SetInflictor( inflictor )
            dmg:SetDamageType( 0 )
            dmg:SetDamageForce( Vector() )
            dmg:SetDamagePosition( pos )
            self:TakeDamageInfo( dmg )
        end
    end

    local isValidPhys = selfTbl.hasValidPhysics

    -- Update wheels
    if selfTbl.wheelCount > 0 and isValidPhys then
        selfTbl.WheelThink( self, dt, selfTbl )
    end

    -- Handle hold input actions
    for action, data in pairs( selfTbl.holdInputActions ) do
        -- If this action has been held for long enough...
        if data.timer and time > data.timer then
            data.timer = nil
            selfTbl.OnHoldInputAction( self, action, data )

        elseif data.shouldRelease then
            data.shouldRelease = nil
            selfTbl.SetInputBool( self, 1, action, false )
        end
    end

    -- Update bodygroups
    selfTbl.UpdateLightBodygroups( self, selfTbl )

    -- Let children classes do their own stuff
    selfTbl.OnPostThink( self, dt, selfTbl )

    -- Let children classes update their features
    selfTbl.OnUpdateFeatures( self, dt )

    -- Draw debug overlays, if `developer` cvar is active
    if GetDevMode() and isValidPhys then
        debugoverlay.Axis( self:LocalToWorld( phys:GetMassCenter() ), self:GetAngles(), 15, 0.1, true )
    end

    return true
end

local colors = {
    Color( 180, 70, 70 ),
    Color( 80, 65, 50 ),
    Color( 162, 188, 243 ),
    Color( 214, 106, 53 ),
    Color( 45, 45, 45 ),
    Color( 20, 20, 20 ),
    Color( 100, 100, 100 ),
    Color( 190, 190, 190 ),
    Color( 255, 255, 255 )
}

function ENT:GetSpawnColor()
    local color = colors[math.random( #colors )]
    return Color( color.r, color.g, color.b )
end
