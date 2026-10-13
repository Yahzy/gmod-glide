do
    local minForce, maxForce = -400000000, 400000000

    -- Timer resolves issue with table not existing until next tick on Linux.
    hook.Add( "InitPostEntity", "Glide.GetForceLimit", function()
        timer.Simple( 0, function()
            local maxVelocity = physenv.GetPerformanceSettings().MaxVelocity

            -- Ensure at least the default MaxVelocity value
            if maxVelocity < 4000 then
                maxVelocity = 4000
            end

            maxForce = 100000 * maxVelocity
            minForce = -maxForce
        end )
    end )

    local Clamp = math.Clamp
    local VectorUnpack = FindMetaTable( "Vector" ).Unpack
    local VectorSetUnpacked = FindMetaTable( "Vector" ).SetUnpacked

    --- Ensures that the force is within the range
    --- of a float, to prevent physics engine crashes.
    function Glide.ClampForce( v )
        local x, y, z = VectorUnpack( v )
        VectorSetUnpacked( v, Clamp( x, minForce, maxForce ), Clamp( y, minForce, maxForce ), Clamp( z, minForce, maxForce ) )
    end
end

do
    -- Sideways traction logic
    local x

    function Glide.TractionRamp( slipAngle, sideTractionMaxAng, sideTractionMax, sideTractionMin )
        sideTractionMaxAng = sideTractionMaxAng / 90 -- Convert max slip angle to the 0-1 range
        x = ( slipAngle - sideTractionMaxAng ) / ( 1 - sideTractionMaxAng )

        return slipAngle < sideTractionMaxAng and sideTractionMax or ( sideTractionMax * ( 1 - x ) ) + ( sideTractionMin * x )
    end
end

-- Call a hook when a player finishes loading into the server
-- and is ready to receive network events.
local Player = Player

hook.Add( "ClientSignOnStateChanged", "Glide.TriggerOnPlayerLoad", function( user, _, new )
    if new ~= SIGNONSTATE_FULL then return end

    -- We can only retrieve the player entity after this hook runs, so lets use a timer.
    -- It could have been 0 seconds, its just higher here to put less strain on the network.
    timer.Simple( 3, function()
        local ply = Player( user )

        if IsValid( ply ) and not ply:IsBot() then
            ply.GlideLoaded = true
            hook.Run( "Glide_OnPlayerLoad", ply )
        end
    end )
end )

local IsValid = IsValid

function Glide.CanSpawnVehicle( ply, class )
    if not IsValid( ply ) then return false end
    if not ply:CheckLimit( "glide_vehicles" ) then return false end

    if hook.Run( "Glide_CanSpawnVehicle", ply, class ) == false then
        return false
    end

    return true
end

function Glide.VehicleFactory( ply, data )
    if not Glide.CanSpawnVehicle( ply, data.Class ) then return end

    local ent = ents.Create( data.Class )
    if not IsValid( ent ) then return end

    ent:SetPos( data.Pos )
    ent:SetAngles( data.Angle )
    ent:SetCreator( ply )
    ent:Spawn()
    ent:Activate()

    ply:AddCount( "glide_vehicles", ent )
    cleanup.Add( ply, "glide_vehicles", ent )

    return ent
end

--- Check if a player can lock the vehicle by either
--- being it's creator or being a CPPI friend of the creator.
function Glide.CanLockVehicle( ply, vehicle )
    local creator = vehicle:GetCreator()

    if creator == ply then
        return true
    end

    if CPPI then
        if vehicle:CPPIGetOwner() == ply then
            return true
        end

        if vehicle:CPPICanPhysgun( ply ) then
            return true
        end
    end

    if vehicle.GetEntityOwner then
        if vehicle:GetEntityOwner() == ply then
            return true
        end
    end

    return hook.Run( "Glide_CanLockVehicle", ply, vehicle ) or false
end


