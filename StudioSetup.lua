--[[
	SHADOWREALM STAGE 1 - STUDIO SETUP SCRIPT
	==========================================
	HOW TO USE:
	1. Open Roblox Studio with a BLANK place (or your current place)
	2. In Studio top menu: View → Command Bar
	3. Type this in the command bar:
	   loadstring(game:HttpGet("..."))()
	   OR: paste the content of this file into a Script in ServerScriptService,
	   then press F5 (Run), wait 2 seconds, then press Stop.
	4. Everything will be created automatically!
	5. DELETE this setup script after running it.
	==========================================
	
	ALTERNATE METHOD (easier):
	1. In Explorer, right-click ServerScriptService → Insert Object → Script
	2. Rename it "SETUP_RUN_ONCE"  
	3. Paste ALL of this code into it
	4. Click File → Publish to Roblox (or just Press Run button, not Play)
	   Actually: In Studio, select the script, then in the Properties panel
	   set RunContext to "Edit" OR just use: Plugins tab → Run Script
	   
	SIMPLEST METHOD:
	1. View → Command Bar (at the bottom of Studio)
	2. Type: loadstring(require(INSERT_ASSET_ID))() 
	   -- OR just paste chunks into the command bar
	   
	ACTUALLY THE EASIEST:
	See the comment at the bottom - use the Plugin method.
]]

-- This script creates ALL Stage 1 content when run in Studio.
-- Run it by pasting into the Command Bar in chunks, OR
-- inserting as a Script and using Test → Run (not Play).

local function Setup()

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")  
local SG = game:GetService("StarterGui")
local SP = game:GetService("StarterPlayer")

print("=== SHADOWREALM STAGE 1 SETUP STARTING ===")

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
local function GetOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local obj = Instance.new(className)
	obj.Name = name
	obj.Parent = parent
	return obj
end

local function CreateScript(parent, scriptType, name, source)
	-- Remove existing
	local existing = parent:FindFirstChild(name)
	if existing then existing:Destroy() end
	
	local s = Instance.new(scriptType)
	s.Name = name
	s.Source = source
	s.Parent = parent
	return s
end

-- ============================================================
-- STEP 1: FOLDER STRUCTURE
-- ============================================================
print("[Setup] Creating folder structure...")

-- ReplicatedStorage
local Remotes = GetOrCreate(RS, "Folder", "Remotes")
local Modules = GetOrCreate(RS, "Folder", "Modules")

-- ServerScriptService  
local Services = GetOrCreate(SSS, "Folder", "Services")

-- StarterPlayer
local SPS = SP:FindFirstChild("StarterPlayerScripts") or SP:WaitForChild("StarterPlayerScripts")

print("[Setup] Folders created!")

-- ============================================================
-- STEP 2: REMOTE EVENTS
-- ============================================================
print("[Setup] Creating RemoteEvents...")

local remoteNames = {
	"UpdateStats", "SpendStatPoint", "RequestStats", "LevelUpEffect",
	"AttackRequest", "AbilityRequest", "DamageNumber", "EnemyDied",
	"ExtractShadow", "ShadowUpdate", "OpenChest", "LootDrop",
	"QuestUpdate", "ShopPurchase"
}
for _, name in ipairs(remoteNames) do
	GetOrCreate(Remotes, "RemoteEvent", name)
end
print("[Setup] RemoteEvents created!")

-- ============================================================
-- STEP 3: RANK CONFIG MODULE
-- ============================================================
print("[Setup] Creating RankConfig...")

CreateScript(Modules, "ModuleScript", "RankConfig", [[
local RankConfig = {}

RankConfig.Ranks = {
	[1] = { name = "E",    color = Color3.fromRGB(180, 180, 180), multiplier = 1.0  },
	[2] = { name = "D",    color = Color3.fromRGB(100, 200, 100), multiplier = 1.5  },
	[3] = { name = "C",    color = Color3.fromRGB(100, 150, 255), multiplier = 2.5  },
	[4] = { name = "B",    color = Color3.fromRGB(180, 100, 255), multiplier = 4.0  },
	[5] = { name = "A",    color = Color3.fromRGB(255, 200, 0),   multiplier = 7.0  },
	[6] = { name = "S",    color = Color3.fromRGB(255, 120, 0),   multiplier = 12.0 },
	[7] = { name = "SS",   color = Color3.fromRGB(255, 50,  50),  multiplier = 20.0 },
	[8] = { name = "SSS",  color = Color3.fromRGB(200, 0,   200), multiplier = 35.0 },
	[9] = { name = "SSS+", color = Color3.fromRGB(255, 255, 255), multiplier = 60.0 },
}

RankConfig.RankIndex = {}
for i, rankData in ipairs(RankConfig.Ranks) do
	RankConfig.RankIndex[rankData.name] = i
end

function RankConfig.GetRank(rankName: string)
	local idx = RankConfig.RankIndex[rankName]
	if idx then return RankConfig.Ranks[idx] end
	return RankConfig.Ranks[1]
end

function RankConfig.GetRankName(index: number): string
	local r = RankConfig.Ranks[index]
	return r and r.name or "E"
end

return RankConfig
]])

