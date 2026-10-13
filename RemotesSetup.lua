-- RemotesSetup Script
-- Place in: ServerScriptService > RemotesSetup
-- Purpose: Creates all RemoteEvents BEFORE any other script tries to use them.
-- This MUST run before PlayerDataService. In Roblox, Scripts in SSS run by priority.
-- We use a Script (not a ModuleScript) so it runs immediately.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ===========================
-- CREATE REMOTES FOLDER
-- ===========================
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

-- ===========================
-- HELPER: Get or create RemoteEvent
-- ===========================
local function GetOrCreateRemote(name: string, class: string): Instance
	local existing = Remotes:FindFirstChild(name)
	if existing then return existing end

	local remote = Instance.new(class)
	remote.Name = name
	remote.Parent = Remotes
	return remote
end

-- ===========================
-- STAGE 1: PLAYER DATA REMOTES
-- ===========================
GetOrCreateRemote("UpdateStats",      "RemoteEvent")   -- Server → Client: send stats packet
GetOrCreateRemote("SpendStatPoint",   "RemoteEvent")   -- Client → Server: spend stat point
GetOrCreateRemote("RequestStats",     "RemoteEvent")   -- Client → Server: request stats refresh
GetOrCreateRemote("LevelUpEffect",    "RemoteEvent")   -- Server → Client: trigger level up VFX

-- ===========================
-- STAGE 2+ REMOTES (created now so client scripts don't error on WaitForChild)
-- ===========================
GetOrCreateRemote("AttackRequest",    "RemoteEvent")   -- Client → Server: request attack
GetOrCreateRemote("AbilityRequest",   "RemoteEvent")   -- Client → Server: use ability
GetOrCreateRemote("DamageNumber",     "RemoteEvent")   -- Server → Client: show damage number
GetOrCreateRemote("EnemyDied",        "RemoteEvent")   -- Server → Client: enemy death VFX
GetOrCreateRemote("ExtractShadow",    "RemoteEvent")   -- Client → Server: extract shadow
GetOrCreateRemote("ShadowUpdate",     "RemoteEvent")   -- Server → Client: update army panel
GetOrCreateRemote("OpenChest",        "RemoteEvent")   -- Client → Server: open chest
GetOrCreateRemote("LootDrop",         "RemoteEvent")   -- Server → Client: loot drop popup
GetOrCreateRemote("QuestUpdate",      "RemoteEvent")   -- Server → Client: quest progress
GetOrCreateRemote("ShopPurchase",     "RemoteEvent")   -- Client → Server: shop purchase

print("[RemotesSetup] All remotes created successfully!")
