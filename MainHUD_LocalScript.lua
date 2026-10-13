-- MainHUD LocalScript
-- Place in: StarterGui > MainHUD (ScreenGui) > LocalScript
-- Purpose: Client-side HUD showing HP, Mana, XP, Level, Coins, Gems

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateStatsRemote   = Remotes:WaitForChild("UpdateStats")
local LevelUpEffectRemote = Remotes:WaitForChild("LevelUpEffect")
local SpendStatPointRemote = Remotes:WaitForChild("SpendStatPoint")
local RequestStatsRemote  = Remotes:WaitForChild("RequestStats")

-- Wait for the ScreenGui
local ScreenGui = script.Parent

-- Current stats cache
local currentStats = {}

-- ===========================
-- HP BAR (real-time from character humanoid)
-- ===========================
local function GetHUD()
	return ScreenGui:FindFirstChild("HUD")
end

-- ===========================
-- UPDATE HUD FROM STATS PACKET
-- ===========================
local function UpdateHUD(stats)
	currentStats = stats

	local HUD = GetHUD()
	if not HUD then return end

	-- Level
	local levelLabel = HUD:FindFirstChild("LevelLabel", true)
	if levelLabel then
		levelLabel.Text = "LVL " .. stats.Level
	end

	-- XP Bar
	local xpBar = HUD:FindFirstChild("XPBar", true)
	local xpFill = xpBar and xpBar:FindFirstChild("Fill")
	local xpLabel = HUD:FindFirstChild("XPLabel", true)
	if xpFill then
		local ratio = math.clamp(stats.XP / math.max(stats.XPRequired, 1), 0, 1)
		TweenService:Create(xpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()
	end
	if xpLabel then
		xpLabel.Text = stats.XP .. " / " .. stats.XPRequired .. " XP"
	end

	-- Coins & Gems
	local coinsLabel = HUD:FindFirstChild("CoinsLabel", true)
	if coinsLabel then coinsLabel.Text = "🪙 " .. tostring(stats.Coins) end

	local gemsLabel = HUD:FindFirstChild("GemsLabel", true)
	if gemsLabel then gemsLabel.Text = "💎 " .. tostring(stats.Gems) end

	-- Stat Points indicator
	local statPointsLabel = HUD:FindFirstChild("StatPointsLabel", true)
	if statPointsLabel then
		if stats.StatPoints > 0 then
			statPointsLabel.Text = "⬆ " .. stats.StatPoints .. " STAT POINTS!"
			statPointsLabel.Visible = true
		else
			statPointsLabel.Visible = false
		end
	end

	-- Update Stats Panel if open
	UpdateStatsPanel(stats)
end

-- ===========================
-- HP BAR: Poll from humanoid (real-time, not from server)
-- ===========================
local function StartHPManaUpdate()
	local RunService = game:GetService("RunService")

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		local HUD = GetHUD()
		if not HUD then return end

		-- HP Bar
		local hpBar = HUD:FindFirstChild("HPBar", true)
		local hpFill = hpBar and hpBar:FindFirstChild("Fill")
		local hpLabel = HUD:FindFirstChild("HPLabel", true)

		if hpFill then
			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			hpFill.Size = UDim2.new(ratio, 0, 1, 0)
		end
		if hpLabel then
			hpLabel.Text = math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
		end

		-- Mana bar: we fake mana as full for Stage 1 (no mana consumption yet)
		local manaBar = HUD:FindFirstChild("ManaBar", true)
		local manaFill = manaBar and manaBar:FindFirstChild("Fill")
		local manaLabel = HUD:FindFirstChild("ManaLabel", true)

		if manaFill and currentStats.MaxMana then
			-- Stage 1: mana stays at max
			manaFill.Size = UDim2.new(1, 0, 1, 0)
		end
		if manaLabel and currentStats.MaxMana then
			manaLabel.Text = currentStats.MaxMana .. " / " .. currentStats.MaxMana
		end
	end)
end