print("[Setup] RankConfig created!")

-- ============================================================
-- STEP 4: PLAYER DATA SERVICE
-- ============================================================
print("[Setup] Creating PlayerDataService...")

CreateScript(Services, "Script", "PlayerDataService", [[
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerDataStore = DataStoreService:GetDataStore("ShadowRealm_PlayerData_v1")
local AUTO_SAVE_INTERVAL = 60

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateStatsRemote    = Remotes:WaitForChild("UpdateStats")
local SpendStatPointRemote = Remotes:WaitForChild("SpendStatPoint")
local RequestStatsRemote   = Remotes:WaitForChild("RequestStats")
local LevelUpEffectRemote  = Remotes:WaitForChild("LevelUpEffect")

local function GetDefaultData()
	return {
		Level = 1, XP = 0, Coins = 0, Gems = 0, StatPoints = 0,
		MaxHealth = 100, MaxMana = 50,
		Strength = 10, Defense = 5,
		CriticalChance = 5, CriticalDamage = 150,
		AttackSpeed = 1.0, MovementSpeed = 16,
		AllocatedStats = {
			Strength = 0, Defense = 0,
			MaxHealth = 0, MaxMana = 0, CriticalChance = 0,
		},
		Inventory = {}, Equipment = {}, Abilities = {},
		Shadows = {}, ArmySlots = 2, Quests = {}, Settings = {},
	}
end

local function GetXPRequired(level: number): number
	return math.floor(100 * (level ^ 1.5))
end

local function RecalculateStats(data)
	local lvl = data.Level
	data.MaxHealth      = 100 + (lvl-1)*20 + data.AllocatedStats.MaxHealth      * 25
	data.MaxMana        = 50  + (lvl-1)*8  + data.AllocatedStats.MaxMana         * 15
	data.Strength       = 10  + (lvl-1)*2  + data.AllocatedStats.Strength        * 5
	data.Defense        = 5   + (lvl-1)*1  + data.AllocatedStats.Defense         * 3
	data.CriticalChance = 5   + math.floor((lvl-1)*0.5) + data.AllocatedStats.CriticalChance * 2
	data.CriticalDamage = 150 + (lvl-1)*5
	data.AttackSpeed    = math.floor((1.0 + (lvl-1)*0.01)*100)/100
	data.MovementSpeed  = 16  + math.floor((lvl-1)*0.1)
end

local PlayerData = {}
local PlayerConnections = {}

local function LoadData(player: Player)
	local userId = tostring(player.UserId)
	local data = nil
	local attempts = 0
	repeat
		attempts += 1
		local ok, result = pcall(function()
			return PlayerDataStore:GetAsync(userId)
		end)
		if ok then data = result; break
		else warn("[PlayerDataService] GetAsync failed attempt", attempts, ":", result)
			task.wait(2 * attempts)
		end
	until attempts >= 5
	
	local default = GetDefaultData()
	if data then
		for k, v in pairs(default) do
			if data[k] == nil then data[k] = v end
		end
		for k, v in pairs(default.AllocatedStats) do
			if data.AllocatedStats[k] == nil then data.AllocatedStats[k] = v end
		end
	else
		data = default
	end
	RecalculateStats(data)
	return data
end

local function SaveData(player: Player)
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end
	local attempts = 0
	repeat
		attempts += 1
		local ok, err = pcall(function()
			PlayerDataStore:UpdateAsync(userId, function() return data end)
		end)
		if ok then print("[PlayerDataService] Saved:", player.Name); return
		else warn("[PlayerDataService] Save failed attempt", attempts, ":", err)
			task.wait(2 * attempts)
		end
	until attempts >= 5
	warn("[PlayerDataService] FAILED to save data for", player.Name)
end

local function ApplyStatsToCharacter(player: Player)
	local character = player.Character
	if not character then return end
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = data.MaxHealth
		if humanoid.Health > data.MaxHealth then humanoid.Health = data.MaxHealth end
		humanoid.WalkSpeed = data.MovementSpeed
	end
end

local function SendStatsToClient(player: Player)
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end
	UpdateStatsRemote:FireClient(player, {
		Level = data.Level, XP = data.XP,
		XPRequired = GetXPRequired(data.Level),
		Coins = data.Coins, Gems = data.Gems,
		StatPoints = data.StatPoints,
		MaxHealth = data.MaxHealth, MaxMana = data.MaxMana,
		Strength = data.Strength, Defense = data.Defense,
		CriticalChance = data.CriticalChance,
		CriticalDamage = data.CriticalDamage,
		AttackSpeed = data.AttackSpeed,
		MovementSpeed = data.MovementSpeed,
		AllocatedStats = data.AllocatedStats,
	})
end

local function CheckLevelUp(player: Player)
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end
	local leveled = false
	while data.XP >= GetXPRequired(data.Level) do
		data.XP -= GetXPRequired(data.Level)
		data.Level += 1
		data.StatPoints += 3
		RecalculateStats(data)
		ApplyStatsToCharacter(player)
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = data.MaxHealth end
		end
		leveled = true
		print("[PlayerDataService]", player.Name, "leveled up to Level", data.Level)
	end
	if leveled then
		LevelUpEffectRemote:FireClient(player, data.Level)
		SendStatsToClient(player)
	end
end

-- Public API
function GiveXP(player: Player, amount: number)
	if amount <= 0 then return end
	local data = PlayerData[tostring(player.UserId)]
	if not data then return end
	data.XP += amount
	CheckLevelUp(player)
	SendStatsToClient(player)
end

function GiveCoins(player: Player, amount: number)
	if amount <= 0 then return end
	local data = PlayerData[tostring(player.UserId)]
	if not data then return end
	data.Coins += amount
	SendStatsToClient(player)
end

function GiveGems(player: Player, amount: number)
	if amount <= 0 then return end
	local data = PlayerData[tostring(player.UserId)]
	if not data then return end
	data.Gems += amount
	SendStatsToClient(player)
end

function GetData(player: Player)
	return PlayerData[tostring(player.UserId)]
end

SpendStatPointRemote.OnServerEvent:Connect(function(player: Player, statName: string)
	local data = PlayerData[tostring(player.UserId)]
	if not data then return end
	if data.StatPoints <= 0 then return end
	local allowed = { Strength=true, Defense=true, MaxHealth=true, MaxMana=true, CriticalChance=true }
	if not allowed[statName] then
		warn("[PlayerDataService] Invalid stat name:", statName, "from", player.Name)
		return
	end
	data.StatPoints -= 1
	data.AllocatedStats[statName] = (data.AllocatedStats[statName] or 0) + 1
	RecalculateStats(data)
	ApplyStatsToCharacter(player)
	SendStatsToClient(player)
	print("[PlayerDataService]", player.Name, "spent stat point on", statName)
end)

RequestStatsRemote.OnServerEvent:Connect(function(player: Player)
	SendStatsToClient(player)
end)

Players.PlayerAdded:Connect(function(player: Player)
	local data = LoadData(player)
	PlayerData[tostring(player.UserId)] = data
	local function onChar(char)
		task.wait(0.5)
		ApplyStatsToCharacter(player)
		SendStatsToClient(player)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then onChar(player.Character) end
	print("[PlayerDataService] Loaded:", player.Name, "| Level:", data.Level)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	SaveData(player)
	PlayerData[tostring(player.UserId)] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(function() SaveData(p) end)
		end
	end
end)

_G.PlayerDataAPI = {
	GiveXP = GiveXP, GiveCoins = GiveCoins,
	GiveGems = GiveGems, GetData = GetData,
	SaveData = SaveData, SendStats = SendStatsToClient,
}

print("[PlayerDataService] Initialized!")
]])

