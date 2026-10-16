-- BeastService (Server Script)
-- Place in: ServerScriptService > BeastService
-- Slices 01+02+04a: trail spawns, tap-to-catch, per-player dens, theft (lure/carry/slap),
-- den locks, revenge shields, wanted markers. Slice 04b adds Guardian + bidding.
-- Server-authoritative: clients only trigger ProximityPrompts; every transfer validated here.
-- Mirror: this file is the source of truth; Studio copy is pushed from here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SnatchConfig"))
local SaveManager = require(script.Parent:WaitForChild("SaveManager"))
local RankConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RankConfig"))

-- Fail-safe defaults so a stale SnatchConfig can never silently kill spawning.
Config.RARITIES = Config.RARITIES or { { name = "Common", weight = 1, incomeMult = 1, priceMult = 1 } }
Config.VARIANTS = Config.VARIANTS or { { name = "Normal", weight = 1, incomeMult = 1, color = nil } }
Config.MUTATIONS = Config.MUTATIONS or {}

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
local SLOT_OFFSETS = { -9, -3, 3, 9 } -- X offsets within a den; z=25 like the old shared row
local DEN_Z = 25
local DELIVER_RADIUS = 18 -- auto-pen distance to own den center

local roaming = {} -- [Model] = waypointIndex
local penned = {} -- array of {model, owner, nameIdx, den, slot, state} (slice 04a: per-player dens)
local carried = {} -- [Model] = {entry, carrier, baseSpeed, weld, slapPrompt}
local dens = {} -- [userId] = {player, folder, originX, lockUntil}
local denCount = 0
local lastCatch = {} -- [userId] = os.clock()
local lastSlap = {} -- [userId] = os.clock()
local shieldUntil = {} -- [userId] = os.clock() (victim unlurable window)
local wantedUntil = {} -- [userId] = os.clock() (thief marker window)
local pendingOffline = {} -- [Player] = claimable offline coins (slice 10, one claim per join)
local bidWindows = {} -- [Model] = {holder, endsAt, id} (slice 04b interception)
local bidSeq = 0
local openBidWindow -- forward: assigned below; tryCatch (defined above it) calls it
-- Slice 09: live-ops event state (weather window + kind; weekly/shadow flags).
local weatherUntil = 0
local weatherKind = nil
local shadowWeekend = false
local weeklyCritter = NAMES[1]
local guardians = {} -- [Model] = {speed} (slice 04b; zone 0 exempt, none spawn naturally)
local profiles = {} -- [Player] = loaded profile table
local savePlayer -- forward: assigned below; requestPrestige (defined above it) calls it

local root, rems, trailFolder, densFolder

local function rollIdx(list)
	local total = 0
	for _, e in ipairs(list) do total += e.weight end
	local roll = math.random() * total
	for i, e in ipairs(list) do
		roll -= e.weight
		if roll <= 0 then return i end
	end
	return 1
end

local function findIdx(list, name)
	for i, e in ipairs(list) do
		if e.name == name then return i end
	end
	return nil
end

-- Per-beast price/income from its rolled traits (single source; entries snapshot income at pen).
local function beastPrice(model)
	local rar = Config.RARITIES[model:GetAttribute("RarityIdx") or 1] or Config.RARITIES[1]
	return math.max(1, math.floor(Config.CatchPrice * rar.priceMult))
end

local function beastIncome(model)
	local rar = Config.RARITIES[model:GetAttribute("RarityIdx") or 1] or Config.RARITIES[1]
	local var = Config.VARIANTS[model:GetAttribute("VariantIdx") or 1] or Config.VARIANTS[1]
	local mult = rar.incomeMult * var.incomeMult
	local mut = model:GetAttribute("Mutation")
	if mut and Config.MUTATIONS[mut] then mult *= Config.MUTATIONS[mut] end
	return Config.IncomePerSec * mult
end

-- Slice 07: prestige rank multiplier (reuses the RankConfig E→SSS+ ladder).
local function prestigeMult(player)
	local prof = profiles[player]
	local rank = (prof and prof.prestigeRank) or 1
	local def = RankConfig.Ranks[rank]
	return (def and def.multiplier) or 1
end

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
	local r = rems:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = rems
	end
	return r
end

-- Single-game economy: PlayerDataService owns the wallet. leaderstats mirrors it
-- for the leaderboard; when the API isn't ready yet we fall back to leaderstats.
local function getCoins(player)
	if _G.PlayerDataAPI then
		local data = _G.PlayerDataAPI.GetData(player)
		if data then return data.Coins end
	end
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	return coins and coins.Value or 0
end

local function setCoins(player, amount)
	amount = math.max(0, math.floor(amount))
	if _G.PlayerDataAPI and _G.PlayerDataAPI.GetData(player) then
		_G.PlayerDataAPI.SetCoins(player, amount) -- fans out: MainHUD + leaderstats + SnatchHUD
		return
	end
	-- API not ready: leaderstats-only until PlayerDataService loads.
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins then coins.Value = amount end
	rems.IncomeTick:FireClient(player, { balance = amount })
end

-- Toast + optional SFX tag. Client plays sfx when present, else Catch/Error by ok.
local function notify(player, packet, sfx)
	if sfx then packet.sfx = sfx end
	rems.CatchResult:FireClient(player, packet)
end

-- Slice 11: bond aging stages + income multipliers (tasks scale by rarity idx).
local STAGE_NAMES = { "Hatchling", "Sprout", "Stripling", "Prime" }
local STAGE_MULT = { 1, 1.15, 1.4, 1.8 }
local STAGE_TASKS = { 8, 20, 40 } -- tasks to reach stage 2/3/4

