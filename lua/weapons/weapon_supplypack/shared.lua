if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Paczka zaopatrzeniowa"
SWEP.Author = "Stary"
SWEP.Instructions = "LPM - rzuc paczke pod nogi. Uzupelnia HP, pancerz i amunicje w promieniu 5 m."
SWEP.Category = "Zaopatrzenie"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"
SWEP.HoldType = "grenade"
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_grenade.mdl"
SWEP.WorldModel = "models/weapons/w_grenade.mdl"
SWEP.ViewModelFOV = 62
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Slot = 4
SWEP.SlotPos = 2

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType("grenade")
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end

    local cfg = SupplyPack.Config
    local now = CurTime()

    -- Serwer pilnuje cooldownu rowniez przy zmianie lub ponownym nadaniu broni.
    if SERVER and now < (owner.SupplyPackNextThrow or 0) then
        self:SetNextPrimaryFire(owner.SupplyPackNextThrow)
        return
    end

    self:SetNextPrimaryFire(now + cfg.ThrowCooldown)
    self:SetNextSecondaryFire(now + cfg.ThrowCooldown)
    self:SendWeaponAnim(ACT_VM_THROW)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:EmitSound("WeaponFrag.Throw", 70, 100, 0.8)

    -- Encje fizyczne tworzymy wylacznie na serwerze.
    if CLIENT then return end

    local eyeAng = owner:EyeAngles()
    local forward = Angle(0, eyeAng.y, 0):Forward()
    local startPos = owner:GetPos() + Vector(0, 0, 40)

    -- Nie spawnuj paczki w scianie znajdujacej sie przed graczem.
    local tr = util.TraceHull({
        start = startPos,
        endpos = startPos + forward * 45,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8),
        filter = owner,
        mask = MASK_SOLID
    })

    local pack = ents.Create("ent_supplypack")
    if not IsValid(pack) then return end

    owner.SupplyPackNextThrow = now + cfg.ThrowCooldown

    pack:SetPos(tr.HitPos)
    pack:SetAngles(Angle(0, eyeAng.y, 0))
    pack:SetOwner(owner)
    pack:Spawn()
    pack:Activate()

    -- Jedna aktywna paczka na gracza (zabezpieczenie przed spamem).
    if IsValid(owner.SupplyPackActive) then
        owner.SupplyPackActive:Remove()
    end
    owner.SupplyPackActive = pack

    local phys = pack:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(forward * 165 + Vector(0, 0, 95) + owner:GetVelocity() * 0.2)
        phys:AddAngleVelocity(Vector(0, 100, 30))
    end
end

function SWEP:SecondaryAttack()
    -- Brak alternatywnego ataku.
end

function SWEP:Reload()
    -- Paczka odnawia sie automatycznie po czasie cooldownu.
end
