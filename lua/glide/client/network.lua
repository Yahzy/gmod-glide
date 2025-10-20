local commands = {}

commands[Glide.CMD_CREATE_EXPLOSION] = function()
    local pos = net.ReadVector()
    local normal = net.ReadVector()
    local explosionType = net.ReadUInt( 2 )

    Glide.CreateExplosion( pos, normal, explosionType )
end

commands[Glide.CMD_VIEW_PUNCH] = function()
    Glide.Camera:ViewPunch( net.ReadFloat() )
end

commands[Glide.CMD_SET_CURRENT_VEHICLE] = function()
    local ply = LocalPlayer()
    local vehicle = net.ReadEntity()
    local seatIndex = net.ReadUInt( 6 )

    -- BUG: ReadEntity returns `worldspawn` if a NULL entity was sent.
    -- In that case, using IsValid on `worldspawn` returns false, which
    -- we can use to detect if it was NULL.
    if not IsValid( vehicle ) then
        vehicle = NULL
    end

    ply:SetNWEntity( "GlideVehicle", vehicle )
    ply:SetNWInt( "GlideSeatIndex", seatIndex )
end

net.Receive( "glide.command", function()
    local cmd = net.ReadUInt( Glide.CMD_SIZE )

    if commands[cmd] then
        commands[cmd]()
    end
end )