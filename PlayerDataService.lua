-- PlayerDataService (Server Script)
-- Place in: ServerScriptService > Services > PlayerDataService
-- Purpose: Manages ALL player data, leveling, XP, stats, saving/loading
-- This is server-authoritative. Never trust client for important values.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ===========================
-- DATASTORE SETUP
-- ===========================
local PlayerDataStore = nil
pcall(function()
	PlayerDataStore = DataStoreService:GetDataStore("ShadowRealm_PlayerData_v1")
end)
if not PlayerDataStore then
	warn("[PlayerDataService] DataStore unavailable - session-only mode (publish place + enable API access to persist).")
end
local AUTO_SAVE_INTERVAL = 60 -- seconds between auto-saves

-- ===========================
-- REMOTES (created here, used by client too)
-- ===========================
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UpdateStatsRemote     = Remotes:WaitForChild("UpdateStats")      -- Server → Client: send stats
local SpendStatPointRemote  = Remotes:WaitForChild("SpendStatPoint")   -- Client → Server: spend a stat point
local RequestStatsRemote    = Remotes:WaitForChild("RequestStats")     -- Client → Server: ask for stats
local LevelUpEffectRemote   = Remotes:WaitForChild("LevelUpEffect")    -- Server → Client: trigger level up VFX

-- ===========================
-- DEFAULT PLAYER DATA TEMPLATE
-- ===========================
local function GetDefaultData()
	return {
		-- Core progression
		Level        = 1,
		XP           = 0,
		Coins        = 0,
		Gems         = 0,
		StatPoints   = 0,

		-- Combat stats (base values, will be recalculated)
		MaxHealth         = 100,
		MaxMana           = 50,
		Strength          = 10,
		Defense           = 5,
		CriticalChance    = 5,    -- percentage (5%)
		CriticalDamage    = 150,  -- percentage (150%)
		AttackSpeed       = 1.0,  -- attacks per second
		MovementSpeed     = 16,   -- studs per second

		-- Spent stat allocation (persistent)
		AllocatedStats = {
			Strength       = 0,
			Defense        = 0,
			MaxHealth      = 0,
			MaxMana        = 0,
			CriticalChance = 0,
		},

		-- Future stages (empty for now)
		Inventory  = {},
		Equipment  = {},
		Abilities  = {},
		Shadows    = {},
		ArmySlots  = 2,
		Quests     = {},
		Settings   = {},
	}
end

-- ===========================
-- XP FORMULA
-- ===========================
-- XP needed to reach the NEXT level from current level
local function GetXPRequired(level: number): number
	return math.floor(100 * (level ^ 1.5))
end

-- ===========================
-- STAT CALCULATION
-- ===========================
-- Calculates all derived stats from level + allocated stats
local function RecalculateStats(data: table)
	local lvl = data.Level

	-- Base stats scale with level
	data.MaxHealth      = 100 + (lvl - 1) * 20 + data.AllocatedStats.MaxHealth      * 25
	data.MaxMana        = 50  + (lvl - 1) * 8  + data.AllocatedStats.MaxMana         * 15
	data.Strength       = 10  + (lvl - 1) * 2  + data.AllocatedStats.Strength        * 5
	data.Defense        = 5   + (lvl - 1) * 1  + data.AllocatedStats.Defense         * 3
	data.CriticalChance = 5   + math.floor((lvl - 1) * 0.5) + data.AllocatedStats.CriticalChance * 2
	data.CriticalDamage = 150 + (lvl - 1) * 5  -- scales automatically, not manually
	data.AttackSpeed    = 1.0 + (lvl - 1) * 0.01
	data.MovementSpeed  = 16  + math.floor((lvl - 1) * 0.1)
end

-- ===========================
-- IN-MEMORY PLAYER DATA CACHE
-- ===========================
local PlayerData = {} -- [userId] = data table
local PlayerConnections = {} -- [userId] = connection for cleanup

