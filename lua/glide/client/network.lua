local commands = {}

commands[Glide.CMD_CREATE_EXPLOSION] = function()
    local pos = net.ReadVector()
    local normal = net.ReadVector()

    Glide.CreateExplosion( pos, normal )
end

commands[Glide.CMD_VIEW_PUNCH] = function()
    Glide.Camera:ViewPunch( net.ReadFloat() )
end

commands[Glide.CMD_FORCE_THIRDPERSON] = function()
    local useThirdPerson = net.ReadBool()
    Glide.Camera:SetFirstPerson( not useThirdPerson )
end

net.Receive( "glide.command", function()
    local cmd = net.ReadUInt( Glide.CMD_SIZE )

    if commands[cmd] then
        commands[cmd]()
    end
end )