local function stageIncome(model, stage)
	return beastIncome(model) * (STAGE_MULT[stage] or 1)
end

-- Slice 11: journal milestones {combos seen, income mult, one-time prisms}.
local JOURNAL_MILES = {
	{ combos = 6, mult = 1.1, prisms = 10 },
	{ combos = 12, mult = 1.25, prisms = 25 },
	{ combos = 18, mult = 1.5, prisms = 50 },
	{ combos = 24, mult = 2, prisms = 100 },
}

local function journalCount(player)
	local prof = profiles[player]
	local d = prof and prof.discovered
	if not d then return 0 end
	local n = 0
	for _ in pairs(d) do n += 1 end
	return n
end

local function journalMult(player)
	local n = journalCount(player)
	local mult = 1
	for _, m in ipairs(JOURNAL_MILES) do
		if n >= m.combos then mult = m.mult end
	end
	return mult
end

local function grantPrisms(player, n, reason)
	local prof = profiles[player]
	if not prof then return end
	prof.prisms = (prof.prisms or 0) + n
	local ls = player:FindFirstChild("leaderstats")
	local pv = ls and ls:FindFirstChild("Prisms")
	if pv then pv.Value = prof.prisms end
	rems.PrismUpdate:FireClient(player, { balance = prof.prisms })
	notify(player, { ok = true, reason = reason })
	print(("[BeastService] %s +%d prisms (%s)"):format(player.Name, n, reason))
end

local function checkJournal(player)
	local prof = profiles[player]
	if not prof then return end
	prof.prismMiles = prof.prismMiles or {}
	local n = journalCount(player)
	for _, m in ipairs(JOURNAL_MILES) do
		if n >= m.combos and not prof.prismMiles[m.combos] then
			prof.prismMiles[m.combos] = true
			grantPrisms(player, m.prisms, "📖 Journal " .. m.combos .. "! +" .. m.prisms .. " 🔷")
		end
	end
end

local function denCenter(den)
	return Vector3.new(den.originX, 4, DEN_Z)
end

local function slotPos(den, slotIdx)
	return Vector3.new(den.originX + SLOT_OFFSETS[slotIdx], 0.5, DEN_Z)
end

local function freeSlot(denUserId)
	local den = dens[denUserId]
	if not den then return nil end
	for i = 1, Config.PedestalCount do
		local taken = false
		for _, entry in ipairs(penned) do
			if entry.den == denUserId and entry.slot == i then
				taken = true
				break
			end
		end
		if not taken then return i end
	end
	return nil
end

local function entryByModel(model)
	for _, entry in ipairs(penned) do
		if entry.model == model then return entry end
	end
	return nil
end

local function ensureDen(player)
	local userId = player.UserId
	if dens[userId] then return dens[userId] end
	denCount += 1
	local originX = (denCount - 1) * Config.DenSpacing
	local folder = Instance.new("Folder")
	folder.Name = tostring(userId)
	folder.Parent = densFolder
	for i = 1, Config.PedestalCount do
		local pad = Instance.new("Part")
		pad.Name = "Pedestal" .. i
		pad.Size = Vector3.new(6, 1, 6)
		pad.Position = Vector3.new(originX + SLOT_OFFSETS[i], 0.5, DEN_Z)
		pad.Anchored = true
		pad.Material = Enum.Material.SmoothPlastic
		pad.Color = Color3.fromRGB(90, 90, 110)
		pad.Parent = folder
	end
	dens[userId] = { player = player, folder = folder, originX = originX, lockUntil = 0 }
	-- Slice 07: Evolve prompt on the first pedestal (hold-to-confirm, no dialog needed).
	local evo = Instance.new("ProximityPrompt")
	evo.Name = "EvolvePrompt"
	evo.ActionText = "Evolve"
	evo.ObjectText = "Release den"
	evo.HoldDuration = 3
	evo.RequiresLineOfSight = false
	evo.MaxActivationDistance = 14
	evo.Parent = folder:FindFirstChild("Pedestal1")
	evo.Triggered:Connect(function(p)
		requestPrestige(p, userId)
	end)
	-- Slice 11: Fuse prompt on the second pedestal (hold 2s, auto-fuses first set).
	local fuse = Instance.new("ProximityPrompt")
	fuse.Name = "FusePrompt"
	fuse.ActionText = "Fuse"
	fuse.ObjectText = "4 Primes → Radiant"
	fuse.HoldDuration = 2
	fuse.RequiresLineOfSight = false
	fuse.MaxActivationDistance = 14
	fuse.Parent = folder:FindFirstChild("Pedestal2")
	fuse.Triggered:Connect(function(p)
		requestFuse(p, userId)
	end)
	return dens[userId]
end

local function addLurePrompt(model, entry)
	local body = model:FindFirstChild("Body")
	if not body then return end
	for _, p in ipairs(body:GetChildren()) do
		if p:IsA("ProximityPrompt") and p.ActionText == "Lure" then return end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Lure"
	prompt.ObjectText = model.Name
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Config.CatchMaxDistance
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		requestLure(player, model)
	end)
end

-- Slice 11: owner-only bonding prompt (validated server-side like everything else).
local function addBondPrompt(model)
	local body = model:FindFirstChild("Body")
	if not body then return end
	for _, p in ipairs(body:GetChildren()) do
		if p:IsA("ProximityPrompt") and p.ActionText == "Bond" then return end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Bond"
	prompt.ObjectText = model.Name
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.R -- E is taken by Lure on the same body
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Config.CatchMaxDistance
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		requestBond(player, model)
	end)
