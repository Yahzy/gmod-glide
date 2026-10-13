local commands = {}

commands[Glide.CMD_INPUT_SETTINGS] = function( ply )
    local data = Glide.ReadTable()

    Glide.PrintDev( "Received input data from %s <%s>", ply:Nick(), ply:SteamID() )
    Glide.SetupPlayerInput( ply, data )
end

commands[Glide.CMD_SWITCH_SEATS] = function( ply )
    local seatIndex = net.ReadUInt( 5 )
    Glide.SwitchSeat( ply, seatIndex )
end

commands[Glide.CMD_SET_HEADLIGHTS] = function( ply )
    local toggle = net.ReadBool()
    local veh = ply:GlideGetVehicle()

    if IsValid( veh ) and ply:GlideGetSeatIndex() == 1 and veh.SetHeadlightState then
        veh:ChangeHeadlightState( toggle and 2 or 0 )
    end
end

-- Store the last entity the CLIENT told it was aiming at.
-- Used for lag compensation on turrets.
local lastAimEntity = Glide.lastAimEntity or {}

Glide.lastAimEntity = lastAimEntity

commands[Glide.CMD_LAST_AIM_ENTITY] = function( ply )
    local ent = net.ReadEntity()

    if IsValid( ent ) then
        lastAimEntity[ply] = ent
    end
end

-- Safeguard against spam
local cooldowns = {
    [Glide.CMD_INPUT_SETTINGS] = { interval = 1, players = {} },
    [Glide.CMD_SWITCH_SEATS] = { interval = 0.5, players = {} },
    [Glide.CMD_SET_HEADLIGHTS] = { interval = 0.5, players = {} },
    [Glide.CMD_LAST_AIM_ENTITY] = { interval = 0.01, players = {} }
}

-- Receive and validate network commands
net.Receive( "glide.command", function( _, ply )
    local id = ply:SteamID()
    local cmd = net.ReadUInt( Glide.CMD_SIZE )

    if not commands[cmd] then
        Glide.Print( "%s <%s> sent a unknown network command! (%d)", ply:Nick(), id, cmd )
        return
    end

    local cooldown = cooldowns[cmd]
    if not cooldown then return end

    local t = RealTime()
    local players = cooldown.players

    if players[id] and players[id] > t then
        Glide.Print( "%s <%s> sent network commands too fast!", ply:Nick(), id )
        return
    end

    players[id] = t + cooldown.interval
    commands[cmd]( ply )
end )

-- Cleanup cooldown/last aim entity entries for this player
hook.Add( "PlayerDisconnected", "Glide.NetCleanup", function( ply )
    local id = ply:SteamID()

    for _, c in pairs( cooldowns ) do
        c.players[id] = nil
    end

    lastAimEntity[ply] = nil
end )

local type = type

local function ValidateTarget( target )
    if type( target ) == "table" then
        for _, ent in ipairs( target ) do
            if not IsValid( ent ) or not ent:IsPlayer() then
                return false
            end
        end

        return #target > 0
    end

    return IsValid( target ) and target:IsPlayer()
end
--- Apply a camera shake to the target's Glide camera.
function Glide.SendViewPunch( target, force )
    if not ValidateTarget( target ) then return end

    Glide.StartCommand( Glide.CMD_VIEW_PUNCH, false )
    net.WriteFloat( force )
    net.Send( target )
end