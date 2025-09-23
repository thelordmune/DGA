local ClientThread = {}
ClientThread.__index = ClientThread
local self = setmetatable({}, ClientThread);

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local UserInputService  = game:GetService("UserInputService");
local HttpService 		= game:GetService("HttpService");

local Client = require(ReplicatedStorage:WaitForChild('Client'));
local Actors = require(ReplicatedStorage.Modules.Actor.Actors);
local start = require(ReplicatedStorage.Modules.ECS.jecs_start)

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

	Actors.AddToTempLoop(function(DeltaTime)
		DeltaTime = math.clamp(DeltaTime, 0, 1/60)

		if Client.Character and Client.Root and Client.Humanoid then
			task.desynchronize();
			local Character = Client.Character :: Model;
			local Root 		= Client.Root :: BasePart | MeshPart;
			local Humanoid  = Client.Humanoid :: Humanoid;

			local DownRay = workspace:Raycast(Root.Position, Root.Position - Vector3.new(0, 3, 0), FloorRayParams);
			if DownRay and DownRay.Instance then 
				Client.InAir = true
			else
				Client.InAir = false;
			end

			local RX, RY, RZ = Root.CFrame:ToOrientation();
			local Orientation = Vector3.new(RX, RY, RZ);
			
			local Direction = Camera.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
			local X = Direction.X * (1/10)
			local Z = Direction.Z * (1/10)
			--local Angles = {-Z, -X, 0}

			task.desynchronize()
			local CharDirection = Root.CFrame.LookVector
			local MoveDirection = Vector3.new(Humanoid.MoveDirection.X, 0, Humanoid.MoveDirection.Z)
			local Angle = math.deg(math.acos(CharDirection:Dot(MoveDirection) / (CharDirection.Magnitude * MoveDirection.Magnitude)))
			local BackwardDot = MoveDirection:Dot(Root.CFrame.LookVector) < -.5
			
			task.synchronize()
			-- // Running Handling
			if Client.RunAnim then
				RSpeed += ((Character.Humanoid.FloorMaterial == Enum.Material.Air and 0.1 or 1) - RSpeed * math.clamp(R * 10, 0, 1))
				Client.RunAnim:AdjustSpeed(RSpeed)
			end
			
			if Client.Running and ((Client.Library.StateCount(Client.Actions) and not Client.Library.StateCheck(Client.Actions, "Dodging")) or Client.Library.StateCount(Client.Stuns)) or (MoveDirection.Magnitude > 0 and BackwardDot) or MoveDirection.Magnitude <= 0 then
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
					Humanoid.CameraOffset = Humanoid.CameraOffset:Lerp(offset, DeltaTime * 1.5)
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
			
			-- // Client Netcode
			Client.Packets.ClientCFrame.send({
				Position = Root.CFrame.Position;
				Orientation = Orientation;
				AssemblyLinearVelocity = Root.AssemblyLinearVelocity;
			});
			task.desynchronize();
			
		else return true end;
		R += DeltaTime
		
		task.synchronize();
		Client.Service["RunService"].RenderStepped:Wait()
		task.desynchronize();
	end)



	
end

return ClientThread
