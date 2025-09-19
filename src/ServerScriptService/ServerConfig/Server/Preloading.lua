local module = {}
local animationsGrabbed = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local MAX_ANIMATIONS_PER_RIG = 100
local MAX_CONCURRENT_ANIMATIONS = 10

local function grabAnimations(givenDesc)
    for _, v in (givenDesc:GetDescendants()) do
        if v:IsA("Animation") then
            table.insert(animationsGrabbed, v)
        end
    end
end

local function createRig()
    local preloadRig = script.PreloadRig:Clone()
    preloadRig.Parent = game.Workspace
    return preloadRig
end

grabAnimations(ReplicatedStorage.Assets.Animations)
warn("# of Animations: " .. #animationsGrabbed)

local start = os.clock()
ContentProvider:PreloadAsync(animationsGrabbed)
local deltaTime = os.clock() - start
warn(("Content Preloader Complete; %.2f seconds"):format(deltaTime))

local rigs = {}
local animTracks = {}

local neededRigs = math.ceil(#animationsGrabbed / MAX_ANIMATIONS_PER_RIG)
for i = 1, neededRigs do
    rigs[i] = createRig()
end

local function processBatch(startIndex, endIndex, rigIndex)
    local promises = {}
    
    for i = startIndex, math.min(endIndex, #animationsGrabbed) do
        local v = animationsGrabbed[i]
        local promise = coroutine.create(function()
            local animator = rigs[rigIndex].Humanoid.Animator
            local anim = animator:LoadAnimation(v)
            anim:Play()
            task.wait(0.2)
            anim:AdjustSpeed(math.huge)
            table.insert(animTracks, anim)
        end)
        table.insert(promises, promise)
    end
    
    for i = 1, #promises, MAX_CONCURRENT_ANIMATIONS do
        local batch = {}
        for j = i, math.min(i + MAX_CONCURRENT_ANIMATIONS - 1, #promises) do
            table.insert(batch, promises[j])
        end
        
        for _, co in (batch) do
            coroutine.resume(co)
        end
        
        task.wait(0.2)
    end
end

for rigIndex = 1, neededRigs do
    local startIndex = (rigIndex - 1) * MAX_ANIMATIONS_PER_RIG + 1
    local endIndex = rigIndex * MAX_ANIMATIONS_PER_RIG
    processBatch(startIndex, endIndex, rigIndex)
end

task.delay(1, function()
    for count, rig in (rigs) do
        rig:Destroy()
        warn(rig.Name .. count .. " Destroyed")
    end
end)

warn("Done Preloading!")


return module