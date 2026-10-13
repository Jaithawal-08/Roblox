-- TestScript (Server Script)
-- Place in: ServerScriptService > TestScript
-- Purpose: TESTING ONLY - gives XP and coins every few seconds so you can see the level-up system work.
-- DELETE THIS SCRIPT before publishing your game!

local Players = game:GetService("Players")

-- Wait for PlayerDataAPI to be set up by PlayerDataService
task.wait(3) -- give PlayerDataService time to initialize

-- ===========================
-- TESTING: Auto-give XP every 5 seconds
-- ===========================
while true do
	task.wait(5)

	for _, player in ipairs(Players:GetPlayers()) do
		-- Check if the API is ready
		if _G.PlayerDataAPI then
			-- Give 50 XP and 25 coins every 5 seconds
			_G.PlayerDataAPI.GiveXP(player, 50)
			_G.PlayerDataAPI.GiveCoins(player, 25)
			print("[TestScript] Gave 50 XP and 25 Coins to", player.Name)
		else
			warn("[TestScript] PlayerDataAPI not ready yet!")
		end
	end
end
