local Replicated = game:GetService("ReplicatedStorage");
local RS		 = game:GetService("RunService");
local Players 	 = game:GetService("Players");

local ByteNet = require(script.Parent:WaitForChild("ByteNet"));

return ByteNet.defineNamespace("Networking", function()
	return {
		Visuals = ByteNet.definePacket({
			reliabilityType = "reliable"; -- Changed from unreliable to reliable to prevent VFX packet loss
			value = ByteNet.struct({
				Module    = ByteNet.string;
				Function  = ByteNet.string;
				Arguments = ByteNet.array(ByteNet.unknown); --> IF DATA LOSS THEN REVERT IT TO JUST BYTENET.UNKNOWN
			})
		});
		AlchemyUpdate = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Alchemy = ByteNet.string;
			})
		});
		
		ClientCFrame = ByteNet.definePacket({
			reliabilityType = "unreliable";
			value = ByteNet.struct({
				Position = ByteNet.vec3;
				Orientation = ByteNet.vec3;
				AssemblyLinearVelocity = ByteNet.vec3
			})
		});
		
		Attack = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Type = ByteNet.string,
				Held = ByteNet.bool,
				Air  = ByteNet.bool,
			})
		});
		
		Critical = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Held = ByteNet.bool,
				Air  = ByteNet.bool,
			})
		});
		
		Construct = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Held = ByteNet.bool,
				Air = ByteNet.bool,
				Duration = ByteNet.int8
			})
		});
		["Sky Arc"] = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Held = ByteNet.bool,
				Air = ByteNet.bool,
				MousePosition = ByteNet.vec3,  -- Mouse hit position for bridge endpoint
			})
		});
		["Stone Lance"] = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Held = ByteNet.bool,
				Air = ByteNet.bool,
			})
		});
		["Stone Lance Path"] = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Held = ByteNet.bool,
				Air = ByteNet.bool,
			})
		});
		["Rock Skewer"] = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Air = ByteNet.bool,
				MousePosition = ByteNet.vec3,  -- Added mouse position for aiming
			})
		});
		Firestorm = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Air = ByteNet.bool,
			})
		});
		Cinder = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Air = ByteNet.bool,
			})
		});
		Cascade = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Air = ByteNet.bool,
			})
		});
		Branch = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Held = ByteNet.bool,
				Air = ByteNet.bool,
			})
		});
		["Ground Decay"] = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Held = ByteNet.bool,
				Air = ByteNet.bool,
			})
		});
		UseItem = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				itemName = ByteNet.string;
				hotbarSlot = ByteNet.int8;
				inputType = ByteNet.optional(ByteNet.string); -- "began" or "ended" for hold system
			})
		});
		
		Dodge = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Direction = ByteNet.string;	
			});
		});
		
		DodgeCancel = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.nothing;
		});

		CancelSprint = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.nothing;
		});

		Deconstruct = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Air = ByteNet.bool;
			})
		});

		AlchemicAssault = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Air = ByteNet.bool;
			})
		});
		
		Block = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Held = ByteNet.bool,
				Air  = ByteNet.bool
			})
		});

		Equip = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.nothing;
		});
		
		Bvel = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Character = ByteNet.inst;
				Name = ByteNet.string;
				Targ = ByteNet.optional(ByteNet.inst);
				Velocity = ByteNet.optional(ByteNet.vec3);
				Direction = ByteNet.optional(ByteNet.string); -- Changed from vec3 to string for dash direction names
				HorizontalPower = ByteNet.optional(ByteNet.float32);
				UpwardPower = ByteNet.optional(ByteNet.float32);
				duration = ByteNet.optional(ByteNet.float32);
			})
		});
		
		Flash = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Remove = ByteNet.bool;	
			});
		});
		Quests = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Module = ByteNet.string;
				Function = ByteNet.string;
				Arguments = ByteNet.array(ByteNet.unknown);
			})
		});

		TestDestructible = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				-- Empty struct for simple test command
			})
		});

		HitboxDebug = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Enabled = ByteNet.bool;
			})
		});

	};
end)