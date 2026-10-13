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
}

return SnatchConfig
