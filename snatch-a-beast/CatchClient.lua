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

incomeTick.OnClientEvent:Connect(function(packet)
	coins.Text = "🪙 " .. tostring(packet.balance)
end)

catchResult.OnClientEvent:Connect(function(packet)
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

print("[CatchClient] Slice 01 HUD live.")