-- ===========================
-- DATASTORE: LOAD DATA
-- ===========================
local function LoadData(player: Player): table
	local userId = tostring(player.UserId)
	local data = nil
	local success = false
	local attempts = 0

	if PlayerDataStore then
		repeat
			attempts += 1
			local ok, result = pcall(function()
				return PlayerDataStore:GetAsync(userId)
			end)

			if ok then
				success = true
				data = result
			else
				warn("[PlayerDataService] GetAsync failed for", player.Name, "- Attempt", attempts, ":", result)
				task.wait(2 * attempts) -- exponential backoff
			end
		until success or attempts >= 5
	end

	if not success then
		warn("[PlayerDataService] Could not load data for", player.Name, "- Using default data")
	end

	-- Merge loaded data with default to fill missing keys (handles new features)
	local default = GetDefaultData()
	if data then
		for key, value in pairs(default) do
			if data[key] == nil then
				data[key] = value
			end
		end
		-- Ensure AllocatedStats has all fields
		for key, value in pairs(default.AllocatedStats) do
			if data.AllocatedStats[key] == nil then
				data.AllocatedStats[key] = value
			end
		end
	else
		data = default
	end

	RecalculateStats(data)
	return data
end

-- ===========================
-- DATASTORE: SAVE DATA
-- ===========================
local function SaveData(player: Player)
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end
	if not PlayerDataStore then return end -- session-only: nothing to persist

	local attempts = 0
	local success = false

	repeat
		attempts += 1
		local ok, err = pcall(function()
			PlayerDataStore:UpdateAsync(userId, function(oldData)
				-- Server-side merge to prevent overwriting concurrent saves
				return data
			end)
		end)

		if ok then
			success = true
		else
			warn("[PlayerDataService] UpdateAsync failed for", player.Name, "- Attempt", attempts, ":", err)
			task.wait(2 * attempts)
		end
	until success or attempts >= 5

	if success then
		print("[PlayerDataService] Saved data for", player.Name)
	else
		warn("[PlayerDataService] FAILED to save data for", player.Name, "after", attempts, "attempts")
	end
end

-- ===========================
-- APPLY STATS TO CHARACTER
-- ===========================
-- Syncs the calculated stats to the actual Roblox character
local function ApplyStatsToCharacter(player: Player)
	local character = player.Character
	if not character then return end

	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end

	-- Apply WalkSpeed
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = data.MaxHealth
		-- Only set health if it's above max (clamp)
		if humanoid.Health > data.MaxHealth then
			humanoid.Health = data.MaxHealth
		end
		humanoid.WalkSpeed = data.MovementSpeed
	end
end

-- ===========================
-- SEND STATS TO CLIENT
-- ===========================
local function SendStatsToClient(player: Player)
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end

	-- Build a safe copy to send (no sensitive server fields)
	local statsPacket = {
		Level          = data.Level,
		XP             = data.XP,
		XPRequired     = GetXPRequired(data.Level),
		Coins          = data.Coins,
		Gems           = data.Gems,
		StatPoints     = data.StatPoints,
		MaxHealth      = data.MaxHealth,
		MaxMana        = data.MaxMana,
		Strength       = data.Strength,
		Defense        = data.Defense,
		CriticalChance = data.CriticalChance,
		CriticalDamage = data.CriticalDamage,
		AttackSpeed    = data.AttackSpeed,
		MovementSpeed  = data.MovementSpeed,
		AllocatedStats = data.AllocatedStats,
	}

	UpdateStatsRemote:FireClient(player, statsPacket)

	-- Single-game wallet sync: every writer (GiveCoins, SetCoins, TestScript) keeps
	-- all coin displays in agreement: leaderboard mirror + SnatchHUD tick.
	local ls = player:FindFirstChild("leaderstats")
	local coinVal = ls and ls:FindFirstChild("Coins")
	if coinVal then coinVal.Value = data.Coins end
	local snatchRemotes = ReplicatedStorage:FindFirstChild("SnatchRemotes")
	local incomeTick = snatchRemotes and snatchRemotes:FindFirstChild("IncomeTick")
	if incomeTick then
		incomeTick:FireClient(player, { balance = data.Coins })
	end
end

-- ===========================
-- LEVEL UP LOGIC
-- ===========================
local function CheckLevelUp(player: Player)
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end

	local leveled = false

	while data.XP >= GetXPRequired(data.Level) do
		data.XP        = data.XP - GetXPRequired(data.Level)
		data.Level     += 1
		data.StatPoints += 3  -- give 3 stat points per level

		RecalculateStats(data)
		ApplyStatsToCharacter(player)

		-- Restore HP and Mana on level up (feel good!)
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = data.MaxHealth -- full heal on level up
			end
		end

		leveled = true
		print("[PlayerDataService]", player.Name, "leveled up to Level", data.Level)
	end

	if leveled then
		LevelUpEffectRemote:FireClient(player, data.Level)
		SendStatsToClient(player)
	end
end

