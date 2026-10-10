-- Builds the supermarket, lobby and jail out of parts.
-- If a model named "StealTheStoreMap" already exists in Workspace it is used instead,
-- so you can build the map once, decorate it by hand, and keep your changes.
local MapBuilder = {}

local MAP_NAME = "StealTheStoreMap"

local STORE_W, STORE_D = 160, 120
local HALF_W, HALF_D = STORE_W / 2, STORE_D / 2
local WALL_H, WALL_T = 20, 2

local SHELF_XS = { -60, -45, -30, -15, 0, 15, 30, 45, 60 }
local SHELF_SEGMENT_ZS = { -24, 24 } -- two shelves per aisle with a cross aisle between
local SHELF_LEN, SHELF_W, SHELF_H = 36, 4, 12 -- tall enough that players can't jump on top
local LEDGE_TOP = 2.6

local CORRIDOR_XS = { -70.5, -52.5, -37.5, -22.5, -7.5, 7.5, 22.5, 37.5, 52.5, 70.5 }
local PATROL_ZS = { -51, -24, 0, 24, 54 }

local LOBBY_POS = Vector3.new(0, 80, 260)
local JAIL_POS = Vector3.new(0, 80, 320)

local SHELF_COLORS = {
	Color3.fromRGB(70, 130, 220),
	Color3.fromRGB(240, 170, 50),
	Color3.fromRGB(80, 190, 110),
	Color3.fromRGB(200, 80, 160),
	Color3.fromRGB(110, 200, 220),
}

