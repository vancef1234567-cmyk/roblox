-- Saves cash and upgrades between sessions.
-- In Studio, turn on Game Settings > Security > "Enable Studio Access to API Services"
-- or progress will only last for the current play test.
local DataStoreService = game:GetService("DataStoreService")

local DataService = {}

local DEFAULTS = {
	Cash = 0,
	BackpackLevel = 1,
	SpeedLevel = 1,
	BestHeist = 0,
}

local store: DataStore? = nil
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore("StealTheStore_v1")
end)
if not ok then
	warn("[StealTheStore] DataStores unavailable, progress won't save: " .. tostring(err))
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

function DataService.load(player: Player)
	local data = nil
	if store then
		local success, result = pcall(function()
			return store:GetAsync(key(player))
		end)
		if success and type(result) == "table" then
			data = result
		elseif not success then
			warn("[StealTheStore] Could not load data for " .. player.Name .. ": " .. tostring(result))
		end
	end
	data = data or {}
	for k, v in pairs(DEFAULTS) do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

function DataService.save(player: Player, data)
	if not store then
		return
	end
	local success, result = pcall(function()
		store:SetAsync(key(player), data)
	end)
	if not success then
		warn("[StealTheStore] Could not save data for " .. player.Name .. ": " .. tostring(result))
	end
end

return DataService
