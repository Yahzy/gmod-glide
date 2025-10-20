
local EyePos = EyePos
local Effect = util.Effect
local EffectData = EffectData
local EmitSound = EmitSound

local GetVolume = Glide.Config.GetVolume
local PlaySoundSet = Glide.PlaySoundSet
local IsUnderWater = Glide.IsUnderWater

local MAX_DETAIL_DISTANCE = 4000 * 4000

function Glide.CreateExplosion( pos, normal )
    local volume = GetVolume( "explosionVolume" )
    local isUnderWater = IsUnderWater( pos )

    if pos:DistToSqr( EyePos() ) < MAX_DETAIL_DISTANCE then
        PlaySoundSet( "Glide.Explosion.Impact", pos, volume )
        PlaySoundSet( "Glide.Explosion.Metal", pos, volume )

        if isUnderWater then
            EmitSound( ")glide/collisions/land_on_water_1.wav", pos, 0, 6, volume, 90 )
            EmitSound( "WaterExplosionEffect.Sound", pos, 0, 6, volume, 100 )
        else
            EmitSound( "glide/explosions/impact_fire.wav", pos, 0, 6, volume * 0.8, 95 )
            PlaySoundSet( "Glide.Explosion.PreImpact", pos, volume )
        end
    end

    if isUnderWater then
        pos = Glide.FindWaterSurfaceAbove( pos, 500 ) or pos

        local eff = EffectData()
        eff:SetOrigin( pos )
        eff:SetScale( 100 )
        eff:SetFlags( 2 )
        eff:SetNormal( normal )
        Effect( "WaterSplash", eff, true, true )
    else
        local eff = EffectData()
        eff:SetOrigin( pos )
        eff:SetNormal( normal )
        eff:SetScale( 1 )
        Effect( "glide_explosion", eff )
    end

    PlaySoundSet( "Glide.Explosion.Distant", pos, volume )
end
