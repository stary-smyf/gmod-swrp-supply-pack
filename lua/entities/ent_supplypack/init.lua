AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MODEL = "models/custom/scifiboxes/crate_d.mdl"
local MODEL_SCALE = 0.7
local COLLISION_SCALE = 0.5
local COLLISION_TOP_INSET = 10
local RESUPPLY_SOUNDS = {
    Health = "items/smallmedkit1.wav",
    Armor = "items/battery_pickup.wav",
    Ammo = "items/ammo_pickup.wav"
}
local RESUPPLY_SOUND_INTERVAL = 1

function ENT:Initialize()
    local cfg = SupplyPack.Config

    self:SetModel(MODEL)
    self:SetColor(cfg.BoxColor)
    self:SetModelScale(MODEL_SCALE, 0)
    -- Always use an explicit box, independent of the model's physics mesh.
    -- Player movement and physics must use the same rotated box.
    local mins, maxs = self:GetModelBounds()
    mins = mins * MODEL_SCALE
    maxs = maxs * MODEL_SCALE
    -- Inset the hull, preserving its bottom so the crate rests on the floor.
    local center = (mins + maxs) * 0.5
    local halfSize = (maxs - mins) * (COLLISION_SCALE * 0.5)
    center.z = mins.z + halfSize.z
    mins, maxs = center - halfSize, center + halfSize
    -- Lower only the lid; keep the base and side clearances unchanged.
    maxs.z = math.max(mins.z + 1, maxs.z - COLLISION_TOP_INSET)
    self:SetCrateCollisionMins(mins)
    self:SetCrateCollisionMaxs(maxs)
    self:PhysicsInitBox(mins, maxs)
    self:SetSolid(SOLID_VPHYSICS)
    -- SetCollisionBounds is also affected by model scale; avoid scaling twice.
    self:SetCollisionBounds(mins / MODEL_SCALE, maxs / MODEL_SCALE)
    self:EnableCustomCollisions()
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(5)
        phys:EnableCollisions(true)
        local upright = constraint.Keepupright(self, Angle(0, self:GetAngles().y, 0), 0, 999999)
        if IsValid(upright) then
            self:DeleteOnRemove(upright)
        end
    end

    self.ExpireAt = CurTime() + cfg.Lifetime
    self.NextPulseAt = CurTime() + cfg.PulseInterval
    self.NextAmmoPulseAt = CurTime() + cfg.AmmoPulseInterval
end

function ENT:PhysicsCollide(data)
    if self.Settled or self.SettlePending or math.abs(data.HitNormal.z) < 0.7 then return end
    local support = data.HitEntity
    if not IsValid(support) and not support:IsWorld() then return end
    local supportPhys = support:GetPhysicsObject()
    if not support:IsWorld() and (not IsValid(supportPhys) or supportPhys:IsMotionEnabled()) then return end

    self.SettlePending = true
    -- Physics objects must be frozen outside the collision callback.
    timer.Simple(0, function()
        if not IsValid(self) then return end
        self.SettlePending = nil
        local mins, maxs = self:GetCrateCollisionMins(), self:GetCrateCollisionMaxs()
        local bottom = self:LocalToWorld(Vector((mins.x + maxs.x) * 0.5,
            (mins.y + maxs.y) * 0.5, mins.z))
        local ground = util.TraceLine({
            start = bottom + Vector(0, 0, 4),
            endpos = bottom - Vector(0, 0, 8),
            filter = self,
            mask = MASK_SOLID
        })
        if not ground.Hit or ground.HitNormal.z < 0.7 or ground.Entity ~= support then return end
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            self.Settled = true
        end
    end)
end

function ENT:Use(activator)
    if self.PickedUp or CurTime() >= self.ExpireAt then return end
    if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive()
        or activator ~= self.SupplyPackOwner then return end

    self.PickedUp = true
    local nextThrow = CurTime() + SupplyPack.Config.PickupCooldown
    activator.SupplyPackNextThrow = nextThrow
    activator:SetNWFloat("SupplyPackCooldownDuration", SupplyPack.Config.PickupCooldown)
    activator:SetNWFloat("SupplyPackNextThrow", nextThrow)

    -- Replace the old weapon cooldown as well as the player-wide cooldown.
    for _, weapon in ipairs(activator:GetWeapons()) do
        if weapon:GetClass() == "weapon_supplypack" then
            weapon:SetNextPrimaryFire(nextThrow)
            weapon:SetNextSecondaryFire(nextThrow)
        end
    end

    self:Remove()
end

