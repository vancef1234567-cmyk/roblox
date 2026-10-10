-- Real store products. Price is the cash you get for escaping with the item, so
-- expensive things (electronics, jewelry) pay far more than groceries.
-- Category decides which shelves, coolers, tables or cases an item appears on.
-- Weight = how often it shows up compared to other items in the same category.
-- Slots = how much backpack space it takes (default 1).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Items = {}

local C = Color3.fromRGB
local M = Enum.Material
local CYLINDER = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local GOLD = C(230, 180, 60)
local WHITE = C(250, 250, 250)

-- How full each kind of display starts (0-1).
Items.fill = {
	grocery = 0.3,
	household = 0.3,
	toys = 0.35,
	cooler = 0.35,
	produce = 0.6,
	checkout = 0.4,
	electronics = 0.5,
	tv = 0.6,
	jewelry = 0.5,
	clothing = 0.6,
	shoes = 0.4,
}

--------------------------------------------------------------------------------
-- Model helpers. Every builder gets `cf`: the spot the item sits on
-- (bottom centre, front face pointing at the shopper).
--------------------------------------------------------------------------------

local function make(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Parent = model
	return p
end

local function label(p: Part, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.9, 0.8)
	t.Position = UDim2.fromScale(0.05, 0.1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.Parent = gui
end

local function at(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local function box(m, cf, w, h, d, color, text: string?, textColor: Color3?, material: Enum.Material?)
	local p = make(m, Vector3.new(w, h, d), at(cf, 0, h / 2, 0), color, material)
	if text then
		label(p, text, textColor or WHITE)
	end
	return p
end

local function cyl(m, cf, diameter, height, color, material: Enum.Material?)
	-- upright cylinder (Roblox cylinders point along X, so tip it up)
	return make(m, Vector3.new(height, diameter, diameter), at(cf, 0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color, material, CYLINDER)
end

local function ball(m, cf, diameter, color, material: Enum.Material?)
	return make(m, Vector3.new(diameter, diameter, diameter), at(cf, 0, diameter / 2, 0), color, material, BALL)
end

local function screenOn(m, frameCf: CFrame, w: number, h: number, depth: number)
	return make(m, Vector3.new(w, h, 0.01), frameCf * CFrame.new(0, 0, -depth / 2 - 0.005), C(35, 75, 140), M.Neon)
end

local function tv(m, cf, w, h)
	local stand = box(m, cf, w * 0.35, 0.1, 1.0, C(25, 25, 25), nil, nil, M.Metal)
	make(m, Vector3.new(0.3, 0.6, 0.3), at(cf, 0, 0.4, 0.1), C(25, 25, 25), M.Metal)
	local panel = at(cf, 0, 0.7 + h / 2, 0.1)
	make(m, Vector3.new(w, h, 0.2), panel, C(15, 15, 15))
	screenOn(m, panel, w - 0.2, h - 0.2, 0.2)
	return stand
end

local function shoe(m, cf, x, upper, sole, height: number?)
	local h = height or 0.4
	make(m, Vector3.new(0.42, 0.15, 1.0), at(cf, x, 0.075, 0), sole)
	make(m, Vector3.new(0.4, h, 0.6), at(cf, x, 0.15 + h / 2, 0.18), upper, M.Fabric)
	return make(m, Vector3.new(0.4, 0.25, 0.4), at(cf, x, 0.275, -0.28), upper, M.Fabric)
end

local function pairOfShoes(upper, sole, height: number?)
	return function(m, cf)
		local left = shoe(m, cf, -0.24, upper, sole, height)
		shoe(m, cf, 0.24, upper, sole, height)
		return left
	end
end

local function cartonBox(w, h, d, color, text, textColor)
	return function(m, cf)
		return box(m, cf, w, h, d, color, text, textColor)
	end
end

--------------------------------------------------------------------------------
-- The catalog
--------------------------------------------------------------------------------

Items.list = {
	-- Checkout lane impulse buys
	{ Name = "Candy Bar", Price = 2, Category = "checkout", Weight = 30, Build = cartonBox(0.45, 0.9, 0.12, C(90, 50, 25), "CHOCO", C(255, 220, 120)) },
	{ Name = "Pack of Gum", Price = 2, Category = "checkout", Weight = 30, Build = cartonBox(0.35, 0.7, 0.12, C(40, 170, 90), "MINT") },
	{ Name = "Energy Drink", Price = 3, Category = "checkout", Weight = 25, Build = function(m, cf)
		local can = cyl(m, cf, 0.42, 1.0, C(120, 220, 40), M.Metal)
		cyl(m, at(cf, 0, 1.0, 0), 0.38, 0.05, C(200, 200, 205), M.Metal)
		return can
	end },
	{ Name = "AA Batteries (8-Pack)", Price = 12, Category = "checkout", Weight = 12, Build = cartonBox(0.6, 0.95, 0.15, C(30, 30, 30), "AA x8", C(255, 150, 0)) },
	{ Name = "$100 Gift Card", Price = 100, Category = "checkout", Weight = 3, Build = cartonBox(0.55, 0.85, 0.04, C(0, 90, 170), "$100\nGIFT CARD", C(255, 200, 40)) },

	-- Grocery aisles
	{ Name = "Box of Cereal", Price = 5, Category = "grocery", Weight = 18, Build = cartonBox(1.1, 1.5, 0.4, C(240, 140, 30), "CRUNCHY\nO's") },
	{ Name = "Box of Pasta", Price = 2, Category = "grocery", Weight = 18, Build = cartonBox(1.2, 0.5, 0.4, C(30, 80, 170), "PASTA") },
	{ Name = "Can of Soup", Price = 2, Category = "grocery", Weight = 18, Build = function(m, cf)
		local can = cyl(m, cf, 0.6, 0.8, C(200, 30, 30), M.Metal)
		cyl(m, at(cf, 0, 0.25, 0), 0.62, 0.3, WHITE)
		return can
	end },
	{ Name = "Jar of Peanut Butter", Price = 4, Category = "grocery", Weight = 14, Build = function(m, cf)
		local jar = cyl(m, cf, 0.7, 0.75, C(190, 130, 60))
		cyl(m, at(cf, 0, 0.75, 0), 0.72, 0.18, C(200, 40, 40))
		return jar
	end },
	{ Name = "Bottle of Ketchup", Price = 3, Category = "grocery", Weight = 14, Build = function(m, cf)
		local bottle = cyl(m, cf, 0.5, 1.05, C(190, 20, 20))
		cyl(m, at(cf, 0, 1.05, 0), 0.26, 0.25, WHITE)
		return bottle
	end },
	{ Name = "Bag of Chips", Price = 4, Category = "grocery", Weight = 14, Build = cartonBox(1.0, 1.35, 0.45, C(255, 210, 40), "CHIPS", C(200, 30, 30)) },
	{ Name = "Bag of Coffee", Price = 12, Category = "grocery", Weight = 8, Build = cartonBox(0.9, 1.3, 0.55, C(55, 35, 20), "COFFEE", C(230, 200, 150)) },
	{ Name = "Bottle of Olive Oil", Price = 10, Category = "grocery", Weight = 8, Build = function(m, cf)
		local bottle = cyl(m, cf, 0.5, 0.95, C(90, 110, 30), M.Glass)
		cyl(m, at(cf, 0, 0.95, 0), 0.22, 0.35, C(90, 110, 30), M.Glass)
		cyl(m, at(cf, 0, 1.3, 0), 0.25, 0.1, GOLD, M.Metal)
		return bottle
	end },
	{ Name = "Jar of Honey", Price = 8, Category = "grocery", Weight = 8, Build = function(m, cf)
		local jar = cyl(m, cf, 0.6, 0.85, C(230, 150, 20), M.Glass)
		cyl(m, at(cf, 0, 0.85, 0), 0.62, 0.15, C(250, 220, 60))
		return jar
	end },

	-- Coolers and freezers
	{ Name = "Gallon of Milk", Price = 4, Category = "cooler", Weight = 18, Build = function(m, cf)
		local jug = box(m, cf, 1.0, 1.3, 1.0, WHITE, "MILK", C(30, 80, 190))
		cyl(m, at(cf, 0.25, 1.3, 0.25), 0.3, 0.15, C(200, 30, 30))
		return jug
	end },
	{ Name = "Orange Juice", Price = 5, Category = "cooler", Weight = 14, Build = cartonBox(0.9, 1.3, 0.6, C(255, 140, 20), "ORANGE\nJUICE") },
	{ Name = "12-Pack of Soda", Price = 7, Category = "cooler", Weight = 14, Build = cartonBox(1.8, 0.9, 1.1, C(190, 20, 30), "COLA\n12 PACK") },
	{ Name = "Tub of Ice Cream", Price = 6, Category = "cooler", Weight = 12, Build = function(m, cf)
		local tub = cyl(m, cf, 0.9, 0.75, C(250, 190, 210))
		cyl(m, at(cf, 0, 0.75, 0), 0.92, 0.1, WHITE)
		return tub
	end },
	{ Name = "Frozen Pizza", Price = 7, Category = "cooler", Weight = 12, Build = cartonBox(1.5, 1.5, 0.25, C(200, 40, 30), "PIZZA", C(255, 230, 120)) },
	{ Name = "Ribeye Steak", Price = 25, Category = "cooler", Weight = 6, Build = function(m, cf)
		local tray = box(m, cf, 1.3, 0.15, 0.9, WHITE)
		box(m, at(cf, 0, 0.15, 0), 1.1, 0.2, 0.7, C(150, 30, 35))
		return tray
	end },
	{ Name = "Salmon Fillet", Price = 18, Category = "cooler", Weight = 6, Build = function(m, cf)
		local tray = box(m, cf, 1.3, 0.15, 0.9, WHITE)
		box(m, at(cf, 0, 0.15, 0), 1.1, 0.2, 0.6, C(250, 130, 90))
		return tray
	end },

	-- Produce
	{ Name = "Watermelon", Price = 6, Category = "produce", Weight = 14, Build = function(m, cf)
		return ball(m, cf, 1.6, C(40, 110, 40))
	end },
	{ Name = "Pineapple", Price = 4, Category = "produce", Weight = 14, Build = function(m, cf)
		local body = cyl(m, cf, 0.8, 1.0, C(190, 140, 40))
		make(m, Vector3.new(0.45, 0.6, 0.45), at(cf, 0, 1.3, 0) * CFrame.Angles(0, math.rad(45), 0), C(60, 130, 50))
		return body
	end },
	{ Name = "Bunch of Bananas", Price = 2, Category = "produce", Weight = 18, Build = function(m, cf)
		local first
		for i, yaw in ipairs({ -15, 0, 15 }) do
			local p = make(m, Vector3.new(1.3, 0.3, 0.3), at(cf, 0, 0.15, (i - 2) * 0.25) * CFrame.Angles(0, math.rad(yaw), 0), C(250, 215, 60), M.SmoothPlastic, CYLINDER)
			first = first or p
		end
		return first
	end },
	{ Name = "Bag of Apples", Price = 5, Category = "produce", Weight = 14, Build = function(m, cf)
		local first
		for _, o in ipairs({ { -0.25, 0, -0.2 }, { 0.25, 0, -0.2 }, { 0, 0, 0.25 }, { 0, 0.4, 0 } }) do
			local p = ball(m, at(cf, o[1], o[2], o[3]), 0.5, C(190, 25, 30))
			first = first or p
		end
		return first
	end },
	{ Name = "Avocados", Price = 3, Category = "produce", Weight = 14, Build = function(m, cf)
		local first
		for _, x in ipairs({ -0.3, 0, 0.3 }) do
			local p = ball(m, at(cf, x, 0, 0), 0.5, C(50, 70, 30))
			first = first or p
		end
		return first
	end },

	-- Household
	{ Name = "Laundry Detergent", Price = 15, Category = "household", Weight = 12, Build = function(m, cf)
		local jug = box(m, cf, 1.0, 1.35, 0.7, C(255, 120, 0), "WASH")
		cyl(m, at(cf, -0.25, 1.35, 0), 0.3, 0.15, C(40, 90, 200))
		return jug
	end },
	{ Name = "Paper Towels (6 Rolls)", Price = 12, Category = "household", Weight = 12, Build = function(m, cf)
		local roll = cyl(m, at(cf, -0.33, 0, 0), 0.6, 1.3, WHITE, M.Fabric)
		cyl(m, at(cf, 0.33, 0, 0), 0.6, 1.3, WHITE, M.Fabric)
		return roll
	end },
	{ Name = "Toilet Paper (12 Rolls)", Price = 14, Category = "household", Weight = 12, Build = cartonBox(1.4, 1.2, 1.0, C(245, 245, 250), "SOFT\n12 ROLLS", C(40, 100, 200)) },
	{ Name = "Shampoo", Price = 8, Category = "household", Weight = 12, Build = function(m, cf)
		local bottle = box(m, cf, 0.5, 1.15, 0.3, C(30, 160, 170))
		cyl(m, at(cf, 0, 1.15, 0), 0.22, 0.15, WHITE)
		return bottle
	end },
	{ Name = "Bottle of Vitamins", Price = 20, Category = "household", Weight = 8, Build = function(m, cf)
		local bottle = cyl(m, cf, 0.45, 0.65, C(240, 140, 30))
		cyl(m, at(cf, 0, 0.65, 0), 0.46, 0.15, WHITE)
		return bottle
	end },
	{ Name = "Box of Diapers", Price = 30, Category = "household", Weight = 6, Build = cartonBox(1.5, 1.35, 0.9, C(150, 200, 240), "DIAPERS") },

	-- Toys
	{ Name = "Teddy Bear", Price = 20, Category = "toys", Weight = 12, Build = function(m, cf)
		local fur = C(150, 100, 60)
		local body = ball(m, cf, 0.9, fur, M.Fabric)
		ball(m, at(cf, 0, 0.75, 0), 0.65, fur, M.Fabric)
		ball(m, at(cf, -0.25, 1.2, 0), 0.25, fur, M.Fabric)
		ball(m, at(cf, 0.25, 1.2, 0), 0.25, fur, M.Fabric)
		ball(m, at(cf, 0, 0.9, -0.28), 0.25, C(220, 180, 130), M.Fabric)
		return body
	end },
	{ Name = "Building Blocks Set", Price = 60, Category = "toys", Weight = 8, Build = cartonBox(1.5, 1.1, 0.35, C(255, 205, 0), "BRICK\nBUILDER", C(210, 30, 30)) },
	{ Name = "Board Game", Price = 25, Category = "toys", Weight = 10, Build = cartonBox(1.4, 1.4, 0.25, C(200, 30, 30), "PROPERTY\nTYCOON") },
	{ Name = "RC Car", Price = 45, Category = "toys", Weight = 8, Build = cartonBox(1.4, 0.9, 0.6, C(20, 120, 220), "RC RACER") },
	{ Name = "Basketball", Price = 25, Category = "toys", Weight = 10, Build = function(m, cf)
		return ball(m, cf, 0.95, C(230, 110, 30))
	end },
	{ Name = "Action Figure", Price = 15, Category = "toys", Weight = 12, Build = cartonBox(0.7, 1.2, 0.25, C(120, 50, 170), "HERO") },

	-- Electronics tables
	{ Name = "Video Game", Price = 70, Category = "electronics", Weight = 16, Build = cartonBox(0.55, 0.75, 0.08, C(20, 40, 120), "GAME") },
	{ Name = "Bluetooth Speaker", Price = 80, Category = "electronics", Weight = 12, Build = function(m, cf)
		return box(m, cf, 0.9, 0.45, 0.45, C(30, 30, 35), nil, nil, M.Fabric)
	end },
	{ Name = "Wireless Headphones", Price = 250, Category = "electronics", Weight = 10, Build = function(m, cf)
		local stand = cyl(m, cf, 0.4, 0.1, C(200, 200, 200), M.Metal)
		make(m, Vector3.new(0.08, 0.7, 0.08), at(cf, 0, 0.45, 0), C(200, 200, 200), M.Metal)
		make(m, Vector3.new(0.85, 0.12, 0.25), at(cf, 0, 0.85, 0), C(25, 25, 25))
		make(m, Vector3.new(0.2, 0.45, 0.45), at(cf, -0.4, 0.6, 0), C(25, 25, 25), M.SmoothPlastic, CYLINDER)
		make(m, Vector3.new(0.2, 0.45, 0.45), at(cf, 0.4, 0.6, 0), C(25, 25, 25), M.SmoothPlastic, CYLINDER)
		return stand
	end },
	{ Name = "Smartwatch", Price = 350, Category = "electronics", Weight = 8, Build = function(m, cf)
		local stand = box(m, cf, 0.35, 0.5, 0.25, C(240, 240, 240))
		local face = at(cf, 0, 0.55, -0.15)
		make(m, Vector3.new(0.35, 0.4, 0.08), face, C(20, 20, 20))
		screenOn(m, face, 0.3, 0.34, 0.08)
		return stand
	end },
	{ Name = "Tablet", Price = 400, Category = "electronics", Weight = 8, Build = function(m, cf)
		local stand = box(m, cf, 0.6, 0.12, 0.5, C(200, 200, 205), nil, nil, M.Metal)
		local frame = at(cf, 0, 0.12, 0.1) * CFrame.Angles(math.rad(12), 0, 0) * CFrame.new(0, 0.8, 0)
		make(m, Vector3.new(1.2, 1.6, 0.07), frame, C(20, 20, 22))
		screenOn(m, frame, 1.1, 1.5, 0.07)
		return stand
	end },
	{ Name = "Game Console", Price = 500, Category = "electronics", Weight = 6, Build = function(m, cf)
		local body = box(m, cf, 1.4, 0.45, 1.0, C(20, 20, 22))
		make(m, Vector3.new(1.2, 0.03, 0.02), at(cf, 0, 0.3, -0.51), C(60, 140, 255), M.Neon)
		box(m, at(cf, 0.35, 0.45, 0), 0.5, 0.12, 0.3, C(35, 35, 40))
		return body
	end },
	{ Name = "Smartphone", Price = 1000, Category = "electronics", Weight = 5, Build = function(m, cf)
		local stand = box(m, cf, 0.45, 0.1, 0.4, C(240, 240, 240))
		local phone = at(cf, 0, 0.1, 0.05) * CFrame.Angles(math.rad(12), 0, 0) * CFrame.new(0, 0.5, 0)
		make(m, Vector3.new(0.5, 1.0, 0.06), phone, C(15, 15, 18))
		screenOn(m, phone, 0.46, 0.94, 0.06)
		return stand
	end },
	{ Name = "Laptop", Price = 1200, Category = "electronics", Weight = 5, Build = function(m, cf)
		local base = box(m, cf, 1.4, 0.08, 1.0, C(190, 190, 195), nil, nil, M.Metal)
		-- hinged at the back edge, leaning back 15 degrees
		local lid = at(cf, 0, 0.08, 0.48) * CFrame.Angles(math.rad(15), 0, 0) * CFrame.new(0, 0.475, 0)
		make(m, Vector3.new(1.4, 0.95, 0.05), lid, C(190, 190, 195), M.Metal)
		screenOn(m, lid, 1.3, 0.85, 0.05)
		return base
	end },

	-- TVs (big, take several bag slots)
	{ Name = '65" 4K TV', Price = 900, Category = "tv", Weight = 10, Slots = 3, Build = function(m, cf)
		return tv(m, cf, 6, 3.5)
	end },
	{ Name = '85" OLED TV', Price = 2500, Category = "tv", Weight = 3, Slots = 4, Build = function(m, cf)
		return tv(m, cf, 7.6, 4.3)
	end },

	-- Jewelry counter
	{ Name = "Gold Necklace", Price = 2500, Category = "jewelry", Weight = 10, Build = function(m, cf)
		local bust = box(m, cf, 0.7, 0.9, 0.3, C(20, 20, 25), nil, nil, M.Fabric)
		make(m, Vector3.new(0.04, 0.5, 0.02), at(cf, -0.12, 0.62, -0.16) * CFrame.Angles(0, 0, math.rad(25)), GOLD, M.Metal)
		make(m, Vector3.new(0.04, 0.5, 0.02), at(cf, 0.12, 0.62, -0.16) * CFrame.Angles(0, 0, math.rad(-25)), GOLD, M.Metal)
		make(m, Vector3.new(0.13, 0.13, 0.13), at(cf, 0, 0.36, -0.17), GOLD, M.Metal, BALL)
		return bust
	end },
	{ Name = "Diamond Earrings", Price = 5000, Category = "jewelry", Weight = 6, Build = function(m, cf)
		local case = box(m, cf, 0.6, 0.3, 0.45, C(20, 20, 25), nil, nil, M.Fabric)
		for _, x in ipairs({ -0.13, 0.13 }) do
			local gem = make(m, Vector3.new(0.13, 0.13, 0.13), at(cf, x, 0.37, 0), C(230, 245, 255), M.Glass, BALL)
			gem.Reflectance = 0.6
		end
		return case
	end },
	{ Name = "Luxury Watch", Price = 8000, Category = "jewelry", Weight = 5, Build = function(m, cf)
		local stand = box(m, cf, 0.4, 0.5, 0.3, C(20, 20, 25), nil, nil, M.Fabric)
		make(m, Vector3.new(0.26, 0.6, 0.03), at(cf, 0, 0.3, -0.165), GOLD, M.Metal)
		make(m, Vector3.new(0.06, 0.42, 0.42), at(cf, 0, 0.4, -0.2) * CFrame.Angles(0, math.rad(90), 0), GOLD, M.Metal, CYLINDER)
		make(m, Vector3.new(0.01, 0.34, 0.34), at(cf, 0, 0.4, -0.235) * CFrame.Angles(0, math.rad(90), 0), C(245, 245, 240), M.SmoothPlastic, CYLINDER)
		return stand
	end },
	{ Name = "Diamond Ring", Price = 15000, Category = "jewelry", Weight = 2, Build = function(m, cf)
		local case = box(m, cf, 0.45, 0.32, 0.45, C(15, 15, 20), nil, nil, M.Fabric)
		make(m, Vector3.new(0.05, 0.3, 0.3), at(cf, 0, 0.47, 0) * CFrame.Angles(0, math.rad(90), 0), GOLD, M.Metal, CYLINDER)
		local gem = make(m, Vector3.new(0.15, 0.15, 0.15), at(cf, 0, 0.66, 0), C(230, 245, 255), M.Glass, BALL)
		gem.Reflectance = 0.7
		return case
	end },

	-- Clothing tables
	{ Name = "Pair of Jeans", Price = 30, Category = "clothing", Weight = 15, Build = function(m, cf)
		local bottom = box(m, cf, 1.2, 0.25, 0.9, C(40, 70, 130), nil, nil, M.Fabric)
		box(m, at(cf, 0, 0.25, 0), 1.2, 0.25, 0.9, C(50, 85, 150), nil, nil, M.Fabric)
		return bottom
	end },
	{ Name = "Hoodie", Price = 35, Category = "clothing", Weight = 15, Build = function(m, cf)
		return box(m, cf, 1.2, 0.35, 0.9, C(120, 120, 125), nil, nil, M.Fabric)
	end },
	{ Name = "Graphic T-Shirt", Price = 15, Category = "clothing", Weight = 15, Build = function(m, cf)
		return box(m, cf, 1.1, 0.15, 0.8, C(240, 240, 240), nil, nil, M.Fabric)
	end },
	{ Name = "Designer Handbag", Price = 1500, Category = "clothing", Weight = 2, Build = function(m, cf)
		local bag = box(m, cf, 1.0, 0.75, 0.45, C(110, 60, 30), nil, nil, M.Leather)
		make(m, Vector3.new(0.08, 0.45, 0.06), at(cf, -0.3, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-20)), C(90, 50, 25), M.Leather)
		make(m, Vector3.new(0.08, 0.45, 0.06), at(cf, 0.3, 0.95, 0) * CFrame.Angles(0, 0, math.rad(20)), C(90, 50, 25), M.Leather)
		make(m, Vector3.new(0.2, 0.12, 0.03), at(cf, 0, 0.6, -0.24), GOLD, M.Metal)
		return bag
	end },

	-- Shoe wall
	{ Name = "Sneakers", Price = 90, Category = "shoes", Weight = 14, Build = pairOfShoes(C(200, 30, 40), WHITE) },
	{ Name = "Running Shoes", Price = 120, Category = "shoes", Weight = 10, Build = pairOfShoes(C(40, 110, 220), C(230, 230, 230)) },
	{ Name = "Work Boots", Price = 70, Category = "shoes", Weight = 12, Build = pairOfShoes(C(110, 70, 35), C(40, 30, 20), 0.8) },
	{ Name = "Designer Sneakers", Price = 800, Category = "shoes", Weight = 2, Build = pairOfShoes(WHITE, GOLD) },
}

Items.byCategory = {}
for _, def in ipairs(Items.list) do
	def.Slots = def.Slots or 1
	def.Rarity = Config.rarityFor(def.Price)
	Items.byCategory[def.Category] = Items.byCategory[def.Category] or {}
	table.insert(Items.byCategory[def.Category], def)
end

function Items.pick(category: string)
	local list = Items.byCategory[category]
	if not list then
		return nil
	end
	local total = 0
	for _, def in ipairs(list) do
		total += def.Weight
	end
	local roll = math.random() * total
	for _, def in ipairs(list) do
		roll -= def.Weight
		if roll <= 0 then
			return def
		end
	end
	return list[1]
end

-- Returns the item model and the part the "Steal" prompt goes on.
function Items.build(def, cf: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = def.Name
	local main = def.Build(model, cf)
	model.PrimaryPart = main
	return model, main
end

return Items
