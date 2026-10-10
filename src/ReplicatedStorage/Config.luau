-- Shared settings for Steal the Store. Tweak numbers here to balance the game.
local Config = {}

-- Rounds
Config.ROUND_TIME = 300 -- 5 minute heist
Config.INTERMISSION_TIME = 20
Config.MIN_PLAYERS = 1

-- Loot
Config.LOOT_FILL = 0.55 -- fraction of shelf spots that start with an item
Config.LOOT_RESPAWN_TIME = 25 -- seconds before an emptied spot restocks

-- Getting caught
Config.JAIL_TIME = 10

-- Robbing other players
Config.ROB_COOLDOWN = 8

-- Guards
Config.GUARD_COUNT = 3
Config.GUARD_PATROL_SPEED = 10
Config.GUARD_CHASE_SPEED = 17 -- a little faster than a fresh player (16)
Config.GUARD_SIGHT_RANGE = 45
Config.GUARD_CATCH_RANGE = 4.5
Config.ALARM_TIME = 8 -- how long guards know your location after an alarm

Config.Rarities = {
	Common = { Color = Color3.fromRGB(210, 210, 210), HoldTime = 0, Order = 1 },
	Uncommon = { Color = Color3.fromRGB(90, 220, 90), HoldTime = 0.3, Order = 2 },
	Rare = { Color = Color3.fromRGB(70, 150, 255), HoldTime = 0.6, Order = 3 },
	Epic = { Color = Color3.fromRGB(190, 80, 255), HoldTime = 1, Order = 4 },
	Legendary = { Color = Color3.fromRGB(255, 200, 40), HoldTime = 2, Order = 5 },
}

-- Weight = how often it spawns compared to the others.
Config.Items = {
	{ Name = "Bubble Gum", Value = 5, Weight = 20, Rarity = "Common", Color = Color3.fromRGB(255, 150, 200), Size = Vector3.new(1, 0.5, 0.6) },
	{ Name = "Soda", Value = 8, Weight = 20, Rarity = "Common", Color = Color3.fromRGB(220, 40, 40), Size = Vector3.new(0.8, 1.6, 0.8) },
	{ Name = "Chips", Value = 10, Weight = 20, Rarity = "Common", Color = Color3.fromRGB(255, 220, 60), Size = Vector3.new(1.4, 1.8, 0.6) },
	{ Name = "Bread", Value = 12, Weight = 20, Rarity = "Common", Color = Color3.fromRGB(215, 170, 110), Size = Vector3.new(2, 1, 1) },
	{ Name = "Cheese Wheel", Value = 40, Weight = 8, Rarity = "Uncommon", Color = Color3.fromRGB(255, 190, 50), Size = Vector3.new(1.6, 0.8, 1.6) },
	{ Name = "Steak", Value = 60, Weight = 8, Rarity = "Uncommon", Color = Color3.fromRGB(150, 30, 40), Size = Vector3.new(1.6, 0.4, 1.2) },
	{ Name = "Lobster", Value = 250, Weight = 3, Rarity = "Rare", Color = Color3.fromRGB(255, 80, 40), Size = Vector3.new(2, 0.8, 1) },
	{ Name = "Fancy Perfume", Value = 400, Weight = 3, Rarity = "Rare", Color = Color3.fromRGB(180, 120, 255), Size = Vector3.new(0.6, 1.2, 0.6) },
	{ Name = "Golden Watermelon", Value = 5000, Weight = 0.8, Rarity = "Epic", Color = Color3.fromRGB(255, 215, 0), Size = Vector3.new(1.8, 1.8, 1.8), Shape = Enum.PartType.Ball },
	{ Name = "Gaming Console", Value = 12000, Weight = 0.8, Rarity = "Epic", Color = Color3.fromRGB(25, 25, 30), Size = Vector3.new(1.8, 0.5, 1.2) },
	{ Name = "Diamond Cereal", Value = 1000000, Weight = 0.15, Rarity = "Legendary", Color = Color3.fromRGB(120, 255, 255), Size = Vector3.new(1.2, 2, 0.6) },
}

-- Level 1 is what every player starts with.
Config.Upgrades = {
	Backpack = {
		Title = "Bigger Backpack",
		Unit = " slots",
		Levels = {
			{ Value = 3, Cost = 0 },
			{ Value = 5, Cost = 150 },
			{ Value = 8, Cost = 750 },
			{ Value = 12, Cost = 4000 },
			{ Value = 20, Cost = 25000 },
			{ Value = 35, Cost = 250000 },
		},
	},
	Speed = {
		Title = "Sneaky Shoes",
		Unit = " speed",
		Levels = {
			{ Value = 16, Cost = 0 },
			{ Value = 18, Cost = 200 },
			{ Value = 20, Cost = 1000 },
			{ Value = 22, Cost = 6000 },
			{ Value = 24, Cost = 40000 },
			{ Value = 26, Cost = 300000 },
		},
	},
}
Config.UPGRADE_ORDER = { "Backpack", "Speed" }

function Config.formatMoney(n: number): string
	n = math.floor(n)
	local suffixes = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, s in ipairs(suffixes) do
		if n >= s[1] then
			return (string.format("$%.1f%s", n / s[1], s[2]):gsub("%.0(%a)$", "%1"))
		end
	end
	return "$" .. tostring(n)
end

return Config