-- ===========================
-- STATS PANEL UPDATE
-- ===========================
function UpdateStatsPanel(stats)
	local StatsPanel = ScreenGui:FindFirstChild("StatsPanel")
	if not StatsPanel or not StatsPanel.Visible then return end

	local statsList = {
		{ name = "Strength",       key = "Strength"       },
		{ name = "Defense",        key = "Defense"        },
		{ name = "Max HP",         key = "MaxHealth"      },
		{ name = "Max Mana",       key = "MaxMana"        },
		{ name = "Crit Chance",    key = "CriticalChance" },
		{ name = "Crit Damage",    key = "CriticalDamage" },
		{ name = "Atk Speed",      key = "AttackSpeed"    },
		{ name = "Move Speed",     key = "MovementSpeed"  },
	}

	local frame = StatsPanel:FindFirstChild("StatsFrame")
	if not frame then return end

	for _, statInfo in ipairs(statsList) do
		local row = frame:FindFirstChild(statInfo.key .. "Row")
		if row then
			local valueLabel = row:FindFirstChild("ValueLabel")
			if valueLabel then
				local val = stats[statInfo.key]
				if statInfo.key == "CriticalChance" then
					valueLabel.Text = tostring(val) .. "%"
				elseif statInfo.key == "CriticalDamage" then
					valueLabel.Text = tostring(val) .. "%"
				elseif statInfo.key == "AttackSpeed" then
					valueLabel.Text = string.format("%.2f", val)
				else
					valueLabel.Text = tostring(val)
				end
			end

			-- Show spend button only if stat is spendable and we have points
			local spendBtn = row:FindFirstChild("SpendButton")
			local spendable = {
				Strength = true, Defense = true,
				MaxHealth = true, MaxMana = true, CriticalChance = true
			}
			if spendBtn then
				spendBtn.Visible = (spendable[statInfo.key] ~= nil) and (stats.StatPoints > 0)
			end
		end
	end

	-- Stat points display
	local pointsLabel = StatsPanel:FindFirstChild("StatPointsLabel")
	if pointsLabel then
		pointsLabel.Text = "Stat Points: " .. tostring(stats.StatPoints)
	end
end

-- ===========================
-- LEVEL UP EFFECT
-- ===========================
LevelUpEffectRemote.OnClientEvent:Connect(function(newLevel: number)
	local HUD = GetHUD()
	if not HUD then return end

	-- Create big LEVEL UP text
	local gui = Instance.new("ScreenGui")
	gui.Name = "LevelUpEffect"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 600, 0, 120)
	label.Position = UDim2.new(0.5, -300, 0.35, 0)
	label.BackgroundTransparency = 1
	label.Text = "⚡ LEVEL UP! ⚡\nLevel " .. newLevel
	label.TextColor3 = Color3.fromRGB(255, 220, 0)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = frame

	-- Animate: pop in
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	local tweenIn = TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextStrokeTransparency = 0,
	})
	tweenIn:Play()

	-- Wait then fade out
	task.delay(2, function()
		local tweenOut = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Position = UDim2.new(0.5, -300, 0.2, 0),
		})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			gui:Destroy()
		end)
	end)
end)

-- ===========================
-- RECEIVE STATS FROM SERVER
-- ===========================
UpdateStatsRemote.OnClientEvent:Connect(function(stats)
	UpdateHUD(stats)
end)

-- ===========================
-- STATS PANEL TOGGLE
-- ===========================
local function SetupStatsPanelToggle()
	local HUD = GetHUD()
	if not HUD then return end

	local statsBtn = HUD:FindFirstChild("StatsButton", true)
	local StatsPanel = ScreenGui:FindFirstChild("StatsPanel")
	if not statsBtn or not StatsPanel then return end

	statsBtn.MouseButton1Click:Connect(function()
		StatsPanel.Visible = not StatsPanel.Visible
		if StatsPanel.Visible and currentStats.Level then
			UpdateStatsPanel(currentStats)
		end
	end)

	-- Close button
	local closeBtn = StatsPanel:FindFirstChild("CloseButton")
	if closeBtn then
		closeBtn.MouseButton1Click:Connect(function()
			StatsPanel.Visible = false
		end)
	end
end

-- ===========================
-- INIT
-- ===========================
task.wait(1) -- give server time to load player data
RequestStatsRemote:FireServer()
StartHPManaUpdate()
SetupStatsPanelToggle()

print("[UIController] HUD initialized!")
