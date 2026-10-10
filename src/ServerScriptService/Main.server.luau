-- Steal the Store: round loop, stealing, escaping, robbing, upgrades.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local GuardAI = require(script.Parent:WaitForChild("GuardAI"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local formatMoney = Config.formatMoney
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(90, 255, 130)
local YELLOW = Color3.fromRGB(255, 220, 80)

local map = MapBuilder.build()

local remotes = Instance.new("Folder")
remotes.Name = "StealTheStoreRemotes"
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes
local buyEvent = Instance.new("RemoteEvent")
buyEvent.Name = "BuyUpgrade"
buyEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

local lootFolder = Instance.new("Folder")
lootFolder.Name = "Loot"
lootFolder.Parent = workspace
local guardFolder = Instance.new("Folder")
guardFolder.Name = "Guards"
guardFolder.Parent = workspace

local state = {} -- [Player] = per-player info
local alarms = {} -- [Player] = time the alarm wears off
local occupied = {} -- [loot spawn part] = item on it
local guards = {}
local roundActive = false
local roundId = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function notify(player: Player, text: string, color: Color3?)
	notifyEvent:FireClient(player, text, color or Color3.new(1, 1, 1))
end

local function announce(text: string, color: Color3?)
	notifyEvent:FireAllClients(text, color or YELLOW)
end

local function getRoot(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function bagValue(bag): number
	local total = 0
	for _, item in ipairs(bag) do
		total += item.Value
	end
	return total
end

local function upgradeValue(kind: string, level: number): number
	local levels = Config.Upgrades[kind].Levels
	return levels[math.clamp(level, 1, #levels)].Value
end

local function capacity(st): number
	return upgradeValue("Backpack", st.data.BackpackLevel)
end

local function refreshPlayer(player: Player)
	local st = state[player]
	if not st then
		return
	end
	local value = bagValue(st.bag)
	player:SetAttribute("Capacity", capacity(st))
	player:SetAttribute("BagCount", #st.bag)
	player:SetAttribute("BagValue", value)
	player:SetAttribute("BackpackLevel", st.data.BackpackLevel)
	player:SetAttribute("SpeedLevel", st.data.SpeedLevel)
	player:SetAttribute("Jailed", st.jailed)
	st.cashValue.Value = st.data.Cash
	st.bestValue.Value = st.data.BestHeist

	local char = player.Character
	if not char then
		return
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = upgradeValue("Speed", st.data.SpeedLevel)
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local robPrompt = root and root:FindFirstChild("RobPrompt")
	if robPrompt then
		robPrompt.Enabled = roundActive and #st.bag > 0
	end
	local head = char:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("LootTag")
	if tag then
		tag.Enabled = value > 0
		tag.Label.Text = "💰 " .. formatMoney(value)
	end
end

local function teleport(player: Player, pos: Vector3)
	local char = player.Character
	if char then
		char:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	end
end

local function sendToStore(player: Player)
	local char = player.Character
	if char then
		local pos = map.entrances[math.random(#map.entrances)] + Vector3.new(0, 3, 0)
		char:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -10)))
	end
end

local function isAlarmed(player: Player): boolean
	return (alarms[player] or 0) > os.clock()
end

local function raiseAlarm(player: Player)
	alarms[player] = os.clock() + Config.ALARM_TIME
end

local function isPlaying(st): boolean
	return st ~= nil and roundActive and st.inRound and not st.jailed
end

-- Guards only go after players carrying loot, or players who set off an alarm.
local function isTargetable(player: Player): boolean
	local st = state[player]
	if not isPlaying(st) then
		return false
	end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	return #st.bag > 0 or isAlarmed(player)
end

--------------------------------------------------------------------------------
-- Loot
--------------------------------------------------------------------------------

local totalWeight = 0
for _, def in ipairs(Config.Items) do
	totalWeight += def.Weight
end

local function pickItemDef()
	local roll = math.random() * totalWeight
	for _, def in ipairs(Config.Items) do
		roll -= def.Weight
		if roll <= 0 then
			return def
		end
	end
	return Config.Items[1]
end

local spawnLoot

local function onSteal(player: Player, item: BasePart, def, spawnPart: BasePart)
	local st = state[player]
	if not isPlaying(st) or item.Parent ~= lootFolder then
		return
	end
	local root = getRoot(player)
	if not root or (root.Position - item.Position).Magnitude > 12 then
		return
	end
	if #st.bag >= capacity(st) then
		notify(player, "Your bag is full! Escape through an EXIT to cash out.", RED)
		return
	end

	table.insert(st.bag, { Name = def.Name, Value = def.Value, Rarity = def.Rarity })
	item:Destroy()
	occupied[spawnPart] = nil
	local thisRound = roundId
	task.delay(Config.LOOT_RESPAWN_TIME, function()
		if roundActive and roundId == thisRound and not occupied[spawnPart] then
			spawnLoot(spawnPart)
		end
	end)
	refreshPlayer(player)

	local rarity = Config.Rarities[def.Rarity]
	if rarity.Order >= 4 then
		announce(
			string.format("%s stole a %s %s! The guards are coming!", player.DisplayName, string.upper(def.Rarity), def.Name),
			rarity.Color
		)
		raiseAlarm(player)
	else
		notify(player, string.format("+ %s (%s)", def.Name, formatMoney(def.Value)), rarity.Color)
	end
end

function spawnLoot(spawnPart: BasePart)
	local def = pickItemDef()
	local rarity = Config.Rarities[def.Rarity]

	local item = Instance.new("Part")
	item.Name = def.Name
	item.Size = def.Size
	if def.Shape then
		item.Shape = def.Shape
	end
	item.Color = def.Color
	item.Material = rarity.Order >= 4 and Enum.Material.Neon or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = false
	item.CFrame = CFrame.new(spawnPart.Position + Vector3.new(0, def.Size.Y / 2, 0))
	item:SetAttribute("Value", def.Value)
	item:SetAttribute("Rarity", def.Rarity)

	if rarity.Order >= 3 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 8
		light.Brightness = 2
		light.Parent = item
	end
	if rarity.Order >= 4 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rarity.Color
		sparkles.Parent = item
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = string.format("%s (%s)", def.Name, formatMoney(def.Value))
	prompt.HoldDuration = rarity.HoldTime
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = item
	prompt.Triggered:Connect(function(player)
		onSteal(player, item, def, spawnPart)
	end)

	item.Parent = lootFolder
	occupied[spawnPart] = item
end

--------------------------------------------------------------------------------
-- Getting caught, escaping, robbing
--------------------------------------------------------------------------------

local function onCaught(player: Player)
	local st = state[player]
	if not isPlaying(st) then
		return
	end
	local lost = bagValue(st.bag)
	st.bag = {}
	st.jailed = true
	alarms[player] = nil
	refreshPlayer(player)
	teleport(player, map.jail)
	notify(player, string.format("BUSTED! You lost %s of loot. Jail for %d seconds...", formatMoney(lost), Config.JAIL_TIME), RED)
	if lost >= 1000 then
		announce(string.format("%s got busted carrying %s!", player.DisplayName, formatMoney(lost)), RED)
	end

	local thisRound = roundId
	task.delay(Config.JAIL_TIME, function()
		if state[player] ~= st or not st.jailed then
			return
		end
		st.jailed = false
		refreshPlayer(player)
		if roundActive and roundId == thisRound and st.inRound then
			sendToStore(player)
			notify(player, "You're out of jail. Back to work!", YELLOW)
		end
	end)
end

local function bank(player: Player, exitName: string)
	local st = state[player]
	if not isPlaying(st) or #st.bag == 0 then
		return
	end
	local total = bagValue(st.bag)
	local count = #st.bag
	st.bag = {}
	st.data.Cash += total
	st.roundEarnings += total
	st.data.BestHeist = math.max(st.data.BestHeist, st.roundEarnings)
	alarms[player] = nil
	refreshPlayer(player)
	notify(player, string.format("Escaped through the %s with %d items: +%s!", exitName, count, formatMoney(total)), GREEN)
	if total >= 5000 then
		announce(string.format("%s escaped with %s!", player.DisplayName, formatMoney(total)), GREEN)
	end
end

for _, exit in ipairs(map.exits) do
	exit.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			bank(player, exit:GetAttribute("ExitName") or exit.Name)
		end
	end)
end

local function onRob(robber: Player, victim: Player)
	if robber == victim then
		return
	end
	local rs, vs = state[robber], state[victim]
	if not isPlaying(rs) or not isPlaying(vs) or #vs.bag == 0 then
		return
	end
	if os.clock() - rs.lastRob < Config.ROB_COOLDOWN then
		notify(robber, "Your sticky fingers need a break...", RED)
		return
	end
	if #rs.bag >= capacity(rs) then
		notify(robber, "Your bag is full!", RED)
		return
	end
	rs.lastRob = os.clock()
	local item = table.remove(vs.bag, math.random(#vs.bag))
	table.insert(rs.bag, item)
	refreshPlayer(robber)
	refreshPlayer(victim)
	notify(robber, string.format("You robbed %s's %s!", victim.DisplayName, item.Name), GREEN)
	notify(victim, string.format("%s stole your %s!", robber.DisplayName, item.Name), RED)
end

--------------------------------------------------------------------------------
-- Lasers
--------------------------------------------------------------------------------

for i, laser in ipairs(map.lasers) do
	laser.Touched:Connect(function(hit)
		if not laser:GetAttribute("On") then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local st = player and state[player]
		if player and isPlaying(st) then
			if not isAlarmed(player) then
				notify(player, "ALARM! You tripped a laser. The guards know where you are!", RED)
			end
			raiseAlarm(player)
		end
	end)
	task.spawn(function()
		task.wait(i * 0.7)
		while laser.Parent do
			laser:SetAttribute("On", true)
			laser.Transparency = 0.2
			task.wait(3)
			laser:SetAttribute("On", false)
			laser.Transparency = 0.9
			task.wait(1.5)
		end
	end)
end

--------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------

local function setupCharacter(player: Player, char: Model)
	local st = state[player]
	local root = char:WaitForChild("HumanoidRootPart", 10)
	local head = char:WaitForChild("Head", 10)
	local humanoid = char:WaitForChild("Humanoid", 10)
	if not (root and head and humanoid) or state[player] ~= st then
		return
	end

	local robPrompt = Instance.new("ProximityPrompt")
	robPrompt.Name = "RobPrompt"
	robPrompt.ActionText = "Rob"
	robPrompt.ObjectText = player.DisplayName
	robPrompt.HoldDuration = 0.75
	robPrompt.MaxActivationDistance = 7
	robPrompt.RequiresLineOfSight = false
	robPrompt.Enabled = false
	robPrompt.Parent = root
	robPrompt.Triggered:Connect(function(robber)
		onRob(robber, player)
	end)

	local tag = Instance.new("BillboardGui")
	tag.Name = "LootTag"
	tag.Size = UDim2.fromOffset(160, 36)
	tag.StudsOffset = Vector3.new(0, 2.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 80
	tag.Enabled = false
	tag.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = YELLOW
	label.TextStrokeTransparency = 0
	label.Parent = tag

	humanoid.Died:Connect(function()
		if #st.bag > 0 then
			st.bag = {}
			notify(player, "You dropped all your loot!", RED)
			refreshPlayer(player)
		end
	end)

	refreshPlayer(player)

	-- Joining mid-round or respawning: drop them back into the action.
	if roundActive then
		st.inRound = true
		task.wait(0.2)
		if st.jailed then
			teleport(player, map.jail)
		else
			sendToStore(player)
		end
	end
end

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)
	if not player.Parent then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local best = Instance.new("IntValue")
	best.Name = "Best Heist"
	best.Parent = leaderstats
	leaderstats.Parent = player

	state[player] = {
		data = data,
		bag = {},
		inRound = false,
		jailed = false,
		lastRob = 0,
		roundEarnings = 0,
		cashValue = cash,
		bestValue = best,
	}

	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
	refreshPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local st = state[player]
	state[player] = nil
	alarms[player] = nil
	if st then
		DataService.save(player, st.data)
	end
end)

game:BindToClose(function()
	for player, st in pairs(state) do
		DataService.save(player, st.data)
	end
end)

task.spawn(function()
	while true do
		task.wait(120)
		for player, st in pairs(state) do
			task.spawn(DataService.save, player, st.data)
		end
	end
end)

buyEvent.OnServerEvent:Connect(function(player, kind)
	local st = state[player]
	local upgrade = typeof(kind) == "string" and Config.Upgrades[kind]
	if not st or not upgrade then
		return
	end
	local key = kind .. "Level"
	local level = st.data[key]
	local nextLevel = upgrade.Levels[level + 1]
	if not nextLevel then
		notify(player, upgrade.Title .. " is already maxed out!", YELLOW)
		return
	end
	if st.data.Cash < nextLevel.Cost then
		notify(player, string.format("You need %s more for that.", formatMoney(nextLevel.Cost - st.data.Cash)), RED)
		return
	end
	st.data.Cash -= nextLevel.Cost
	st.data[key] = level + 1
	refreshPlayer(player)
	notify(player, string.format("%s upgraded to level %d!", upgrade.Title, level + 1), GREEN)
end)

--------------------------------------------------------------------------------
-- Rounds
--------------------------------------------------------------------------------

local function setStatus(status: string, timeLeft: number)
	ReplicatedStorage:SetAttribute("RoundState", status)
	ReplicatedStorage:SetAttribute("TimeLeft", timeLeft)
end

local function startRound()
	roundId += 1
	roundActive = true
	table.clear(alarms)

	for _, spawnPart in ipairs(map.lootSpawns) do
		if math.random() < Config.LOOT_FILL then
			spawnLoot(spawnPart)
		end
	end

	local ctx = {
		folder = guardFolder,
		patrolPoints = map.patrolPoints,
		isTargetable = isTargetable,
		isAlarmed = isAlarmed,
		onCatch = onCaught,
	}
	for i = 1, Config.GUARD_COUNT do
		local spawnPos = map.guardSpawns[(i - 1) % #map.guardSpawns + 1]
		local guard = GuardAI.new(spawnPos, ctx)
		if guard then
			table.insert(guards, guard)
		end
	end

	for player, st in pairs(state) do
		st.bag = {}
		st.inRound = true
		st.jailed = false
		st.roundEarnings = 0
		sendToStore(player)
		refreshPlayer(player)
	end
	announce("The store is OPEN! Steal everything and escape before time runs out!")
end

local function endRound()
	roundActive = false
	for _, guard in ipairs(guards) do
		guard:destroy()
	end
	table.clear(guards)
	lootFolder:ClearAllChildren()
	table.clear(occupied)

	local results = {}
	for player, st in pairs(state) do
		if #st.bag > 0 then
			notify(player, "Time's up! You didn't escape, so your loot was confiscated.", RED)
		end
		st.bag = {}
		st.inRound = false
		st.jailed = false
		table.insert(results, { player = player, earned = st.roundEarnings })
		teleport(player, map.lobby)
		refreshPlayer(player)
	end
	table.sort(results, function(a, b)
		return a.earned > b.earned
	end)
	local top = results[1]
	if top and top.earned > 0 then
		announce(string.format("Biggest heist: %s with %s!", top.player.DisplayName, formatMoney(top.earned)))
	end
end

while true do
	while #Players:GetPlayers() < Config.MIN_PLAYERS do
		setStatus("Waiting", 0)
		task.wait(1)
	end
	for t = Config.INTERMISSION_TIME, 1, -1 do
		setStatus("Intermission", t)
		task.wait(1)
	end
	startRound()
	for t = Config.ROUND_TIME, 1, -1 do
		setStatus("Heist", t)
		task.wait(1)
	end
	endRound()
end