end

-- Pen a model into a den slot (catch restore, catch, or theft delivery).
local function penInDen(model, denUserId, slotIdx, owner)
	local den = dens[denUserId]
	if not den then return nil end
	local body = model:FindFirstChild("Body")
	if not body then return nil end
	roaming[model] = nil
	model:PivotTo(CFrame.new(slotPos(den, slotIdx) + Vector3.new(0, 2, 0)))
	local wild = body:FindFirstChildOfClass("ProximityPrompt")
	if wild and wild.ActionText == "Catch" then wild:Destroy() end
	local entry = entryByModel(model)
	if entry then
		entry.owner = owner
		entry.den = denUserId
		entry.slot = slotIdx
		entry.state = "penned"
	else
		entry = { model = model, owner = owner, baseName = model.Name, nameIdx = model:GetAttribute("NameIdx"), den = denUserId, slot = slotIdx, state = "penned", income = beastIncome(model), bond = 0, stage = 1, fuse = 0 }
		table.insert(penned, entry)
	end
	addLurePrompt(model, entry)
	addBondPrompt(model)
	return entry
end

local InsertService = game:GetService("InsertService")
local modelCache = {} -- [speciesIdx] = scaled template Model, or false when unusable

-- Load + auto-fit a species template once. Any failure → nil → ball fallback.
local function loadBeastTemplate(i)
	if modelCache[i] ~= nil then
		return modelCache[i] or nil
	end
	local id = Config.MODELS and Config.MODELS[i]
	local template = nil
	if id then
		local ok, asset = pcall(function() return InsertService:LoadAsset(id) end)
		if ok and asset then
			template = asset:FindFirstChildWhichIsA("Model") or asset:FindFirstChildWhichIsA("MeshPart")
			if template and template:IsA("MeshPart") then
				local wrap = Instance.new("Model")
				template.Parent = wrap
				template = wrap
			end
		end
	end
	if template then
		local size = template:GetExtentsSize()
		local big = math.max(size.X, math.max(size.Y, size.Z))
		if big > 0 then
			pcall(function() template:ScaleTo(Config.BEAST_FIT / big) end)
		end
		for _, d in ipairs(template:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		template.Parent = script
		modelCache[i] = template
	else
		modelCache[i] = false
	end
	return modelCache[i] or nil
end

-- Clone the species mesh as this beast's body (renamed "Body" for all the
-- position/prompt/weld code below). Returns model + body, or nils to fall back.
local function tryBeastModel(i, v)
	local template = loadBeastTemplate(i)
	if not template then return nil, nil end
	local ok, model = pcall(function()
		local m = template:Clone()
		local body = m:FindFirstChildWhichIsA("MeshPart", true) or m:FindFirstChildWhichIsA("BasePart", true)
		if not body then return nil end
		body.Name = "Body"
		local var = Config.VARIANTS[v]
		body.Color = (var and var.color) or Color3.new(1, 1, 1) -- white = true mesh colors
		return m
	end)
	if not ok or not model then return nil, nil end
	return model, model:FindFirstChild("Body")
end

-- Slice 09: stamp a mutation onto a live model (weather + test hook share this).
local function applyMutation(model, kind)
	if not Config.MUTATIONS[kind] then return nil end
	model:SetAttribute("Mutation", kind)
	local body = model:FindFirstChild("Body")
	if body then
		body.Color = Color3.fromRGB(255, 255, 255)
		local tag = body:FindFirstChildOfClass("BillboardGui")
		local label = tag and tag:FindFirstChildOfClass("TextLabel")
		if label and not string.find(label.Text, "✨", 1, true) then
			label.Text = "✨ " .. label.Text
		end
	end
	return model
end