local function newPart(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function marker(parent: Instance, name: string, pos: Vector3): Part
	return newPart(parent, {
		Name = name,
		Size = Vector3.new(1, 0.2, 1),
		Position = pos,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

local function wall(parent: Instance, x1: number, z1: number, x2: number, z2: number, color: Color3)
	newPart(parent, {
		Name = "Wall",
		Size = Vector3.new(math.max(math.abs(x2 - x1), WALL_T), WALL_H, math.max(math.abs(z2 - z1), WALL_T)),
		Position = Vector3.new((x1 + x2) / 2, WALL_H / 2, (z1 + z2) / 2),
		Color = color,
		Material = Enum.Material.Concrete,
	})
end

local function sign(parent: Instance, text: string, pos: Vector3, color: Color3, width: number?)
	local anchor = marker(parent, "Sign", pos)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width or 12, (width or 12) / 4) -- scale is in studs
	gui.MaxDistance = 250
	gui.Parent = anchor
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

local function box(parent: Instance, name: string, center: Vector3, size: Vector3, height: number, color: Color3, transparency: number)
	-- four walls and no roof, centred on `center` (the floor top)
	local hx, hz = size.X / 2, size.Z / 2
	local y = center.Y + height / 2
	local sides = {
		{ Vector3.new(center.X, y, center.Z + hz), Vector3.new(size.X, height, 1) },
		{ Vector3.new(center.X, y, center.Z - hz), Vector3.new(size.X, height, 1) },
		{ Vector3.new(center.X + hx, y, center.Z), Vector3.new(1, height, size.Z) },
		{ Vector3.new(center.X - hx, y, center.Z), Vector3.new(1, height, size.Z) },
	}
	for _, s in ipairs(sides) do
		newPart(parent, { Name = name, Position = s[1], Size = s[2], Color = color, Transparency = transparency })
	end
end

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
	-- Only the lobby spawn should be used.
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") and not d:IsDescendantOf(model) then
			d.Enabled = false
		end
	end
	local markers = model:WaitForChild("Markers")
	return {
		model = model,
		lootSpawns = collectParts(model:WaitForChild("LootSpawns")),
		patrolPoints = collectPositions(model:WaitForChild("PatrolPoints")),
		guardSpawns = collectPositions(model:WaitForChild("GuardSpawns")),
		entrances = collectPositions(model:WaitForChild("Entrances")),
		exits = collectParts(model:WaitForChild("Exits")),
		lasers = collectParts(model:WaitForChild("Lasers")),
		lobby = (markers:WaitForChild("Lobby") :: BasePart).Position,
		jail = (markers:WaitForChild("Jail") :: BasePart).Position,
	}
end

function MapBuilder.build()
	-- The default Baseplate would z-fight with the store floor, and other spawns would
	-- put players outside the lobby. These changes only last for the play session.
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
	local function folder(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		return f
	end
	local structure = folder("Structure")
	local lootSpawns = folder("LootSpawns")
	local patrolPoints = folder("PatrolPoints")
	local guardSpawns = folder("GuardSpawns")
	local entrances = folder("Entrances")
	local exits = folder("Exits")
	local lasers = folder("Lasers")
	local markers = folder("Markers")

	-- Parking lot and store floor
	newPart(structure, {
		Name = "ParkingLot",
		Size = Vector3.new(600, 1, 600),
		Position = Vector3.new(0, -0.6, 0),
		Color = Color3.fromRGB(70, 70, 75),
		Material = Enum.Material.Asphalt,
	})
	newPart(structure, {
		Name = "StoreFloor",
		Size = Vector3.new(STORE_W, 1, STORE_D),
		Position = Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(235, 235, 225),
		Material = Enum.Material.Marble,
	})

	-- Walls with three gaps: front door, loading dock, fire exit
	local wallColor = Color3.fromRGB(220, 90, 70)
	wall(structure, -HALF_W, HALF_D, -6, HALF_D, wallColor)
	wall(structure, 6, HALF_D, HALF_W, HALF_D, wallColor)
	wall(structure, -HALF_W, -HALF_D, -46, -HALF_D, wallColor)
	wall(structure, -34, -HALF_D, HALF_W, -HALF_D, wallColor)
	wall(structure, -HALF_W, -HALF_D, -HALF_W, HALF_D, wallColor)
	wall(structure, HALF_W, -HALF_D, HALF_W, 14, wallColor)
	wall(structure, HALF_W, 26, HALF_W, HALF_D, wallColor)
	sign(structure, "MEGA MART", Vector3.new(0, 26, HALF_D), Color3.fromRGB(255, 230, 80), 40)

	-- Aisles: tall shelves with a ledge on each side that holds loot
	for i, x in ipairs(SHELF_XS) do
		local color = SHELF_COLORS[(i - 1) % #SHELF_COLORS + 1]
		for _, zc in ipairs(SHELF_SEGMENT_ZS) do
			newPart(structure, {
				Name = "Shelf",
				Size = Vector3.new(SHELF_W, SHELF_H, SHELF_LEN),
				Position = Vector3.new(x, SHELF_H / 2, zc),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
			})
			for _, side in ipairs({ -1, 1 }) do
				local ledgeX = x + side * (SHELF_W / 2 + 0.6)
				newPart(structure, {
					Name = "Ledge",
					Size = Vector3.new(1.2, 0.2, SHELF_LEN),
					Position = Vector3.new(ledgeX, LEDGE_TOP - 0.1, zc),
					Color = Color3.fromRGB(245, 245, 245),
				})
				for _, dz in ipairs({ -12, 0, 12 }) do
					marker(lootSpawns, "LootSpawn", Vector3.new(ledgeX, LEDGE_TOP, zc + dz))
				end
			end
		end
	end

	-- Checkout counters (decoration)
	for _, x in ipairs({ -50, -30, 30, 50 }) do
		newPart(structure, { Name = "Checkout", Size = Vector3.new(8, 3.5, 3), Position = Vector3.new(x, 1.75, 47), Color = Color3.fromRGB(60, 60, 70) })
		newPart(structure, { Name = "Belt", Size = Vector3.new(6, 0.2, 2), Position = Vector3.new(x, 3.6, 47), Color = Color3.fromRGB(20, 20, 20) })
	end

	-- Where guards walk, where they start, and where players enter
	for _, x in ipairs(CORRIDOR_XS) do
		for _, z in ipairs(PATROL_ZS) do
			marker(patrolPoints, "PatrolPoint", Vector3.new(x, 0, z))
		end
	end
	for _, pos in ipairs({ Vector3.new(0, 0, -51), Vector3.new(-37.5, 0, 0), Vector3.new(37.5, 0, 0) }) do
		marker(guardSpawns, "GuardSpawn", pos)
	end
	for _, x in ipairs({ -8, -4, 0, 4, 8 }) do
		marker(entrances, "Entrance", Vector3.new(x, 0, 53))
	end

	-- Exits: step in with loot to cash out
	local function exitZone(name: string, pos: Vector3, size: Vector3)
		local zone = newPart(exits, {
			Name = name,
			Size = size,
			Position = pos,
			Color = Color3.fromRGB(60, 255, 120),
			Material = Enum.Material.Neon,
			Transparency = 0.7,
			CanCollide = false,
			CanQuery = false,
		})
		zone:SetAttribute("ExitName", name)
		sign(structure, "EXIT: " .. string.upper(name), pos + Vector3.new(0, 8, 0), Color3.fromRGB(80, 255, 140))
	end
	exitZone("Front Door", Vector3.new(0, 5, 66), Vector3.new(12, 10, 8))
	exitZone("Loading Dock", Vector3.new(-40, 5, -66), Vector3.new(12, 10, 8))
	exitZone("Fire Exit", Vector3.new(86, 5, 20), Vector3.new(8, 10, 12))

	-- Security lasers: they blink, touching one while it's on sets off the alarm
	local laserSpots = {
		{ Vector3.new(-37.5, 2, 24), Vector3.new(11, 0.25, 0.25) },
		{ Vector3.new(22.5, 2, -24), Vector3.new(11, 0.25, 0.25) },
		{ Vector3.new(52.5, 2, 24), Vector3.new(11, 0.25, 0.25) },
		{ Vector3.new(-7.5, 2, -24), Vector3.new(11, 0.25, 0.25) },
		{ Vector3.new(-70.5, 2, -24), Vector3.new(17, 0.25, 0.25) },
		{ Vector3.new(-40, 2, -58), Vector3.new(12, 0.25, 0.25) }, -- loading dock
		{ Vector3.new(78, 2, 20), Vector3.new(0.25, 0.25, 12) }, -- fire exit
	}
	for _, spot in ipairs(laserSpots) do
		newPart(lasers, {
			Name = "Laser",
			Position = spot[1],
			Size = spot[2],
			Color = Color3.fromRGB(255, 30, 30),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		})
	end

	-- Lobby (floating above the parking lot)
	newPart(structure, {
		Name = "LobbyFloor",
		Size = Vector3.new(60, 1, 60),
		Position = LOBBY_POS - Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(90, 160, 255),
		Material = Enum.Material.SmoothPlastic,
	})
	box(structure, "LobbyWall", LOBBY_POS, Vector3.new(60, 0, 60), 8, Color3.fromRGB(255, 255, 255), 0.5)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = LOBBY_POS + Vector3.new(0, 0.5, 0)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(255, 220, 80)
	spawn.Parent = structure
	sign(structure, "STEAL THE STORE", LOBBY_POS + Vector3.new(0, 14, -24), Color3.fromRGB(255, 220, 80), 30)
	marker(markers, "Lobby", LOBBY_POS + Vector3.new(0, 1, 8))

	-- Jail (next to the lobby, so everyone can see who got busted)
	newPart(structure, {
		Name = "JailFloor",
		Size = Vector3.new(16, 1, 16),
		Position = JAIL_POS - Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(50, 50, 55),
	})
	box(structure, "JailBars", JAIL_POS, Vector3.new(16, 0, 16), 12, Color3.fromRGB(40, 40, 40), 0.4)
	newPart(structure, {
		Name = "JailRoof",
		Size = Vector3.new(17, 1, 17),
		Position = JAIL_POS + Vector3.new(0, 12.5, 0),
		Color = Color3.fromRGB(40, 40, 40),
	})
	sign(structure, "JAIL", JAIL_POS + Vector3.new(0, 16, 0), Color3.fromRGB(255, 80, 80))
	marker(markers, "Jail", JAIL_POS + Vector3.new(0, 1, 0))

	model.Parent = workspace
	return MapBuilder.read(model)
end

return MapBuilder
