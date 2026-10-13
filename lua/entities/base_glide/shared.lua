ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Glide Base Vehicle"
ENT.Author = "StyledStrike"
ENT.Purpose = "Move around"
ENT.Instructions = "Aim at it, then press USE to enter"
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

-- Do not allow copying vehicles with the duplicator/AdvDupe
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

-- Let Glide know it should handle this entity differently
ENT.IsGlideVehicle = true
ENT.VehicleType = Glide.VEHICLE_TYPE.UNDEFINED

-- Max. chassis health
ENT.MaxChassisHealth = 1000

-- Does this vehicle have headlights?
ENT.CanSwitchHeadlights = false

-- Does this vehicle have turn signals?
ENT.CanSwitchTurnSignals = false

-- How long is the on/off cycle for turn signals?
ENT.TurnSignalCycle = 0.8

--[[
    For all vehicles, the values on Get/SetEngineState mean:

    0 - Off
    1 - Starting
    2 - Running
    3 - Shutting down or Ignition/Fuel cut-off
]]

function ENT:SetupDataTables()
    -- Setup default network variables. Do not override these slots
    -- when creating children classes! You can omit the 3rd "slot"
    -- argument (like how I did here) to avoid that.
    self:NetworkVar( "Entity", "Driver" )
    self:NetworkVar( "Int", "EngineState" )
    self:NetworkVar( "Bool", "IsEngineOnFire" )
    self:NetworkVar( "Bool", "IsLocked" )

    self:NetworkVar( "Float", "ChassisHealth" )
    self:NetworkVar( "Float", "EngineHealth" )

    self:NetworkVar( "Float", "BrakeValue" )
    self:NetworkVar( "Int", "HeadlightState" )
    self:NetworkVar( "Int", "TurnSignalState" )
    self:NetworkVar( "Int", "ConnectedReceptacleCount" )

    --[[
        0: Not on water
        1: At least one buoyancy point is on water
        2: At least half of the buoyancy points are on water
        3: Fully submerged
    ]]
    self:NetworkVar( "Int", "WaterState" )

    if CLIENT then
        self:NetworkVarNotify( "WaterState", self.OnWaterStateChange )
    end

    -- Headlight color can be edited if it's available
    local editData = nil

    if self.CanSwitchHeadlights then
        editData = { KeyName = "HeadlightColor", Edit = { type = "VectorColor", order = 0, category = "#glide.settings" } }
    end

    self:NetworkVar( "Vector", "HeadlightColor", editData )

    -- Set default values, to avoid some weird behaviour when prediction kicks in
    self:SetDriver( NULL )
    self:SetEngineState( 0 )
    self:SetIsEngineOnFire( false )

    self:SetBrakeValue( 0 )
    self:SetHeadlightState( 0 )
    self:SetTurnSignalState( 0 )

    -- Callback used to run `ENT:OnTurnOn` and `ENT:OnTurnOff`
    self:NetworkVarNotify( "EngineState", self.OnEngineStateChange )

    if CLIENT then
        -- Callback used to update the light color
        self:NetworkVarNotify( "HeadlightColor", self.OnHeadlightColorChange )
    end
end

function ENT:GravGunPickupAllowed( _ply )
    return false
end

do
    local gravGunPuntCvar = GetConVar( "glide_allow_gravity_gun_punt" )

    function ENT:GravGunPunt( _ply )
        return gravGunPuntCvar:GetBool()
    end
end

-- You can safely override these on children classes
function ENT:IsEngineOn()
    return self:GetEngineState() > 1
end

-- You can safely override this on children classes.
-- Used to update bodygroups and draw sprites while in reverse gear.
function ENT:IsReversing()
    return false
end

-- You can safely override this on children classes.
-- Used to update bodygroups and draw sprites while braking.
function ENT:IsBraking()
    return self:GetBrakeValue() > 0.1
end

-- You can safely override these on children classes.
function ENT:OnPostInitialize() end
function ENT:OnEntityReload() end
function ENT:OnTurnOn() end
function ENT:OnTurnOff() end
function ENT:UpdatePlayerPoseParameters( _ply ) return false end

function ENT:GetPlayerSitSequence( seatIndex )
    -- Some sequences I'm aware of are:
    -- drive_airboat, drive_pd, sit, sit_rollercoaster
    return seatIndex > 1 and "sit" or "drive_jeep"
end

function ENT:GetFirstPersonOffset( _seatIndex, localEyePos )
    localEyePos[1] = localEyePos[1] + 10
    localEyePos[3] = localEyePos[3] + 5

    return localEyePos