print("[Setup] PlayerDataService created!")

-- ============================================================
-- STEP 5: TEST SCRIPT  
-- ============================================================
print("[Setup] Creating TestScript...")

CreateScript(SSS, "Script", "TestScript_DELETE_BEFORE_PUBLISH", [[
-- TESTING ONLY: Gives XP and Coins every 5 seconds
-- DELETE THIS BEFORE PUBLISHING!
task.wait(4)
local Players = game:GetService("Players")
while true do
	task.wait(5)
	for _, player in ipairs(Players:GetPlayers()) do
		if _G.PlayerDataAPI then
			_G.PlayerDataAPI.GiveXP(player, 50)
			_G.PlayerDataAPI.GiveCoins(player, 25)
			print("[TEST] Gave 50 XP + 25 Coins to", player.Name)
		end
	end
end
]])

print("[Setup] TestScript created!")

-- ============================================================
-- STEP 6: BUILD THE HUD UI
-- ============================================================
print("[Setup] Building Main HUD UI...")

-- Remove existing MainHUD
local existingHUD = SG:FindFirstChild("MainHUD")
if existingHUD then existingHUD:Destroy() end

local MainHUD = Instance.new("ScreenGui")
MainHUD.Name = "MainHUD"
MainHUD.ResetOnSpawn = false
MainHUD.DisplayOrder = 1
MainHUD.IgnoreGuiInset = false

-- === HUD FRAME (bottom-left) ===
local HUD = Instance.new("Frame")
HUD.Name = "HUD"
HUD.Size = UDim2.new(0, 320, 0, 168)
HUD.Position = UDim2.new(0, 10, 1, -178)
HUD.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
HUD.BackgroundTransparency = 0.15
HUD.BorderSizePixel = 0
HUD.Parent = MainHUD

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 12)
hudCorner.Parent = HUD

local hudStroke = Instance.new("UIStroke")
hudStroke.Color = Color3.fromRGB(90, 60, 150)
hudStroke.Thickness = 1.5
hudStroke.Parent = HUD

