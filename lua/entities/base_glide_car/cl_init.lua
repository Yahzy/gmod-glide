include( "shared.lua" )

ENT.AutomaticFrameAdvance = true

--- Implement this base class function.
function ENT:OnPostInitialize()
    self.slowBrakePressure = 0
    self.fastBrakePressure = 0
    self.turboInertia = 0

    self.rpmFraction = 0
    self.streamJSONOverride = nil
end

function ENT:OnGearChange( _, _, gear )
    if self.lastGear then
        self.doWobble = gear > 1 and gear > self.lastGear
    end

    self.lastGear = gear

    if self.stream and self.stream.firstPerson then
        if self.InternalGearSwitchSound ~= "" then
            Glide.PlaySoundSet( self.InternalGearSwitchSound, self )
        end

    elseif self.ExternalGearSwitchSound ~= "" then
        Glide.PlaySoundSet( self.ExternalGearSwitchSound, self )
    end
end

local GetVolume = Glide.Config.GetVolume

--- Implement this base class function.
function ENT:OnTurnOn()
    if self.StartedSound ~= "" then
        Glide.PlaySoundSet( self.StartedSound, self, GetVolume( "carVolume" ), nil, 85 )
    end
end

--- Implement this base class function.
function ENT:OnTurnOff()
    if self.StoppedSound ~= "" then
        Glide.PlaySoundSet( self.StoppedSound, self, GetVolume( "carVolume" ), nil, 85 )
    end

    self:DeactivateSounds()
end

--- Implement this base class function.
function ENT:OnActivateMisc()
    self.slowBrakePressure = 0
    self.fastBrakePressure = 0
    self.rpmFraction = 0
    self.turboInertia = 0
end

--- Implement this base class function.
function ENT:OnDeactivateSounds()
    if self.stream then
        self.stream:Destroy()
        self.stream = nil
    end
end

local Clamp = math.Clamp
local FrameTime = FrameTime
local ExpDecay = Glide.ExpDecay

function ENT:UpdateTurboSound( sounds, dt )
    local lastInertia = self.turboInertia
    local inertia = ExpDecay( lastInertia, self:GetEngineThrottle(), 1, dt )

    if inertia < lastInertia and inertia > 0.6 and self.rpmFraction > 0.5 and self.TurboBlowoffSound ~= "" then
        self:EmitSound( self.TurboBlowoffSound, 80, math.random( 100, 110 ), self.TurboBlowoffVolume * inertia )
        inertia = 0
    end

    if inertia > 0.2 then
        local volume = inertia * 0.5 * GetVolume( "carVolume" )
        local pitch = self.TurboPitch * 0.5
        pitch = pitch + self.rpmFraction * pitch

        if sounds.turbo then
            sounds.turbo:ChangeVolume( volume )
            sounds.turbo:ChangePitch( pitch )

        elseif self.TurboLoopSound ~= "" then
            local snd = self:CreateLoopingSound( "turbo", self.TurboLoopSound, 80, self )
            snd:PlayEx( volume, pitch )
        end

    elseif sounds.turbo then
        sounds.turbo:Stop()
        sounds.turbo = nil
    end

    self.turboInertia = inertia
end

local Min = math.min
local Pow = math.pow