end

if CLIENT then
    ENT.Spawnable = false -- Hide from the default spawn list clientside

    -- Setup the camera parameters for this vehicle
    ENT.CameraOffset = Vector( -200, 0, 50 )
    ENT.CameraCenterOffset = Vector( 0, 0, 0 )
    ENT.CameraAngleOffset = Angle( 6, 0, 0 )

    -- This multiplier adds to the final forward offset
    -- while a trailer is attached.
    ENT.CameraTrailerDistanceMultiplier = 0.3

    -- Added to ENT.CameraCenterOffset while a trailer is attached.
    ENT.CameraTrailerOffset = Vector( -150, 0, 10 ) -- Push the camera backwards and a little bit up

    -- Setup how close players need to be for many client-side features
    -- (animations, sounds, lights, particles, etc) to become active.
    -- Also note that, those features will also deactivate
    -- if the vehicle is not on the player's potential visible set.
    ENT.MaxFeaturesDistance = 5000

    -- Startup/ignition sounds, leave empty to disable
    ENT.StartSound = ""
    ENT.StartTailSound = ""

    -- Positions where engine fire comes from.
    -- This should contain a array of tables, where each table contains:
    -- - Mandatory "offset" key with a Vector value, where the fire comes from.
    -- - Optional "angle" key with a Angle value, sets the direction of the flames. Points up by default.
    -- - Optional "scale" key with a number value, sets the size of the flames.
    ENT.EngineFireOffsets = {}

    -- How wide should the skidmarks be?
    ENT.WheelSkidmarkScale = 0.5

    -- Properties for break, reverse and headlight sprites
    ENT.LightSprites = {}

    -- Positions and colors for headlights
    ENT.Headlights = {}

    -- Light sounds
    ENT.TurnSignalPitch = 90
    ENT.TurnSignalVolume = 0.75
    ENT.TurnSignalTickOnSound = ")glide/headlights_on.wav"
    ENT.TurnSignalTickOffSound = ")glide/headlights_off.wav"

    --[[
        Sounds played when floating over water surfaces.
        These are audible only if your vehicle/vehicle base calls `ENT:DoWaterSounds`.
    ]]
    ENT.FallOnWaterSound = "Glide.Collision.BoatLandOnWater"

    ENT.WaterSideSlideLoop = ")ambient/levels/canals/dam_water_loop2.wav"
    ENT.WaterSideSlideVolume = 0.8
    ENT.WaterSideSlidePitch = 255

    ENT.FastWaterLoop = "vehicles/airboat/pontoon_fast_water_loop1.wav"
    ENT.FastWaterPitch = 110
    ENT.FastWaterVolume = 0.5

    ENT.CalmWaterLoop = ")vehicles/airboat/pontoon_stopped_water_loop1.wav"
    ENT.CalmWaterPitch = 100
    ENT.CalmWaterVolume = 0.9

    -- Offsets where propeller particle effects are emitted.
    -- These are visible only if your vehicle/vehicle base calls `ENT:DoWaterParticles`.
    ENT.PropellerPositions = {}

    -- Size multiplier for water foam/splash effects.
    -- They are visible only if your vehicle/vehicle base calls `ENT:DoWaterParticles`.
    ENT.WaterParticlesScale = 1

    -- You can safely override these on children classes.
    function ENT:ShouldActivateSounds() return true end
    function ENT:OnActivateSounds() end
    function ENT:OnDeactivateSounds() end
    function ENT:OnUpdateSounds() end
    function ENT:OnUpdateAnimations() end

    function ENT:OnLocalPlayerEnter( _seatIndex ) end
    function ENT:OnLocalPlayerExit() end

    function ENT:OnActivateMisc() end
    function ENT:OnDeactivateMisc() end
    function ENT:OnUpdateMisc() end
    function ENT:OnUpdateParticles() end
    function ENT:OnActivateWheel( _wheel, _index ) end

    function ENT:GetSeatBoneManipulations( _seatIndex ) end
    function ENT:AllowFirstPersonMuffledSound( _seatIndex ) return true end
    function ENT:AllowWindSound( _seatIndex ) return false, 0 end

    --- Given a `soundType` and surface material ID,
    --- you can override the wheel roll/skid sound.
    ---
    --- Sound types: "fastRoll", "slowRoll", "sideSlip", "forwardSlip"
    function ENT:OverrideWheelSound( _soundType, _surfaceType )
        return nil
    end
end