-- LEVEL label
local LevelLabel = Instance.new("TextLabel")
LevelLabel.Name = "LevelLabel"
LevelLabel.Size = UDim2.new(0, 130, 0, 30)
LevelLabel.Position = UDim2.new(0, 10, 0, 6)
LevelLabel.BackgroundTransparency = 1
LevelLabel.Text = "LVL 1"
LevelLabel.TextColor3 = Color3.fromRGB(255, 220, 0)
LevelLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
LevelLabel.TextStrokeTransparency = 0.3
LevelLabel.Font = Enum.Font.GothamBold
LevelLabel.TextSize = 20
LevelLabel.TextXAlignment = Enum.TextXAlignment.Left
LevelLabel.Parent = HUD

-- COINS label
local CoinsLabel = Instance.new("TextLabel")
CoinsLabel.Name = "CoinsLabel"
CoinsLabel.Size = UDim2.new(0, 90, 0, 22)
CoinsLabel.Position = UDim2.new(0, 145, 0, 10)
CoinsLabel.BackgroundTransparency = 1
CoinsLabel.Text = "Coins: 0"
CoinsLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
CoinsLabel.Font = Enum.Font.GothamSemibold
CoinsLabel.TextSize = 12
CoinsLabel.TextXAlignment = Enum.TextXAlignment.Left
CoinsLabel.Parent = HUD

-- GEMS label
local GemsLabel = Instance.new("TextLabel")
GemsLabel.Name = "GemsLabel"
GemsLabel.Size = UDim2.new(0, 70, 0, 22)
GemsLabel.Position = UDim2.new(0, 245, 0, 10)
GemsLabel.BackgroundTransparency = 1
GemsLabel.Text = "Gems: 0"
GemsLabel.TextColor3 = Color3.fromRGB(130, 200, 255)
GemsLabel.Font = Enum.Font.GothamSemibold
GemsLabel.TextSize = 12
GemsLabel.TextXAlignment = Enum.TextXAlignment.Left
GemsLabel.Parent = HUD

-- HP ICON
local HPIcon = Instance.new("TextLabel")
HPIcon.Name = "HPIcon"
HPIcon.Size = UDim2.new(0, 296, 0, 13)
HPIcon.Position = UDim2.new(0, 10, 0, 36)
HPIcon.BackgroundTransparency = 1
HPIcon.Text = "HP"
HPIcon.TextColor3 = Color3.fromRGB(255, 130, 130)
HPIcon.Font = Enum.Font.GothamBold
HPIcon.TextSize = 10
HPIcon.TextXAlignment = Enum.TextXAlignment.Left
HPIcon.Parent = HUD

-- HP BAR background
local HPBarBG = Instance.new("Frame")
HPBarBG.Name = "HPBar"
HPBarBG.Size = UDim2.new(0, 296, 0, 18)
HPBarBG.Position = UDim2.new(0, 10, 0, 50)
HPBarBG.BackgroundColor3 = Color3.fromRGB(15, 8, 8)
HPBarBG.BorderSizePixel = 0
HPBarBG.ClipsDescendants = true
HPBarBG.Parent = HUD
Instance.new("UICorner", HPBarBG).CornerRadius = UDim.new(0, 6)

local HPFill = Instance.new("Frame")
HPFill.Name = "Fill"
HPFill.Size = UDim2.new(1, 0, 1, 0)
HPFill.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
HPFill.BorderSizePixel = 0
HPFill.Parent = HPBarBG
Instance.new("UICorner", HPFill).CornerRadius = UDim.new(0, 6)

local HPLabel = Instance.new("TextLabel")
HPLabel.Name = "HPLabel"
HPLabel.Size = UDim2.new(1, 0, 1, 0)
HPLabel.BackgroundTransparency = 1
HPLabel.Text = "100 / 100"
HPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
HPLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
HPLabel.TextStrokeTransparency = 0
HPLabel.Font = Enum.Font.GothamBold
HPLabel.TextSize = 11
HPLabel.Parent = HPBarBG

-- MANA ICON
local ManaIcon = Instance.new("TextLabel")
ManaIcon.Name = "ManaIcon"
ManaIcon.Size = UDim2.new(0, 296, 0, 13)
ManaIcon.Position = UDim2.new(0, 10, 0, 70)
ManaIcon.BackgroundTransparency = 1
ManaIcon.Text = "MANA"
ManaIcon.TextColor3 = Color3.fromRGB(100, 150, 255)
ManaIcon.Font = Enum.Font.GothamBold
ManaIcon.TextSize = 10
ManaIcon.TextXAlignment = Enum.TextXAlignment.Left
ManaIcon.Parent = HUD

-- MANA BAR
local ManaBG = Instance.new("Frame")
ManaBG.Name = "ManaBar"
ManaBG.Size = UDim2.new(0, 296, 0, 18)
ManaBG.Position = UDim2.new(0, 10, 0, 84)
ManaBG.BackgroundColor3 = Color3.fromRGB(5, 8, 20)
ManaBG.BorderSizePixel = 0
ManaBG.ClipsDescendants = true
ManaBG.Parent = HUD
Instance.new("UICorner", ManaBG).CornerRadius = UDim.new(0, 6)

