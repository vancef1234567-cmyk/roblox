-- Shared settings for Steal the Store. Tweak numbers here to balance the game.
-- The products themselves (names, prices, models) are in ServerScriptService > Items.
local Config = {}

-- Rounds
Config.ROUND_TIME = 300 -- 5 minute heist
Config.INTERMISSION_TIME = 20
Config.MIN_PLAYERS = 1

-- Loot
Config.LOOT_RESPAWN_TIME = 30 -- seconds before an emptied shelf spot restocks

-- Getting caught
Config.JAIL_TIME = 10

-- Robbing other players
Config.ROB_COOLDOWN = 8

-- Guards: GUARDS_BASE + GUARDS_PER_PLAYER for every player in the server, up to GUARDS_MAX.
-- More guards are called in mid-round when players join.
Config.GUARDS_BASE = 2
Config.GUARDS_PER_PLAYER = 1
Config.GUARDS_MAX = 14
Config.GUARD_PATROL_SPEED = 10
Config.GUARD_CHASE_SPEED = 17 -- a little faster than a fresh player (16)
Config.GUARD_SIGHT_RANGE = 55
Config.GUARD_CATCH_RANGE = 4.5
Config.ALARM_TIME = 8 -- how long guards know your location after an alarm

-- Security cameras sweep back and forth and spot anyone carrying loot.
Config.CAMERA_RANGE = 70
Config.CAMERA_FOV = 22 -- degrees from the centre of the view
Config.CAMERA_SWEEP = 40 -- degrees each way
Config.CAMERA_SWEEP_TIME = 8 -- seconds for a full sweep

-- Rarity comes from the item's price: the more it's worth, the longer it takes to grab.
Config.Rarities = {
	{ Name = "Common", MinPrice = 0, Color = Color3.fromRGB(220, 220, 220), HoldTime = 0 },
	{ Name = "Uncommon", MinPrice = 20, Color = Color3.fromRGB(90, 220, 90), HoldTime = 0.3 },
	{ Name = "Rare", MinPrice = 100, Color = Color3.fromRGB(70, 150, 255), HoldTime = 0.7 },
	{ Name = "Epic", MinPrice = 1000, Color = Color3.fromRGB(190, 80, 255), HoldTime = 1.2 },
	{ Name = "Legendary", MinPrice = 10000, Color = Color3.fromRGB(255, 200, 40), HoldTime = 2.5 },
}

for order, rarity in ipairs(Config.Rarities) do
	rarity.Order = order
end

function Config.rarityFor(price: number)
	local found = Config.Rarities[1]
	for _, rarity in ipairs(Config.Rarities) do
		if price >= rarity.MinPrice then
			found = rarity
		end
	end
	return found
end

-- Level 1 is what every player starts with. Backpack values are bag slots
-- (most items take 1 slot, big TVs take more).
Config.Upgrades = {
	Backpack = {
		Title = "Bigger Backpack",
		Unit = " slots",
		Levels = {
			{ Value = 3, Cost = 0 },
			{ Value = 5, Cost = 150 },
			{ Value = 8, Cost = 600 },
			{ Value = 12, Cost = 2500 },
			{ Value = 20, Cost = 10000 },
			{ Value = 30, Cost = 40000 },
			{ Value = 50, Cost = 150000 },
		},
	},
	Speed = {
		Title = "Sneaky Shoes",
		Unit = " speed",
		Levels = {
			{ Value = 16, Cost = 0 },
			{ Value = 18, Cost = 200 },
			{ Value = 20, Cost = 1000 },
			{ Value = 22, Cost = 5000 },
			{ Value = 24, Cost = 20000 },
			{ Value = 26, Cost = 75000 },
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
