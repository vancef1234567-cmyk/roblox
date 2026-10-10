-- On-screen UI: round timer, backpack, cash, messages and the upgrade shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("StealTheStoreRemotes")
local notifyEvent = remotes:WaitForChild("Notify")
local buyEvent = remotes:WaitForChild("BuyUpgrade")

local player = Players.LocalPlayer
local formatMoney = Config.formatMoney

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(20, 20, 30)
local GREEN = Color3.fromRGB(60, 200, 100)
local GRAY = Color3.fromRGB(90, 90, 100)

local function create(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function round(parent: Instance, radius: number?)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local gui = create("ScreenGui", {
	Name = "StealTheStoreUI",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Round status (top centre)
local statusLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(300, 42),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.25,
	TextColor3 = WHITE,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	Text = "",
	Parent = gui,
})
round(statusLabel)
create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = statusLabel })

-- Messages (under the status)
local toast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.new(0.9, 0, 0, 34),
	BackgroundTransparency = 1,
	TextColor3 = WHITE,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	Text = "",
	Parent = gui,
})
create("UISizeConstraint", { MaxSize = Vector2.new(700, 34), Parent = toast })

-- Backpack (bottom centre)
local bagLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(280, 40),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.25,
	TextColor3 = WHITE,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	Text = "",
	Parent = gui,
})
round(bagLabel)
create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = bagLabel })

-- Shop button (bottom right)
local shopButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12),
	Size = UDim2.fromOffset(150, 48),
	BackgroundColor3 = Color3.fromRGB(255, 170, 40),
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	Text = "UPGRADES",
	Parent = gui,
})
round(shopButton)
create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = shopButton })

local shopFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(420, 290),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.1,
	Visible = false,
	Parent = gui,
})
round(shopFrame, 14)
create("UISizeConstraint", { MaxSize = Vector2.new(420, 290), Parent = shopFrame })

local cashLabel = create("TextLabel", {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -70, 0, 40),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(255, 220, 80),
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	Text = "Cash: $0",
	Parent = shopFrame,
})

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60),
	TextColor3 = WHITE,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	Text = "X",
	Parent = shopFrame,
})
round(closeButton, 8)

local rows = {}
for i, kind in ipairs(Config.UPGRADE_ORDER) do
	local row = create("Frame", {
		Position = UDim2.new(0, 16, 0, 60 + (i - 1) * 110),
		Size = UDim2.new(1, -32, 0, 96),
		BackgroundColor3 = Color3.fromRGB(40, 40, 55),
		Parent = shopFrame,
	})
	round(row)
	local info = create("TextLabel", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -150, 1, -16),
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Text = "",
		Parent = row,
	})
	local buy = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(120, 56),
		BackgroundColor3 = GREEN,
		TextColor3 = WHITE,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Text = "",
		Parent = row,
	})
	round(buy, 8)
	buy.Activated:Connect(function()
		buyEvent:FireServer(kind)
	end)
	rows[kind] = { info = info, buy = buy }
end

local leaderstats = player:WaitForChild("leaderstats")
local cashValue = leaderstats:WaitForChild("Cash")

local function refreshShop()
	local cash = cashValue.Value
	cashLabel.Text = "Cash: " .. formatMoney(cash)
	for kind, row in pairs(rows) do
		local upgrade = Config.Upgrades[kind]
		local level = math.clamp(player:GetAttribute(kind .. "Level") or 1, 1, #upgrade.Levels)
		local current = upgrade.Levels[level]
		local nextLevel = upgrade.Levels[level + 1]
		if nextLevel then
			row.info.Text = string.format("%s (Lv %d)\n%d → %d%s", upgrade.Title, level, current.Value, nextLevel.Value, upgrade.Unit)
			row.buy.Text = formatMoney(nextLevel.Cost)
			row.buy.BackgroundColor3 = cash >= nextLevel.Cost and GREEN or GRAY
		else
			row.info.Text = string.format("%s (MAX)\n%d%s", upgrade.Title, current.Value, upgrade.Unit)
			row.buy.Text = "MAXED"
			row.buy.BackgroundColor3 = GRAY
		end
	end
end

local function refreshBag()
	if player:GetAttribute("Jailed") then
		bagLabel.Text = "🚔 IN JAIL"
		bagLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		return
	end
	local count = player:GetAttribute("BagCount") or 0
	local cap = player:GetAttribute("Capacity") or 0
	local value = player:GetAttribute("BagValue") or 0
	bagLabel.Text = string.format("🎒 %d/%d   💰 %s", count, cap, formatMoney(value))
	bagLabel.TextColor3 = (cap > 0 and count >= cap) and Color3.fromRGB(255, 170, 60) or WHITE
end

local function refreshStatus()
	local roundState = ReplicatedStorage:GetAttribute("RoundState") or "Waiting"
	local t = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	if roundState == "Heist" then
		statusLabel.Text = string.format("🛒 HEIST  %d:%02d", math.floor(t / 60), t % 60)
		statusLabel.TextColor3 = t <= 30 and Color3.fromRGB(255, 90, 90) or WHITE
	elseif roundState == "Intermission" then
		statusLabel.Text = "Store opens in " .. t
		statusLabel.TextColor3 = WHITE
	else
		statusLabel.Text = "Waiting for players..."
		statusLabel.TextColor3 = WHITE
	end
end

local toastId = 0
notifyEvent.OnClientEvent:Connect(function(text: string, color: Color3?)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or WHITE
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(3.5, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

shopButton.Activated:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
	refreshShop()
end)
closeButton.Activated:Connect(function()
	shopFrame.Visible = false
end)

for _, attr in ipairs({ "BagCount", "BagValue", "Capacity", "Jailed" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshBag)
end
for _, attr in ipairs({ "BackpackLevel", "SpeedLevel" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshShop)
end
cashValue.Changed:Connect(refreshShop)
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refreshStatus)
ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(refreshStatus)

-- You can't rob yourself, so hide the "Rob" prompt on your own character.
local function hideOwnRobPrompt(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local function hook(child: Instance)
		if child:IsA("ProximityPrompt") and child.Name == "RobPrompt" then
			child.Enabled = false
			child:GetPropertyChangedSignal("Enabled"):Connect(function()
				if child.Enabled then
					child.Enabled = false
				end
			end)
		end
	end
	for _, child in ipairs(root:GetChildren()) do
		hook(child)
	end
	root.ChildAdded:Connect(hook)
end
player.CharacterAdded:Connect(hideOwnRobPrompt)
if player.Character then
	task.spawn(hideOwnRobPrompt, player.Character)
end

refreshStatus()
refreshBag()
refreshShop()