local ManaFill = Instance.new("Frame")
ManaFill.Name = "Fill"
ManaFill.Size = UDim2.new(1, 0, 1, 0)
ManaFill.BackgroundColor3 = Color3.fromRGB(50, 100, 230)
ManaFill.BorderSizePixel = 0
ManaFill.Parent = ManaBG
Instance.new("UICorner", ManaFill).CornerRadius = UDim.new(0, 6)

local ManaLabel = Instance.new("TextLabel")
ManaLabel.Name = "ManaLabel"
ManaLabel.Size = UDim2.new(1, 0, 1, 0)
ManaLabel.BackgroundTransparency = 1
ManaLabel.Text = "50 / 50"
ManaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ManaLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ManaLabel.TextStrokeTransparency = 0
ManaLabel.Font = Enum.Font.GothamBold
ManaLabel.TextSize = 11
ManaLabel.Parent = ManaBG

-- XP ICON
local XPIcon = Instance.new("TextLabel")
XPIcon.Name = "XPIcon"
XPIcon.Size = UDim2.new(0, 296, 0, 12)
XPIcon.Position = UDim2.new(0, 10, 0, 104)
XPIcon.BackgroundTransparency = 1
XPIcon.Text = "XP"
XPIcon.TextColor3 = Color3.fromRGB(160, 100, 255)
XPIcon.Font = Enum.Font.GothamBold
XPIcon.TextSize = 10
XPIcon.TextXAlignment = Enum.TextXAlignment.Left
XPIcon.Parent = HUD

-- XP BAR
local XPBG = Instance.new("Frame")
XPBG.Name = "XPBar"
XPBG.Size = UDim2.new(0, 296, 0, 14)
XPBG.Position = UDim2.new(0, 10, 0, 117)
XPBG.BackgroundColor3 = Color3.fromRGB(10, 5, 20)
XPBG.BorderSizePixel = 0
XPBG.ClipsDescendants = true
XPBG.Parent = HUD
Instance.new("UICorner", XPBG).CornerRadius = UDim.new(0, 5)

local XPFill = Instance.new("Frame")
XPFill.Name = "Fill"
XPFill.Size = UDim2.new(0, 0, 1, 0)
XPFill.BackgroundColor3 = Color3.fromRGB(120, 60, 220)
XPFill.BorderSizePixel = 0
XPFill.Parent = XPBG
Instance.new("UICorner", XPFill).CornerRadius = UDim.new(0, 5)

local XPLabel = Instance.new("TextLabel")
XPLabel.Name = "XPLabel"
XPLabel.Size = UDim2.new(1, 0, 1, 0)
XPLabel.BackgroundTransparency = 1
XPLabel.Text = "0 / 100 XP"
XPLabel.TextColor3 = Color3.fromRGB(210, 180, 255)
XPLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
XPLabel.TextStrokeTransparency = 0
XPLabel.Font = Enum.Font.GothamBold
XPLabel.TextSize = 10
XPLabel.Parent = XPBG

-- STAT POINTS alert
local StatPointsLabel = Instance.new("TextLabel")
StatPointsLabel.Name = "StatPointsLabel"
StatPointsLabel.Size = UDim2.new(0, 190, 0, 20)
StatPointsLabel.Position = UDim2.new(0, 10, 0, 143)
StatPointsLabel.BackgroundTransparency = 1
StatPointsLabel.Text = "UP STAT POINTS!"
StatPointsLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
StatPointsLabel.Font = Enum.Font.GothamBold
StatPointsLabel.TextSize = 13
StatPointsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatPointsLabel.Visible = false
StatPointsLabel.Parent = HUD

-- STATS BUTTON
local StatsButton = Instance.new("TextButton")
StatsButton.Name = "StatsButton"
StatsButton.Size = UDim2.new(0, 100, 0, 20)
StatsButton.Position = UDim2.new(0, 210, 0, 143)
StatsButton.BackgroundColor3 = Color3.fromRGB(55, 35, 100)
StatsButton.BorderSizePixel = 0
StatsButton.Text = "STATS"
StatsButton.TextColor3 = Color3.fromRGB(210, 170, 255)
StatsButton.Font = Enum.Font.GothamBold
StatsButton.TextSize = 12
StatsButton.Parent = HUD
Instance.new("UICorner", StatsButton).CornerRadius = UDim.new(0, 6)
local sbStroke = Instance.new("UIStroke", StatsButton)
sbStroke.Color = Color3.fromRGB(130, 80, 220)
sbStroke.Thickness = 1

-- HUD LocalScript
local HUDScript = Instance.new("LocalScript")
HUDScript.Name = "HUDController"
HUDScript.Source = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateStatsRemote   = Remotes:WaitForChild("UpdateStats")
local LevelUpEffectRemote = Remotes:WaitForChild("LevelUpEffect")
local RequestStatsRemote  = Remotes:WaitForChild("RequestStats")

