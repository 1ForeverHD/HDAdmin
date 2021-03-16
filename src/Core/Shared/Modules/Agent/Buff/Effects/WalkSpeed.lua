local function getHumanoid(player)
    local char = player and player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    return humanoid
end

return function(player)
    local humanoid = getHumanoid(player)
    local instancesAndProps = {}
    if humanoid then
        instancesAndProps = {{humanoid, "WalkSpeed"}}
    end
    return instancesAndProps
end