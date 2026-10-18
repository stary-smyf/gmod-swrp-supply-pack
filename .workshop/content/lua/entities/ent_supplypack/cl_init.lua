include("shared.lua")

-- Load the renderer here too: this entity can reload without the autorun config.
if not SupplyPack or not SupplyPack.DrawMedicalSymbol then
    include("supplypack/cl_medical_symbol.lua")
end

local RING_COLOR = Color(132, 230, 162, 255)
local SEGMENTS = 48
local CRATE_BASE_COLOR = Color(255, 255, 255)

function ENT:Initialize()
    self:EnableCustomCollisions()
end

function ENT:OnRemove()
    self:ClearTraceShape()
end

function ENT:Draw()
    -- Apply the current tint directly, including crates spawned before a config reload.
    local color = SupplyPack.Config.BoxColor
    self:SetColor(CRATE_BASE_COLOR)
    local r, g, b = render.GetColorModulation()
    render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
    self:DrawModel()
    self:SetColor(color)
    SupplyPack.DrawMedicalSymbol(self)
    render.SetColorModulation(r, g, b)

    if not SupplyPack.Config.DrawRangeCircle then return end

    local center = self:GetPos() + Vector(0, 0, 3)
    local radius = SupplyPack.Config.Radius

    -- Prosty okrag 5 m. Nie wymaga dodatkowych materialow ani tekstur.
    for i = 0, SEGMENTS - 1 do
        local a = (i / SEGMENTS) * math.pi * 2
        local b = ((i + 1) / SEGMENTS) * math.pi * 2

        local p1 = center + Vector(math.cos(a) * radius, math.sin(a) * radius, 0)
        local p2 = center + Vector(math.cos(b) * radius, math.sin(b) * radius, 0)
        render.DrawLine(p1, p2, RING_COLOR, true)
    end
end