local ScreenGui = script.Parent
local HUD = ScreenGui:WaitForChild("HUD")
local LevelLabel     = HUD:WaitForChild("LevelLabel")
local CoinsLabel     = HUD:WaitForChild("CoinsLabel")
local GemsLabel      = HUD:WaitForChild("GemsLabel")
local HPBar          = HUD:WaitForChild("HPBar")
local HPFill         = HPBar:WaitForChild("Fill")
local HPLabel        = HPBar:WaitForChild("HPLabel")
local ManaBar        = HUD:WaitForChild("ManaBar")
local ManaFill       = ManaBar:WaitForChild("Fill")
local ManaLabel      = ManaBar:WaitForChild("ManaLabel")
local XPBar          = HUD:WaitForChild("XPBar")
local XPFill         = XPBar:WaitForChild("Fill")
local XPLabel        = XPBar:WaitForChild("XPLabel")
local StatPointsLabel = HUD:WaitForChild("StatPointsLabel")
local StatsButton    = HUD:WaitForChild("StatsButton")

local currentStats = {}

-- Update HUD from server stats packet
local function UpdateHUD(stats)
	currentStats = stats
	LevelLabel.Text = "LVL " .. stats.Level
	CoinsLabel.Text = "Coins: " .. tostring(stats.Coins)
	GemsLabel.Text  = "Gems: "  .. tostring(stats.Gems)
	
	-- XP bar
	local xpRatio = math.clamp(stats.XP / math.max(stats.XPRequired, 1), 0, 1)
	TweenService:Create(XPFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.new(xpRatio, 0, 1, 0)
	}):Play()
	XPLabel.Text = stats.XP .. " / " .. stats.XPRequired .. " XP"
	
	-- Stat points
	if stats.StatPoints > 0 then
		StatPointsLabel.Text = "+" .. stats.StatPoints .. " STAT POINTS!"
		StatPointsLabel.Visible = true
	else
		StatPointsLabel.Visible = false
	end
end

-- HP/Mana: poll from humanoid (real-time)
RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local hpRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	HPFill.Size = UDim2.new(hpRatio, 0, 1, 0)
	HPLabel.Text = math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
	
	-- Color shift: green->yellow->red based on HP
	local r = math.floor(lerp(45, 220, 1 - hpRatio))
	local g = math.floor(lerp(220, 45, 1 - hpRatio))
	HPFill.BackgroundColor3 = Color3.fromRGB(r, g, 45)
	
	-- Mana stays full for Stage 1
	if currentStats.MaxMana then
		ManaFill.Size = UDim2.new(1, 0, 1, 0)
		ManaLabel.Text = currentStats.MaxMana .. " / " .. currentStats.MaxMana
	end
end)

function lerp(a, b, t) return a + (b - a) * t end

-- Level up effect
LevelUpEffectRemote.OnClientEvent:Connect(function(newLevel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "LevelUpEffect"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 99
	gui.Parent = playerGui

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 500, 0, 100)
	lbl.Position = UDim2.new(0.5, -250, 0.3, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "LEVEL UP!\nLevel " .. newLevel
	lbl.TextColor3 = Color3.fromRGB(255, 230, 0)
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextStrokeTransparency = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextTransparency = 1
	lbl.Parent = gui

	-- Pop in
	TweenService:Create(lbl, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0
	}):Play()
	
	-- Pulse effect
	task.delay(0.4, function()
		for i = 1, 3 do
			task.wait(0.2)
			TweenService:Create(lbl, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(255,255,255) }):Play()
			task.wait(0.1)
			TweenService:Create(lbl, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(255,230,0) }):Play()
		end
	end)

	-- Fade out after 2.5s
	task.delay(2.5, function()
		TweenService:Create(lbl, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			TextTransparency = 1,
			Position = UDim2.new(0.5, -250, 0.15, 0),
		}):Play()
		task.delay(0.6, function() gui:Destroy() end)
	end)
end)

UpdateStatsRemote.OnClientEvent:Connect(UpdateHUD)

-- Stats button wires to StatsPanel
StatsButton.MouseButton1Click:Connect(function()
	local statsPanel = playerGui:FindFirstChild("StatsPanel")
	if statsPanel then
		statsPanel.Enabled = not statsPanel.Enabled
	end
end)

-- Request initial stats
task.wait(1.5)
RequestStatsRemote:FireServer()
print("[HUDController] Ready!")
]]
HUDScript.Parent = MainHUD

MainHUD.Parent = SG
print("[Setup] MainHUD created!")

-- ============================================================
-- STEP 7: STATS PANEL UI
-- ============================================================
print("[Setup] Building Stats Panel...")

local existingSP = SG:FindFirstChild("StatsPanel")
if existingSP then existingSP:Destroy() end