if SERVER then
    ENT.Spawnable = true -- Allow it to be spawned serverside

    -- Setup the vehicle's chassis properties
    ENT.ChassisMass = 700
    ENT.ChassisModel = "models/props_phx/construct/metal_plate1.mdl"
    ENT.AngularDrag = Vector( -0.1, -0.1, -3 ) -- Roll, pitch, yaw

    -- Use these offsets when spawning this vehicle
    ENT.SpawnPositionOffset = Vector( 0, 0, 10 )
    ENT.SpawnAngleOffset = Angle( 0, 90, 0 )

    -- Multiply damage taken by these values
    ENT.BulletDamageMultiplier = 1.0
    ENT.BlastDamageMultiplier = 5
    ENT.CollisionDamageMultiplier = 0.5

    ENT.SoftCollisionSound = "Glide.Collision.VehicleHard"
    ENT.HardCollisionSound = "Glide.Collision.VehicleSoft"

    -- How much of the chassis damage is also applied to the engine?
    ENT.EngineDamageMultiplier = 1.3

    -- How much of the blast damage force should be applied to the vehicle?
    ENT.BlastForceMultiplier = 0.01

    -- Damage multiplier for engine fire
    ENT.ChassisFireDamageMultiplier = 0.01

    -- Play a heavy metal noise when hitting things hard
    ENT.IsHeavyVehicle = false

    -- Can this vehicle be set on fire?
    ENT.CanCatchOnFire = true

    -- Particle size multiplier for collisions
    ENT.CollisionParticleSize = 1

    -- The force that makes this vehicle temporarely float on water.
    -- Set to 0 to disable the slow water sinking logic.
    ENT.SlowWaterSinkingBuoyancy = 600
    -- Damage things nearby when the vehicle explodes
    ENT.ExplosionRadius = 500

    -- Spawn these gibs when the vehicle explodes
    ENT.ExplosionGibs = {}

    -- Can the vehicle explode?
    ENT.CanExplode = true

    -- Suspension sounds
    ENT.SuspensionHeavySound = "Glide.Suspension.CompressHeavy"
    ENT.SuspensionDownSound = "Glide.Suspension.Down"
    ENT.SuspensionUpSound = "Glide.Suspension.Up"

    -- Bodygroup toggles for break, reverse lights, headlights and turn signals
    ENT.LightBodygroups = {}

    --[[
        The following parameters are relevant only if
        the vehicle calls the `ENT:SimulateBoat` function.
    ]]

    -- If you have not overritten `ENT:GetBuoyancyOffsets`,
    -- this variable moves the auto-generated points on the Z axis.
    ENT.BuoyancyPointsZOffset = 5

    -- If you have not overritten `ENT:GetBuoyancyOffsets`,
    -- this variable spaces out the auto-generated points on the X axis.
    ENT.BuoyancyPointsXSpacing = 0.6

    -- If you have not overritten `ENT:GetBuoyancyOffsets`,
    -- this variable spaces out the auto-generated points on the Y axis.
    ENT.BuoyancyPointsYSpacing = 0.6

    -- Drag & force constants for floating on water.
    ENT.BoatParams = {
        waterLinearDrag = Vector( 0.2, 1.5, 0.02 ), -- (Forward, right, up)
        waterAngularDrag = Vector( -5, -20, -15 ), -- (Roll, pitch, yaw)

        buoyancy = 6,           -- How strong is the buoyancy force on each buoyancy point?
        buoyancyDepth = 30,     -- How far from the water surface each buoyancy point have to be for the `buoyancy` to fully apply?

        turbulanceForce = 100,  -- Force to wobble the vehicle
        alignForce = 800,       -- Force to align the vehicle towards the direction of movement
        maxSpeed = 1000,        -- Stop applying `engineForce` once the vehicle hits this speed

        engineForce = 500,
        engineLiftForce = 1300, -- Pitch the vehicle up when accelerating
        turnForce = 1200,
        rollForce = 200         -- Roll the vehicle when turning
    }

    --- Return which input groups should be activated
    --- for a specific seat on this vehicle.
    function ENT:GetInputGroups( _seatIndex )
        return { "general_controls" }
    end

    -- You can safely override these on children classes
    function ENT:CreateFeatures() end

    function ENT:OnDriverEnter() end
    function ENT:OnDriverExit() end
    function ENT:OnSeatInput( _seatIndex, _action, _pressed ) end
    function ENT:OnHoldInputAction( _action, _data ) end

    function ENT:OnPostThink( _dt, _selfTbl ) end
    function ENT:OnSimulatePhysics( _phys, _dt, _outLin, _outAng, _selfTbl ) end
    function ENT:OnUpdateFeatures( _dt ) end
end
