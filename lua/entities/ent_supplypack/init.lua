AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MODEL = "models/items/boxmrounds.mdl" -- standardowy model pudelka amunicji HL2/GMod

function ENT:Initialize()
    local cfg = SupplyPack.Config

    self:SetModel(MODEL)
    self:SetColor(Color(140, 220, 155))
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(5)
    end

    self.ExpireAt = CurTime() + cfg.Lifetime
    self.NextPulseAt = CurTime() + cfg.PulseInterval
    self.LastSoundAt = 0
end

local function AddAmmoForWeapons(ply, cfg)
    -- Zbieramy unikalne rodzaje amunicji ze wszystkich posiadanych broni.
    local ammoTypes = {}
    for _, weapon in ipairs(ply:GetWeapons()) do
        if IsValid(weapon) then
            local primary = weapon:GetPrimaryAmmoType()
            local secondary = weapon:GetSecondaryAmmoType()

            if isnumber(primary) and primary >= 0 then
                ammoTypes[primary] = true
            end
            if isnumber(secondary) and secondary >= 0 then
                ammoTypes[secondary] = true
            end
        end
    end

    local changed = false
    for ammoID in pairs(ammoTypes) do
        local engineLimit = game.GetAmmoMax(ammoID)

        -- -2 oznacza amunicje bez limitu; nie nadpisujemy tej zasady.
        if engineLimit ~= -2 then
            local cap = cfg.AmmoReserveCap
            if engineLimit and engineLimit > 0 then
                cap = math.min(cap, engineLimit)
            end

            local current = ply:GetAmmoCount(ammoID)
            if current < cap then
                local added = ply:GiveAmmo(math.min(cfg.AmmoPerPulse, cap - current), ammoID, true)
                changed = changed or (added > 0)
            end
        end
    end

    return changed
end

function ENT:SupplyPulse()
    local cfg = SupplyPack.Config
    local radiusSqr = cfg.Radius * cfg.Radius
    local origin = self:GetPos()
    local somethingChanged = false

    -- Znajdujemy graczy w poblizu, ale mierzymy rzeczywista odleglosc
    -- od ich pozycji (FindInSphere moze uwzgledniac granice modelu).
    for _, ply in ipairs(ents.FindInSphere(origin, cfg.Radius + 72)) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive()
            and ply:GetPos():DistToSqr(origin) <= radiusSqr then

            local maxHP = math.max(1, ply:GetMaxHealth())
            if ply:Health() < maxHP then
                ply:SetHealth(math.min(maxHP, ply:Health() + cfg.HealthPerPulse))
                somethingChanged = true
            end

            local maxArmor = ply:GetMaxArmor()
            if not maxArmor or maxArmor <= 0 then maxArmor = 100 end
            if ply:Armor() < maxArmor then
                ply:SetArmor(math.min(maxArmor, ply:Armor() + cfg.ArmorPerPulse))
                somethingChanged = true
            end

            if AddAmmoForWeapons(ply, cfg) then
                somethingChanged = true
            end
        end
    end

    if somethingChanged and CurTime() >= self.LastSoundAt + 2 then
        self:EmitSound("items/suitchargeok1.wav", 58, 115, 0.35)
        self.LastSoundAt = CurTime()
    end
end

function ENT:Think()
    local now = CurTime()
    if now >= self.ExpireAt then
        self:Remove()
        return
    end

    if now >= self.NextPulseAt then
        self:SupplyPulse()
        self.NextPulseAt = now + SupplyPack.Config.PulseInterval
    end

    self:NextThink(math.min(self.NextPulseAt, self.ExpireAt))
    return true
end

function ENT:OnRemove()
    -- Nie zachowujemy wskaznika do usunietej paczki.
    local owner = self:GetOwner()
    if IsValid(owner) and owner.SupplyPackActive == self then
        owner.SupplyPackActive = nil
    end
end