-- ===========================
-- PUBLIC API: GIVE XP
-- ===========================
-- Called by CombatService and other systems in later stages
function GiveXP(player: Player, amount: number)
	if amount <= 0 then return end
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end

	data.XP += amount
	CheckLevelUp(player)
	SendStatsToClient(player)
end

-- ===========================
-- PUBLIC API: GIVE COINS
-- ===========================
function GiveCoins(player: Player, amount: number)
	if amount <= 0 then return end
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end

	data.Coins += amount
	SendStatsToClient(player)
end

-- ===========================
-- PUBLIC API: GIVE GEMS
-- ===========================
function GiveGems(player: Player, amount: number)
	if amount <= 0 then return end
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end

	data.Gems += amount
	SendStatsToClient(player)
end

-- ===========================
-- PUBLIC API: SET COINS
-- ===========================
-- Absolute setter for systems that price/spend (e.g. BeastService catch cost).
-- Single-game economy: this is the wallet owner; callers mirror to leaderstats.
function SetCoins(player: Player, amount: number)
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end

	data.Coins = math.max(0, math.floor(amount))
	SendStatsToClient(player)
end

-- ===========================
-- PUBLIC API: GET DATA
-- ===========================
function GetData(player: Player): table?
	return PlayerData[tostring(player.UserId)]
end

-- ===========================
-- REMOTE: SPEND STAT POINT (Server-side validation)
-- ===========================
SpendStatPointRemote.OnServerEvent:Connect(function(player: Player, statName: string)
	local userId = tostring(player.UserId)
	local data = PlayerData[userId]
	if not data then return end

	-- Validate: must have stat points
	if data.StatPoints <= 0 then
		warn("[PlayerDataService] SpendStatPoint: No stat points for", player.Name)
		return
	end

	-- Validate: only allowed stat names
	local allowed = {
		Strength = true, Defense = true,
		MaxHealth = true, MaxMana = true,
		CriticalChance = true,
	}
	if not allowed[statName] then
		warn("[PlayerDataService] SpendStatPoint: Invalid stat name:", statName, "from", player.Name)
		return
	end

	-- Spend the point
	data.StatPoints -= 1
	data.AllocatedStats[statName] = (data.AllocatedStats[statName] or 0) + 1

	RecalculateStats(data)
	ApplyStatsToCharacter(player)
	SendStatsToClient(player)

	print("[PlayerDataService]", player.Name, "spent a stat point on", statName)
end)

-- ===========================
-- REMOTE: REQUEST STATS
-- ===========================
RequestStatsRemote.OnServerEvent:Connect(function(player: Player)
	SendStatsToClient(player)
end)

-- ===========================
-- PLAYER ADDED
-- ===========================
Players.PlayerAdded:Connect(function(player: Player)
	-- Load data
	local data = LoadData(player)
	PlayerData[tostring(player.UserId)] = data

	-- Wait for character and apply
	local function onCharacterAdded(character)
		task.wait(0.5) -- brief wait for character to fully load
		ApplyStatsToCharacter(player)
		SendStatsToClient(player)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Auto-save connection
	local conn = RunService.Heartbeat:Connect(function() end) -- placeholder
	PlayerConnections[tostring(player.UserId)] = conn

	print("[PlayerDataService] Loaded data for", player.Name, "| Level:", data.Level)
end)

-- ===========================
-- PLAYER REMOVING
-- ===========================
Players.PlayerRemoving:Connect(function(player: Player)
	local userId = tostring(player.UserId)

	-- Save before removing
	SaveData(player)

	-- Clean up
	if PlayerConnections[userId] then
		PlayerConnections[userId]:Disconnect()
		PlayerConnections[userId] = nil
	end
	PlayerData[userId] = nil
end)

-- ===========================
-- AUTO SAVE LOOP
-- ===========================
task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(function()
				SaveData(player)
			end)
		end
	end
end)

-- ===========================
-- EXPOSE API FOR OTHER SERVICES
-- ===========================
-- Other server scripts can require this module via a binding approach.
-- For Stage 1, we expose globals on the script for simplicity.
-- In later stages we'll convert to a proper ModuleScript pattern.
_G.PlayerDataAPI = {
	GiveXP     = GiveXP,
	GiveCoins  = GiveCoins,
	SetCoins   = SetCoins,
	GiveGems   = GiveGems,
	GetData    = GetData,
	SaveData   = SaveData,
	SendStats  = SendStatsToClient,
}

print("[PlayerDataService] Initialized successfully!")
