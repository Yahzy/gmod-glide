local BlastDamage = util.BlastDamage
local GetNearbyPlayers = Glide.GetNearbyPlayers

--- Utility function to deal damage and send a explosion event to nearby players.
function Glide.CreateExplosion( inflictor, attacker, origin, radius, damage, normal, explosionType )
    if not IsValid( inflictor ) then return end

    if not IsValid( attacker ) then
        attacker = inflictor
    end

    -- Deal damage
    BlastDamage( inflictor, attacker, origin, radius, damage )

    -- Let nearby players handle sounds and effects client side
    local targets, count = GetNearbyPlayers( origin, Glide.MAX_EXPLOSION_DISTANCE )

    -- Always let the attacker see/hear it too, if they are a player
    if attacker:IsPlayer() then
        count = count + 1
        targets[count] = attacker
    end

    if count == 0 then return end

    Glide.StartCommand( Glide.CMD_CREATE_EXPLOSION, true )
    net.WriteVector( origin )
    net.WriteVector( normal )
    net.WriteUInt( explosionType, 2 )
    net.Send( targets )

    util.ScreenShake( origin, explosionType == 2 and 0.5 or 5, 0.5, 1.0, 1500, true )
end