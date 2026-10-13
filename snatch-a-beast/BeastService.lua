-- BeastService (Server Script)
-- Place in: ServerScriptService > BeastService
-- Slice 01 (Snatch a Beast): trail spawns, tap-to-catch, pedestals, coin income.
-- Server-authoritative: the client only requests catches via ProximityPrompt.
-- Mirror: this file is the source of truth; Studio copy is pushed from here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SnatchConfig"))
local SaveManager = require(script.Parent:WaitForChild("SaveManager"))

-- Original cast (no third-party IP): alliterative food/nature beasts.
local NAMES = { "Pebble Pup", "Moss Mouse", "Bubble Bird", "Cinder Cub", "Tide Turtle", "Gale Gecko" }
local COAT = {
	Color3.fromRGB(255, 170, 60), Color3.fromRGB(120, 220, 120), Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(120, 220, 220), Color3.fromRGB(190, 160, 255),
}

local WAYPOINTS = {
	Vector3.new(40, 4, -40), Vector3.new(-40, 4, -40),
	Vector3.new(-40, 4, 40), Vector3.new(40, 4, 40),
}
local PEDESTALS = {
	Vector3.new(-9, 0.5, 25), Vector3.new(-3, 0.5, 25),
	Vector3.new(3, 0.5, 25), Vector3.new(9, 0.5, 25),
}

local roaming = {} -- [Model] = waypointIndex
local penned = {} -- array of {model, owner, nameIdx} (slice 04: per-player dens)
local lastCatch = {} -- [userId] = os.clock()
local profiles = {} -- [Player] = loaded profile table

local root, remotes, trailFolder, sanctuaryFolder

