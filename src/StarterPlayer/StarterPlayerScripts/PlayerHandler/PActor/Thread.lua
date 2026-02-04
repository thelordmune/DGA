local ClientThread = {}
ClientThread.__index = ClientThread
-- local self = setmetatable({}, ClientThread);

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local UserInputService  = game:GetService("UserInputService");
-- local HttpService 		= game:GetService("HttpService");

local Client = require(ReplicatedStorage:WaitForChild('Client'));
local Actors = require(ReplicatedStorage.Modules.Actor.Actors);
-- local start = require(ReplicatedStorage.Modules.ECS.jecs_start)

local Camera = workspace.CurrentCamera;

local FloorRayParams = RaycastParams.new();
FloorRayParams.FilterType = Enum.RaycastFilterType.Include;
FloorRayParams.FilterDescendantsInstances = {workspace.World.Map};

ClientThread.Spawn = function()
    local RSpeed   = 2;
    local R 	   = 0;
    local InitC0   = Client.Character.PrimaryPart:WaitForChild("RootJoint").C0

    -- Reset camera offset on character spawn to fix shift lock reset bug
    if Client.Humanoid then
        Client.Humanoid.CameraOffset = Vector3.zero
    end

    -- ⚡ PERFORMANCE OPTIMIZATION: Network throttling (60Hz → 15Hz)
    -- Reduces network traffic by ~75%
    local NETWORK_HZ = 15
    local NETWORK_TICK = 1 / NETWORK_HZ
    local networkAcc = 0
    local lastSentPosition = Vector3.zero
    local lastSentOrientation = Vector3.zero
    local POSITION_THRESHOLD = 0.5 -- Only send if moved 0.5 studs
    local ORIENTATION_THRESHOLD = 0.1 -- Only send if rotated significantly

    -- ⚡ PERFORMANCE OPTIMIZATION: Raycast caching (60Hz → 10Hz)
    -- Reduces raycasts by ~83%
    local RAYCAST_HZ = 10
    local RAYCAST_TICK = 1 / RAYCAST_HZ
    local raycastAcc = 0
    local cachedInAir = false

    Actors.AddToTempLoop(function(DeltaTime)
        DeltaTime = math.clamp(DeltaTime, 0, 1/60)

        if Client.Character and Client.Root and Client.Humanoid then
            task.desynchronize();
            local Character = Client.Character :: Model;
            local Root 		= Client.Root :: BasePart | MeshPart;
            local Humanoid  = Client.Humanoid :: Humanoid;

            -- ⚡ OPTIMIZED: Raycast only every 0.1 seconds instead of every frame
            raycastAcc += DeltaTime
            if raycastAcc >= RAYCAST_TICK then
                raycastAcc = 0
                local DownRay = workspace:Raycast(Root.Position, Root.Position - Vector3.new(0, 3, 0), FloorRayParams);
                cachedInAir = not (DownRay and DownRay.Instance)
            end
            Client.InAir = cachedInAir

            local RX, RY, RZ = Root.CFrame:ToOrientation();
            local Orientation = Vector3.new(RX, RY, RZ);
            
            local Direction = Camera.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
            local X = Direction.X * (1/10)
            local Z = Direction.Z * (1/10)
            --local Angles = {-Z, -X, 0}

            task.desynchronize()
            --local CharDirection = Root.CFrame.LookVector
            local MoveDirection = Vector3.new(Humanoid.MoveDirection.X, 0, Humanoid.MoveDirection.Z)
            --local Angle = math.deg(math.acos(CharDirection:Dot(MoveDirection) / (CharDirection.Magnitude * MoveDirection.Magnitude)))
            local BackwardDot = MoveDirection:Dot(Root.CFrame.LookVector) < -.5
            
            task.synchronize()
            -- // Running Handling
            if Client.RunAnim then
                RSpeed += ((Character.Humanoid.FloorMaterial == Enum.Material.Air and 0.1 or 1) - RSpeed * math.clamp(R * 10, 0, 1))
                Client.RunAnim:AdjustSpeed(RSpeed)
            end

            -- Stop running if:
            -- 1. Player has blocking actions (not Dodging/Sprinting/DodgeRecovery) or blocking stuns
            -- 2. Player is moving backward

            -- Check if player has any blocking stuns (not Dashing - dodging while running is OK)
            local hasBlockingStun = false
            local stunStates = Client.Library.GetAllStates(Client.Character, "Stuns") or {}
            for _, stun in ipairs(stunStates) do
                if stun ~= "Dashing" then
                    hasBlockingStun = true
                    break
                end
            end

            -- Check if player has any blocking actions (not Dodging, Sprinting, Running, or DodgeRecovery)
            local hasBlockingAction = false
            local actionStates = Client.Library.GetAllStates(Client.Character, "Actions") or {}
            for _, action in ipairs(actionStates) do
                if action ~= "Dodging" and action ~= "Sprinting" and action ~= "Running" and action ~= "DodgeRecovery" then
                    hasBlockingAction = true
                    break
                end
            end

            if Client.Running and (hasBlockingAction or hasBlockingStun or (MoveDirection.Magnitude > 0 and BackwardDot)) then
                print("[Thread] 🛑 Stopping running - BlockingAction:", hasBlockingAction, "Actions:", table.concat(actionStates, ","), "| BlockingStun:", hasBlockingStun, "Stuns:", table.concat(stunStates, ","), "| BackwardDot:", BackwardDot)
                Client.Modules['Movement'].Run(false)
            end
            
            -- // Character Tilting
            Root.RootJoint.C0 = Root.RootJoint.C0:Lerp(InitC0 * CFrame.Angles(-Z, -X, 0), DeltaTime * 7.5)
            
            -- // Camera Offset
            if Humanoid:GetState() == Enum.HumanoidStateType.Dead then
                Humanoid.CameraOffset = Vector3.zero
            elseif UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                -- Shift lock mode - MouseLockController handles smooth transitions
                local offset = Root.CFrame:PointToObjectSpace(Character.Head.Position)
                -- Reset camera offset if it becomes invalid (fixes reset bug)
                if Humanoid.CameraOffset.Magnitude > 50 or Humanoid.CameraOffset ~= Humanoid.CameraOffset then
                    Humanoid.CameraOffset = offset
                else
                    Humanoid.CameraOffset = Humanoid.CameraOffset:Lerp(offset, DeltaTime * 1.8)
                end
            else
                -- Normal mode
                local offset = (Root.CFrame + Vector3.new(0, .3, 0)):PointToObjectSpace(Character.Head.Position)
                -- Reset camera offset if it becomes invalid (fixes reset bug)
                if Humanoid.CameraOffset.Magnitude > 50 or Humanoid.CameraOffset ~= Humanoid.CameraOffset then
                    Humanoid.CameraOffset = offset
                else
                    Humanoid.CameraOffset = Humanoid.CameraOffset:Lerp(offset, DeltaTime * 1.5)
                end
            end
            
            -- ⚡ OPTIMIZED: Network throttling with delta compression
            -- Only send position updates 15 times per second instead of 60
            -- Only send if position/orientation changed significantly
            networkAcc += DeltaTime
            if networkAcc >= NETWORK_TICK then
                networkAcc = 0
                
                -- Delta compression: only send if changed significantly
                local positionDelta = (Root.CFrame.Position - lastSentPosition).Magnitude
                local orientationDelta = (Orientation - lastSentOrientation).Magnitude
                
                if positionDelta > POSITION_THRESHOLD or orientationDelta > ORIENTATION_THRESHOLD then
                    Client.Packets.ClientCFrame.send({
                        Position = Root.CFrame.Position;
                        Orientation = Orientation;
                        AssemblyLinearVelocity = Root.AssemblyLinearVelocity;
                    });
                    lastSentPosition = Root.CFrame.Position
                    lastSentOrientation = Orientation
                end
            end
            task.desynchronize();
            
        else return true end;
        R += DeltaTime

        task.synchronize();
        Client.Service["RunService"].RenderStepped:Wait()
        task.desynchronize();

        return false
    end)

end

return ClientThread