--- Check if a player can enter a locked vehicle.
function Glide.CanEnterLockedVehicle( ply, vehicle )
    local canEnter = hook.Run( "Glide_CanEnterLockedVehicle", ply, vehicle )
    if canEnter == false then return false end

    if Glide.Config.alwaysCanEnterLockedVehicles then return true end
    if not canEnter then return false end

    return Glide.CanLockVehicle( ply, vehicle )
end


function Glide.EnterVehicleSeat( ply, vehicle, seat )
    if not IsValid( vehicle ) or not IsValid( seat ) then return end
    if not seat.GlideSeatIndex then return end

    ply:SetAllowWeaponsInVehicle( Glide.Config.allowPlayerWeaponsInVehicle )
    ply:EnterVehicle( seat )
end

--- Make a player switch to another seat
--- while inside a Glide vehicle.
function Glide.SwitchSeat( ply, seatIndex )
    if hook.Run( "Glide_CanSwitchSeat", ply, seatIndex ) == false then return end

    hook.Run( "Glide_PreSwitchSeat", ply, seatIndex )

    local vehicle = ply:GlideGetVehicle()
    if not IsValid( vehicle ) then return end

    local seat = vehicle.seats[seatIndex]

    if not IsValid( seat ) then
        ply:EmitSound( "player/suit_denydevice.wav", 50, 100, 1.0, 6, 0, 0 )
        return
    end

    if IsValid( seat:GetDriver() ) then
        ply:EmitSound( "player/suit_denydevice.wav", 50, 100, 1.0, 6, 0, 0 )
        return
    end

    ply:ExitVehicle()
    Glide.EnterVehicleSeat( ply, vehicle, seat )

    hook.Run( "Glide_PostSwitchSeat", ply, seatIndex )
end

--- Finds and returns all human players near a certain position.
function Glide.GetNearbyPlayers( pos, radius )
    radius = radius * radius

    local found, count = {}, 0

    for _, ply in player.Iterator() do
        local dist = pos:DistToSqr( ply:GetPos() )

        if dist < radius then
            count = count + 1
            found[count] = ply
        end
    end

    return found, count
end

-- Utility function used by the Repair SWEPs, to restore
-- chassis/engine health either partially or completely, and
-- to recreate parts and run extra functions when completely repaired.
function Glide.PartialRepair( vehicle, chassisAmount, engineAmount )
    local engineHealth = vehicle:GetEngineHealth()
    local chassisHealth = vehicle:GetChassisHealth()

    -- If the vehicle is at max. chassis and engine health...
    if chassisHealth >= vehicle.MaxChassisHealth and engineHealth >= 1 then
        local hasRepairedWheels = false

        if vehicle.wheels then
            -- Fix any blown wheels
            for _, wheel in Glide.EntityPairs( vehicle.wheels ) do
                if wheel:IsBlown() then
                    wheel:Repair()
                    hasRepairedWheels = true
                end
            end
        end

        -- No need to run the code below
        return hasRepairedWheels, hasRepairedWheels
    end

    local wasHealthIncreased = false
    local hasFinished = false

    -- Increate chassis/engine health, allowing overflow
    if chassisHealth < vehicle.MaxChassisHealth then
        chassisHealth = chassisHealth + chassisAmount
        engineHealth = math.Clamp( engineHealth + engineAmount, 0, 1 )
        wasHealthIncreased = true

        if chassisHealth > 0.3 and vehicle.SetIsEngineOnFire then
            vehicle:SetIsEngineOnFire( false )
        end
    end

    -- If are at the health limit, or have overflowed it, set it to
    -- the max. value, and call the vehicle's `Repair` function.
    if chassisHealth > vehicle.MaxChassisHealth then
        chassisHealth = vehicle.MaxChassisHealth
        hasFinished = true

        vehicle:Repair()
    end

    -- If we are at the max. chassis health already,
    -- set the engine health to the max. value.
    if chassisHealth >= vehicle.MaxChassisHealth then
        engineHealth = 1
        wasHealthIncreased = true
    end

    vehicle:SetChassisHealth( chassisHealth )
    vehicle:SetEngineHealth( engineHealth )

    return wasHealthIncreased, hasFinished
end
