-- StatsPanelController LocalScript
-- Place in: StarterGui > StatsPanel (ScreenGui) > LocalScript
-- Purpose: Handles stats panel visibility and spend button interactions

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpendStatPointRemote = Remotes:WaitForChild("SpendStatPoint")
local UpdateStatsRemote    = Remotes:WaitForChild("UpdateStats")

local ScreenGui = script.Parent
-- Hide the entire StatsPanel gui on start; the HUD button toggles it
ScreenGui.Enabled = false

local StatsPanel = ScreenGui:WaitForChild("StatsPanel")

-- Current stats cache
local currentStats = {}

-- ===========================
-- UPDATE STATS PANEL DISPLAY
-- ===========================
local statRowKeys = {
	"Strength", "Defense", "MaxHealth", "MaxMana",
	"CriticalChance", "CriticalDamage", "AttackSpeed", "MovementSpeed"
}

local spendableStats = {
	Strength = true, Defense = true,
	MaxHealth = true, MaxMana = true,
	CriticalChance = true,
}

local function UpdateStatsPanel(stats)
	currentStats = stats

	if not ScreenGui.Enabled then return end

	-- Update each row
	local statsFrame = StatsPanel:FindFirstChild("StatsFrame")
	if not statsFrame then return end

	for _, key in ipairs(statRowKeys) do
		local row = statsFrame:FindFirstChild(key .. "Row")
		if not row then continue end

		local valueLabel = row:FindFirstChild("ValueLabel")
		if valueLabel then
			local val = stats[key]
			if key == "CriticalChance" then
				valueLabel.Text = tostring(val) .. "%"
			elseif key == "CriticalDamage" then
				valueLabel.Text = tostring(val) .. "%"
			elseif key == "AttackSpeed" then
				valueLabel.Text = string.format("%.2f", val)
			else
				valueLabel.Text = tostring(val)
			end
		end

		local spendBtn = row:FindFirstChild("SpendButton")
		if spendBtn then
			local canSpend = spendableStats[key] and (stats.StatPoints or 0) > 0
			spendBtn.Visible = canSpend
			spendBtn.BackgroundColor3 = Color3.fromRGB(70, 50, 130)
		end
	end

	-- Stat points label
	local spLabel = StatsPanel:FindFirstChild("StatPointsLabel")
	if spLabel then
		local pts = stats.StatPoints or 0
		if pts > 0 then
			spLabel.Text = "⬆ Stat Points: " .. pts .. "  (Click + SPEND to allocate)"
			spLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
		else
			spLabel.Text = "Stat Points: 0  (Level up to earn more)"
			spLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
		end
	end
end

-- ===========================
-- WIRE SPEND BUTTONS
-- ===========================
local function WireSpendButtons()
	local statsFrame = StatsPanel:FindFirstChild("StatsFrame")
	if not statsFrame then return end

	for _, key in ipairs(statRowKeys) do
		local row = statsFrame:FindFirstChild(key .. "Row")
		if not row then continue end

		local spendBtn = row:FindFirstChild("SpendButton")
		if spendBtn and spendableStats[key] then
			spendBtn.MouseButton1Click:Connect(function()
				if (currentStats.StatPoints or 0) <= 0 then
					-- Flash red feedback
					local orig = spendBtn.BackgroundColor3
					spendBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
					task.delay(0.3, function()
						spendBtn.BackgroundColor3 = orig
					end)
					return
				end

				-- Send to server
				SpendStatPointRemote:FireServer(key)

				-- Optimistic UI: reduce stat points display
				currentStats.StatPoints = math.max(0, (currentStats.StatPoints or 0) - 1)
				UpdateStatsPanel(currentStats)

				-- Flash green
				local orig = spendBtn.BackgroundColor3
				spendBtn.BackgroundColor3 = Color3.fromRGB(30, 180, 60)
				task.delay(0.3, function()
					spendBtn.BackgroundColor3 = orig
				end)
			end)
		end
	end
end

-- ===========================
-- LISTEN TO STATS UPDATES
-- ===========================
UpdateStatsRemote.OnClientEvent:Connect(function(stats)
	UpdateStatsPanel(stats)
end)

-- ===========================
-- CONNECT STATS BUTTON (in HUD) TO TOGGLE THIS PANEL
-- ===========================
local function ConnectHUDStatsButton()
	-- Find the HUD in MainHUD ScreenGui
	local mainHUD = playerGui:WaitForChild("MainHUD", 10)
	if not mainHUD then return end
	local hud = mainHUD:WaitForChild("HUD", 5)
	if not hud then return end
	local statsBtn = hud:FindFirstChild("StatsButton")
	if not statsBtn then return end

	statsBtn.MouseButton1Click:Connect(function()
		local nowEnabled = not ScreenGui.Enabled
		ScreenGui.Enabled = nowEnabled
		if nowEnabled then
			UpdateStatsPanel(currentStats)
			-- Animate open
			StatsPanel.Size = UDim2.new(0, 380, 0, 0)
			TweenService:Create(StatsPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 380, 0, 480),
			}):Play()
		end
	end)

	-- Close button
	local closeBtn = StatsPanel:FindFirstChild("CloseButton")
	if closeBtn then
		closeBtn.MouseButton1Click:Connect(function()
			ScreenGui.Enabled = false
		end)
	end
end

-- ===========================
-- INIT
-- ===========================
WireSpendButtons()
ConnectHUDStatsButton()

print("[StatsPanelController] Initialized!")
