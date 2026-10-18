if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("supplypack/cl_medical_symbol.lua")
end

SWEP.PrintName = "Supply Crate"
SWEP.Author = "StarySmyf"
SWEP.Instructions = "LMB - throw crate, E - Pick up crate"
SWEP.Category = "Supply Crate"
SWEP.IconOverride = "entities/weapon_supplypack.png"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"
SWEP.HoldType = "shotgun"
SWEP.UseHands = false
SWEP.ViewModel = "models/custom/scifiboxes/crate_d.mdl"
SWEP.ViewModelScale = 0.8
SWEP.WorldModel = "models/custom/scifiboxes/crate_d.mdl"
SWEP.WorldModelScale = 0.4
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

function SWEP:UpdateSupplyPackHoldType()
    local owner = self:GetOwner()
    local nextThrow = self:GetNextPrimaryFire()
    if IsValid(owner) then
        nextThrow = math.max(nextThrow, owner:GetNWFloat("SupplyPackNextThrow", 0))
        if SERVER then
            nextThrow = math.max(nextThrow, owner.SupplyPackNextThrow or 0)
        end
    end

    local holdType = CurTime() < nextThrow and "normal" or self.HoldType
    if self:GetHoldType() ~= holdType then
        self:SetHoldType(holdType)
    end
end

function SWEP:Initialize()
    self:UpdateSupplyPackHoldType()
    self:SetColor(SupplyPack.Config.BoxColor)
end

function SWEP:Deploy()
    self:UpdateSupplyPackHoldType()
    return true
end

function SWEP:Think()
    self:UpdateSupplyPackHoldType()
    -- Refresh weapons that were already spawned before the color changed.
    self:SetColor(SupplyPack.Config.BoxColor)
end

