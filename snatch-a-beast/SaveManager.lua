-- SaveManager (ModuleScript)
-- Place in: ServerScriptService > SaveManager
-- Slice 02: DataStore profiles with retry, validation, schema version.
-- NOTE: Requires published place + API services enabled. Until then the game falls back
-- to session-only (same behavior as now - nothing is lost, it just doesn't persist).
-- Mirror: this file is the source of truth; Studio copy is pushed from here.

local DataStoreService = game:GetService("DataStoreService")

local SaveManager = {}

local STORE_NAME = "SnatchSave_01"
local SCHEMA_VERSION = 1
local MAX_RETRIES = 3

local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk or not store then
	store = nil
	warn("[SaveManager] DataStore unavailable - session-only mode. Requires published place.")
end

local function validNumber(n)
	return type(n) == "number" and n == n and n >= 0
end

function SaveManager.validate(profile)
	if type(profile) ~= "table" then return false end
	if profile.schemaVersion ~= SCHEMA_VERSION then return false end
	if profile.coins ~= nil and not validNumber(profile.coins) then return false end
	if type(profile.penned) ~= "table" then return false end
	for _, entry in ipairs(profile.penned) do
		if type(entry) ~= "table" or type(entry.name) ~= "string" then return false end
	end
	return true
end

function SaveManager.load(userId)
	if not store then return nil end
	for attempt = 1, MAX_RETRIES do
		local okGet, data = pcall(function()
			return store:GetAsync("player_" .. userId)
		end)
		if okGet then
			if data == nil then
				return { schemaVersion = SCHEMA_VERSION, coins = nil, penned = {} }
			end
			if SaveManager.validate(data) then
				return data
			end
			warn(("[SaveManager] Invalid profile for %d, starting fresh"):format(userId))
			return { schemaVersion = SCHEMA_VERSION, coins = nil, penned = {} }
		end
		task.wait(2 ^ attempt)
	end
	warn(("[SaveManager] Load failed for %d after retries"):format(userId))
	return nil
end

function SaveManager.save(userId, profile)
	if not store then return false end
	profile.schemaVersion = SCHEMA_VERSION
	for attempt = 1, MAX_RETRIES do
		local okSet = pcall(function()
			store:SetAsync("player_" .. userId, profile)
		end)
		if okSet then return true end
		task.wait(2 ^ attempt)
	end
	warn(("[SaveManager] Save failed for %d, will retry next interval"):format(userId))
	return false
end

function SaveManager.available()
	return store ~= nil
end

return SaveManager