local StatsPanel_GUI = Instance.new("ScreenGui")
StatsPanel_GUI.Name = "StatsPanel"
StatsPanel_GUI.ResetOnSpawn = false
StatsPanel_GUI.DisplayOrder = 5
StatsPanel_GUI.Enabled = false

-- Main panel frame
local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.Size = UDim2.new(0, 380, 0, 490)
Panel.Position = UDim2.new(0.5, -190, 0.5, -245)
Panel.BackgroundColor3 = Color3.fromRGB(10, 10, 22)
Panel.BorderSizePixel = 0
Panel.Parent = StatsPanel_GUI
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 16)
local pStroke = Instance.new("UIStroke", Panel)
pStroke.Color = Color3.fromRGB(110, 60, 190)
pStroke.Thickness = 2

-- Title
local PanelTitle = Instance.new("TextLabel")
PanelTitle.Size = UDim2.new(1, -50, 0, 42)
PanelTitle.Position = UDim2.new(0, 16, 0, 10)
PanelTitle.BackgroundTransparency = 1
PanelTitle.Text = "CHARACTER STATS"
PanelTitle.TextColor3 = Color3.fromRGB(255, 215, 50)
PanelTitle.TextStrokeColor3 = Color3.fromRGB(0,0,0)
PanelTitle.TextStrokeTransparency = 0.3
PanelTitle.Font = Enum.Font.GothamBold
PanelTitle.TextSize = 22
PanelTitle.TextXAlignment = Enum.TextXAlignment.Left
PanelTitle.Parent = Panel

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseButton"
CloseBtn.Size = UDim2.new(0, 36, 0, 32)
CloseBtn.Position = UDim2.new(1, -46, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 35, 35)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Panel
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Stat Points label
local SPLabel = Instance.new("TextLabel")
SPLabel.Name = "StatPointsLabel"
SPLabel.Size = UDim2.new(1, -32, 0, 26)
SPLabel.Position = UDim2.new(0, 16, 0, 54)
SPLabel.BackgroundTransparency = 1
SPLabel.Text = "Stat Points: 0"
SPLabel.TextColor3 = Color3.fromRGB(80, 255, 100)
SPLabel.Font = Enum.Font.GothamSemibold
SPLabel.TextSize = 15
SPLabel.TextXAlignment = Enum.TextXAlignment.Left
SPLabel.Parent = Panel

-- Stats rows container
local StatsFrame = Instance.new("Frame")
StatsFrame.Name = "StatsFrame"
StatsFrame.Size = UDim2.new(1, -32, 1, -96)
StatsFrame.Position = UDim2.new(0, 16, 0, 88)
StatsFrame.BackgroundTransparency = 1
StatsFrame.Parent = Panel

-- Define stat rows
local statDefs = {
	{ key="Strength",       label="Strength",     icon="[STR]", spend=true  },
	{ key="Defense",        label="Defense",      icon="[DEF]", spend=true  },
	{ key="MaxHealth",      label="Max HP",       icon="[HP]",  spend=true  },
	{ key="MaxMana",        label="Max Mana",     icon="[MP]",  spend=true  },
	{ key="CriticalChance", label="Crit Chance",  icon="[CRT]", spend=true  },
	{ key="CriticalDamage", label="Crit Damage",  icon="[CDM]", spend=false },
	{ key="AttackSpeed",    label="Atk Speed",    icon="[SPD]", spend=false },
	{ key="MovementSpeed",  label="Move Speed",   icon="[MOV]", spend=false },
}