local function makeCritter(nameIdx, rarityIdx, variantIdx)
	local i = nameIdx or math.random(1, #NAMES)
	local r = rarityIdx or rollIdx(Config.RARITIES)
	local v = variantIdx or rollIdx(Config.VARIANTS)
	local rar = Config.RARITIES[r]
	local var = Config.VARIANTS[v]
	local price = math.max(1, math.floor(Config.CatchPrice * rar.priceMult))
	local model, body = tryBeastModel(i, v)
	if not model then
		model = Instance.new("Model")
		body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(3, 3, 3)
		body.Shape = Enum.PartType.Ball
		body.Color = var.color or COAT[i]
		body.Material = Enum.Material.SmoothPlastic
		body.CanCollide = false
		body.Anchored = true
		body.Parent = model
	end
	model.Name = NAMES[i]
	model:SetAttribute("NameIdx", i)
	model:SetAttribute("RarityIdx", r)
	model:SetAttribute("VariantIdx", v)

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.new(0, 120, 0, 40)
	tag.StudsOffset = Vector3.new(0, (body.Size.Y or 3) * 0.5 + 2, 0)
	tag.AlwaysOnTop = true
	tag.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = NAMES[i] .. " [" .. rar.name .. "]" .. (v > 1 and " " .. var.name or "") .. "\n$" .. price
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
	-- Slice 09: mutation weather re-rolls new spawns mid-window.
	if os.clock() < weatherUntil and weatherKind and math.random() < 0.25 then
		applyMutation(model, weatherKind)
	end
	return model
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
		notify(player, { ok = false, reason = "Too far away!" })
		return
	end
	if getCoins(player) < beastPrice(model) then
		notify(player, { ok = false, reason = "Need more coins!" })
		return
	end
	local slot = freeSlot(player.UserId)
	if not slot then
		notify(player, { ok = false, reason = "Den full!" })
		return
	end

	setCoins(player, getCoins(player) - beastPrice(model))
	local entry = penInDen(model, player.UserId, slot, player)
	local prof = profiles[player]
	if prof then
		prof.discovered = prof.discovered or {}
		local varName = (Config.VARIANTS[model:GetAttribute("VariantIdx") or 1] or {}).name or "Normal"
		prof.discovered[model.Name .. "|" .. varName] = true
		checkJournal(player)
	end
	print(("[BeastService] %s caught %s"):format(player.Name, model.Name))
	notify(player, { ok = true, reason = model.Name .. " penned! +" .. beastIncome(model) .. "/s" })
	openBidWindow(player, entry)
end

-- ===========================
-- THEFT (slice 04a)
-- ===========================
local function lockDen(denUserId, duration, reason)
	local den = dens[denUserId]
	if not den then return end
	den.lockUntil = os.clock() + duration
	rems.LockState:FireAllClients({ den = denUserId, denName = den.player.Name, locked = true, reason = reason })
end

local function markWanted(player)
	wantedUntil[player.UserId] = os.clock() + Config.WantedDurationSec
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	if head:FindFirstChild("WantedTag") then return end
	local tag = Instance.new("BillboardGui")
	tag.Name = "WantedTag"
	tag.Size = UDim2.new(0, 120, 0, 40)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.AlwaysOnTop = true
	tag.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "🚨 WANTED"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	label.TextStrokeTransparency = 0.5
	label.Parent = tag
	task.delay(Config.WantedDurationSec, function()
		if tag.Parent then tag:Destroy() end
	end)
end

local function restoreSpeed(carry)
	local humanoid = carry.carrier.Character and carry.carrier.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = carry.baseSpeed end
end

local function endCarryVisuals(carry)
	if carry.weld and carry.weld.Parent then carry.weld:Destroy() end
	if carry.slapPrompt and carry.slapPrompt.Parent then carry.slapPrompt:Destroy() end
	local body = carry.entry.model:FindFirstChild("Body")
	if body then body.Anchored = true end
end

-- Drop the carried beast back to its owner's reserved slot (slap, death, leave).
local function dropBeast(model, why)
	local carry = carried[model]
	if not carry then return end
	carried[model] = nil
	restoreSpeed(carry)
	endCarryVisuals(carry)
	local entry = carry.entry
	penInDen(model, entry.den, entry.slot, entry.owner)
	notify(carry.carrier, { ok = false, reason = "Dropped " .. model.Name .. " (" .. why .. ")!" }, why == "tackled" and "Tackle" or nil)
	notify(entry.owner, { ok = true, reason = "Saved " .. model.Name .. "!" })
	print(("[BeastService] %s dropped %s (%s)"):format(carry.carrier.Name, model.Name, why))
end

-- Deliver the carried beast into the carrier's den: the theft completes.
local function deliverCarry(model)
	local carry = carried[model]
	if not carry then return end
	local thief = carry.carrier
	local slot = freeSlot(thief.UserId)
	if not slot then
		dropBeast(model, "den full")
		return
	end
	carried[model] = nil
	restoreSpeed(carry)
	if carry.weld and carry.weld.Parent then carry.weld:Destroy() end
	if carry.slapPrompt and carry.slapPrompt.Parent then carry.slapPrompt:Destroy() end
	local victim = carry.entry.owner
	penInDen(model, thief.UserId, slot, thief)
	-- Victim gets a revenge shield + instant relock; thief gets marked.
	shieldUntil[victim.UserId] = os.clock() + Config.ShieldDurationSec
	lockDen(victim.UserId, Config.LockDurationSec, "robbed")
	markWanted(thief)
	notify(thief, { ok = true, reason = model.Name .. " snatched! +" .. Config.IncomePerSec .. "/s" })
	notify(victim, { ok = false, reason = model.Name .. " was snatched! Shield up 60s." })
	print(("[BeastService] %s snatched %s from %s"):format(thief.Name, model.Name, victim.Name))
end

function requestLure(lurer, model)
	local entry = entryByModel(model)
	if not entry or entry.state ~= "penned" then return end -- already penned/carried
	if lurer == entry.owner then return end -- lure is for other players' dens
	local now = os.clock()
	if now - (lastCatch[lurer.UserId] or 0) < Config.CatchCooldownSec then return end
	lastCatch[lurer.UserId] = now

	local den = dens[entry.den]
	if not den then return end
	if now < den.lockUntil then
		notify(lurer, { ok = false, reason = "Den locked!" })
		return
	end
	if now < (shieldUntil[entry.owner.UserId] or 0) then
		notify(lurer, { ok = false, reason = "Shielded!" })
		return
	end
	if not freeSlot(lurer.UserId) then
		notify(lurer, { ok = false, reason = "Your den is full!" })
		return
	end
	local char = lurer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local body = model:FindFirstChild("Body")
	if not hrp or not humanoid or not body then return end
	if (hrp.Position - body.Position).Magnitude > Config.CatchMaxDistance then
		notify(lurer, { ok = false, reason = "Too far away!" })
		return
	end

	-- Grab: overhead carry at 60% speed. Slot stays reserved until delivered.
	entry.state = "carried"
	local lurePrompt = body:FindFirstChildOfClass("ProximityPrompt")
	if lurePrompt then lurePrompt:Destroy() end
	model:PivotTo(hrp.CFrame * CFrame.new(0, 4, 0))
	body.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = body
	weld.Parent = body
	local slapPrompt = Instance.new("ProximityPrompt")
	slapPrompt.Name = "TacklePrompt"
	slapPrompt.ActionText = "Tackle"
	slapPrompt.ObjectText = entry.owner.Name .. "'s carrier"
	slapPrompt.HoldDuration = 0
	slapPrompt.RequiresLineOfSight = false
	slapPrompt.MaxActivationDistance = Config.SlapRange
	slapPrompt.Parent = hrp
	slapPrompt.Triggered:Connect(function(player)
		requestSlap(player, model)
	end)
	carried[model] = { entry = entry, carrier = lurer, baseSpeed = humanoid.WalkSpeed, weld = weld, slapPrompt = slapPrompt }
	humanoid.WalkSpeed = humanoid.WalkSpeed * Config.CarrySlowMult
	notify(lurer, { ok = true, reason = "Carrying " .. model.Name .. " — haul it home!" })
	notify(entry.owner, { ok = false, reason = lurer.Name .. " is luring your " .. model.Name .. "!" })
	print(("[BeastService] %s lured %s from %s"):format(lurer.Name, model.Name, entry.owner.Name))
end

function requestSlap(triggerer, model)
	local carry = carried[model]
	if not carry then return end
	if triggerer ~= carry.entry.owner then return end -- only the victim tackles
	local now = os.clock()
	if now - (lastSlap[triggerer.UserId] or 0) < Config.SlapCooldownSec then return end
	local char = triggerer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local carrierHrp = carry.carrier.Character and carry.carrier.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not carrierHrp then return end
	if (hrp.Position - carrierHrp.Position).Magnitude > Config.SlapRange then return end
	lastSlap[triggerer.UserId] = now
	dropBeast(model, "tackled")
end

-- Slice 11: active bonding task. One credit per trigger (3s per-beast cooldown);
-- thresholds scale by rarity so Secrets stay a chase. Stage-ups retune income.
function requestBond(player, model)
	local entry = entryByModel(model)
	if not entry or entry.state ~= "penned" or entry.owner ~= player then return end
	local now = os.clock()
	entry.bondCd = entry.bondCd or 0
	if now - entry.bondCd < 3 then return end
	entry.bondCd = now
	entry.bond = (entry.bond or 0) + 1
	local rIdx = model:GetAttribute("RarityIdx") or 1
	local stage = 1
	for i, need in ipairs(STAGE_TASKS) do
		if entry.bond >= need * rIdx then stage = i + 1 end
	end
	if stage > (entry.stage or 1) then
		entry.stage = stage
		entry.income = stageIncome(model, stage)
		notify(player, { ok = true, reason = (entry.baseName or model.Name) .. " grew to " .. STAGE_NAMES[stage] .. "!" })
		print(("[BeastService] %s bonded %s to %s"):format(player.Name, entry.baseName or model.Name, STAGE_NAMES[stage]))
	end
end

local function applyFuseVisual(entry)
	local body = entry.model:FindFirstChild("Body")
	if not body then return end
	if (entry.fuse or 0) >= 2 then
		if not entry._megaLoop then
			entry._megaLoop = true
			body.Color = Color3.fromRGB(255, 255, 255)
			task.spawn(function()
				local h = 0
				while entry.model.Parent and (entry.fuse or 0) >= 2 do
					h = (h + 0.02) % 1
					pcall(function() body.Color = Color3.fromHSV(h, 0.7, 1) end)
					task.wait(0.1)
				end
				entry._megaLoop = nil
			end)
		end
		if not string.find(entry.model.Name, "💫", 1, true) then
			entry.model.Name = "💫 " .. (entry.baseName or entry.model.Name)
		end
	elseif (entry.fuse or 0) == 1 then
		body.Color = Color3.fromRGB(255, 240, 200)
		if not string.find(entry.model.Name, "🌟", 1, true) then
			entry.model.Name = "🌟 " .. (entry.baseName or entry.model.Name)
		end
	end
end

-- Slice 11: fuse 4 matching Primes → Radiant (2.6×), 4 Radiants → Mega (4×).
-- Auto-fuses the first valid set (no selection UI in this slice).
function requestFuse(player, denUserId)
	if player.UserId ~= denUserId then return end
	local groups = {} -- key species|variant|fuseLevel → entries at Prime/stage-4
	for _, entry in ipairs(penned) do
		if entry.owner == player and entry.state == "penned" and (entry.stage or 1) >= 4 then
			local vIdx = entry.model:GetAttribute("VariantIdx") or 1
			local key = (entry.nameIdx or 0) .. "|" .. vIdx .. "|" .. (entry.fuse or 0)
			groups[key] = groups[key] or {}
			table.insert(groups[key], entry)
		end
	end
	local set = nil
	for _, g in pairs(groups) do
		if #g >= 4 then set = g break end
	end
	if not set then
		notify(player, { ok = false, reason = "Need 4 matching Primes to fuse!" })
		return
	end
	local keep = set[1]
	for i = 2, 4 do
		local e = set[i]
		if e.model.Parent then e.model:Destroy() end
		for j = #penned, 1, -1 do
			if penned[j] == e then table.remove(penned, j) break end
		end
	end
	keep.fuse = (keep.fuse or 0) + 1
	keep.bond = 0
	keep.income = beastIncome(keep.model) * (keep.fuse >= 2 and 4 or 2.6)
	applyFuseVisual(keep)
	savePlayer(player)
	local what = keep.fuse >= 2 and "MEGA RADIANT" or "RADIANT"
	notify(player, { ok = true, reason = (keep.baseName or keep.model.Name) .. " became " .. what .. "!" }, "Prestige")
	print(("[BeastService] %s fused %s to %s"):format(player.Name, keep.baseName or "?", what))
end

-- ===========================
-- INTERCEPTION BIDDING (slice 04b)
-- ===========================
-- Rare+ wild catches announce server-wide and open an 8-second Snatch Back window:
-- anyone (not the holder) may pay 150% of coin value to take the penned beast into
-- their own den. Chains allowed until the window closes. Shadows never (none spawn).
openBidWindow = function(snapper, entry)
	if not entry then return end
	local rIdx = entry.model:GetAttribute("RarityIdx") or 1
	if rIdx < 3 then return end -- Rare+ only
	bidSeq += 1
	local model = entry.model
	local window = { holder = snapper, endsAt = os.clock() + 8, id = bidSeq }
	bidWindows[model] = window
	local price = math.floor(beastPrice(model) * 1.5)
	rems.BidOpen:FireAllClients({ beast = model.Name, by = snapper.Name, price = price })
	print(("[BeastService] Bid window open: %s snagged %s (%d coins to steal)"):format(snapper.Name, model.Name, price))
	task.delay(8, function()
		if bidWindows[model] and bidWindows[model].id == window.id then
			bidWindows[model] = nil
		end
	end)
end

function requestBid(bidder, model)
	local window = bidWindows[model]
	local entry = entryByModel(model)
	if not window or not entry or entry.state ~= "penned" then return end
	if os.clock() > window.endsAt then
		bidWindows[model] = nil
		return
	end
	if bidder == window.holder then return end
	local now = os.clock()
	if now - (lastCatch[bidder.UserId] or 0) < Config.CatchCooldownSec then return end
	local price = math.floor(beastPrice(model) * 1.5)
	if getCoins(bidder) < price then
		notify(bidder, { ok = false, reason = "Bid needs " .. price .. " coins!" })
		return
	end
	local slot = freeSlot(bidder.UserId)
	if not slot then
		notify(bidder, { ok = false, reason = "Your den is full!" })
		return
	end
	lastCatch[bidder.UserId] = now
	setCoins(bidder, getCoins(bidder) - price) -- coin sink (PRD)
	window.holder = bidder
	penInDen(model, bidder.UserId, slot, bidder)
	rems.BidOpen:FireAllClients({ beast = model.Name, by = bidder.Name, price = price, snatched = true })
	print(("[BeastService] %s outbid for %s at %d"):format(bidder.Name, model.Name, price))
end

-- ===========================
-- GUARDIANS (slice 04b)
-- ===========================
-- Zone-gated chasers. Zone 0 (Trailhead) is exempt per PRD, so none spawn naturally
-- yet — slice 09 posts them per zone. Speed beats a slowed carrier; tag = drop.
local function spawnGuardian(name, speed)
	local model = Instance.new("Model")
	model.Name = name or "Guardian"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(6, 6, 6)
	body.Shape = Enum.PartType.Ball
	body.Color = Color3.fromRGB(150, 60, 60)
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Anchored = true
	body.Parent = model
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.new(0, 140, 0, 40)
	tag.StudsOffset = Vector3.new(0, 5, 0)
	tag.AlwaysOnTop = true
	tag.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "👹 " .. model.Name
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	label.TextStrokeTransparency = 0.5
	label.Parent = tag
	model:PivotTo(CFrame.new(0, 6, -60))
	model.Parent = trailFolder
	guardians[model] = { speed = speed or 12 }
	print(("[BeastService] Guardian %s posted"):format(model.Name))
	return model
end

-- Slice 07: release the whole den → rank up on the RankConfig ladder.
function requestPrestige(player, denUserId)
	if player.UserId ~= denUserId then
		notify(player, { ok = false, reason = "Only the den owner can evolve!" })
		return
	end
	local prof = profiles[player]
	local rank = (prof and prof.prestigeRank) or 1
	if rank >= #RankConfig.Ranks then
		notify(player, { ok = false, reason = "Max rank reached!" })
		return
	end
	local count = 0
	for _, entry in ipairs(penned) do
		if entry.owner == player then count += 1 end
	end
	if count == 0 then
		notify(player, { ok = false, reason = "Pen a beast first!" })
		return
	end
	for i = #penned, 1, -1 do
		local entry = penned[i]
		if entry.owner == player then
			if carried[entry.model] then dropBeast(entry.model, "released") end
			if entry.model.Parent then entry.model:Destroy() end
			table.remove(penned, i)
		end
	end
	rank += 1
	if prof then prof.prestigeRank = rank end
	local def = RankConfig.Ranks[rank]
	local ls = player:FindFirstChild("leaderstats")
	local rv = ls and ls:FindFirstChild("Rank")
	if rv then rv.Value = def.name end
	savePlayer(player)
	notify(player, { ok = true, reason = "Evolved to rank " .. def.name .. "! Income x" .. def.multiplier }, "Prestige")
	print(("[BeastService] %s prestiged to %s"):format(player.Name, def.name))
end

local function dropAllCarried(player)
	for model, carry in pairs(carried) do
		if carry.carrier == player then
			dropBeast(model, "left")
		end
	end
end

local function buildProfile(player)
	local entries = {}
	for _, entry in ipairs(penned) do
		if entry.owner == player and entry.model.Parent then
			table.insert(entries, { name = entry.baseName or entry.model.Name, income = entry.income or Config.IncomePerSec, bond = entry.bond or 0, stage = entry.stage or 1, fuse = entry.fuse or 0 })
		end
	end
	return { schemaVersion = 1, coins = getCoins(player), penned = entries, lastSeen = os.time(), discovered = (profiles[player] and profiles[player].discovered) or {}, prestigeRank = (profiles[player] and profiles[player].prestigeRank) or 1, prisms = (profiles[player] and profiles[player].prisms) or 0, prismMiles = (profiles[player] and profiles[player].prismMiles) or {} }
end

savePlayer = function(player)
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
	ensureDen(player)

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = getCoins(player) -- mirror of the shared wallet (0 until grants land)
	coins.Parent = ls
	local rank = profile.prestigeRank or 1
	profile.prestigeRank = rank
	local rv = Instance.new("StringValue")
	rv.Name = "Rank"
	rv.Value = (RankConfig.Ranks[rank] and RankConfig.Ranks[rank].name) or "E"
	rv.Parent = ls
	profile.prisms = profile.prisms or 0
	profile.prismMiles = profile.prismMiles or {}
	local pv = Instance.new("IntValue")
	pv.Name = "Prisms"
	pv.Value = profile.prisms
	pv.Parent = ls

	if profile.coins ~= nil then
		setCoins(player, profile.coins) -- restore saved wallet
	else
		-- First-timer: pocket money. Waits briefly for PlayerDataService (load order
		-- between PlayerAdded handlers is not guaranteed); falls back to leaderstats.
		task.spawn(function()
			local waited = 0
			while not (_G.PlayerDataAPI and _G.PlayerDataAPI.GetData(player)) and waited < 5 do
				task.wait(0.5)
				waited += 0.5
			end
			setCoins(player, getCoins(player) + Config.StartingCoins)
		end)
	end

	-- Restore penned critters onto free pedestals.
	for _, entry in ipairs(profile.penned) do
		local slot = freeSlot(player.UserId)
		if slot then
			local model = makeCritter(nameToIdx(entry.name))
			local e = penInDen(model, player.UserId, slot, player)
			if e then
				e.bond = entry.bond or 0
				e.stage = entry.stage or 1
				e.fuse = entry.fuse or 0
				e.income = stageIncome(model, e.stage) * (e.fuse >= 2 and 4 or (e.fuse == 1 and 2.6 or 1))
				if e.fuse > 0 then applyFuseVisual(e) end
			end
		end
	end

	rems.IncomeTick:FireClient(player, { balance = coins.Value })

	-- Slice 10: capped offline income (25% rate, 8h cap). Computed from the stored
	-- pen rates, never stored as a balance. Published place only (needs DataStore).
	if profile.lastSeen and SaveManager.available() then
		local away = os.time() - profile.lastSeen
		if away > 60 then -- ignore session blips under a minute
			local rate = 0
			for _, e in ipairs(profile.penned) do rate += e.income or Config.IncomePerSec end
			local payout = math.floor(math.min(away, 8 * 3600) * rate * 0.25)
			if payout > 0 then
				pendingOffline[player] = payout
				rems.OfflineGrant:FireClient(player, { amount = payout })
			end
		end
	end
	player.CharacterRemoving:Connect(function()
		dropAllCarried(player)
	end)
end

local function onPlayerRemoving(player)
	dropAllCarried(player)
	pendingOffline[player] = nil
	savePlayer(player)
	profiles[player] = nil
end

-- Roam movement (8 studs/s along the waypoint loop) + carry auto-deliver check.
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
	for model, carry in pairs(carried) do
		local hrp = carry.carrier.Character and carry.carrier.Character:FindFirstChild("HumanoidRootPart")
		local den = dens[carry.carrier.UserId]
		if not hrp or not den then
			dropBeast(model, "lost")
		elseif (hrp.Position - denCenter(den)).Magnitude < DELIVER_RADIUS then
			deliverCarry(model)
		end
	end
	for gmodel, g in pairs(guardians) do
		local gbody = gmodel:FindFirstChild("Body")
		if not gbody then
			guardians[gmodel] = nil
		else
			-- Chase the nearest carrier; tag = drop. Idle when no one carries.
			local best, bestD, bestHrp = nil, math.huge, nil
			for cmodel, carry in pairs(carried) do
				local hrp = carry.carrier.Character and carry.carrier.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local d = (hrp.Position - gbody.Position).Magnitude
					if d < bestD then bestD, best, bestHrp = d, cmodel, hrp end
				end
			end
			if best and bestD < 80 then
				if bestD < 6 then
					dropBeast(best, "caught")
				else
					local dir = bestHrp.Position - gbody.Position
					local step = dir.Unit * math.min(g.speed * dt, dir.Magnitude)
					gmodel:PivotTo(CFrame.new(gbody.Position + step))
				end
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

-- Slice 09: live-ops scheduler. Opening festival ~2 min after boot (testable),
-- then hourly 10-min mutation windows. Weekly critter + shadow weekend are
-- scheduled flags until zones land (09 full); daily species bonus is live above.
task.spawn(function()
	task.wait(120)
	while true do
		local kinds = {}
		for k in pairs(Config.MUTATIONS) do table.insert(kinds, k) end
		weatherKind = kinds[math.random(1, #kinds)]
		weatherUntil = os.clock() + 600
		rems.EventState:FireAllClients({ kind = weatherKind })
		print(("[Event] Mutation weather: %s for 10 min"):format(weatherKind))
		-- Immediate effect: mutate up to 2 beasts already out (new spawns roll too).
		local pool = {}
		for model in pairs(roaming) do table.insert(pool, model) end
		for _ = 1, math.min(2, #pool) do
			local pick = table.remove(pool, math.random(1, #pool))
			applyMutation(pick, weatherKind)
		end
		task.wait(600 + 3000)
	end
end)

-- Income tick: 1/sec per penned (not carried) critter, paid to its owner.
task.spawn(function()
	while true do
		task.wait(1)
		local owed = {}
		local bonus = NAMES[(os.date("*t").wday % #NAMES) + 1] -- slice 09: daily species 2x
		for _, entry in ipairs(penned) do
			if entry.state == "penned" and entry.owner.Parent then
				local pay = (entry.income or Config.IncomePerSec) * prestigeMult(entry.owner) * journalMult(entry.owner)
				if (entry.baseName or "") == bonus then pay *= 2 end
				owed[entry.owner] = (owed[entry.owner] or 0) + pay
			end
		end
		for player, amount in pairs(owed) do
			setCoins(player, getCoins(player) + amount)
		end
	end
end)

-- Ops/test hooks (also the slice-09 force-trigger path): visible globals by design.
_G.SnatchOps = {
	SpawnBeast = function(rarityName, variantName)
		local r = (rarityName and findIdx(Config.RARITIES, rarityName)) or nil
		local v = (variantName and findIdx(Config.VARIANTS, variantName)) or nil
		local model = makeCritter(nil, r, v)
		print(("[SnatchOps] Spawned %s"):format(model.Name))
		return model
	end,
	ComputeOffline = function(awaySec, rate)
		return math.floor(math.min(awaySec, 8 * 3600) * rate * 0.25)
	end,
	SpawnGuardian = function(name, speed)
		return spawnGuardian(name, speed)
	end,
	ForceMutation = function(kind)
		if not Config.MUTATIONS[kind] then return nil end
		local roamers = {}
		for model in pairs(roaming) do table.insert(roamers, model) end
		if #roamers == 0 then return nil end
		local model = roamers[math.random(1, #roamers)]
		applyMutation(model, kind)
		print(("[SnatchOps] Mutated %s into %s"):format(model.Name, kind))
		return model
	end,
}

-- Slice assets: runtime-placed trail dressing + ground texture (binary assets can't
-- live in generate_rbxl.py, so they load by ID at boot; all fail-safe).
local function loadProp(id, targetH)
	local ok, asset = pcall(function() return InsertService:LoadAsset(id) end)
	local m = ok and asset and asset:FindFirstChildWhichIsA("Model")
	if not m then return nil end
	local size = m:GetExtentsSize()
	local big = math.max(size.X, math.max(size.Y, size.Z))
	if big > 0 then
		pcall(function() m:ScaleTo(targetH / big) end)
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	return m
end

local function buildDressing()
	local decor = GetOrCreateFolder(root, "Decor")
	for _, spec in ipairs(Config.PROPS or {}) do
		local m = loadProp(spec[1], spec[2])
		if m then
			m:PivotTo(CFrame.new(spec[3], spec[2] * 0.45, spec[4]))
			m.Parent = decor
		end
	end
	local base = Workspace:FindFirstChild("Baseplate")
	if base and Config.GROUND_TEXTURE then
		if not base:FindFirstChild("GroundTexture") then
			local t = Instance.new("Texture")
			t.Name = "GroundTexture"
			t.Texture = "rbxassetid://" .. Config.GROUND_TEXTURE
			t.StudsPerTileU = 8
			t.StudsPerTileV = 8
			t.Face = Enum.NormalId.Top
			t.Parent = base
		end
	end
end

-- Init (idempotent: safe to re-run).
root = GetOrCreateFolder(Workspace, "Snatch")
rems = GetOrCreateFolder(ReplicatedStorage, "SnatchRemotes")
GetOrCreateRemote("CatchResult")
GetOrCreateRemote("IncomeTick")
GetOrCreateRemote("LockState")
GetOrCreateRemote("OfflineGrant")
GetOrCreateRemote("OfflineClaim")
GetOrCreateRemote("BidOpen")
GetOrCreateRemote("BidRequest")
GetOrCreateRemote("EventState")
GetOrCreateRemote("PrismUpdate")
rems.OfflineClaim.OnServerEvent:Connect(function(player)
	local amt = pendingOffline[player]
	if not amt then return end -- one claim per join; replays ignored
	pendingOffline[player] = nil
	setCoins(player, getCoins(player) + amt)
	print(("[BeastService] %s claimed %d offline coins"):format(player.Name, amt))
end)
rems.BidRequest.OnServerEvent:Connect(function(player, beastName)
	if type(beastName) ~= "string" then return end
	for model, window in pairs(bidWindows) do
		if model.Parent and model.Name == beastName then
			requestBid(player, model)
			return
		end
	end
end)
trailFolder = GetOrCreateFolder(root, "Trail")
densFolder = GetOrCreateFolder(root, "Dens")
do
	local day = os.date("*t").wday
	shadowWeekend = (day == 1 or day == 7)
	weeklyCritter = NAMES[((os.time() // 604800) % #NAMES) + 1]
	print(("[Event] Today: %s 2x bonus; weekly critter: %s; shadow weekend: %s"):format(NAMES[(day % #NAMES) + 1], weeklyCritter, tostring(shadowWeekend)))
end
task.spawn(buildDressing) -- async: model loads yield, must not block spawns
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
print("[BeastService] Snatch systems live: catch, pen, earn, persist, steal, rarity, prestige, bidding, guardians.")
