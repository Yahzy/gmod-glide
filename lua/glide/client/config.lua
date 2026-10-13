local Config = Glide.Config

-- Settings are constants, see `lua/glide_config.lua`.

--- Setup bind actions with their default buttons,
--- then apply the player's GMod movement keys.
function Config:SetupBinds()
    local binds = {}

    -- Setup default action groups and buttons
    for groupId, actions in pairs( Glide.InputGroups ) do
        binds[groupId] = {}

        for action, button in pairs( actions ) do
            binds[groupId][action] = button
        end
    end

    self.binds = binds
    self:ApplyGameBinds()
end

--- Copy the player's GMod movement keys into the binds table.
--- Returns `true` if any bind changed.
function Config:ApplyGameBinds()
    local binds = self.binds
    if not binds then return false end

    local changed = false

    for groupId, actions in pairs( self.GAME_BINDS ) do
        local groupBinds = binds[groupId]

        if groupBinds then
            for action, bind in pairs( actions ) do
                local keyName = input.LookupBinding( bind )
                local button = keyName and input.GetKeyCode( keyName )

                -- Fallback to the default key if this bind is not set
                if not button or button <= KEY_NONE then
                    button = Glide.InputGroups[groupId][action]
                end

                if groupBinds[action] ~= button then
                    groupBinds[action] = button
                    changed = true
                end
            end
        end
    end

    return changed
end

-- Utility function to get the button bound to a certain input action.
function Config:GetInputActionButton( action, groupId )
    local group = self.binds[groupId]
    if group then
        return group[action]
    end
end

--- Send the current input settings to the server.
function Config:TransmitInputSettings( immediate )
    timer.Remove( "Glide.TransmitInputSettings" )

    if not immediate then
        -- Don't spam when this function gets called in quick succession
        timer.Create( "Glide.TransmitInputSettings", 1, 1, function()
            self:TransmitInputSettings( true )
        end )

        return
    end

    local data = {
        -- Mouse settings
        mouseFlyMode = self.mouseFlyMode,
        mouseSteerMode = self.mouseSteerMode,
        replaceYawWithRoll = self.mouseFlyMode == Glide.MOUSE_FLY_MODE.DIRECT and self.yawMouseAxis > 0,

        -- Keyboard settings
        manualGearShifting = self.manualGearShifting,
        throttleModifierMode = self.throttleModifierMode,

        -- Misc. settings
        autoTurnOffLights = self.autoTurnOffLights,
        autoTurnOnEngine = self.autoTurnOnEngine,

        -- Action-key dictionary
        binds = self.binds
    }

    Glide.PrintDev( "Transmitting input data to the server." )

    Glide.StartCommand( Glide.CMD_INPUT_SETTINGS )
    Glide.WriteTable( data )
    net.SendToServer()
end

-- Setup binds right away, to prevent errors
Config:SetupBinds()

-- Follow changes to the player's GMod movement keys
timer.Create( "Glide.CheckGameBinds", 2, 0, function()
    if Config:ApplyGameBinds() then
        hook.Run( "Glide_OnConfigChange" )
        Config:TransmitInputSettings()
    end
end )

local function SendSettings()
    Config:ApplyGameBinds()
    hook.Run( "Glide_OnConfigChange" )
    Config:TransmitInputSettings()
    Glide.SetupSkidMarkMeshes()
end

if game.SinglePlayer() then
    -- On singleplayer, setup settings on InitPostEntity
    hook.Add( "InitPostEntity", "Glide.LoadSettings", SendSettings )
else
    -- SetupMove seems like a better time to send network messages
    hook.Add( "SetupMove", "Glide.LoadSettings", function()
        hook.Remove( "SetupMove", "Glide.LoadSettings" )
        SendSettings()
    end )
end

local volumeMultiplier = 1.0

-- Calculate the volume multiplier for a specific audio type,
-- depending on settings and how loud the voice chat is.
--
-- audioType must be one of these:
-- "carVolume", "explosionVolume", "hornVolume", "windVolume"
function Config.GetVolume( audioType )
    return Config[audioType] * volumeMultiplier
end

-- Run the voice activity.
-- Please note that any changes in the logic here require restarting
-- the game to test, since many scripts localize `Config.GetVolume`.

local FrameTime = FrameTime
local Approach = math.Approach
local PlayerIterator = player.Iterator

local VoiceVolume = FindMetaTable( "Player" ).VoiceVolume
local IsVoiceAudible = FindMetaTable( "Player" ).IsVoiceAudible
local IsValid = IsValid

local playerIndex = 0
local isAnyoneTalking = false
local shouldReduceVolume = false

hook.Add( "Think", "Glide.DetectVoiceActivity", function()
    -- Iterate over the list of players, checking for
    -- voice activity on one player per frame.
    local iterator, allPlayers = PlayerIterator()
    local i, ply = iterator( allPlayers, playerIndex )

    playerIndex = playerIndex + 1

    if i and IsValid( ply ) and IsVoiceAudible( ply ) and VoiceVolume( ply ) > 0.01 then
        isAnyoneTalking = true
        i = nil -- Break out of the iteration early
    end

    -- When we reach the end of the iteration...
    if not i then
        shouldReduceVolume = isAnyoneTalking

        -- Begin a new iteration
        playerIndex = 0
        isAnyoneTalking = false
    end

    volumeMultiplier = Approach(
        volumeMultiplier,
        shouldReduceVolume and Config.vcVolume or 1,
        FrameTime() * ( shouldReduceVolume and 4 or 1 )
    )
end )
