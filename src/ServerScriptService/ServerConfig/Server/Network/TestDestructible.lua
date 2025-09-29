-- Test script for destructible objects
local TestDestructible = {}
local Server = require(script.Parent.Parent)

TestDestructible.EndPoint = function(Player: Player, Data: {})
    local Character = Player.Character
    if not Character then return end
    
    local Entity = Server.Modules.Entities.Get(Character)
    if not Entity then return end
    
    print("Testing destructible system for player:", Player.Name)
    
    -- Create a test hitbox in front of the player
    local HitTargets = Server.Modules.Hitbox.SpatialQuery(
        Character,
        Vector3.new(10, 10, 10), -- Large hitbox to catch objects
        Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -8), -- In front of player
        true -- Visualize the hitbox
    )
    
    print("Found", #HitTargets, "targets in front of player")
    
    -- Test damage on all found targets
    for _, Target in pairs(HitTargets) do
        print("Testing damage on target:", Target.Name, "Type:", typeof(Target))
        
        -- Create a test damage table
        local testDamageTable = {
            Damage = 50,
            SFX = "Blood", -- Use Blood SFX as test
            Knockback = true
        }
        
        Server.Modules.Damage.Tag(Character, Target, testDamageTable)
    end
    
    print("Destructible test completed for player:", Player.Name)
end

return TestDestructible
