-- Builds the whole world out of parts: a big-box supercenter, its parking lot and
-- neighbourhood, an enclosed crew hideout (lobby) and an enclosed jail.
-- If a model named "StealTheStoreMap" already exists in Workspace it is used instead,
-- so you can build the map once, decorate it by hand, and keep your changes.
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local MAP_NAME = "StealTheStoreMap"

local C = Color3.fromRGB
local M = Enum.Material

-- Store footprint: X -150..150, Z -110..110. The front (entrances) faces +Z.
local HALF_W, HALF_D = 150, 110
local WALL_H, WALL_T = 33, 2
local CEILING_Y = 30
local STORE_BLUE = C(0, 83, 159)
local STORE_YELLOW = C(255, 194, 32)
local SHELF_METAL = C(205, 207, 210)

-- The lobby and jail are sealed rooms far away, so you can't see the store from them.
local LOBBY_POS = Vector3.new(0, 0, 3000)
local JAIL_POS = Vector3.new(0, 0, -3000)

local rng = Random.new(20261010) -- fixed seed: the store looks the same every time

local PALETTES = {
	grocery = { C(230, 60, 40), C(250, 180, 40), C(60, 120, 200), C(240, 240, 230), C(130, 80, 40), C(60, 150, 70), C(200, 40, 90) },
	household = { C(40, 120, 220), C(250, 250, 250), C(30, 170, 170), C(250, 130, 30), C(120, 200, 240), C(150, 90, 200) },
	toys = { C(250, 60, 60), C(255, 200, 0), C(40, 140, 255), C(250, 110, 200), C(80, 200, 90), C(150, 70, 220) },
	cooler = { C(250, 250, 250), C(40, 90, 200), C(220, 40, 40), C(250, 200, 60), C(120, 180, 240) },
	shoes = { C(240, 120, 30), C(30, 30, 30), C(220, 220, 220), C(40, 80, 160), C(180, 30, 40) },
	clothes = { C(40, 70, 130), C(200, 200, 200), C(30, 30, 35), C(170, 40, 50), C(80, 130, 80), C(230, 200, 160), C(120, 80, 160) },
	cars = { C(240, 240, 240), C(25, 25, 28), C(150, 150, 155), C(160, 20, 25), C(30, 60, 140), C(90, 95, 100), C(200, 200, 205), C(40, 90, 60) },
	leaves = { C(70, 130, 50), C(55, 115, 45), C(90, 145, 60) },
}

--------------------------------------------------------------------------------
-- Part helpers
--------------------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function merge(base: { [string]: any }, extra: { [string]: any }?)
	if extra then
		for k, v in pairs(extra) do
			base[k] = v
		end
	end
	return base
end

-- Axis-aligned block at a position.
local function block(parent, name, size, pos, color, material, extra: { [string]: any }?)
	return part(parent, merge({ Name = name, Size = size, CFrame = CFrame.new(pos), Color = color, Material = material or M.SmoothPlastic }, extra))
end

-- Block at a CFrame.
local function cblock(parent, name, size, cf, color, material, extra: { [string]: any }?)
	return part(parent, merge({ Name = name, Size = size, CFrame = cf, Color = color, Material = material or M.SmoothPlastic }, extra))
end

local DECOR = { CanCollide = false, CanQuery = false, CanTouch = false }
local DECOR_NOSHADOW = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

-- Upright cylinder standing on `base`.
local function pillar(parent, name, diameter, height, base: Vector3, color, material, extra: { [string]: any }?)
	return cblock(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material, merge({ Shape = Enum.PartType.Cylinder }, extra))
end

local function sphere(parent, name, diameter, pos, color, material, extra: { [string]: any }?)
	return block(parent, name, Vector3.new(diameter, diameter, diameter), pos, color, material, merge({ Shape = Enum.PartType.Ball }, extra))
end