local function AddAmmoForWeapons(ply, cfg)
    -- Give each ammo type once, even when several weapons share it.
    local ammoTypes = {}
    local function AddAmmoType(ammoID, declaredAmmo)
        -- Some scripted weapons expose their ammo name before the engine ID.
        if not isnumber(ammoID) or ammoID < 0 then
            if not isstring(declaredAmmo) then return end
            ammoID = game.GetAmmoID(declaredAmmo)
        end
        if not isnumber(ammoID) or ammoID < 0 or not game.GetAmmoName(ammoID) then return end
        ammoTypes[ammoID] = true
    end

    for _, weapon in ipairs(ply:GetWeapons()) do
        if IsValid(weapon) then
            local primary = weapon:GetPrimaryAmmoType()
            local secondary = weapon:GetSecondaryAmmoType()

            AddAmmoType(primary, weapon.Primary and weapon.Primary.Ammo)
            AddAmmoType(secondary, weapon.Secondary and weapon.Secondary.Ammo)
        end
    end

    local changed = false
    for ammoID in pairs(ammoTypes) do
        local current = ply:GetAmmoCount(ammoID)
        local ammoName = string.lower(game.GetAmmoName(ammoID))
        local cap = (cfg.AmmoReserveCaps and cfg.AmmoReserveCaps[ammoName]) or cfg.AmmoReserveCap
        local target = math.min(current + cfg.AmmoPerPulse, cap)
        if target > current then
            -- Set the reserve directly so lower engine pickup limits cannot block it.
            ply:SetAmmo(target, ammoID)
            changed = (ply:GetAmmoCount(ammoID) > current) or changed
        end
    end

    return changed
end

function ENT:SupplyPulse(healthArmorDue, ammoDue)
    local cfg = SupplyPack.Config
    local radiusSqr = cfg.Radius * cfg.Radius
    local origin = self:GetPos()
    local now = CurTime()

    -- Znajdujemy graczy w poblizu, ale mierzymy rzeczywista odleglosc
    -- od ich pozycji (FindInSphere moze uwzgledniac granice modelu).
    for _, ply in ipairs(ents.FindInSphere(origin, cfg.Radius + 72)) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive()
            and ply:GetPos():DistToSqr(origin) <= radiusSqr then
            local resupplySound

            local maxHP = math.max(1, ply:GetMaxHealth())
            if healthArmorDue and ply:Health() < maxHP then
                ply:SetHealth(math.min(maxHP, ply:Health() + cfg.HealthPerPulse))
                resupplySound = RESUPPLY_SOUNDS.Health
            end

            local maxArmor = ply:GetMaxArmor()
            if not maxArmor or maxArmor <= 0 then maxArmor = 100 end
            if healthArmorDue and ply:Armor() < maxArmor then
                ply:SetArmor(math.min(maxArmor, ply:Armor() + cfg.ArmorPerPulse))
                resupplySound = resupplySound or RESUPPLY_SOUNDS.Armor
            end

            if ammoDue and AddAmmoForWeapons(ply, cfg) then
                resupplySound = resupplySound or RESUPPLY_SOUNDS.Ammo
            end

            -- Share the cooldown across crates to avoid overlapping pickup sounds.
            if resupplySound and now >= (ply.SupplyPackNextResupplySound or 0) then
                ply:EmitSound(resupplySound, 65, 100, 0.65)
                ply.SupplyPackNextResupplySound = now + RESUPPLY_SOUND_INTERVAL
            end
        end
    end

end

function ENT:Think()
    local now = CurTime()
    if now >= self.ExpireAt then
        self:Remove()
        return
    end

    local cfg = SupplyPack.Config
    self.NextAmmoPulseAt = self.NextAmmoPulseAt or (now + cfg.AmmoPulseInterval)
    local healthArmorDue = now >= self.NextPulseAt
    local ammoDue = now >= self.NextAmmoPulseAt
    if healthArmorDue or ammoDue then
        self:SupplyPulse(healthArmorDue, ammoDue)
        if healthArmorDue then
            self.NextPulseAt = now + cfg.PulseInterval
        end
        if ammoDue then
            self.NextAmmoPulseAt = now + cfg.AmmoPulseInterval
        end
    end

    self:NextThink(math.min(self.NextPulseAt, self.NextAmmoPulseAt, self.ExpireAt))
    return true
end

function ENT:OnRemove()
    self:ClearTraceShape()
    -- Nie zachowujemy wskaznika do usunietej paczki.
    local owner = self.SupplyPackOwner
    if IsValid(owner) and owner.SupplyPackActive == self then
        owner.SupplyPackActive = nil
    end
end
