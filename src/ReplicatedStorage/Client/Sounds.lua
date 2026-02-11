local Sound = {}; local CSystem = require(script.Parent); local ClientConfig = require(script.Parent.ClientConfig);
Sound.__index = Sound
local self = setmetatable({}, Sound)

Sound.StepIDs = {
	["Default"] = {120893069078878, 124748495267774, 94884812021013}
}

Sound.Footsteps    = {};
Sound.CombatTracks = {};
Sound.Tracks 	   = {};

Sound.CurrentSong = nil;
Sound.StepNumber = 1;

task.spawn(function()
	local SoundGroup = Instance.new("SoundGroup");
	SoundGroup.Name = "Footsteps"; SoundGroup.Parent = CSystem.Service["SoundService"]

	for i, v in next, self.StepIDs do
		for index, Id in next, v do
			if not self.Footsteps[i] then self.Footsteps[i] = {} end;
			local instance = Instance.new("Sound"); instance.Name = i..index;
			instance.SoundId = "rbxassetid://"..Id
			instance.Volume = ClientConfig.Sounds.FOOTSTEP_VOLUME
			instance.RollOffMaxDistance = ClientConfig.Sounds.ROLLOFF_MAX; instance.RollOffMinDistance = ClientConfig.Sounds.ROLLOFF_MIN;
			instance.Parent = SoundGroup

			table.insert(self.Footsteps[i], instance)
		end
	end

end)


Sound.Step = function(Material)	
	Material = Material.Name
	if not self.Footsteps[Material] then
		Material = "Default"
	end

	if #self.Footsteps[Material] < Sound.StepNumber then Sound.StepNumber = 1 end
	self.Footsteps[Material][Sound.StepNumber]:Play()
	Sound.StepNumber += 1
end

return Sound