--- Implement this base class function.
function ENT:OnUpdateSounds()
    local sounds = self.sounds

    local dt = FrameTime()
    local isSirenEnabled = self.lastSirenEnableTime and CurTime() - self.lastSirenEnableTime > 0.25
    local isHonking = self:GetIsHonking()

    if isHonking and self.HornSound then
        local volume = GetVolume( "hornVolume" ) * ( isSirenEnabled and self.SirenVolume or 1 )

        if sounds.horn then
            sounds.horn:ChangeVolume( volume )
        else
            local snd = self:CreateLoopingSound( "horn", isSirenEnabled and self.SirenLoopAltSound or self.HornSound, 85, self )
            snd:PlayEx( volume, 100 )
        end

    elseif sounds.horn then
        if sounds.horn:GetVolume() > 0 then
            sounds.horn:ChangeVolume( sounds.horn:GetVolume() - dt * 8 )
        else
            sounds.horn:Stop()
            sounds.horn = nil
        end
    end

    if isSirenEnabled and not isHonking then
        if sounds.siren then
            sounds.siren:ChangeVolume( self.SirenVolume * GetVolume( "hornVolume" ) )
        else
            local snd = self:CreateLoopingSound( "siren", self.SirenLoopSound, 90, self )
            snd:PlayEx( self.SirenVolume * GetVolume( "hornVolume" ), 100 )
        end

    elseif sounds.siren then
        sounds.siren:Stop()
        sounds.siren = nil
    end

    -- Brake sounds
    local brake = self:IsEngineOn() and self:GetBrakeValue() or 0

    if brake > 0.1 then
        local isSlow = self:GetVelocity():LengthSqr() < 1000

        self.slowBrakePressure = Min( isSlow and self.slowBrakePressure + dt or 0, 1 )
        self.fastBrakePressure = Min( isSlow and 0 or self.fastBrakePressure + dt, 1 )
    else
        if self.slowBrakePressure > 0.5 and self.BrakeReleaseSound ~= "" then
            Glide.PlaySoundSet( self.BrakeReleaseSound, self, 0.8 )
        end

        self.slowBrakePressure = 0
        self.fastBrakePressure = 0
    end

    if self.fastBrakePressure > 0.1 then
        if sounds.brakeLoop then
            sounds.brakeLoop:ChangeVolume( ( self.fastBrakePressure - 0.1 ) * self.BrakeLoopVolume * brake )

        elseif self.BrakeLoopSound ~= "" then
            local snd = self:CreateLoopingSound( "brakeLoop", self.BrakeLoopSound, 80, self )
            snd:PlayEx( 0.0, 100 )
        end

    elseif sounds.brakeLoop then
        sounds.brakeLoop:Stop()
        sounds.brakeLoop = nil

        if self.BrakeSqueakSound ~= "" then
            Glide.PlaySoundSet( self.BrakeSqueakSound, self, 0.8 )
        end
    end

    if self.IsAmphibious then
        self:DoWaterSounds()
    end

    if not self:IsEngineOn() then return end

    if self:GetGear() == -1 and self.ReverseSound ~= "" then
        if not sounds.reverse then
            local snd = self:CreateLoopingSound( "reverse", self.ReverseSound, 85, self )
            snd:PlayEx( GetVolume( "hornVolume" ) * 0.9, 100 )
        end

    elseif sounds.reverse then
        sounds.reverse:Stop()
        sounds.reverse = nil
    end

    if self:GetTurboCharged() then
        self:UpdateTurboSound( sounds, dt )

    elseif sounds.turbo then
        sounds.turbo:Stop()
        sounds.turbo = nil
    end

    -- Handle the engine sound
    local stream = self.stream

    if not stream then
        if self:GetEngineState() < 3 then
            self.stream = Glide.CreateEngineStream( self )

            if self.streamJSONOverride then
                self.stream:LoadJSON( self.streamJSONOverride )
            else
                self:OnCreateEngineStream( self.stream )
            end

            self.stream:Play()
        end

        return
    end

    stream.firstPerson = self.isLocalPlayerInFirstPerson

    local health = self:GetEngineHealth()
    local engineThrottle = self:GetEngineThrottle()
    local inputs = stream.inputs

    if engineThrottle > inputs.throttle and self.doWobble then
        stream.wobbleTime = 1
    end

    inputs.rpmFraction = self.rpmFraction or 0
    inputs.throttle = Pow( engineThrottle, 0.6 )

    local isRedlining = self:GetIsRedlining() and inputs.throttle > 0.9

    if isRedlining ~= stream.isRedlining then
        stream.isRedlining = isRedlining

        if not isRedlining and inputs.rpmFraction > 0.5 and ( self:GetGear() < 3 or health < 0.1 ) then
            self:DoExhaustPop()
        end
    end

    -- Handle damaged engine sounds
    if health < 0.4 then
        if sounds.runDamaged then
            sounds.runDamaged:ChangePitch( 100 + self.rpmFraction * 20 )
            sounds.runDamaged:ChangeVolume( Clamp( ( 0.75 - health ) + inputs.throttle, 0, 1 ) * 0.8 )
        else
            local snd = self:CreateLoopingSound( "runDamaged", "glide/engines/run_damaged_1.wav", 75, self )
            snd:PlayEx( 0.5, 100 )
        end

    elseif sounds.runDamaged then
        sounds.runDamaged:Stop()
        sounds.runDamaged = nil
    end

    if health < 0.6 then
        if sounds.rattle then
            sounds.rattle:ChangeVolume( Clamp( self.rpmFraction - inputs.throttle, 0, 1 ) * ( 1 - health ) * 0.9 )
        else
            local snd = self:CreateLoopingSound( "rattle", "glide/engines/exhaust_rattle.wav", 75, self )
            snd:PlayEx( 0.5, 100 )
        end

    elseif sounds.rattle then
        sounds.rattle:Stop()
        sounds.rattle = nil
    end
end

local CurTime = CurTime
local DrawLight = Glide.DrawLight
local DrawLightSprite = Glide.DrawLightSprite

local DEFAULT_SIREN_COLOR = Color( 255, 255, 255, 255 )

