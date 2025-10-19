local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(world: any, Invoker: Player, Target: Player, Table: {})
    -- print("kinetic redirection activated")
    local targetCharacter = Target.Character
    if not targetCharacter then return end
    
    local storedDamage = Table.Damage or 10
    targetCharacter:SetAttribute("KineticEnergy", storedDamage)
    targetCharacter:SetAttribute("KineticExpiry", os.clock() + 5)
    
    -- print("Stored kinetic energy:", storedDamage, "for 5 seconds on", Target.Name, "character:", targetCharacter.Name)
end