if CLIENT then
    -- Refresh the renderer along with the SWEP instead of retaining an older helper.
    include("supplypack/cl_medical_symbol.lua")

    -- Follow the player's confirmed cooldown even while another weapon is selected.
    local wasCoolingDown = false
    hook.Add("Think", "SupplyPack.CooldownReadySound", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() or not ply:HasWeapon("weapon_supplypack") then
            wasCoolingDown = false
            return
        end

        local nextThrow = ply:GetNWFloat("SupplyPackNextThrow", 0)
        if nextThrow > CurTime() then
            wasCoolingDown = true
        elseif wasCoolingDown then
            wasCoolingDown = false
            if nextThrow > 0 then
                surface.PlaySound(SupplyPack.Config.CooldownReadySound or "buttons/button14.wav")
            end
        end
    end)

    local HUD_TRACK = Color(55, 58, 65, 230)
    local HUD_COOLDOWN = Color(158, 155, 155)
    local HUD_READY = Color(85, 200, 120)
    local WORLD_MODEL_BASE_COLOR = Color(255, 255, 255)


    function SWEP:DrawHUD()
        local owner = self:GetOwner()
        if not IsValid(owner) or owner ~= LocalPlayer() or not owner:Alive() then return end

        local nextThrow = owner:GetNWFloat("SupplyPackNextThrow", 0)
        local duration = owner:GetNWFloat("SupplyPackCooldownDuration", SupplyPack.Config.ThrowCooldown)
        -- Include predicted throws before the server's cooldown reaches the client.
        if self:GetNextPrimaryFire() > nextThrow then
            nextThrow = self:GetNextPrimaryFire()
            duration = SupplyPack.Config.ThrowCooldown
        end
        local remaining = math.max(0, nextThrow - CurTime())
        local progress = 1 - math.Clamp(remaining / math.max(duration, 0.001), 0, 1)
        local width, height = math.min(320, ScrW() - 32), 48
        local x, y = (ScrW() - width) * 0.5, ScrH() - height - 32

        draw.RoundedBox(3, x + 10, y - 500, width - 20, 8, HUD_TRACK)
        if progress > 0 then
            draw.RoundedBox(3, x + 10, y - 500, (width - 20) * progress, 8,
                remaining > 0 and HUD_COOLDOWN or HUD_READY)
        end
    end

    function SWEP:GetCrateWorldModelTransform()
        local owner = self:GetOwner()
        if not IsValid(owner) then return self:GetPos(), self:GetAngles() end

        local ang = owner:EyeAngles()
        local modelAng = Angle(ang.p, ang.y, ang.r)
        modelAng:RotateAroundAxis(ang:Up(), 90)

        local rightBone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        local leftBone = owner:LookupBone("ValveBiped.Bip01_L_Hand")
        local rightHand = rightBone and owner:GetBoneMatrix(rightBone)
        local leftHand = leftBone and owner:GetBoneMatrix(leftBone)
        local grip = owner:GetPos() + owner:GetUp() * 50 + ang:Forward() * 20
        if rightHand then
            grip = rightHand:GetTranslation()
            if leftHand then
                grip = (grip + leftHand:GetTranslation()) * 0.5
            end
        end

        -- The crate origin is at its base; rest the bottom on the player's hands.
        return grip + modelAng:Up() * 2, modelAng
    end

    function SWEP:DrawWorldModel(flags)
        local owner = self:GetOwner()
        if IsValid(owner) and CurTime() < math.max(self:GetNextPrimaryFire(),
            owner:GetNWFloat("SupplyPackNextThrow", 0)) then return end

        if not IsValid(self.SupplyPackWorldModel) then
            self.SupplyPackWorldModel = ClientsideModel(self.WorldModel)
            if not IsValid(self.SupplyPackWorldModel) then return end
            self.SupplyPackWorldModel:SetNoDraw(true)
        end

        local model = self.SupplyPackWorldModel
        -- Apply the configured tint once, directly in the model's render pass.
        local color = SupplyPack.Config.BoxColor
        model:SetColor(WORLD_MODEL_BASE_COLOR)
        model:SetModelScale(self.WorldModelScale, 0)
        local pos, ang = self:GetCrateWorldModelTransform()
        model:SetPos(pos)
        model:SetAngles(ang)
        model:SetupBones()
        -- Do not inherit a red modulation left by a viewmodel render pass.
        local r, g, b = render.GetColorModulation()
        render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
        model:DrawModel(flags)
        SupplyPack.DrawMedicalSymbol(model)
        render.SetColorModulation(r, g, b)
    end

    function SWEP:OnRemove()
        if IsValid(self.SupplyPackWorldModel) then
            self.SupplyPackWorldModel:Remove()
        end
        self.SupplyPackWorldModel = nil
    end

    function SWEP:GetViewModelPosition(pos, ang)
        local modelPos = pos + ang:Forward() * 60 + ang:Right() * 10 - ang:Up() * 48
        local modelAng = Angle(ang.p, ang.y, ang.r)
        modelAng:RotateAroundAxis(ang:Up(), 90)
        return modelPos, modelAng
    end

    function SWEP:PreDrawViewModel(vm)
        local owner = self:GetOwner()
        local nextThrow = IsValid(owner) and owner:GetNWFloat("SupplyPackNextThrow", 0) or 0
        -- Predicted fire time hides it immediately; player state survives weapon switches.
        if CurTime() < math.max(self:GetNextPrimaryFire(), nextThrow) then
            return true
        end

        self.SupplyPackPreviousViewModelScale = vm:GetModelScale()
        self.SupplyPackPreviousViewModelColor = vm:GetColor()
        vm:SetModelScale(self.ViewModelScale, 0)
        vm:SetColor(SupplyPack.Config.BoxColor)
        -- Apply the tint directly to the first-person render pass.
        self.SupplyPackPreviousColorModulation = {render.GetColorModulation()}
        local color = SupplyPack.Config.BoxColor
        render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
    end

    function SWEP:PostDrawViewModel(vm)
        local previous = self.SupplyPackPreviousColorModulation
        if previous then
            render.SetColorModulation(previous[1], previous[2], previous[3])
            self.SupplyPackPreviousColorModulation = nil
        end
    end

    function SWEP:ViewModelDrawn(vm)
        if self.SupplyPackPreviousViewModelScale ~= nil then
            SupplyPack.DrawViewModelMedicalSymbol(vm)
        end
        -- The player shares this viewmodel entity with other weapons.
        vm:SetModelScale(self.SupplyPackPreviousViewModelScale or 1, 0)
        vm:SetColor(self.SupplyPackPreviousViewModelColor or Color(255, 255, 255))
        self.SupplyPackPreviousViewModelScale = nil
        self.SupplyPackPreviousViewModelColor = nil
    end
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
    self:UpdateSupplyPackHoldType()
    self:SendWeaponAnim(ACT_VM_THROW)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:EmitSound("WeaponFrag.Throw", 70, 100, 0.8)

    -- Encje fizyczne tworzymy wylacznie na serwerze.
    if CLIENT then return end

    local eyeAng = owner:EyeAngles()
    local forward = Angle(0, eyeAng.y, 0):Forward()
    local startPos = owner:GetPos() + Vector(0, 0, 40)

    local pack = ents.Create("ent_supplypack")
    if not IsValid(pack) then
        self:SetNextPrimaryFire(now)
        self:SetNextSecondaryFire(now)
        return
    end

    pack:SetPos(startPos)
    pack:SetAngles(Angle(0, eyeAng.y + 90, 0))
    -- Engine ownership disables collisions with the thrower.
    pack.SupplyPackOwner = owner
    pack:SetCreator(owner)
    pack:Spawn()
    pack:Activate()

    -- Check the actual crate hull instead of the old ammo-box dimensions.
    local mins, maxs = pack:WorldSpaceAABB()
    mins = mins - pack:GetPos()
    maxs = maxs - pack:GetPos()
    local tr = util.TraceHull({
        start = startPos,
        endpos = startPos + forward * 45,
        mins = mins,
        maxs = maxs,
        filter = {owner, pack},
        mask = MASK_SOLID
    })
    if tr.StartSolid or tr.AllSolid then
        pack:Remove()
        self:SetNextPrimaryFire(now)
        self:SetNextSecondaryFire(now)
        return
    end
    pack:SetPos(tr.HitPos + tr.HitNormal)
    owner.SupplyPackNextThrow = now + cfg.ThrowCooldown
    owner:SetNWFloat("SupplyPackCooldownDuration", cfg.ThrowCooldown)
    owner:SetNWFloat("SupplyPackNextThrow", owner.SupplyPackNextThrow)

    -- Jedna aktywna paczka na gracza (zabezpieczenie przed spamem).
    if IsValid(owner.SupplyPackActive) then
        owner.SupplyPackActive:Remove()
    end
    owner.SupplyPackActive = pack

    local phys = pack:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(forward * 165 + Vector(0, 0, 95) + owner:GetVelocity() * 0.2)
    end
end

function SWEP:SecondaryAttack()
    -- Brak alternatywnego ataku.
end

function SWEP:Reload()
    -- Paczka odnawia sie automatycznie po czasie cooldownu.
end
