include("shared.lua")

local RING_COLOR = Color(230, 226, 12, 180)
local SEGMENTS = 48

function ENT:Initialize()
    self:EnableCustomCollisions()
end

function ENT:OnRemove()
    self:ClearTraceShape()
end

function ENT:Draw()
    self:DrawModel()

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