local function marker(parent: Instance, name: string, where: Vector3 | CFrame): Part
	local p = part(parent, { Name = name, Size = Vector3.new(1, 0.2, 1), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	p.CFrame = if typeof(where) == "CFrame" then where else CFrame.new(where)
	return p
end

-- Invisible wall used for shelves so players can't climb them and guards can't see through them.
local function collider(parent, size: Vector3, cf: CFrame)
	return part(parent, { Name = "Collider", Size = size, CFrame = cf, Transparency = 1, CanTouch = false })
end

local function surfaceText(p: BasePart, face: Enum.NormalId, text: string, color: Color3, pixelsPerStud: number?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 30
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.94, 0.86)
	label.Position = UDim2.fromScale(0.03, 0.07)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBold
	label.TextColor3 = color
	label.Parent = gui
	return gui
end

-- Two-sided sign hanging from the ceiling on cables. Faces +Z / -Z.
local function hangingSign(parent, text: string, pos: Vector3, size: Vector3, bg: Color3, fg: Color3)
	local board = block(parent, "Sign", size, pos, bg, M.SmoothPlastic, DECOR)
	surfaceText(board, Enum.NormalId.Front, text, fg, 20)
	surfaceText(board, Enum.NormalId.Back, text, fg, 20)
	local top = pos.Y + size.Y / 2
	for _, dx in ipairs({ -size.X / 2 + 0.6, size.X / 2 - 0.6 }) do
		block(parent, "Cable", Vector3.new(0.08, CEILING_Y - top, 0.08), Vector3.new(pos.X + dx, (top + CEILING_Y) / 2, pos.Z), C(70, 70, 70), M.Metal, DECOR_NOSHADOW)
	end
	return board
end

-- Billboard that floats above something and is visible through walls (for exits).
local function floatingLabel(adornee: BasePart, text: string, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 600
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
end

--------------------------------------------------------------------------------
-- Store fixtures
--------------------------------------------------------------------------------

-- One-sided shelving unit. `cf` is the floor centre of the unit with its LookVector
-- pointing out of the shelf toward the shopper. Builds metal shelves, price strips,
-- filler products and loot spots.
local function shelfUnit(o)
	local L, D, H = o.length, o.depth, o.height
	local front = -D / 2
	local frame = o.frameColor or SHELF_METAL
	local function add(name, size, pos, color, material, extra)
		return cblock(o.parent, name, size, o.cf * CFrame.new(pos), color, material or M.Metal, merge({ CanCollide = false }, extra))
	end

	add("BackPanel", Vector3.new(L, H, 0.2), Vector3.new(0, H / 2, D / 2 - 0.1), frame)
	add("Base", Vector3.new(L, 0.6, D), Vector3.new(0, 0.3, 0), frame:Lerp(Color3.new(0, 0, 0), 0.3))
	add("Side", Vector3.new(0.15, H, D), Vector3.new(-L / 2 + 0.075, H / 2, 0), frame)
	add("Side", Vector3.new(0.15, H, D), Vector3.new(L / 2 - 0.075, H / 2, 0), frame)

	for i, top in ipairs(o.tiers) do
		if i > 1 then
			add("Shelf", Vector3.new(L - 0.3, 0.12, D - 0.2), Vector3.new(0, top - 0.06, -0.1), frame)
		end
		add("PriceStrip", Vector3.new(L - 0.3, 0.2, 0.04), Vector3.new(0, top - 0.1, front - 0.02), C(245, 245, 245), M.SmoothPlastic, DECOR_NOSHADOW)

		local ceiling = o.tiers[i + 1] or H
		local maxHeight = ceiling - top - 0.25
		local lootXs = {}
		if o.lootTiers and o.lootTiers[i] then
			local count = math.max(1, math.floor(L / o.spacing))
			local gap = L / count
			for k = 1, count do
				local lx = -L / 2 + gap * (k - 0.5)
				table.insert(lootXs, lx)
				local spot = marker(o.spots, "LootSpot", o.cf * CFrame.new(lx, top, front + (o.lootDepth or 0.8)))
				spot:SetAttribute("Category", o.category)
			end
		end

		-- Filler stock so shelves look full. Gaps are left where real loot spawns.
		if o.palette and maxHeight > 0.4 then
			local x = -L / 2 + 0.3
			while true do
				local w = rng:NextNumber(0.7, 1.3)
				if x + w > L / 2 - 0.3 then
					break
				end
				local cx = x + w / 2
				local blocked = false
				for _, lx in ipairs(lootXs) do
					if math.abs(cx - lx) < 1.5 then
						blocked = true
						break
					end
				end
				if not blocked then
					local h = math.min(rng:NextNumber(0.7, 1.6), maxHeight)
					local d = math.min(rng:NextNumber(0.9, 1.5), D - 0.5)
					add("Product", Vector3.new(w, h, d), Vector3.new(cx, top + h / 2, front + 0.1 + d / 2), o.palette[rng:NextInteger(1, #o.palette)], M.SmoothPlastic, DECOR_NOSHADOW)
				end
				x += w + 0.1
			end
		end
	end

	if o.glass then
		local doors = math.max(1, math.floor(L / 4))
		local doorWidth = L / doors
		for k = 1, doors do
			local dx = -L / 2 + doorWidth * (k - 0.5)
			add("GlassDoor", Vector3.new(doorWidth - 0.15, H - 1.0, 0.08), Vector3.new(dx, 0.6 + (H - 1.0) / 2, front - 0.05), C(210, 235, 255), M.Glass, merge({ Transparency = 0.7 }, DECOR_NOSHADOW))
			add("Handle", Vector3.new(0.08, 2.2, 0.08), Vector3.new(dx + doorWidth / 2 - 0.4, H / 2, front - 0.15), C(180, 180, 185), M.Metal, DECOR)
		end
		add("Top", Vector3.new(L, 0.3, D), Vector3.new(0, H - 0.15, 0), frame)
		add("InteriorLight", Vector3.new(L - 0.4, 0.1, 0.2), Vector3.new(0, H - 0.45, front + 0.3), C(240, 250, 255), M.Neon, DECOR_NOSHADOW)
	end

	if o.header then
		local sign = add("Header", Vector3.new(L, 1.4, 0.2), Vector3.new(0, H + 0.7, front + 0.3), o.headerColor or STORE_BLUE, M.SmoothPlastic, DECOR)
		surfaceText(sign, Enum.NormalId.Front, o.header, C(255, 255, 255), 20)
	end

	if o.collide ~= false then
		collider(o.parent, Vector3.new(L + 0.2, 16, D + 0.2), o.cf * CFrame.new(0, 8, 0))
	end
end

-- Double-sided aisle shelving with end caps, running along Z.
local function gondola(parent, spots, cx: number, cz: number, length: number, category: string, palette)
	local depth = 2.3
	for _, side in ipairs({ -1, 1 }) do
		local center = Vector3.new(cx + side * depth / 2, 0, cz)
		shelfUnit({
			parent = parent, spots = spots,
			cf = CFrame.lookAt(center, center + Vector3.new(side, 0, 0)),
			length = length, depth = depth, height = 8.4,
			tiers = { 0.6, 2.4, 4.6, 6.6 }, lootTiers = { true, true, true, false }, spacing = 6,
			category = category, palette = palette, collide = false,
		})
	end
	for _, e in ipairs({ -1, 1 }) do
		local center = Vector3.new(cx, 0, cz + e * (length / 2 + 1))
		shelfUnit({
			parent = parent, spots = spots,
			cf = CFrame.lookAt(center, center + Vector3.new(0, 0, e)),
			length = depth * 2, depth = 2, height = 6.2,
			tiers = { 0.6, 2.4, 4.2 }, palette = palette, collide = false,
		})
	end
	collider(parent, Vector3.new(depth * 2 + 0.4, 16, length + 4.4), CFrame.new(cx, 8, cz))
end

local function displayTable(parent, spots, x, z, length, width, category, topColor: Color3?)
	block(parent, "TableBase", Vector3.new(length - 1, 2.7, width - 1), Vector3.new(x, 1.35, z), C(45, 45, 50))
	block(parent, "TableTop", Vector3.new(length, 0.3, width), Vector3.new(x, 2.85, z), topColor or C(235, 235, 235))
	local count = math.max(1, math.floor(length / 3.4))
	for _, side in ipairs({ -1, 1 }) do
		for k = 1, count do
			local px = x - length / 2 + (length / count) * (k - 0.5)
			local pos = Vector3.new(px, 3.0, z + side * width / 4)
			local spot = marker(spots, "LootSpot", CFrame.lookAt(pos, pos + Vector3.new(0, 0, side)))
			spot:SetAttribute("Category", category)
		end
	end
end

local function jewelryCase(parent, spots, x, z)
	block(parent, "CaseBase", Vector3.new(12, 3, 3), Vector3.new(x, 1.5, z), C(60, 40, 30), M.Wood)
	block(parent, "Velvet", Vector3.new(11.6, 0.1, 2.6), Vector3.new(x, 3.05, z), C(20, 20, 25), M.Fabric, DECOR)
	block(parent, "CaseGlass", Vector3.new(12, 1.4, 3), Vector3.new(x, 3.8, z), C(220, 240, 255), M.Glass, { Transparency = 0.8, CanQuery = false, CastShadow = false })
	local strip = block(parent, "CaseLight", Vector3.new(11.6, 0.05, 0.2), Vector3.new(x, 4.45, z), C(255, 250, 240), M.Neon, DECOR_NOSHADOW)
	local light = Instance.new("PointLight")
	light.Range = 7
	light.Brightness = 1.2
	light.Color = C(255, 245, 230)
	light.Parent = strip
	for k = 1, 4 do
		local pos = Vector3.new(x - 6 + 3 * (k - 0.5), 3.1, z)
		local spot = marker(spots, "LootSpot", CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
		spot:SetAttribute("Category", "jewelry")
	end
end

local function clothingRack(parent, x, z)
	local base = Vector3.new(x, 0, z)
	pillar(parent, "RackBase", 3, 0.2, base, C(160, 160, 165), M.Metal, DECOR)
	pillar(parent, "RackPole", 0.3, 5, base, C(180, 180, 185), M.Metal, DECOR)
	pillar(parent, "RackRing", 6.6, 0.15, base + Vector3.new(0, 5, 0), C(180, 180, 185), M.Metal, DECOR)
	local count = 18
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local cf = CFrame.new(base) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 3.5, -3)
		cblock(parent, "Garment", Vector3.new(0.25, 3, 1.6), cf, PALETTES.clothes[rng:NextInteger(1, #PALETTES.clothes)], M.Fabric, DECOR_NOSHADOW)
	end
	collider(parent, Vector3.new(7, 6, 7), CFrame.new(base + Vector3.new(0, 3, 0)))
end

local function produceBin(parent, spots, x, z, color: Color3)
	block(parent, "Bin", Vector3.new(10, 2.4, 6), Vector3.new(x, 1.2, z), C(120, 80, 45), M.WoodPlanks)
	block(parent, "BinLiner", Vector3.new(9.6, 0.2, 5.6), Vector3.new(x, 2.5, z), C(60, 110, 50), M.Fabric, DECOR)
	-- Piles of produce around the edges, loot in the middle.
	for _, dx in ipairs({ -4.3, -3.7, 3.7, 4.3, -0.3, 0.3 }) do
		for row = -2, 2 do
			local tint = color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25))
			sphere(parent, "Produce", 0.6, Vector3.new(x + dx, 2.9, z + row * 1.1), tint, M.SmoothPlastic, DECOR_NOSHADOW)
		end
	end
	for _, dx in ipairs({ -2.1, 2.1 }) do
		for _, dz in ipairs({ -1.4, 1.4 }) do
			local pos = Vector3.new(x + dx, 2.6, z + dz)
			local spot = marker(spots, "LootSpot", CFrame.lookAt(pos, pos + Vector3.new(0, 0, dz > 0 and 1 or -1)))
			spot:SetAttribute("Category", "produce")
		end
	end
end

local function shoppingCart(parent, cf: CFrame)
	local metal = C(175, 180, 185)
	local wire = { Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	local function add(size, pos, color, material, extra)
		return cblock(parent, "Cart", size, cf * CFrame.new(pos), color, material or M.Metal, extra or DECOR)
	end
	add(Vector3.new(2.6, 0.1, 4), Vector3.new(0, 1.6, 0), metal, M.Metal, wire)
	add(Vector3.new(2.6, 1.8, 0.08), Vector3.new(0, 2.5, -2), metal, M.Metal, wire)
	add(Vector3.new(2.6, 1.8, 0.08), Vector3.new(0, 2.5, 2), metal, M.Metal, wire)
	add(Vector3.new(0.08, 1.8, 4), Vector3.new(-1.3, 2.5, 0), metal, M.Metal, wire)
	add(Vector3.new(0.08, 1.8, 4), Vector3.new(1.3, 2.5, 0), metal, M.Metal, wire)
	add(Vector3.new(2.8, 0.2, 0.2), Vector3.new(0, 3.6, 2.3), C(200, 30, 30), M.SmoothPlastic)
	add(Vector3.new(2.2, 0.1, 3.2), Vector3.new(0, 0.5, 0), metal)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			add(Vector3.new(0.15, 1.3, 0.15), Vector3.new(sx * 1, 0.95, sz * 1.7), metal)
			add(Vector3.new(0.5, 0.5, 0.5), Vector3.new(sx * 1, 0.25, sz * 1.7), C(25, 25, 25), M.SmoothPlastic, merge({ Shape = Enum.PartType.Ball }, DECOR))
		end
	end
end

--------------------------------------------------------------------------------
-- Outdoor props
--------------------------------------------------------------------------------

local function car(parent, cf: CFrame, color: Color3)
	local function add(name, size, pos, c, material, extra)
		return cblock(parent, name, size, cf * CFrame.new(pos), c, material or M.SmoothPlastic, extra)
	end
	add("CarBody", Vector3.new(6.4, 2.2, 14), Vector3.new(0, 2.0, 0), color, M.SmoothPlastic, { Reflectance = 0.08 })
	add("Bumper", Vector3.new(6.6, 0.7, 14.4), Vector3.new(0, 1.15, 0), C(45, 45, 48), M.SmoothPlastic, DECOR)
	add("Windows", Vector3.new(5.8, 2.0, 7), Vector3.new(0, 4.1, 0.8), C(30, 40, 50), M.Glass, merge({ Transparency = 0.15 }, DECOR))
	add("Roof", Vector3.new(5.9, 0.2, 6.4), Vector3.new(0, 5.15, 0.8), color, M.SmoothPlastic, DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			add("Wheel", Vector3.new(0.9, 2.6, 2.6), Vector3.new(sx * 3.0, 1.3, sz * 4.6), C(20, 20, 20), M.SmoothPlastic, merge({ Shape = Enum.PartType.Cylinder }, DECOR))
		end
		add("Headlight", Vector3.new(1.2, 0.5, 0.1), Vector3.new(sx * 2.2, 2.3, -7.05), C(255, 255, 240), M.Neon, DECOR_NOSHADOW)
		add("Taillight", Vector3.new(1.2, 0.5, 0.1), Vector3.new(sx * 2.2, 2.3, 7.05), C(200, 20, 20), M.Neon, DECOR_NOSHADOW)
	end
end

local function van(parent, cf: CFrame, color: Color3)
	local function add(name, size, pos, c, material, extra)
		return cblock(parent, name, size, cf * CFrame.new(pos), c, material or M.SmoothPlastic, extra)
	end
	add("VanBody", Vector3.new(7, 6.5, 16), Vector3.new(0, 4.4, 0), color)
	add("Windshield", Vector3.new(6.2, 2.4, 0.2), Vector3.new(0, 5.8, -8.05), C(30, 40, 50), M.Glass, DECOR)
	add("SideWindow", Vector3.new(0.2, 2, 3.5), Vector3.new(3.55, 5.8, -5.5), C(30, 40, 50), M.Glass, DECOR)
	add("SideWindow", Vector3.new(0.2, 2, 3.5), Vector3.new(-3.55, 5.8, -5.5), C(30, 40, 50), M.Glass, DECOR)
	add("Bumper", Vector3.new(7.2, 0.8, 16.4), Vector3.new(0, 1.3, 0), C(40, 40, 42), M.SmoothPlastic, DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			add("Wheel", Vector3.new(1, 2.8, 2.8), Vector3.new(sx * 3.3, 1.4, sz * 5.2), C(20, 20, 20), M.SmoothPlastic, merge({ Shape = Enum.PartType.Cylinder }, DECOR))
		end
		add("Headlight", Vector3.new(1.2, 0.6, 0.1), Vector3.new(sx * 2.5, 2.6, -8.05), C(255, 255, 240), M.Neon, DECOR_NOSHADOW)
	end
end

local function semiTruck(parent, cf: CFrame)
	local function add(name, size, pos, c, material, extra)
		return cblock(parent, name, size, cf * CFrame.new(pos), c, material or M.SmoothPlastic, extra)
	end
	local trailer = add("Trailer", Vector3.new(10, 12, 40), Vector3.new(0, 8, 0), C(235, 235, 235), M.Metal)
	surfaceText(trailer, Enum.NormalId.Left, "ValueMart", STORE_BLUE, 8, Enum.Font.GothamBlack)
	surfaceText(trailer, Enum.NormalId.Right, "ValueMart", STORE_BLUE, 8, Enum.Font.GothamBlack)
	add("Cab", Vector3.new(9.5, 9, 11), Vector3.new(0, 5.5, -26.5), C(180, 30, 30))
	add("Windshield", Vector3.new(8.5, 3, 0.2), Vector3.new(0, 7.5, -32.1), C(30, 40, 50), M.Glass, DECOR)
	add("Grille", Vector3.new(6, 3, 0.2), Vector3.new(0, 3.5, -32.1), C(180, 180, 185), M.Metal, DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -29, -23, 12, 16 }) do
			add("Wheel", Vector3.new(1.2, 3.4, 3.4), Vector3.new(sx * 4.4, 1.7, z), C(20, 20, 20), M.SmoothPlastic, merge({ Shape = Enum.PartType.Cylinder }, DECOR))
		end
		add("Stack", Vector3.new(0.6, 0.6, 0.6), Vector3.new(sx * 4.2, 11, -21.5), C(170, 170, 175), M.Metal, DECOR)
	end
end

local function tree(parent, pos: Vector3, scale: number)
	pillar(parent, "Trunk", 1.4 * scale, 8 * scale, pos, C(100, 70, 45), M.Wood)
	local leaves = PALETTES.leaves[rng:NextInteger(1, #PALETTES.leaves)]
	sphere(parent, "Leaves", 9 * scale, pos + Vector3.new(0, 10 * scale, 0), leaves, M.Grass, DECOR)
	sphere(parent, "Leaves", 7 * scale, pos + Vector3.new(1.5 * scale, 13 * scale, 1 * scale), leaves:Lerp(C(255, 255, 255), 0.05), M.Grass, DECOR)
	sphere(parent, "Leaves", 6 * scale, pos + Vector3.new(-2 * scale, 11.5 * scale, -1.5 * scale), leaves:Lerp(C(0, 0, 0), 0.08), M.Grass, DECOR)
end

local function lightPole(parent, pos: Vector3)
	block(parent, "PoleBase", Vector3.new(1.6, 2.5, 1.6), pos + Vector3.new(0, 1.25, 0), C(180, 180, 175), M.Concrete)
	pillar(parent, "Pole", 0.8, 26, pos + Vector3.new(0, 2.5, 0), C(90, 95, 100), M.Metal)
	block(parent, "PoleArm", Vector3.new(10, 0.5, 0.5), pos + Vector3.new(0, 28, 0), C(90, 95, 100), M.Metal, DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		block(parent, "LampHead", Vector3.new(2.6, 0.6, 1.3), pos + Vector3.new(sx * 5, 27.8, 0), C(70, 70, 75), M.Metal, DECOR)
		block(parent, "Lamp", Vector3.new(2.2, 0.1, 1), pos + Vector3.new(sx * 5, 27.45, 0), C(255, 245, 220), M.Neon, DECOR_NOSHADOW)
	end
end

local function building(parent, center: Vector3, size: Vector3, color: Color3, signText: string, signColor: Color3, signBg: Color3)
	-- Faces -Z (toward the road and the store).
	local front = center.Z - size.Z / 2
	block(parent, "Building", size, center + Vector3.new(0, size.Y / 2, 0), color, M.Brick)
	block(parent, "RoofTrim", Vector3.new(size.X + 1, 1.2, size.Z + 1), center + Vector3.new(0, size.Y + 0.6, 0), C(70, 70, 75), M.Concrete, DECOR)
	block(parent, "Storefront", Vector3.new(size.X * 0.7, 8, 0.3), Vector3.new(center.X, 4.5, front - 0.15), C(40, 60, 80), M.Glass, merge({ Transparency = 0.2 }, DECOR))
	block(parent, "Door", Vector3.new(4, 7.5, 0.4), Vector3.new(center.X, 3.75, front - 0.3), C(30, 30, 35), M.Glass, DECOR)
	local sign = block(parent, "Sign", Vector3.new(math.min(size.X * 0.8, 40), 4, 0.5), Vector3.new(center.X, size.Y - 3, front - 0.35), signBg, M.SmoothPlastic, DECOR)
	surfaceText(sign, Enum.NormalId.Front, signText, signColor, 10, Enum.Font.GothamBlack)
end

local function sealedRoom(parent, center: Vector3, size: Vector3, wallColor: Color3, wallMaterial, floorColor: Color3, floorMaterial)
	-- `center` is the middle of the floor surface.
	block(parent, "Floor", Vector3.new(size.X + 4, 1, size.Z + 4), center - Vector3.new(0, 0.5, 0), floorColor, floorMaterial)
	block(parent, "Ceiling", Vector3.new(size.X + 4, 1, size.Z + 4), center + Vector3.new(0, size.Y + 0.5, 0), C(60, 60, 62), M.Concrete)
	local y = center.Y + size.Y / 2
	block(parent, "Wall", Vector3.new(size.X + 4, size.Y, 2), Vector3.new(center.X, y, center.Z + size.Z / 2 + 1), wallColor, wallMaterial)
	block(parent, "Wall", Vector3.new(size.X + 4, size.Y, 2), Vector3.new(center.X, y, center.Z - size.Z / 2 - 1), wallColor, wallMaterial)
	block(parent, "Wall", Vector3.new(2, size.Y, size.Z), Vector3.new(center.X + size.X / 2 + 1, y, center.Z), wallColor, wallMaterial)
	block(parent, "Wall", Vector3.new(2, size.Y, size.Z), Vector3.new(center.X - size.X / 2 - 1, y, center.Z), wallColor, wallMaterial)
end

local function ceilingLamp(parent, pos: Vector3, range: number, brightness: number, color: Color3)
	local lamp = block(parent, "Lamp", Vector3.new(2.5, 0.4, 2.5), pos, C(255, 240, 210), M.Neon, DECOR_NOSHADOW)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Shadows = true
	light.Parent = lamp
	return lamp
end

--------------------------------------------------------------------------------
-- Reading the map
--------------------------------------------------------------------------------

local function collectParts(folder: Instance): { BasePart }
	local list = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

local function collectPositions(folder: Instance): { Vector3 }
	local list = {}
	for _, p in ipairs(collectParts(folder)) do
		table.insert(list, p.Position)
	end
	return list
end

function MapBuilder.read(model: Model)
	-- Only the hideout spawn should be used.
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") and not d:IsDescendantOf(model) then
			d.Enabled = false
		end
	end
	local markers = model:WaitForChild("Markers")
	return {
		model = model,
		lootSpots = collectParts(model:WaitForChild("LootSpots")),
		patrolPoints = collectPositions(model:WaitForChild("PatrolPoints")),
		guardSpawns = collectPositions(model:WaitForChild("GuardSpawns")),
		entrances = collectPositions(model:WaitForChild("Entrances")),
		exits = collectParts(model:WaitForChild("Exits")),
		cameras = collectParts(model:WaitForChild("Cameras")),
		alarmGates = collectParts(model:WaitForChild("AlarmGates")),
		lobby = (markers:WaitForChild("Lobby") :: BasePart).Position,
		jail = (markers:WaitForChild("Jail") :: BasePart).Position,
	}
end

--------------------------------------------------------------------------------
-- Lighting
--------------------------------------------------------------------------------

local function effect(className: string)
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local e = Instance.new(className)
	e.Parent = Lighting
	return e
end

function MapBuilder.setupLighting()
	-- Future lighting gives real shadows from the store lights. Scripts can't always set
	-- this, so also set Lighting > Technology to Future in Studio.
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 15
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 3
	Lighting.Ambient = C(95, 95, 100)
	Lighting.OutdoorAmbient = C(135, 135, 145)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0

	effect("Sky")
	local atmosphere = effect("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = C(199, 215, 230)
	atmosphere.Decay = C(110, 120, 135)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	local bloom = effect("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.3
	bloom.Size = 24
	bloom.Threshold = 1.6
	local color = effect("ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Brightness = 0.02
	color.Contrast = 0.08
	color.Saturation = 0.08
	color.TintColor = C(255, 252, 246)
	local rays = effect("SunRaysEffect") :: SunRaysEffect
	rays.Intensity = 0.04
	rays.Spread = 0.6
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function MapBuilder.build()
	MapBuilder.setupLighting()

	-- The default Baseplate would cover the parking lot. This only lasts for the play session.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local existing = workspace:FindFirstChild(MAP_NAME)
	if existing then
		return MapBuilder.read(existing)
	end

	local model = Instance.new("Model")
	model.Name = MAP_NAME
	local function folder(name: string, parent: Instance?): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent or model
		return f
	end
	local store = folder("Store")
	local fixtures = folder("Fixtures", store)
	local outside = folder("Outside")
	local hideout = folder("Hideout")
	local jail = folder("Jail")
	local spots = folder("LootSpots")
	local patrol = folder("PatrolPoints")
	local guardSpawns = folder("GuardSpawns")
	local entrances = folder("Entrances")
	local exits = folder("Exits")
	local cameras = folder("Cameras")
	local alarmGates = folder("AlarmGates")
	local markers = folder("Markers")

	---------------------------------------------------------------- ground
	block(outside, "Grass", Vector3.new(1800, 1, 1800), Vector3.new(0, -1.0, 150), C(85, 130, 60), M.Grass)
	block(outside, "ParkingLot", Vector3.new(560, 1, 520), Vector3.new(0, -0.8, 70), C(55, 55, 58), M.Asphalt)
	block(outside, "Sidewalk", Vector3.new(310, 1, 14), Vector3.new(0, -0.5, 117), C(190, 190, 185), M.Concrete)
	block(outside, "DockApron", Vector3.new(120, 1, 18), Vector3.new(0, -0.5, -119), C(175, 175, 170), M.Concrete)

	---------------------------------------------------------------- shell
	local wallColor = C(232, 230, 222)
	local function wall(x1, z1, x2, z2)
		block(store, "Wall", Vector3.new(math.max(math.abs(x2 - x1), WALL_T), WALL_H, math.max(math.abs(z2 - z1), WALL_T)), Vector3.new((x1 + x2) / 2, WALL_H / 2, (z1 + z2) / 2), wallColor, M.Concrete)
	end
	-- front with two entrances
	wall(-HALF_W, HALF_D, -100, HALF_D)
	wall(-80, HALF_D, 80, HALF_D)
	wall(100, HALF_D, HALF_W, HALF_D)
	-- back with the loading dock door
	wall(-HALF_W, -HALF_D, -10, -HALF_D)
	wall(10, -HALF_D, HALF_W, -HALF_D)
	-- sides with fire exits
	wall(-HALF_W, -HALF_D, -HALF_W, -84)
	wall(-HALF_W, -76, -HALF_W, HALF_D)
	wall(HALF_W, -HALF_D, HALF_W, -34)
	wall(HALF_W, -26, HALF_W, HALF_D)
	-- above the doorways
	for _, x in ipairs({ -90, 90 }) do
		block(store, "Lintel", Vector3.new(20, WALL_H - 14, WALL_T), Vector3.new(x, 14 + (WALL_H - 14) / 2, HALF_D), wallColor, M.Concrete)
	end
	block(store, "Lintel", Vector3.new(20, WALL_H - 16, WALL_T), Vector3.new(0, 16 + (WALL_H - 16) / 2, -HALF_D), wallColor, M.Concrete)
	block(store, "RollUpDoor", Vector3.new(20, 1.6, 1.4), Vector3.new(0, 15.2, -HALF_D), C(150, 150, 155), M.DiamondPlate, DECOR)
	block(store, "Lintel", Vector3.new(WALL_T, WALL_H - 9, 8), Vector3.new(-HALF_W, 9 + (WALL_H - 9) / 2, -80), wallColor, M.Concrete)
	block(store, "Lintel", Vector3.new(WALL_T, WALL_H - 9, 8), Vector3.new(HALF_W, 9 + (WALL_H - 9) / 2, -30), wallColor, M.Concrete)

	block(store, "Floor", Vector3.new(HALF_W * 2, 1, HALF_D * 2), Vector3.new(0, -0.5, 0), C(228, 228, 224), M.Marble)
	block(store, "Ceiling", Vector3.new(HALF_W * 2, 0.6, HALF_D * 2), Vector3.new(0, CEILING_Y + 0.3, 0), C(215, 215, 215), M.SmoothPlastic)
	block(store, "Roof", Vector3.new(HALF_W * 2 + 4, 2, HALF_D * 2 + 4), Vector3.new(0, WALL_H + 1, 0), C(110, 110, 115), M.Concrete)
	for i = 1, 8 do
		local x, z = rng:NextNumber(-120, 120), rng:NextNumber(-80, 80)
		block(store, "RoofAC", Vector3.new(10, 5, 8), Vector3.new(x, WALL_H + 4.5, z), C(170, 170, 170), M.Metal, DECOR)
	end
	-- department floor tones
	block(store, "ElectronicsFloor", Vector3.new(88, 0.05, 74), Vector3.new(104, 0.025, -68), C(200, 205, 215), M.SmoothPlastic, DECOR)
	block(store, "ClothingFloor", Vector3.new(88, 0.05, 72), Vector3.new(104, 0.025, 12), C(215, 205, 190), M.Carpet, DECOR)

	-- ceiling lights
	for x = -135, 135, 30 do
		for z = -95, 95, 30 do
			local fixture = block(store, "LightFixture", Vector3.new(2.2, 0.3, 14), Vector3.new(x, CEILING_Y - 0.4, z), C(255, 255, 250), M.Neon, DECOR_NOSHADOW)
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 34
			light.Angle = 120
			light.Brightness = 1.4
			light.Color = C(255, 248, 235)
			light.Parent = fixture
		end
	end

	---------------------------------------------------------------- facade
	block(store, "FacadeBand", Vector3.new(HALF_W * 2, 5, 0.6), Vector3.new(0, WALL_H - 2.5, HALF_D + 1.3), STORE_BLUE, M.SmoothPlastic, DECOR)
	local mainSign = block(store, "StoreSign", Vector3.new(80, 10, 0.8), Vector3.new(0, 22, HALF_D + 1.4), STORE_BLUE, M.SmoothPlastic, DECOR)
	surfaceText(mainSign, Enum.NormalId.Back, "ValueMart ✱ Supercenter", STORE_YELLOW, 10, Enum.Font.GothamBlack)
	for _, x in ipairs({ -90, 90 }) do
		block(store, "EntranceTower", Vector3.new(30, 27, 2), Vector3.new(x, 27.5, HALF_D + 2), C(200, 200, 205), M.Concrete, DECOR)
		local towerSign = block(store, "EntranceSign", Vector3.new(24, 4, 0.4), Vector3.new(x, 20, HALF_D + 3.2), STORE_BLUE, M.SmoothPlastic, DECOR)
		surfaceText(towerSign, Enum.NormalId.Back, x < 0 and "Grocery & Pharmacy" or "Home & Electronics", C(255, 255, 255), 10)
		block(store, "Canopy", Vector3.new(26, 1, 12), Vector3.new(x, 14.5, HALF_D + 7), C(170, 172, 175), M.Metal)
		for _, dx in ipairs({ -12, 12 }) do
			pillar(store, "CanopyPost", 0.8, 14, Vector3.new(x + dx, 0, HALF_D + 12.5), C(150, 150, 155), M.Metal)
		end
		-- open sliding glass doors
		for _, dx in ipairs({ -7, 7 }) do
			block(store, "SlidingDoor", Vector3.new(6, 13.5, 0.3), Vector3.new(x + dx, 6.75, HALF_D + 0.9), C(200, 225, 240), M.Glass, merge({ Transparency = 0.6 }, DECOR))
		end
		-- anti-theft gates just inside the doors
		for _, dx in ipairs({ -6, 0, 6 }) do
			block(store, "SecurityPedestal", Vector3.new(0.5, 5, 2), Vector3.new(x + dx, 2.5, 105), C(235, 235, 235), M.SmoothPlastic, DECOR)
		end
		local gate = block(alarmGates, x < 0 and "Grocery Entrance" or "Home Entrance", Vector3.new(20, 9, 3), Vector3.new(x, 4.5, 105), C(255, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
		gate:SetAttribute("Gate", true)
	end
	for _, dx in ipairs({ -66, -56, -46, -36, -26, -16, 16, 26, 36, 46, 56, 66, -120, -130, -140, 120, 130, 140 }) do
		pillar(outside, "Bollard", 1, 3.5, Vector3.new(dx, 0, HALF_D + 13), STORE_YELLOW, M.SmoothPlastic)
	end
	-- fire exits
	for _, info in ipairs({ { -HALF_W, -80, "West Fire Exit", 1 }, { HALF_W, -30, "East Fire Exit", -1 } }) do
		local x, z, name, inward = info[1], info[2], info[3], info[4]
		local sign = block(store, "ExitSign", Vector3.new(0.3, 1.2, 4), Vector3.new(x + inward * 1.2, 10, z), C(200, 20, 20), M.Neon, DECOR_NOSHADOW)
		surfaceText(sign, inward > 0 and Enum.NormalId.Right or Enum.NormalId.Left, "EXIT", C(255, 255, 255), 30)
		local warning = block(store, "AlarmWarning", Vector3.new(0.2, 1.4, 6), Vector3.new(x + inward * 1.2, 7.5, z), C(255, 255, 255), M.SmoothPlastic, DECOR)
		surfaceText(warning, inward > 0 and Enum.NormalId.Right or Enum.NormalId.Left, "EMERGENCY EXIT ONLY - ALARM WILL SOUND", C(200, 20, 20), 30)
		block(alarmGates, name, Vector3.new(3, 9, 8), Vector3.new(x, 4.5, z), C(255, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	end

	---------------------------------------------------------------- grocery
	local groceryXs = { -130, -114, -98, -82, -66, -50, -34 }
	local aisleNames = { "Cereal & Breakfast", "Snacks & Chips", "Canned Goods", "Pasta & Sauces", "Baking & Spices", "Coffee & Tea", "Condiments" }
	for i, x in ipairs(groceryXs) do
		for _, cz in ipairs({ -47, -3 }) do
			gondola(fixtures, spots, x, cz, 36, "grocery", PALETTES.grocery)
		end
		hangingSign(fixtures, "AISLE " .. i .. "\n" .. aisleNames[i], Vector3.new(x, 14, 18), Vector3.new(6, 2.6, 0.3), STORE_BLUE, C(255, 255, 255))
	end
	hangingSign(fixtures, "GROCERY", Vector3.new(-82, 21, -25), Vector3.new(30, 4, 0.4), STORE_BLUE, C(255, 255, 255))

	-- coolers along the back wall
	local coolerNames = { "DAIRY", "DAIRY", "MEAT & SEAFOOD", "DRINKS", "FROZEN", "FROZEN" }
	for k = 1, 6 do
		local center = Vector3.new(-148 + 21 * (k - 0.5), 0, -HALF_D + 1 + 2)
		shelfUnit({
			parent = fixtures, spots = spots,
			cf = CFrame.lookAt(center, center + Vector3.new(0, 0, 1)),
			length = 21, depth = 4, height = 9,
			tiers = { 0.6, 3.2, 5.8 }, lootTiers = { true, true, true }, spacing = 3.5, lootDepth = 1.4,
			category = "cooler", palette = PALETTES.cooler, frameColor = C(240, 240, 240),
			glass = true, header = coolerNames[k],
		})
	end
	-- freezers along the west wall
	for k = 1, 4 do
		local center = Vector3.new(-HALF_W + 1 + 2, 0, -60 + 19 * (k - 0.5))
		shelfUnit({
			parent = fixtures, spots = spots,
			cf = CFrame.lookAt(center, center + Vector3.new(1, 0, 0)),
			length = 19, depth = 4, height = 9,
			tiers = { 0.6, 3.2, 5.8 }, lootTiers = { true, true, true }, spacing = 3.5, lootDepth = 1.4,
			category = "cooler", palette = PALETTES.cooler, frameColor = C(240, 240, 240),
			glass = true, header = "FROZEN FOODS",
		})
	end
	hangingSign(fixtures, "DAIRY & FROZEN", Vector3.new(-85, 21, -92), Vector3.new(30, 4, 0.4), STORE_BLUE, C(255, 255, 255))

	-- produce
	local produceColors = { C(200, 30, 30), C(250, 210, 50), C(60, 140, 50), C(250, 140, 30), C(110, 40, 120), C(90, 160, 60) }
	local k = 0
	for _, z in ipairs({ 30, 48 }) do
		for _, x in ipairs({ -135, -120, -105 }) do
			k += 1
			produceBin(fixtures, spots, x, z, produceColors[k])
		end
	end
	hangingSign(fixtures, "PRODUCE", Vector3.new(-120, 21, 39), Vector3.new(24, 4, 0.4), C(40, 130, 60), C(255, 255, 255))

	-- customer service
	block(fixtures, "ServiceDesk", Vector3.new(16, 3.5, 4), Vector3.new(-130, 1.75, 97), C(70, 70, 80), M.SmoothPlastic)
	hangingSign(fixtures, "CUSTOMER SERVICE", Vector3.new(-130, 12, 97), Vector3.new(16, 2.5, 0.3), STORE_BLUE, C(255, 255, 255))

	---------------------------------------------------------------- general merchandise
	local gmAisles = { { 10, "household", "Cleaning" }, { 26, "household", "Paper & Bath" }, { 42, "toys", "Toys & Games" } }
	for i, info in ipairs(gmAisles) do
		for _, cz in ipairs({ -47, -3 }) do
			gondola(fixtures, spots, info[1], cz, 36, info[2], PALETTES[info[2]])
		end
		hangingSign(fixtures, "AISLE " .. (#groceryXs + i) .. "\n" .. info[3], Vector3.new(info[1], 14, 18), Vector3.new(6, 2.6, 0.3), STORE_BLUE, C(255, 255, 255))
	end
	hangingSign(fixtures, "HOME & TOYS", Vector3.new(26, 21, -25), Vector3.new(24, 4, 0.4), STORE_BLUE, C(255, 255, 255))

	-- sale pallets in the main aisle
	for _, z in ipairs({ -55, -35, 5, 25 }) do
		block(fixtures, "Pallet", Vector3.new(4, 0.4, 4), Vector3.new(-12, 0.2, z), C(150, 110, 70), M.WoodPlanks)
		block(fixtures, "SaleStack", Vector3.new(3.6, 3.4, 3.6), Vector3.new(-12, 2.1, z), PALETTES.grocery[rng:NextInteger(1, #PALETTES.grocery)], M.Cardboard)
		local tag = block(fixtures, "SaleTag", Vector3.new(3, 1.2, 0.1), Vector3.new(-12, 4.4, z + 1.85), STORE_YELLOW, M.SmoothPlastic, DECOR)
		surfaceText(tag, Enum.NormalId.Back, "SALE", C(200, 20, 20), 30)
	end

	-- pharmacy along the back wall
	local pharmacyCenter = Vector3.new(35, 0, -HALF_D + 1 + 1)
	shelfUnit({
		parent = fixtures, spots = spots,
		cf = CFrame.lookAt(pharmacyCenter, pharmacyCenter + Vector3.new(0, 0, 1)),
		length = 44, depth = 2, height = 9, tiers = { 0.6, 2.6, 4.6, 6.6 },
		palette = PALETTES.household, header = "PHARMACY",
	})
	block(fixtures, "PharmacyCounter", Vector3.new(40, 3.5, 3), Vector3.new(35, 1.75, -100), C(240, 240, 240), M.SmoothPlastic)

	---------------------------------------------------------------- electronics
	-- TV wall (decoration) and a row of TVs you can steal
	for x = 68, 140, 12 do
		for _, y in ipairs({ 11, 17.5 }) do
			block(fixtures, "DisplayTV", Vector3.new(10, 5.8, 0.4), Vector3.new(x, y, -HALF_D + 1.3), C(15, 15, 15), M.SmoothPlastic, DECOR)
			local hue = rng:NextNumber()
			block(fixtures, "DisplayScreen", Vector3.new(9.6, 5.4, 0.05), Vector3.new(x, y, -HALF_D + 1.53), Color3.fromHSV(hue, 0.6, 0.55), M.Neon, DECOR_NOSHADOW)
		end
	end
	block(fixtures, "TVRiser", Vector3.new(84, 1, 5), Vector3.new(104, 0.5, -104.5), C(40, 40, 45), M.SmoothPlastic)
	for i = 1, 10 do
		local pos = Vector3.new(62 + 8.4 * (i - 0.5), 1, -104)
		local spot = marker(spots, "LootSpot", CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
		spot:SetAttribute("Category", "tv")
	end
	for _, z in ipairs({ -82, -58 }) do
		for _, x in ipairs({ 75, 100, 125 }) do
			displayTable(fixtures, spots, x, z, 14, 5, "electronics")
		end
	end
	hangingSign(fixtures, "ELECTRONICS", Vector3.new(104, 21, -70), Vector3.new(28, 4, 0.4), C(30, 30, 35), C(90, 200, 255))

	---------------------------------------------------------------- clothing, shoes, jewelry
	for _, z in ipairs({ -10, 22 }) do
		for _, x in ipairs({ 75, 100, 125 }) do
			clothingRack(fixtures, x, z)
		end
	end
	for _, x in ipairs({ 87, 112, 137 }) do
		displayTable(fixtures, spots, x, 5, 8, 4, "clothing", C(190, 150, 110))
	end
	local shoeCenter = Vector3.new(HALF_W - 1 - 1.25, 0, 12.5)
	shelfUnit({
		parent = fixtures, spots = spots,
		cf = CFrame.lookAt(shoeCenter, shoeCenter + Vector3.new(-1, 0, 0)),
		length = 65, depth = 2.5, height = 8,
		tiers = { 0.6, 2.4, 4.2, 6.0 }, lootTiers = { true, true, true, false }, spacing = 4, lootDepth = 1.1,
		category = "shoes", palette = PALETTES.shoes, header = "SHOES",
	})
	hangingSign(fixtures, "CLOTHING", Vector3.new(104, 21, 5), Vector3.new(24, 4, 0.4), C(150, 40, 90), C(255, 255, 255))

	for _, x in ipairs({ 108, 122, 136 }) do
		jewelryCase(fixtures, spots, x, 62)
	end
	block(fixtures, "JewelryBackdrop", Vector3.new(42, 9, 1), Vector3.new(122, 4.5, 56), C(50, 35, 28), M.Wood)
	local jewelrySign = block(fixtures, "JewelrySign", Vector3.new(20, 2.4, 0.2), Vector3.new(122, 7.5, 56.6), C(20, 20, 20), M.SmoothPlastic, DECOR)
	surfaceText(jewelrySign, Enum.NormalId.Back, "FINE JEWELRY", C(230, 190, 90), 20)

	---------------------------------------------------------------- checkouts
	for i = 0, 10 do
		local x = -60 + 12 * i
		local cx = x + 3
		block(fixtures, "CheckoutCounter", Vector3.new(2.5, 3, 10), Vector3.new(cx, 1.5, 80), C(60, 60, 68), M.SmoothPlastic)
		block(fixtures, "Belt", Vector3.new(1.8, 0.1, 7), Vector3.new(cx, 3.05, 79), C(20, 20, 20), M.Rubber, DECOR)
		block(fixtures, "Register", Vector3.new(1.4, 1.2, 1.4), Vector3.new(cx, 3.6, 83.5), C(40, 40, 45), M.SmoothPlastic, DECOR)
		block(fixtures, "RegisterScreen", Vector3.new(1.2, 0.8, 0.1), Vector3.new(cx, 4.6, 83.2), C(40, 90, 160), M.Neon, DECOR_NOSHADOW)
		block(fixtures, "LanePole", Vector3.new(0.3, 6, 0.3), Vector3.new(cx, 6, 85.5), C(160, 160, 165), M.Metal, DECOR)
		local laneLight = block(fixtures, "LaneLight", Vector3.new(1.4, 1.4, 0.4), Vector3.new(cx, 9.6, 85.5), C(40, 40, 45), M.SmoothPlastic, DECOR)
		surfaceText(laneLight, Enum.NormalId.Front, tostring(i + 1), C(120, 255, 140), 40)
		surfaceText(laneLight, Enum.NormalId.Back, tostring(i + 1), C(120, 255, 140), 40)
		-- impulse-buy rack at the start of each lane
		local rackCenter = Vector3.new(cx + 1.25 + 0.5, 0, 76)
		shelfUnit({
			parent = fixtures, spots = spots,
			cf = CFrame.lookAt(rackCenter, rackCenter + Vector3.new(1, 0, 0)),
			length = 3, depth = 1, height = 4.5,
			tiers = { 0.6, 1.9, 3.2 }, lootTiers = { false, true, true }, spacing = 1.5, lootDepth = 0.5,
			category = "checkout", palette = PALETTES.toys, frameColor = C(60, 60, 68), collide = false,
		})
	end
	hangingSign(fixtures, "CHECKOUT", Vector3.new(0, 21, 80), Vector3.new(30, 4, 0.4), STORE_BLUE, STORE_YELLOW)

	-- carts lined up at each entrance
	for _, side in ipairs({ -1, 1 }) do
		for n = 0, 4 do
			shoppingCart(fixtures, CFrame.new(side * (104 + n * 3.2), 0, 101) * CFrame.Angles(0, math.rad(90), 0))
		end
	end

	---------------------------------------------------------------- security cameras
	local cameraSpots = {
		{ Vector3.new(-140, 27, -95), Vector3.new(-90, 0, -75) },
		{ Vector3.new(-25, 27, -95), Vector3.new(-70, 0, -70) },
		{ Vector3.new(-12, 27, -25), Vector3.new(-12, 0, 20) },
		{ Vector3.new(-60, 27, -25), Vector3.new(-100, 0, -25) },
		{ Vector3.new(56, 27, -100), Vector3.new(100, 0, -65) },
		{ Vector3.new(146, 27, -40), Vector3.new(105, 0, -75) },
		{ Vector3.new(146, 27, 50), Vector3.new(115, 0, 62) },
		{ Vector3.new(0, 27, 104), Vector3.new(0, 0, 70) },
		{ Vector3.new(-146, 27, 15), Vector3.new(-115, 0, 40) },
	}
	for _, info in ipairs(cameraSpots) do
		local pos, target = info[1], info[2]
		block(store, "CameraMount", Vector3.new(0.3, CEILING_Y - pos.Y, 0.3), Vector3.new(pos.X, (pos.Y + CEILING_Y) / 2, pos.Z), C(40, 40, 40), M.Metal, DECOR)
		local cam = cblock(cameras, "SecurityCamera", Vector3.new(1, 0.9, 1.8), CFrame.lookAt(pos, target), C(35, 35, 38), M.SmoothPlastic, DECOR)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 45
		spot.Range = 60
		spot.Brightness = 3
		spot.Color = C(255, 40, 40)
		spot.Parent = cam
		block(store, "CameraLED", Vector3.new(0.15, 0.15, 0.15), pos + Vector3.new(0, 0.5, 0), C(255, 0, 0), M.Neon, DECOR_NOSHADOW)
	end

	---------------------------------------------------------------- guard routes, spawns
	local function patrolPoint(x, z)
		marker(patrol, "PatrolPoint", Vector3.new(x, 0, z))
	end
	for x = -140, 140, 20 do
		patrolPoint(x, 98)
		patrolPoint(x, 68)
	end
	local corridorXs = { -138.5, -122, -106, -90, -74, -58, -42, -20, -4, 18, 34, 52 }
	for _, x in ipairs(corridorXs) do
		for _, z in ipairs({ -47, -25, -3 }) do
			patrolPoint(x, z)
		end
	end
	for x = -140, 50, 20 do
		patrolPoint(x, -85)
	end
	for _, x in ipairs({ 62, 87, 112, 137 }) do
		patrolPoint(x, -70)
		patrolPoint(x, -45)
		patrolPoint(x, 35)
	end
	for _, x in ipairs({ 75, 100, 125 }) do
		patrolPoint(x, -93)
	end
	for _, x in ipairs({ 62, 75, 100, 125 }) do
		patrolPoint(x, 5)
	end
	for _, x in ipairs({ -144.5, -127.5, -112.5, -92 }) do
		patrolPoint(x, 39)
	end
	for _, pos in ipairs({
		Vector3.new(-90, 0, 68), Vector3.new(90, 0, 68), Vector3.new(0, 0, -85), Vector3.new(-58, 0, -25),
		Vector3.new(34, 0, -25), Vector3.new(100, 0, -45), Vector3.new(100, 0, 35), Vector3.new(-122, 0, -85),
		Vector3.new(-20, 0, 40), Vector3.new(50, 0, 68),
	}) do
		marker(guardSpawns, "GuardSpawn", pos)
	end
	for _, x in ipairs({ -96, -92, -88, -84, 84, 88, 92, 96 }) do
		marker(entrances, "Entrance", Vector3.new(x, 0, 98))
	end

	---------------------------------------------------------------- getaway vans
	local getaways = {
		{ "West Parking Lot", Vector3.new(-160, 0, 195), 0 },
		{ "East Parking Lot", Vector3.new(160, 0, 195), 0 },
		{ "Loading Dock", Vector3.new(0, 0, -150), 0 },
		{ "West Fire Lane", Vector3.new(-190, 0, -80), 90 },
		{ "East Fire Lane", Vector3.new(190, 0, -30), 90 },
	}
	for _, info in ipairs(getaways) do
		local name, pos, yaw = info[1], info[2], info[3]
		local zoneSize = if yaw == 0 then Vector3.new(18, 8, 24) else Vector3.new(24, 8, 18)
		local zone = block(exits, name, zoneSize, pos + Vector3.new(0, 4, 0), C(60, 255, 120), M.Neon, { Transparency = 0.8, CanCollide = false, CanQuery = false, CastShadow = false })
		zone:SetAttribute("ExitName", name)
		floatingLabel(zone, "🚐 GETAWAY VAN", C(90, 255, 140), 7)
		van(outside, CFrame.new(pos + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(5, 0, 0), C(40, 40, 45))
	end

	---------------------------------------------------------------- parking lot
	local lineColor = C(235, 235, 230)
	local lotTop = -0.3
	for _, row in ipairs({ 165, 225, 285 }) do
		block(outside, "CenterLine", Vector3.new(480, 0.05, 0.3), Vector3.new(0, lotTop + 0.025, row), lineColor, M.SmoothPlastic, DECOR_NOSHADOW)
		for x = -240, 240, 10 do
			if math.abs(x) > 6 then
				for _, side in ipairs({ -1, 1 }) do
					block(outside, "StallLine", Vector3.new(0.3, 0.05, 17), Vector3.new(x, lotTop + 0.025, row + side * 9), lineColor, M.SmoothPlastic, DECOR_NOSHADOW)
				end
			end
		end
		for x = -235, 235, 10 do
			if math.abs(x) > 8 then
				for _, side in ipairs({ -1, 1 }) do
					if rng:NextNumber() < 0.28 then
						local pos = Vector3.new(x, lotTop, row + side * 9)
						car(outside, CFrame.lookAt(pos, pos + Vector3.new(0, 0, -side)), PALETTES.cars[rng:NextInteger(1, #PALETTES.cars)])
					end
				end
			end
		end
		for _, x in ipairs({ -250, 0, 250 }) do
			block(outside, "Island", Vector3.new(10, 0.8, 37), Vector3.new(x, -0.1, row), C(185, 185, 180), M.Concrete)
			block(outside, "IslandGrass", Vector3.new(8.6, 0.1, 35.6), Vector3.new(x, 0.32, row), C(85, 135, 60), M.Grass, DECOR)
			tree(outside, Vector3.new(x, 0.3, row - 10), 1)
			tree(outside, Vector3.new(x, 0.3, row + 10), 1)
			lightPole(outside, Vector3.new(x, 0.3, row))
		end
	end
	for _ = 1, 8 do
		local pos = Vector3.new(rng:NextNumber(-200, 200), lotTop, rng:NextNumber(130, 140))
		shoppingCart(outside, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	end

	---------------------------------------------------------------- loading dock
	for _, x in ipairs({ -40, 40 }) do
		semiTruck(outside, CFrame.new(x, -0.3, -HALF_D - 22))
		block(outside, "DockBumper", Vector3.new(10, 3, 1), Vector3.new(x, 4, -HALF_D - 1.5), C(30, 30, 30), M.Rubber)
	end
	for _, x in ipairs({ 70, 80 }) do
		block(outside, "Dumpster", Vector3.new(8, 5, 5), Vector3.new(x, 2.5, -HALF_D - 8), C(40, 100, 60), M.Metal)
		block(outside, "DumpsterLid", Vector3.new(8.2, 0.3, 5.2), Vector3.new(x, 5.15, -HALF_D - 8), C(30, 30, 30), M.Plastic, DECOR)
	end
	for i = 0, 5 do
		block(outside, "PalletStack", Vector3.new(4, 0.5 * (i % 3 + 2), 4), Vector3.new(-70 - (i % 3) * 5, 0.5 * (i % 3 + 2) / 2, -HALF_D - 6 - math.floor(i / 3) * 5), C(150, 110, 70), M.WoodPlanks)
	end

	---------------------------------------------------------------- road and neighbours
	block(outside, "Road", Vector3.new(1100, 1, 40), Vector3.new(0, -0.75, 350), C(40, 40, 42), M.Asphalt)
	block(outside, "RoadSidewalk", Vector3.new(1100, 1, 6), Vector3.new(0, -0.5, 327), C(190, 190, 185), M.Concrete)
	block(outside, "RoadSidewalk", Vector3.new(1100, 1, 6), Vector3.new(0, -0.5, 373), C(190, 190, 185), M.Concrete)
	for _, z in ipairs({ 349.6, 350.4 }) do
		block(outside, "CenterLine", Vector3.new(1100, 0.05, 0.3), Vector3.new(0, -0.22, z), C(240, 200, 40), M.SmoothPlastic, DECOR_NOSHADOW)
	end
	for x = -540, 540, 20 do
		for _, z in ipairs({ 340, 360 }) do
			block(outside, "LaneDash", Vector3.new(8, 0.05, 0.3), Vector3.new(x, -0.22, z), lineColor, M.SmoothPlastic, DECOR_NOSHADOW)
		end
	end
	-- gas station
	block(outside, "GasPad", Vector3.new(100, 1, 90), Vector3.new(-230, -0.45, 425), C(185, 185, 180), M.Concrete)
	block(outside, "GasCanopy", Vector3.new(60, 2, 30), Vector3.new(-230, 17, 410), C(235, 235, 235), M.SmoothPlastic)
	local canopyBand = block(outside, "GasCanopyBand", Vector3.new(60.2, 1.2, 30.2), Vector3.new(-230, 16.2, 410), C(200, 30, 30), M.SmoothPlastic, DECOR)
	surfaceText(canopyBand, Enum.NormalId.Front, "QUICK GAS", C(255, 255, 255), 8, Enum.Font.GothamBlack)
	for _, dx in ipairs({ -20, 0, 20 }) do
		for _, dz in ipairs({ -8, 8 }) do
			pillar(outside, "CanopyPost", 1.2, 16, Vector3.new(-230 + dx, 0, 410 + dz), C(200, 200, 200), M.Metal)
		end
		block(outside, "GasPump", Vector3.new(2, 5, 1.2), Vector3.new(-230 + dx, 2.5, 410), C(220, 220, 220), M.SmoothPlastic)
	end
	building(outside, Vector3.new(-230, 0, 455), Vector3.new(40, 14, 24), C(170, 150, 130), "QUICK GAS MART", C(255, 255, 255), C(200, 30, 30))
	-- restaurant
	block(outside, "DinerLot", Vector3.new(70, 1, 70), Vector3.new(-40, -0.45, 425), C(60, 60, 62), M.Asphalt)
	building(outside, Vector3.new(-40, 0, 430), Vector3.new(44, 16, 32), C(150, 60, 40), "BURGER BARN", C(255, 210, 60), C(120, 30, 20))
	-- strip mall
	block(outside, "MallLot", Vector3.new(220, 1, 80), Vector3.new(200, -0.45, 420), C(60, 60, 62), M.Asphalt)
	local shops = { { "PIZZA PALACE", C(200, 40, 30) }, { "NAIL SPA", C(220, 120, 180) }, { "PHONE FIX", C(40, 120, 220) }, { "LAUNDROMAT", C(60, 160, 160) }, { "PET SUPPLY", C(90, 160, 60) } }
	for i, shop in ipairs(shops) do
		building(outside, Vector3.new(120 + (i - 1) * 32, 0, 445), Vector3.new(32, 18, 34), C(200, 190, 175), shop[1], C(255, 255, 255), shop[2])
	end

	---------------------------------------------------------------- trees and hills around the edge
	for z = -200, 320, 26 do
		tree(outside, Vector3.new(-300 + rng:NextNumber(-6, 6), -0.5, z), rng:NextNumber(1.1, 1.5))
		tree(outside, Vector3.new(300 + rng:NextNumber(-6, 6), -0.5, z), rng:NextNumber(1.1, 1.5))
	end
	for x = -290, 290, 26 do
		tree(outside, Vector3.new(x, -0.5, -205 + rng:NextNumber(-6, 6)), rng:NextNumber(1.1, 1.5))
	end
	for x = -520, 520, 34 do
		tree(outside, Vector3.new(x, -0.5, 500 + rng:NextNumber(-10, 10)), rng:NextNumber(1.2, 1.7))
	end
	for _, info in ipairs({ { -800, -300 }, { 0, -700 }, { 800, -200 }, { -900, 400 }, { 900, 500 }, { 300, 900 }, { -400, 900 } }) do
		sphere(outside, "Hill", 600, Vector3.new(info[1], -230, info[2]), C(80, 125, 60), M.Grass, DECOR)
	end

	---------------------------------------------------------------- crew hideout (lobby)
	local L = LOBBY_POS
	sealedRoom(hideout, L, Vector3.new(80, 18, 60), C(120, 70, 55), M.Brick, C(110, 110, 110), M.Concrete)
	for _, dx in ipairs({ -25, 0, 25 }) do
		for _, dz in ipairs({ -15, 15 }) do
			ceilingLamp(hideout, L + Vector3.new(dx, 17.4, dz), 30, 1.3, C(255, 220, 170))
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HideoutSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.2, 10)
	spawn.CFrame = CFrame.new(L + Vector3.new(0, 0.1, 12))
	spawn.Color = C(120, 30, 30)
	spawn.Material = M.Fabric
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hideout
	marker(markers, "Lobby", L + Vector3.new(0, 1, 12))
	-- planning table
	block(hideout, "PlanTable", Vector3.new(14, 3, 8), L + Vector3.new(-18, 1.5, -5), C(110, 75, 45), M.Wood)
	local plan = block(hideout, "Blueprint", Vector3.new(12, 0.05, 6.5), L + Vector3.new(-18, 3.03, -5), C(40, 90, 170), M.SmoothPlastic, DECOR)
	surfaceText(plan, Enum.NormalId.Top, "VALUEMART HEIST PLAN\nElectronics (back right) and jewelry (front right) pay the most.\nCameras sweep the ceiling. Security gates beep at the doors.\nReach a getaway van to cash out!", C(230, 240, 255), 30)
	-- wall TV
	block(hideout, "WallTV", Vector3.new(22, 12, 0.4), L + Vector3.new(0, 9, -29.8), C(15, 15, 15), M.SmoothPlastic, DECOR)
	local tvScreen = block(hideout, "WallTVScreen", Vector3.new(21, 11, 0.05), L + Vector3.new(0, 9, -29.55), C(25, 50, 90), M.Neon, DECOR_NOSHADOW)
	surfaceText(tvScreen, Enum.NormalId.Back, "STEAL THE STORE\nNext target: ValueMart Supercenter", C(255, 220, 80), 15, Enum.Font.GothamBlack)
	-- couches facing the TV
	for _, dx in ipairs({ -10, 10 }) do
		block(hideout, "CouchSeat", Vector3.new(12, 1.6, 4), L + Vector3.new(dx, 0.8, -12), C(90, 50, 35), M.Leather)
		block(hideout, "CouchBack", Vector3.new(12, 3.4, 1.2), L + Vector3.new(dx, 1.7, -9.6), C(80, 45, 30), M.Leather)
		block(hideout, "CouchArm", Vector3.new(1, 2.4, 4), L + Vector3.new(dx - 6.5, 1.2, -12), C(80, 45, 30), M.Leather)
		block(hideout, "CouchArm", Vector3.new(1, 2.4, 4), L + Vector3.new(dx + 6.5, 1.2, -12), C(80, 45, 30), M.Leather)
	end
	-- lockers, cash and the crew's van
	for i = 0, 5 do
		block(hideout, "Locker", Vector3.new(3, 8, 2.5), L + Vector3.new(-38.7 + 1.25, 4, -18 + i * 3.2), C(90, 100, 110), M.DiamondPlate)
	end
	block(hideout, "CashPallet", Vector3.new(6, 0.5, 6), L + Vector3.new(30, 0.25, 20), C(150, 110, 70), M.WoodPlanks)
	for i = 0, 11 do
		block(hideout, "CashStack", Vector3.new(1.6, 0.6, 0.8), L + Vector3.new(28.5 + (i % 3) * 1.7, 0.8 + math.floor(i / 6) * 0.65, 18.5 + (math.floor(i / 3) % 2) * 2.5), C(80, 150, 80), M.SmoothPlastic)
	end
	van(hideout, CFrame.new(L + Vector3.new(26, 0, -10)) * CFrame.Angles(0, math.rad(20), 0), C(30, 30, 35))
	for i = 0, 3 do
		block(hideout, "Crate", Vector3.new(4, 4, 4), L + Vector3.new(-30 + (i % 2) * 4.2, 2 + math.floor(i / 2) * 4, 24), C(140, 100, 60), M.WoodPlanks)
	end
	block(hideout, "Rug", Vector3.new(20, 0.05, 12), L + Vector3.new(0, 0.03, -12), C(130, 40, 40), M.Fabric, DECOR)

	---------------------------------------------------------------- jail
	local J = JAIL_POS
	sealedRoom(jail, J, Vector3.new(40, 14, 30), C(170, 175, 170), M.Concrete, C(140, 140, 135), M.Concrete)
	-- bars split the room into a cell (back) and a corridor (front)
	for x = -19.5, 19.5, 1.3 do
		pillar(jail, "Bar", 0.25, 14, J + Vector3.new(x, 0, 3), C(60, 60, 65), M.Metal)
	end
	block(jail, "BarRail", Vector3.new(40, 0.4, 0.4), J + Vector3.new(0, 7, 3), C(60, 60, 65), M.Metal)
	block(jail, "Bench", Vector3.new(10, 1.5, 2.5), J + Vector3.new(-10, 0.75, 13.5), C(120, 120, 125), M.Metal)
	block(jail, "Bunk", Vector3.new(4, 1, 8), J + Vector3.new(16, 2, 10), C(120, 120, 125), M.Metal)
	block(jail, "Mattress", Vector3.new(3.6, 0.5, 7.6), J + Vector3.new(16, 2.75, 10), C(200, 200, 190), M.Fabric)
	block(jail, "Toilet", Vector3.new(1.6, 1.6, 2), J + Vector3.new(8, 0.8, 13.7), C(235, 235, 235), M.SmoothPlastic)
	block(jail, "Sink", Vector3.new(1.6, 0.8, 1.2), J + Vector3.new(4, 3, 14.2), C(200, 200, 205), M.Metal)
	ceilingLamp(jail, J + Vector3.new(0, 13.4, 9), 25, 1, C(230, 240, 255))
	ceilingLamp(jail, J + Vector3.new(0, 13.4, -7), 25, 1, C(230, 240, 255))
	block(jail, "OfficerDesk", Vector3.new(8, 3, 3), J + Vector3.new(10, 1.5, -10), C(90, 70, 50), M.Wood)
	local jailSign = block(jail, "JailSign", Vector3.new(16, 3, 0.2), J + Vector3.new(0, 10, -14.9), C(30, 40, 80), M.SmoothPlastic, DECOR)
	surfaceText(jailSign, Enum.NormalId.Back, "COUNTY JAIL", C(255, 255, 255), 20, Enum.Font.GothamBlack)
	marker(markers, "Jail", J + Vector3.new(0, 1, 9))

	model.Parent = workspace
	return MapBuilder.read(model)
end

return MapBuilder
