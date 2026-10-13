--[[
    Glide configuration.

    All Glide settings live here as constants, the same for every player.
    Edit the values below, then restart the server (or change map) to apply them.

    The driving keys (accelerate, brake, steer, handbrake and throttle modifier)
    automatically follow each player's own GMod movement keys,
    see `Config.GAME_BINDS` at the bottom of this file.
]]

local Config = Glide.Config

----- Server settings -----

-- Damage multipliers
Config.bulletDamageMultiplier = 1.0             -- Bullets hitting vehicles
Config.blastDamageMultiplier = 1.0              -- Explosions hitting vehicles
Config.physicsDamageMultiplier = 1.0            -- Collisions against anything that is not the world
Config.worldPhysicsDamageMultiplier = 1.0       -- Collisions against the world
Config.globalDamageMultiplier = 1.0             -- Any damage source (except collisions)

-- Players inside vehicles taking damage from hard collisions
Config.enablePlayerCollisionDamage = false
Config.playerCollisionDamageMultiplier = 0.5

-- Toggles
Config.allowGravityGunPunt = false              -- Allow pushing vehicles with the Gravity Gun
Config.alwaysCanEnterLockedVehicles = false     -- Allow entering locked vehicles that players don't own
Config.allowPlayerWeaponsInVehicle = false      -- Allow players to use their own weapons inside vehicles

-- Gibs
Config.gibLifetime = 8                          -- In seconds, 0 for no despawning
Config.gibEnableCollisions = true               -- When false, gibs won't collide with players/props

if not CLIENT then return end

----- Client settings -----

-- Audio (0 to 1)
Config.carVolume = 1.0
Config.explosionVolume = 1.0
Config.hornVolume = 1.0
Config.windVolume = 0.7
Config.vcVolume = 0.4                           -- Vehicle volume while someone is talking on voice chat

-- Camera
Config.lookSensitivity = 1.0
Config.cameraInvertX = false
Config.cameraInvertY = false

Config.cameraDistance = 1.0
Config.cameraHeight = 1.0
Config.cameraFOVInternal = nil                  -- nil to use the player's own FOV (fov_desired)
Config.cameraFOVExternal = nil                  -- nil to use the player's own FOV (fov_desired)

Config.fixedCameraMode = 0
Config.enableAutoCenter = true
Config.autoCenterDelay = 1.5
Config.shakeStrength = 1.0

-- Mouse
Config.mouseFlyMode = Glide.MOUSE_FLY_MODE.AIM
Config.mouseSensitivityX = 1.0
Config.mouseSensitivityY = 1.0
Config.mouseInvertX = false
Config.mouseInvertY = false

Config.pitchMouseAxis = 2 -- Y
Config.yawMouseAxis = 0 -- None
Config.rollMouseAxis = 1 -- X
Config.mouseDeadzone = 0.15
Config.mouseShow = true
Config.mouseFlyDecayRate = 0.0

Config.mouseSteerMode = Glide.MOUSE_STEER_MODE.DISABLED
Config.mouseSteerSensitivity = 0.5
Config.mouseSteerDecayRate = 1.5

-- Performance
Config.maxSkidMarkPieces = 500
Config.maxTireRollPieces = 400
Config.skidmarkTimeLimit = 15

Config.headlightShadows = true
Config.reduceTireParticles = false

-- Misc.
Config.manualGearShifting = false
Config.throttleModifierMode = 0                 -- 0: hold to full, 1: hold to reduce, 2: tap to toggle
Config.autoHeadlightOn = true
Config.autoHeadlightOff = true
Config.autoTurnOffLights = true
Config.autoTurnOnEngine = true

-- Actions that use the player's own GMod movement keys.
-- Every other action uses the default key set in `lua/glide/sh_input.lua`.
Config.GAME_BINDS = {
    land_controls = {
        accelerate = "+forward",
        brake = "+back",
        steer_left = "+moveleft",
        steer_right = "+moveright",
        handbrake = "+jump",
        throttle_modifier = "+speed"
    }
}