for i, def in ipairs(statDefs) do
	local rowY = (i-1) * 48

	local row = Instance.new("Frame")
	row.Name = def.key .. "Row"
	row.Size = UDim2.new(1, 0, 0, 42)
	row.Position = UDim2.new(0, 0, 0, rowY)
	row.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.Parent = StatsFrame
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(0, 42, 1, 0)
	iconLbl.Position = UDim2.new(0, 4, 0, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = def.icon
	iconLbl.TextColor3 = Color3.fromRGB(160, 120, 255)
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.TextSize = 10
	iconLbl.Parent = row

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "NameLabel"
	nameLbl.Size = UDim2.new(0, 130, 1, 0)
	nameLbl.Position = UDim2.new(0, 48, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = def.label
	nameLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
	nameLbl.Font = Enum.Font.GothamSemibold
	nameLbl.TextSize = 14
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = row

	local valLbl = Instance.new("TextLabel")
	valLbl.Name = "ValueLabel"
	valLbl.Size = UDim2.new(0, 80, 1, 0)
	valLbl.Position = UDim2.new(0, 178, 0, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Text = "0"
	valLbl.TextColor3 = Color3.fromRGB(255, 245, 100)
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextSize = 15
	valLbl.Parent = row

	if def.spend then
		local spendBtn = Instance.new("TextButton")
		spendBtn.Name = "SpendButton"
		spendBtn.Size = UDim2.new(0, 80, 0, 28)
		spendBtn.Position = UDim2.new(1, -88, 0.5, -14)
		spendBtn.BackgroundColor3 = Color3.fromRGB(65, 45, 125)
		spendBtn.BorderSizePixel = 0
		spendBtn.Text = "+ SPEND"
		spendBtn.TextColor3 = Color3.fromRGB(200, 170, 255)
		spendBtn.Font = Enum.Font.GothamBold
		spendBtn.TextSize = 11
		spendBtn.Visible = false
		spendBtn.Parent = row
		Instance.new("UICorner", spendBtn).CornerRadius = UDim.new(0, 6)
		local spStroke = Instance.new("UIStroke", spendBtn)
		spStroke.Color = Color3.fromRGB(120, 80, 220)
		spStroke.Thickness = 1
	end
end

-- Stats Panel LocalScript
local SPScript = Instance.new("LocalScript")
SPScript.Name = "StatsPanelController"
SPScript.Source = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpendStatPointRemote = Remotes:WaitForChild("SpendStatPoint")
local UpdateStatsRemote    = Remotes:WaitForChild("UpdateStats")

local ScreenGui = script.Parent
local Panel = ScreenGui:WaitForChild("Panel")
local CloseBtn = Panel:WaitForChild("CloseButton")
local SPLabel = Panel:WaitForChild("StatPointsLabel")
local StatsFrame = Panel:WaitForChild("StatsFrame")

local currentStats = {}
local spendableKeys = { Strength=true, Defense=true, MaxHealth=true, MaxMana=true, CriticalChance=true }

local function FormatValue(key, val)
	if key == "CriticalChance" or key == "CriticalDamage" then
		return tostring(val) .. "%"
	elseif key == "AttackSpeed" then
		return string.format("%.2f", tonumber(val) or 0)
	end
	return tostring(val)
end

local function RefreshPanel(stats)
	currentStats = stats
	local pts = stats.StatPoints or 0
	if pts > 0 then
		SPLabel.Text = "Stat Points: " .. pts .. "  (spend below!)"
		SPLabel.TextColor3 = Color3.fromRGB(80, 255, 100)
	else
		SPLabel.Text = "Stat Points: 0  (level up to earn more)"
		SPLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
	end
	
	for _, child in ipairs(StatsFrame:GetChildren()) do
		if child:IsA("Frame") then
			local key = child.Name:gsub("Row$", "")
			local valLbl = child:FindFirstChild("ValueLabel")
			if valLbl and stats[key] ~= nil then
				valLbl.Text = FormatValue(key, stats[key])
			end
			local spendBtn = child:FindFirstChild("SpendButton")
			if spendBtn and spendableKeys[key] then
				spendBtn.Visible = pts > 0
			end
		end
	end
end

-- Wire spend buttons
for _, child in ipairs(StatsFrame:GetChildren()) do
	if child:IsA("Frame") then
		local key = child.Name:gsub("Row$", "")
		local spendBtn = child:FindFirstChild("SpendButton")
		if spendBtn and spendableKeys[key] then
			spendBtn.MouseButton1Click:Connect(function()
				if (currentStats.StatPoints or 0) <= 0 then
					TweenService:Create(spendBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(180,30,30) }):Play()
					task.delay(0.3, function()
						TweenService:Create(spendBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(65,45,125) }):Play()
					end)
					return
				end
				SpendStatPointRemote:FireServer(key)
				currentStats.StatPoints = math.max(0, (currentStats.StatPoints or 0) - 1)
				RefreshPanel(currentStats)
				TweenService:Create(spendBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30,160,60) }):Play()
				task.delay(0.3, function()
					TweenService:Create(spendBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(65,45,125) }):Play()
				end)
			end)
		end
	end
end

CloseBtn.MouseButton1Click:Connect(function()
	ScreenGui.Enabled = false
end)

UpdateStatsRemote.OnClientEvent:Connect(function(stats)
	if ScreenGui.Enabled then RefreshPanel(stats) end
end)

print("[StatsPanelController] Ready!")
]]
SPScript.Parent = StatsPanel_GUI

StatsPanel_GUI.Parent = SG
print("[Setup] StatsPanel created!")

-- ============================================================
-- DONE!
-- ============================================================
print("")
print("==============================================")
print("  SHADOWREALM STAGE 1 SETUP COMPLETE!")
print("==============================================")
print("Created:")
print("  ReplicatedStorage/Remotes/ (14 RemoteEvents)")
print("  ReplicatedStorage/Modules/RankConfig")
print("  ServerScriptService/Services/PlayerDataService")
print("  ServerScriptService/TestScript_DELETE_BEFORE_PUBLISH")
print("  StarterGui/MainHUD (with HUDController LocalScript)")
print("  StarterGui/StatsPanel (with StatsPanelController LocalScript)")
print("")
print("NEXT: Press Play to test!")
print("  - XP and Coins auto-grant every 5 seconds")  
print("  - Watch LVL UP animation appear")
print("  - Click STATS button to open stat panel")
print("  - Spend stat points on + SPEND buttons")
print("==============================================")

end -- end Setup()

-- Run it
Setup()
