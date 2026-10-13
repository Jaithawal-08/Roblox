-- RankConfig ModuleScript
-- Place in: ReplicatedStorage > Modules > RankConfig
-- Purpose: Central config for all rank definitions used across the game

local RankConfig = {}

-- ===========================
-- RANK DEFINITIONS
-- ===========================
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

-- Map rank name to index
RankConfig.RankIndex = {}
for i, rankData in ipairs(RankConfig.Ranks) do
	RankConfig.RankIndex[rankData.name] = i
end

-- Get rank data by name
function RankConfig.GetRank(rankName: string)
	local idx = RankConfig.RankIndex[rankName]
	if idx then
		return RankConfig.Ranks[idx]
	end
	return RankConfig.Ranks[1] -- default E
end

-- Get rank name by index
function RankConfig.GetRankName(index: number): string
	local r = RankConfig.Ranks[index]
	return r and r.name or "E"
end

return RankConfig
