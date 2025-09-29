-- Test script for destructible objects
-- This script creates a test barrel and tests the destruction system

local Server = require(game.ServerScriptService.ServerConfig.Server)
local DamageService = require(game.ServerScriptService.ServerConfig.Server.Damage)

-- Wait for the game to load
task.wait(5)

print("Creating test destructible object...")

-- Create a test barrel (using MeshPart to test MeshPart compatibility)
local testBarrel = Instance.new("MeshPart")
testBarrel.Name = "TestBarrel"
testBarrel.Size = Vector3.new(4, 6, 4)
testBarrel.Material = Enum.Material.Wood
testBarrel.Color = Color3.fromRGB(139, 69, 19) -- Brown color
testBarrel.MeshId = "rbxasset://fonts/leftarm.mesh" -- Use a basic mesh for testing
testBarrel.CFrame = CFrame.new(0, 10, 0) -- Position it in the air
testBarrel.Anchored = true
testBarrel.Parent = workspace

-- Set it up as destructible
testBarrel:SetAttribute("Destroyable", true)
testBarrel:SetAttribute("OriginalTransparency", testBarrel.Transparency)
testBarrel:SetAttribute("OriginalCanCollide", testBarrel.CanCollide)
testBarrel:SetAttribute("OriginalCanQuery", testBarrel.CanQuery)

print("Test barrel created at position:", testBarrel.Position)

-- Wait a moment, then test destruction
task.wait(3)

print("Testing destruction...")

-- Create a fake invoker (player character)
local fakeInvoker = Instance.new("Model")
fakeInvoker.Name = "TestInvoker"
fakeInvoker.Parent = workspace

-- Test the destruction
DamageService.HandleDestructibleObject(fakeInvoker, testBarrel, {
    SFX = "Wood" -- Use wood sound effects
})

print("Destruction test completed!")
print("The barrel should respawn in 30 seconds...")

-- Clean up the fake invoker
fakeInvoker:Destroy()

-- Optional: Clean up this test script after testing
task.delay(35, function()
    script:Destroy()
    print("Test script cleaned up")
end)
