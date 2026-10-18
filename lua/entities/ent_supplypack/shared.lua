ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Paczka zaopatrzeniowa"
ENT.Category = "Zaopatrzenie"
ENT.Spawnable = false -- pojawia sie po rzucie SWEP-em
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

-- Remove the old movement hook when this file is hot-reloaded.
hook.Remove("SetupMove", "SupplyPack.SlideOffCrate")

function ENT:SetupDataTables()
    self:NetworkVar("Vector", 0, "CrateCollisionMins")
    self:NetworkVar("Vector", 1, "CrateCollisionMaxs")
end

function ENT:ClearTraceShape()
    if IsValid(self.SupplyPackTraceShape) then
        self.SupplyPackTraceShape:Destroy()
    end
    self.SupplyPackTraceShape = nil
end

-- Use the same rotated shape for server movement and client prediction.
function ENT:TestCollision(startpos, delta, isbox, extents)
    local mins, maxs = self:GetCrateCollisionMins(), self:GetCrateCollisionMaxs()
    if mins == maxs then return end

    if not IsValid(self.SupplyPackTraceShape)
        or self.SupplyPackTraceMins ~= mins or self.SupplyPackTraceMaxs ~= maxs then
        self:ClearTraceShape()
        self.SupplyPackTraceShape = CreatePhysCollideBox(mins, maxs)
        self.SupplyPackTraceMins, self.SupplyPackTraceMaxs = mins, maxs
    end
    if not IsValid(self.SupplyPackTraceShape) then return end

    local traceMins = -extents
    local traceMaxs = Vector(extents.x, extents.y, extents.z * 2)
    traceMins.z = 0
    local hit, normal, fraction = self.SupplyPackTraceShape:TraceBox(
        self:GetPos(), self:GetAngles(), startpos, startpos + delta, traceMins, traceMaxs)
    if not hit then return end
    return {HitPos = hit, Normal = normal, Fraction = fraction}
end