--- Implement this base class function.
function ENT:OnUpdateMisc()
    local dt = FrameTime()
    local rpmFraction = ( self:GetEngineRPM() - self:GetMinRPM() ) / ( self:GetMaxRPM() - self:GetMinRPM() )

    self.rpmFraction = ExpDecay( self.rpmFraction, rpmFraction, rpmFraction > self.rpmFraction and 7 or 4, dt )

    -- Siren lights/bodygroups
    local siren = self:GetSirenState()

    if self.lastSirenState ~= siren then
        self.lastSirenState = siren

        if siren > 1 then
            self.lastSirenEnableTime = CurTime()

        elseif self.lastSirenEnableTime then
            if CurTime() - self.lastSirenEnableTime < 0.25 then
                Glide.PlaySoundSet( self.SirenInterruptSound, self, self.SirenVolume )
            end

            self.lastSirenEnableTime = nil
        end

        -- Set bodygroups to default
        for _, v in ipairs( self.SirenLights ) do
            if v.bodygroup then
                self:SetBodygroup( v.bodygroup, 0 )
            end
        end
    end

    if siren < 1 then return end

    local myPos = self:GetPos()
    local t = ( CurTime() % self.SirenCycle ) / self.SirenCycle
    local on, pos, dir, radius

    local bodygroupState = {}

    for _, v in ipairs( self.SirenLights ) do
        on = t > v.time and t < v.time + ( v.duration or 0.125 )

        -- Check for optional bodygroup requirement
        if v.ifBodygroupId then
            on = on and self:GetBodygroup( v.ifBodygroupId ) == ( v.ifSubModelId or 0 )
        end

        if on and v.offset then
            pos = self:LocalToWorld( v.offset )
            radius = v.lightRadius or 200

            if radius > 0 then
                DrawLight( pos, v.color or DEFAULT_SIREN_COLOR, radius )
            end

            dir = v.dir and self:LocalToWorld( v.dir ) - myPos or nil
            DrawLightSprite( pos, dir, v.size or 30, v.color or DEFAULT_SIREN_COLOR, v.spriteMaterial )
        end

        -- Merge multiple bodygroup entries so that any one of them can "enable" a bodygroup
        if v.bodygroup then
            bodygroupState[v.bodygroup] = bodygroupState[v.bodygroup] or on
        end
    end

    for id, state in pairs( bodygroupState ) do
        self:SetBodygroup( id, state and 1 or 0 )
    end
end

local DEFAULT_EXHAUST_ANG = Angle()
local EXHAUST_COLOR = Color( 255, 190, 100 )

function ENT:DoExhaustPop()
    if self:GetEngineHealth() < 0.3 then
        Glide.PlaySoundSet( "Glide.Damaged.ExhaustPop", self )

    elseif self.ExhaustPopSound == "" then
        return
    end

    Glide.PlaySoundSet( self.ExhaustPopSound, self )

    local eff = EffectData()
    eff:SetEntity( self )

    local emit

    for _, v in ipairs( self.ExhaustOffsets ) do
        emit = true

        -- Check for optional bodygroup requirement
        if v.ifBodygroupId then
            emit = self:GetBodygroup( v.ifBodygroupId ) == ( v.ifSubModelId or 0 )
        end

        if emit then
            local pos = self:LocalToWorld( v.pos )
            local dir = -self:LocalToWorldAngles( v.ang or v.angle or DEFAULT_EXHAUST_ANG ):Forward()

            eff:SetOrigin( pos )
            eff:SetStart( pos + dir * 10 )
            eff:SetScale( 0.5 )
            eff:SetFlags( 0 )
            eff:SetColor( 0 )
            util.Effect( "glide_tracer", eff )

            DrawLight( pos + dir * 50, EXHAUST_COLOR, 80 )
        end
    end
end

local Effect = util.Effect
local EffectData = EffectData

--- Implement this base class function.
function ENT:OnUpdateParticles()
    local rpmFraction = self.rpmFraction
    local velocity = self:GetVelocity()

    if rpmFraction < 0.5 and self:IsEngineOn() then
        rpmFraction = rpmFraction * 2

        local emit

        for _, v in ipairs( self.ExhaustOffsets ) do
            emit = true

            -- Check for optional bodygroup requirement
            if v.ifBodygroupId then
                emit = self:GetBodygroup( v.ifBodygroupId ) == ( v.ifSubModelId or 0 )
            end

            if emit then
                local eff = EffectData()
                eff:SetOrigin( self:LocalToWorld( v.pos ) )
                eff:SetAngles( self:LocalToWorldAngles( v.ang or v.angle or DEFAULT_EXHAUST_ANG ) )
                eff:SetStart( velocity )
                eff:SetScale( v.scale or 1 )
                eff:SetColor( self.ExhaustAlpha )
                eff:SetMagnitude( rpmFraction * 1000 )
                Effect( "glide_exhaust", eff, true, true )
            end
        end
    end

    if self.IsAmphibious and self:GetWaterState() > 0 then
        local throttle = self:GetGear() > 0 and self:GetEngineThrottle() or 0
        self:DoWaterParticles( rpmFraction, throttle )
    end

    local health = self:GetEngineHealth()
    if health > 0.6 then return end

    local color = Clamp( health * 255, 0, 255 )
    local scale = 2 - health * 2

    for _, v in ipairs( self.EngineSmokeStrips ) do
        local eff = EffectData()
        eff:SetOrigin( self:LocalToWorld( v.offset ) )
        eff:SetAngles( self:LocalToWorldAngles( v.angle or DEFAULT_EXHAUST_ANG ) )
        eff:SetStart( velocity )
        eff:SetColor( color )
        eff:SetMagnitude( v.width * 1000 )
        eff:SetScale( scale )
        eff:SetRadius( self.EngineSmokeMaxZVel )
        Effect( "glide_damaged_engine", eff, true, true )
    end
end

DEFINE_BASECLASS( "base_glide" )