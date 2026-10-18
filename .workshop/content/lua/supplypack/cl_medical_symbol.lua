SupplyPack = SupplyPack or {}

local MEDICAL_COLOR = Color(245, 245, 235)
local MEDICAL_CANVAS_SIZE = 256
local MEDICAL_POLYGONS = {}

local function AddMedicalPolygon(points)
    local polygon = {}
    for i = 1, #points, 2 do
        polygon[#polygon + 1] = {x = points[i] - 128, y = points[i + 1] - 128}
    end
    MEDICAL_POLYGONS[#MEDICAL_POLYGONS + 1] = polygon
end

-- Build the medical sigil from convex pieces; DrawPoly cannot fill concave shapes.
AddMedicalPolygon({84, 36, 142, 36, 142, 150, 84, 150})
AddMedicalPolygon({29, 97, 142, 97, 142, 150, 29, 150})
AddMedicalPolygon({137, 126, 223, 126, 223, 152, 137, 152})
AddMedicalPolygon({137, 150, 178, 150, 176, 201, 137, 224})
AddMedicalPolygon({140, 126, 156, 104, 168, 111, 158, 126})
AddMedicalPolygon({155, 80, 186, 80, 186, 111, 155, 111})
AddMedicalPolygon({108, 150, 128, 150, 108, 176, 96, 168})
AddMedicalPolygon({77, 168, 108, 168, 108, 197, 77, 197})

-- A ring of quads leaves the red lid visible through the emblem.
for i = 0, 63 do
    local a, b = i * math.pi * 2 / 64, (i + 1) * math.pi * 2 / 64
    AddMedicalPolygon({
        128 + math.cos(a) * 124, 128 + math.sin(a) * 124,
        128 + math.cos(b) * 124, 128 + math.sin(b) * 124,
        128 + math.cos(b) * 115, 128 + math.sin(b) * 115,
        128 + math.cos(a) * 115, 128 + math.sin(a) * 115
    })
end

local MEDICAL_LIDS = {}

-- Release cached GPU meshes when this helper is hot-reloaded or the game closes.
if SupplyPack.ClearMedicalSymbolMeshes then SupplyPack.ClearMedicalSymbolMeshes() end
function SupplyPack.ClearMedicalSymbolMeshes()
    for _, lid in pairs(MEDICAL_LIDS) do
        if lid and lid.viewModelMesh then lid.viewModelMesh:Destroy() end
    end
end
hook.Add("ShutDown", "SupplyPack.MedicalSymbolMeshes", SupplyPack.ClearMedicalSymbolMeshes)

local VIEWMODEL_MEDICAL_MATERIAL = CreateMaterial("SupplyPack_ViewModelMedicalSymbol", "UnlitGeneric", {
    ["$basetexture"] = "color/white",
    ["$vertexcolor"] = "1",
    ["$vertexalpha"] = "1",
    ["$nocull"] = "1"
})

local function GetMedicalLid(model)
    if MEDICAL_LIDS[model] ~= nil then return MEDICAL_LIDS[model] end
    local meshes, bindPoses = util.GetModelMeshes(model)
    if not meshes then return end

    -- Model bounds can include empty space well above the visible crate.
    -- Measure the actual vertices, then find the surface beneath their XY center.
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, mesh in ipairs(meshes) do
        for _, vertex in ipairs(mesh.triangles) do
            local p = vertex.pos
            minX, minY = math.min(minX, p.x), math.min(minY, p.y)
            maxX, maxY = math.max(maxX, p.x), math.max(maxY, p.y)
        end
    end
    local x, y = (minX + maxX) * 0.5, (minY + maxY) * 0.5
    local topZ, lidBone
    for _, mesh in ipairs(meshes) do
        local triangles = mesh.triangles
        for i = 1, #triangles, 3 do
            local a, b, c = triangles[i].pos, triangles[i + 1].pos, triangles[i + 2].pos
            local denominator = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
            if math.abs(denominator) > 0.000001 then
                local u = ((b.y - c.y) * (x - c.x) + (c.x - b.x) * (y - c.y)) / denominator
                local v = ((c.y - a.y) * (x - c.x) + (a.x - c.x) * (y - c.y)) / denominator
                local w = 1 - u - v
                if u >= -0.00001 and v >= -0.00001 and w >= -0.00001 then
                    local z = u * a.z + v * b.z + w * c.z
                    if not topZ or z > topZ then
                        topZ = z
                        lidBone = nil
                        -- The logo must follow the same bone transform as the lid.
                        local weights = triangles[i].weights or {}
                        local strongestWeight = 0
                        for _, weight in ipairs(weights) do
                            if weight.weight > strongestWeight then
                                strongestWeight = weight.weight
                                lidBone = weight.bone
                            end
                        end
                    end
                end
            end
        end
    end

    local lid = false
    if topZ then
        lid = {
            position = Vector(x, y, topZ),
            size = math.min(maxX - minX, maxY - minY) * 0.5,
            bone = lidBone,
            bindMatrix = bindPoses and lidBone and bindPoses[lidBone] and bindPoses[lidBone].matrix
        }
    end
    MEDICAL_LIDS[model] = lid
    return lid
end

function SupplyPack.DrawViewModelMedicalSymbol(entity)
    local model = entity:GetModel()
    if not model then return end
    local lid = GetMedicalLid(model)
    if not lid then return end

    if not lid.viewModelMesh then
        local vertices = {}
        local function AddVertex(point)
            vertices[#vertices + 1] = {
                pos = lid.position + Vector(point.x, -point.y, 0) * (lid.size / MEDICAL_CANVAS_SIZE)
                    + Vector(0, 0, 0.15),
                color = MEDICAL_COLOR, u = 0, v = 0
            }
        end
        for _, polygon in ipairs(MEDICAL_POLYGONS) do
            for i = 2, #polygon - 1 do
                AddVertex(polygon[1])
                AddVertex(polygon[i])
                AddVertex(polygon[i + 1])
            end
        end
        lid.viewModelMesh = Mesh()
        lid.viewModelMesh:BuildFromTriangles(vertices)
    end

    -- Use the rendered lid bone, including engine viewmodel offsets, animation and scale.
    -- GetViewModelPosition's requested transform is not the final skinned transform.
    local boneMatrix = lid.bone and entity:GetBoneMatrix(lid.bone)
    local matrix
    if boneMatrix and lid.bindMatrix then
        matrix = boneMatrix * lid.bindMatrix
    else
        matrix = Matrix()
        matrix:SetTranslation(entity:GetRenderOrigin() or entity:GetPos())
        matrix:SetAngles(entity:GetRenderAngles() or entity:GetAngles())
        local scale = entity:GetModelScale()
        matrix:SetScale(Vector(scale, scale, scale))
    end
    local r, g, b = render.GetColorModulation()
    render.SetColorModulation(1, 1, 1)
    render.SetMaterial(VIEWMODEL_MEDICAL_MATERIAL)
    cam.PushModelMatrix(matrix)
        lid.viewModelMesh:Draw()
    cam.PopModelMatrix()
    render.SetColorModulation(r, g, b)
end

function SupplyPack.DrawMedicalSymbol(entity, position, angles, modelScale)
    local model = entity:GetModel()
    if not model then return end
    local lid = GetMedicalLid(model)
    if not lid then return end
    local scale = modelScale or entity:GetModelScale()
    local size = lid.size * scale
    if size <= 0 then return end

    local top = lid.position * scale + Vector(0, 0, 0.08)
    position = position or entity:GetRenderOrigin() or entity:GetPos()
    angles = angles or entity:GetRenderAngles() or entity:GetAngles()
    local origin = LocalToWorld(top, angle_zero, position, angles)
    -- Viewmodels are drawn with a red modulation; keep the insignia white.
    local r, g, b = render.GetColorModulation()
    render.SetColorModulation(1, 1, 1)
    cam.Start3D2D(origin, angles, size / MEDICAL_CANVAS_SIZE)
        draw.NoTexture()
        surface.SetDrawColor(MEDICAL_COLOR)
        for _, polygon in ipairs(MEDICAL_POLYGONS) do
            surface.DrawPoly(polygon)
        end
    cam.End3D2D()
    render.SetColorModulation(r, g, b)
end

