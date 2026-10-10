-- Security guards: patrol the aisles, chase anyone they can see carrying loot,
-- and catch players who get too close.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local GuardAI = {}
GuardAI.__index = GuardAI

local UNIFORM = Color3.fromRGB(30, 45, 90)
local SKIN = Color3.fromRGB(234, 184, 146)
local PANTS = Color3.fromRGB(20, 20, 30)

local function buildRig(): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = SKIN
	desc.LeftArmColor = SKIN
	desc.RightArmColor = SKIN
	desc.TorsoColor = UNIFORM
	desc.LeftLegColor = PANTS
	desc.RightLegColor = PANTS
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[StealTheStore] Could not build guard: " .. tostring(result))
		return nil
	end
	return result
end

local function addHat(model: Model, head: BasePart)
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = Vector3.new(1.3, 0.4, 1.4)
	cap.Color = UNIFORM
	cap.CanCollide = false
	cap.Massless = true
	cap.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.15, -0.1)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = cap
	weld.Parent = cap
	cap.Parent = model
end

local function addAlertIcon(head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Alert"
	gui.Size = UDim2.fromOffset(50, 50)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "!"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 50, 50)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	return gui
end

-- ctx = { folder, patrolPoints, isTargetable(player), isAlarmed(player), onCatch(player) }
function GuardAI.new(spawnPos: Vector3, ctx)
	local model = buildRig()
	if not model then
		return nil
	end
	local self = setmetatable({}, GuardAI)
	self.ctx = ctx
	self.model = model
	self.humanoid = model:FindFirstChildOfClass("Humanoid")
	self.root = model:FindFirstChild("HumanoidRootPart")
	self.alive = true

	model.Name = "Security Guard"
	self.humanoid.DisplayName = "Security"
	self.humanoid.WalkSpeed = Config.GUARD_PATROL_SPEED

	local head = model:FindFirstChild("Head")
	if head then
		addHat(model, head)
		self.alertGui = addAlertIcon(head)
	end

	model:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3, 0)))
	model.Parent = ctx.folder
	pcall(function()
		self.root:SetNetworkOwner(nil)
	end)

	self.path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5.5, AgentCanJump = false })
	task.spawn(function()
		self:run()
	end)
	return self
end

function GuardAI:canSee(targetRoot: BasePart): boolean
	local origin = self.root.Position + Vector3.new(0, 1.5, 0)
	local offset = targetRoot.Position - origin
	if offset.Magnitude > Config.GUARD_SIGHT_RANGE then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.ctx.folder, targetRoot.Parent }
	return workspace:Raycast(origin, offset, params) == nil
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function GuardAI:findTarget(): Player?
	local best, bestDist = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		if root and self.ctx.isTargetable(player) then
			local dist = (root.Position - self.root.Position).Magnitude
			if dist < bestDist and (self.ctx.isAlarmed(player) or self:canSee(root)) then
				best, bestDist = player, dist
			end
		end
	end
	return best
end

-- Walk along a computed path. Stops early when the time runs out or shouldStop() returns true.
function GuardAI:walkTo(goal: Vector3, maxTime: number, shouldStop: () -> boolean)
	local deadline = os.clock() + maxTime
	local ok = pcall(function()
		self.path:ComputeAsync(self.root.Position, goal)
	end)
	local points = {}
	if ok and self.path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(self.path:GetWaypoints()) do
			table.insert(points, wp.Position)
		end
	else
		points = { goal }
	end
	for _, point in ipairs(points) do
		self.humanoid:MoveTo(point)
		while self.alive do
			if os.clock() > deadline or shouldStop() then
				return
			end
			if ((point - self.root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2 then
				break
			end
			task.wait(0.1)
		end
		if not self.alive then
			return
		end
	end
end

function GuardAI:chase(player: Player)
	self.humanoid.WalkSpeed = Config.GUARD_CHASE_SPEED
	if self.alertGui then
		self.alertGui.Enabled = true
	end
	local lastSeen: Vector3? = nil
	while self.alive and self.ctx.isTargetable(player) do
		local root = rootOf(player)
		if not root then
			break
		end
		if (root.Position - self.root.Position).Magnitude <= Config.GUARD_CATCH_RANGE then
			self.ctx.onCatch(player)
			self.humanoid:MoveTo(self.root.Position)
			task.wait(1.5)
			break
		end
		local function seesTarget()
			return self:canSee(root)
		end
		if seesTarget() then
			lastSeen = root.Position
			self.humanoid:MoveTo(root.Position)
			task.wait(0.1)
		elseif self.ctx.isAlarmed(player) then
			self:walkTo(root.Position, 1.5, seesTarget)
		elseif lastSeen then
			local spot = lastSeen
			lastSeen = nil
			self:walkTo(spot, 4, seesTarget)
		else
			break -- lost them
		end
	end
	self.humanoid.WalkSpeed = Config.GUARD_PATROL_SPEED
	if self.alertGui then
		self.alertGui.Enabled = false
	end
end

function GuardAI:run()
	while self.alive do
		local target = self:findTarget()
		if target then
			self:chase(target)
		else
			local points = self.ctx.patrolPoints
			local goal = points[math.random(#points)]
			self:walkTo(goal, 12, function()
				return self:findTarget() ~= nil
			end)
		end
		task.wait(0.1)
	end
end

function GuardAI:destroy()
	self.alive = false
	if self.model then
		self.model:Destroy()
	end
end

return GuardAI
