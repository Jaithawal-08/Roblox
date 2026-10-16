-- SnatchConfig ModuleScript
-- Place in: ReplicatedStorage > SnatchConfig
-- Purpose: Single home for Snatch a Beast tuning (slice 01: catch/earn only).
-- Mirror: this file is the source of truth; Studio copy is pushed from here.

local SnatchConfig = {
	StartingCoins = 200, -- enough for ~4 catches; tunable
	CatchPrice = 50,
	IncomePerSec = 2, -- per penned critter (~1/20th of price, per PRD)
	PedestalCount = 4,
	CatchCooldownSec = 1, -- per-player rate limit on catches
	CatchMaxDistance = 30, -- server-side sanity check (studs)
	SpawnIntervalSec = 6,
	MaxRoaming = 8,
	-- Slice 04a: theft
	LockDurationSec = 60, -- den relocks after a completed theft
	ShieldDurationSec = 60, -- victim unlurable window after being robbed
	WantedDurationSec = 60, -- thief marker duration
	SlapRange = 12, -- victim tackle range vs carrier
	SlapCooldownSec = 5,
	CarrySlowMult = 0.6, -- carrier move speed multiplier
	DenSpacing = 48, -- studs between den origins on X
	-- Slice 05: rarity / variants / mutations (zone-0 weights; zones 1+ in slice 09)
	RARITIES = {
		{ name = "Common", weight = 55, incomeMult = 1, priceMult = 1 },
		{ name = "Uncommon", weight = 30, incomeMult = 2, priceMult = 2 },
		{ name = "Rare", weight = 10, incomeMult = 4, priceMult = 5 },
		{ name = "UltraRare", weight = 4, incomeMult = 8, priceMult = 12 },
		{ name = "Legendary", weight = 1, incomeMult = 16, priceMult = 30 },
	},
	VARIANTS = {
		{ name = "Normal", weight = 85, incomeMult = 1, color = nil }, -- nil = species coat
		{ name = "Gold", weight = 10, incomeMult = 2.5, color = Color3.fromRGB(255, 210, 60) },
		{ name = "Diamond", weight = 4, incomeMult = 5, color = Color3.fromRGB(140, 230, 255) },
		{ name = "Rainbow", weight = 1, incomeMult = 12, color = Color3.fromRGB(200, 120, 255) },
	},
	MUTATIONS = { -- slice-09 weather kinds; test/ops hook lands in slice 05
		Crystal = 15, Phantom = 12, Cyber = 11,
	},
	-- SFX asset IDs (Kenney CC0, uploaded via Open Cloud). Presentation only.
	AUDIO = {
		Income = 130891093009835, -- handleCoins: coin tick
		Catch = 96580970330601, -- pepSound1: successful catch
		LevelUp = 138582674922676, -- powerUp11: level up fanfare
		Click = 111965078255836, -- metalClick: UI buttons
		Error = 114726577037046, -- lowDown: rejection buzz
		Tackle = 111974031385870, -- impactPunch: slap/tackle thud
		Lock = 94159842320372, -- metalLatch: den lock
		Bid = 134302201484660, -- phaseJump1: bid announcement
		Prestige = 132899812690701, -- threeTone1: evolve shimmer
	},
	-- Creature models by species idx (Quaternius CC0). Loaded at runtime via
	-- InsertService and auto-fit to BEAST_FIT; any failure falls back to balls.
	MODELS = {
		87326974579115, -- 1 Pebble Pup (Deer)
		119492971705679, -- 2 Moss Mouse (Bat)
		99269509607026, -- 3 Bubble Bird (Bee)
		116304813049631, -- 4 Cinder Cub (Cyclops)
		96185958398483, -- 5 Tide Turtle (Crab)
		94082290087311, -- 6 Gale Gecko (Alien)
	},
	BEAST_FIT = 4.5, -- max dimension in studs after auto-fit
	-- Trail dressing: {assetId, targetHeight, x, z} (Kenney CC0, runtime-placed).
	PROPS = {
		{ 133067432336364, 5, -30, -20 }, -- bushLarge
		{ 121781342715415, 4, 30, 20 }, -- bush
		{ 110969602175696, 6, 20, -30 }, -- rockA
		{ 78947418794391, 5, -35, 5 }, -- rockB
		{ 119987383265690, 2, 5, 8 }, -- flowerRed
		{ 130940788701543, 2, -6, 10 }, -- flowerYellow
		{ 140045105102090, 2, 8, -6 }, -- flowerPurple
		{ 81931160186457, 2, 12, 5 }, -- grass
		{ 81931160186457, 2, -12, -8 }, -- grass
		{ 116972242960593, 3, -15, -15 }, -- mushrooms
		{ 74339227838036, 4, 16, 30 }, -- campfire stones (den hearth)
	},
	GROUND_TEXTURE = 139433303276903, -- aerial_rocks diffuse (Poly Haven CC0)
}

return SnatchConfig
