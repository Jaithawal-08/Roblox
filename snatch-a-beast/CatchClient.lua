-- CatchClient (LocalScript)
-- Place in: StarterPlayer > StarterPlayerScripts > CatchClient
-- Slice 01: coin counter + catch toast. Presentation only — never decides value.
-- Mirror: this file is the source of truth; Studio copy is pushed from here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SnatchRemotes")
local incomeTick = remotes:WaitForChild("IncomeTick")
local catchResult = remotes:WaitForChild("CatchResult")
local lockState = remotes:WaitForChild("LockState")
local offlineGrant = remotes:WaitForChild("OfflineGrant")
local offlineClaim = remotes:WaitForChild("OfflineClaim")
local bidOpen = remotes:WaitForChild("BidOpen")
local bidRequest = remotes:WaitForChild("BidRequest")
local eventState = remotes:WaitForChild("EventState")
local prismUpdate = remotes:WaitForChild("PrismUpdate")

local gui = Instance.new("ScreenGui")
gui.Name = "SnatchHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local coins = Instance.new("TextLabel")
coins.Name = "CoinsLabel"
coins.AnchorPoint = Vector2.new(0.5, 0)
coins.Position = UDim2.new(0.5, 0, 0, 12)
coins.Size = UDim2.new(0, 220, 0, 36)
coins.BackgroundTransparency = 0.3
coins.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
coins.Text = "🪙 ..."
coins.TextScaled = true
coins.TextColor3 = Color3.new(1, 1, 1)
coins.Parent = gui
local coinCorner = Instance.new("UICorner")
coinCorner.CornerRadius = UDim.new(0, 8)
coinCorner.Parent = coins

local prisms = Instance.new("TextLabel")
prisms.Name = "PrismsLabel"
prisms.AnchorPoint = Vector2.new(0.5, 0)
prisms.Position = UDim2.new(0.5, 0, 0, 52)
prisms.Size = UDim2.new(0, 220, 0, 28)
prisms.BackgroundTransparency = 0.5
prisms.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
prisms.Text = "🔷 0"
prisms.TextScaled = true
prisms.TextColor3 = Color3.fromRGB(150, 220, 255)
prisms.Parent = gui
local prismCorner = Instance.new("UICorner")
prismCorner.CornerRadius = UDim.new(0, 8)
prismCorner.Parent = prisms

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 56)
toast.Size = UDim2.new(0, 300, 0, 32)
toast.BackgroundTransparency = 0.3
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
toast.Text = ""
toast.TextScaled = true
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Visible = false
toast.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 8)
toastCorner.Parent = toast

local Config = require(ReplicatedStorage:WaitForChild("SnatchConfig"))

local lastSfx = {}
local function playSound(name, throttleSec)
	local id = Config.AUDIO and Config.AUDIO[name]
	if not id then return end
	local now = os.clock()
	if throttleSec and now - (lastSfx[name] or 0) < throttleSec then return end
	lastSfx[name] = now
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = 0.7
	s.Parent = gui
	s.Ended:Connect(function() s:Destroy() end)
	s:Play()
end

incomeTick.OnClientEvent:Connect(function(packet)
	coins.Text = "🪙 " .. tostring(packet.balance)
	playSound("Income", 8)
end)

catchResult.OnClientEvent:Connect(function(packet)
	playSound(packet.sfx or (packet.ok and "Catch" or "Error"))
	toast.Text = packet.reason
	if packet.ok then
		toast.TextColor3 = Color3.fromRGB(120, 255, 120)
	else
		toast.TextColor3 = Color3.fromRGB(255, 120, 120)
	end
	toast.Visible = true
	task.delay(2, function()
		toast.Visible = false
	end)
end)

lockState.OnClientEvent:Connect(function(packet)
	if packet.locked then
		playSound("Lock")
		toast.Text = "🔒 " .. packet.denName .. "'s den locked!"
	else
		toast.Text = "🔓 " .. packet.denName .. "'s den open!"
	end
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Visible = true
	task.delay(2, function()
		toast.Visible = false
	end)
end)

offlineGrant.OnClientEvent:Connect(function(packet)
	local card = Instance.new("Frame")
	card.Name = "WelcomeBack"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.Size = UDim2.new(0, 300, 0, 170)
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	card.BackgroundTransparency = 0.1
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "Welcome back!"
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = card

	local amount = Instance.new("TextLabel")
	amount.Position = UDim2.new(0, 0, 0, 44)
	amount.Size = UDim2.new(1, 0, 0, 50)
	amount.BackgroundTransparency = 1
	amount.Text = "🪙 +" .. tostring(packet.amount)
	amount.TextScaled = true
	amount.TextColor3 = Color3.fromRGB(255, 210, 80)
	amount.Parent = card

	local claim = Instance.new("TextButton")
	claim.Name = "ClaimButton"
	claim.AnchorPoint = Vector2.new(0.5, 0)
	claim.Position = UDim2.new(0.5, 0, 0, 104)
	claim.Size = UDim2.new(0, 200, 0, 48)
	claim.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
	claim.Text = "Claim"
	claim.TextScaled = true
	claim.TextColor3 = Color3.new(1, 1, 1)
	claim.Parent = card
	local claimCorner = Instance.new("UICorner")
	claimCorner.CornerRadius = UDim.new(0, 8)
	claimCorner.Parent = claim

	claim.MouseButton1Click:Connect(function()
		playSound("Click")
		offlineClaim:FireServer()
		card:Destroy()
	end)
end)

bidOpen.OnClientEvent:Connect(function(packet)
	playSound("Bid")
	if packet.snatched then
		toast.Text = "💰 " .. packet.by .. " snatched " .. packet.beast .. "!"
	else
		toast.Text = "📢 " .. packet.by .. " grabbed " .. packet.beast .. "! Bid " .. packet.price .. "?"
	end
	toast.TextColor3 = Color3.fromRGB(255, 220, 100)
	toast.Visible = true
	task.delay(3, function()
		toast.Visible = false
	end)
	-- BID button (visible 8s window only).
	for _, old in ipairs(gui:GetChildren()) do
		if old.Name == "BidCard" then old:Destroy() end
	end
	if packet.snatched then return end
	local card = Instance.new("TextButton")
	card.Name = "BidCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 96)
	card.Size = UDim2.new(0, 300, 0, 48)
	card.BackgroundColor3 = Color3.fromRGB(120, 70, 10)
	card.Text = "💰 BID " .. packet.price .. " for " .. packet.beast
	card.TextScaled = true
	card.TextColor3 = Color3.new(1, 1, 1)
	card.Parent = gui
	local bidCorner = Instance.new("UICorner")
	bidCorner.CornerRadius = UDim.new(0, 8)
	bidCorner.Parent = card
	card.MouseButton1Click:Connect(function()
		playSound("Click")
		bidRequest:FireServer(packet.beast) -- server resolves the windowed model
		card:Destroy()
	end)
	task.delay(8, function()
		if card.Parent then card:Destroy() end
	end)
end)

eventState.OnClientEvent:Connect(function(packet)
	toast.Text = "🌩 Mutation weather: " .. packet.kind .. "!"
	toast.TextColor3 = Color3.fromRGB(180, 220, 255)
	toast.Visible = true
	task.delay(3, function()
		toast.Visible = false
	end)
end)

prismUpdate.OnClientEvent:Connect(function(packet)
	prisms.Text = "🔷 " .. tostring(packet.balance)
end)

print("[CatchClient] Slice 01 HUD live.")