local function GetOrCreateFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function GetOrCreateRemote(name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end

local function getCoins(player)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	return coins and coins.Value or 0
end

local function setCoins(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins then
		coins.Value = math.max(0, math.floor(amount))
		remotes.IncomeTick:FireClient(player, { balance = coins.Value })
	end
end

local function buildSanctuary()
	for _, pos in ipairs(PEDESTALS) do
		local pad = Instance.new("Part")
		pad.Name = "Pedestal"
		pad.Size = Vector3.new(6, 1, 6)
		pad.Position = pos
		pad.Anchored = true
		pad.Material = Enum.Material.SmoothPlastic
		pad.Color = Color3.fromRGB(90, 90, 110)
		pad.Parent = sanctuaryFolder
	end
end

local function makeCritter(nameIdx)
	local i = nameIdx or math.random(1, #NAMES)
	local model = Instance.new("Model")
	model.Name = NAMES[i]
	model:SetAttribute("NameIdx", i)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 3, 3)
	body.Shape = Enum.PartType.Ball
	body.Color = COAT[i]
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Anchored = true
	body.Parent = model

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.new(0, 120, 0, 40)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.AlwaysOnTop = true
	tag.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = NAMES[i] .. "\n$" .. Config.CatchPrice
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Parent = tag

	-- Mobile-friendly one-tap catch; server validates in tryCatch.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Catch"
	prompt.ObjectText = NAMES[i]
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.Parent = body

	model:PivotTo(CFrame.new(WAYPOINTS[1]))
	model.Parent = trailFolder
	roaming[model] = 2
	prompt.Triggered:Connect(function(player)
		tryCatch(player, model)
	end)
	return model
end

local function placePenned(model, owner)
	local body = model:FindFirstChild("Body")
	if not body then return end
	roaming[model] = nil
	local spot = PEDESTALS[#penned + 1]
	model:PivotTo(CFrame.new(spot + Vector3.new(0, 2, 0)))
	local prompt = body:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt:Destroy() end
	local tag = body:FindFirstChildOfClass("BillboardGui")
	if tag then tag:Destroy() end
	table.insert(penned, { model = model, owner = owner, nameIdx = model:GetAttribute("NameIdx") })
end

function tryCatch(player, model)
	if not roaming[model] then return end -- already penned
	local now = os.clock()
	if now - (lastCatch[player.UserId] or 0) < Config.CatchCooldownSec then return end
	lastCatch[player.UserId] = now

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local body = model:FindFirstChild("Body")
	if not hrp or not body then return end
	if (hrp.Position - body.Position).Magnitude > Config.CatchMaxDistance then
		remotes.CatchResult:FireClient(player, { ok = false, reason = "Too far away!" })
		return
	end
	if getCoins(player) < Config.CatchPrice then
		remotes.CatchResult:FireClient(player, { ok = false, reason = "Need more coins!" })
		return
	end
	if #penned >= #PEDESTALS then
		remotes.CatchResult:FireClient(player, { ok = false, reason = "Sanctuary full!" })
		return
	end

	setCoins(player, getCoins(player) - Config.CatchPrice)
	placePenned(model, player)
	print(("[BeastService] %s caught %s"):format(player.Name, model.Name))
	remotes.CatchResult:FireClient(player, { ok = true, reason = model.Name .. " penned! +" .. Config.IncomePerSec .. "/s" })
end

local function buildProfile(player)
	local entries = {}
	for _, entry in ipairs(penned) do
		if entry.owner == player and entry.model.Parent then
			table.insert(entries, { name = entry.model.Name })
		end
	end
	return { schemaVersion = 1, coins = getCoins(player), penned = entries }
end

local function savePlayer(player)
	local fresh = buildProfile(player)
	profiles[player] = fresh
	SaveManager.save(player.UserId, fresh)
end

local function nameToIdx(name)
	for idx, n in ipairs(NAMES) do
		if n == name then return idx end
	end
	return nil
end

local function onPlayerAdded(player)
	local profile = SaveManager.load(player.UserId) or { coins = nil, penned = {} }
	profiles[player] = profile

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	if profile.coins ~= nil then
		coins.Value = profile.coins
	else
		coins.Value = Config.StartingCoins
	end
	coins.Parent = ls

	-- Restore penned critters onto free pedestals.
	for _, entry in ipairs(profile.penned) do
		if #penned < #PEDESTALS then
			local model = makeCritter(nameToIdx(entry.name))
			placePenned(model, player)
		end
	end

	remotes.IncomeTick:FireClient(player, { balance = coins.Value })
end

local function onPlayerRemoving(player)
	savePlayer(player)
	profiles[player] = nil
end

-- Roam movement (8 studs/s along the waypoint loop).
RunService.Heartbeat:Connect(function(dt)
	for model, wpIndex in pairs(roaming) do
		local body = model:FindFirstChild("Body")
		if not body then
			roaming[model] = nil
		else
			local target = WAYPOINTS[wpIndex]
			local pos = body.Position
			local dir = target - pos
			if dir.Magnitude < 2 then
				roaming[model] = (wpIndex % #WAYPOINTS) + 1
			else
				local step = dir.Unit * math.min(8 * dt, dir.Magnitude)
				-- Pivot the MODEL, not the Body: keeps the stored pivot in sync,
				-- which catch-time PivotTo depends on.
				model:PivotTo(CFrame.new(pos + step, pos + step + Vector3.new(dir.X, 0, dir.Z)))
			end
		end
	end
end)

-- Spawner.
task.spawn(function()
	while true do
		local count = 0
		for _ in pairs(roaming) do count += 1 end
		if count < Config.MaxRoaming then
			makeCritter()
		end
		task.wait(Config.SpawnIntervalSec)
	end
end)

-- Income tick: 1/sec per penned critter, paid to its owner.
task.spawn(function()
	while true do
		task.wait(1)
		local owed = {}
		for _, entry in ipairs(penned) do
			if entry.owner.Parent then
				owed[entry.owner] = (owed[entry.owner] or 0) + Config.IncomePerSec
			end
		end
		for player, amount in pairs(owed) do
			setCoins(player, getCoins(player) + amount)
		end
	end
end)

-- Init (idempotent: safe to re-run).
root = GetOrCreateFolder(Workspace, "Snatch")
remotes = GetOrCreateFolder(ReplicatedStorage, "SnatchRemotes")
GetOrCreateRemote("CatchResult")
GetOrCreateRemote("IncomeTick")
trailFolder = GetOrCreateFolder(root, "Trail")
sanctuaryFolder = GetOrCreateFolder(root, "Sanctuary")
buildSanctuary()
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayer(player)
		end
	end
end)
print("[BeastService] Slice 01+02 live: catch, pen, earn, persist.")
