local Replicated = game:GetService("ReplicatedStorage");
local RS		 = game:GetService("RunService");
local Players 	 = game:GetService("Players");

local ByteNet = require(script.Parent:WaitForChild("ByteNet"));

return ByteNet.defineNamespace("Networking", function()
	return {
		Visuals = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Module    = ByteNet.string;
				Function  = ByteNet.string;
				Arguments = ByteNet.array(ByteNet.unknown); --> IF DATA LOSS THEN REVERT IT TO JUST BYTENET.UNKNOWN
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
		
		-- Attack Type enum: 0=Normal, 1=Running, 2=None
		Attack = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Type = ByteNet.uint8, -- Optimized from string (~8 bytes) to uint8 (1 byte)
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

		-- InputType enum: 0=began, 1=ended
		UseItem = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				hotbarSlot = ByteNet.int8; -- Server looks up item from player's hotbar
				inputType = ByteNet.uint8; -- Optimized: 0=began, 1=ended (from optional string)
			})
		});
		
		-- Direction enum: 0=Forward, 1=Back, 2=Left, 3=Right
		Dodge = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.uint8; -- Optimized from struct+string (~9 bytes) to uint8 (1 byte)
		});
		
		DodgeCancel = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.nothing;
		});

		CancelSprint = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.nothing;
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
		
		-- Generic Bvel (kept for backward compatibility with complex effects)
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
				ChronoId = ByteNet.optional(ByteNet.uint16); -- For resolving Chrono NPC targets by ID instead of Instance ref
			})
		});

		-- BvelSimple: 55% of sends (Character + Effect uint8) - M1, M2, Jump, Lunge, Dash
		-- Effect enum: 0=M1, 1=M2, 2=Jump, 3=Lunge, 4=DashForward, 5=DashBack, 6=DashLeft, 7=DashRight
		BvelSimple = ByteNet.definePacket({
			reliabilityType = "unreliable"; -- Visual velocity, next frame corrects
			value = ByteNet.struct({
				Character = ByteNet.inst;
				Effect = ByteNet.uint8;
			})
		});

		-- BvelKnockback: Knockback effects with direction and power
		BvelKnockback = ByteNet.definePacket({
			reliabilityType = "reliable"; -- Knockback must be reliable for gameplay
			value = ByteNet.struct({
				Character = ByteNet.inst;
				Direction = ByteNet.vec3;
				HorizontalPower = ByteNet.float32;
				UpwardPower = ByteNet.float32;
			})
		});

		-- BvelRemove: Remove velocity effects (9 sends - perfect batch target)
		-- Effect enum: 0=All, 1=M1, 2=M2, 3=Knockback, 4=Dash, 5=Pincer, 6=Lunge
		BvelRemove = ByteNet.definePacket({
			reliabilityType = "reliable"; -- Removal must be reliable
			value = ByteNet.struct({
				Character = ByteNet.inst;
				Effect = ByteNet.uint8;
			})
		});

		-- BvelVelocity: Direct velocity application with optional duration
		BvelVelocity = ByteNet.definePacket({
			reliabilityType = "unreliable"; -- Visual velocity
			value = ByteNet.struct({
				Character = ByteNet.inst;
				Velocity = ByteNet.vec3;
				Duration = ByteNet.optional(ByteNet.float32);
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

		HitboxDebug = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Enabled = ByteNet.bool;
			})
		});

		ObjectInteract = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				ObjectId = ByteNet.string;
			})
		});

		-- Server -> Client: Trigger dialogue UI for wanderer NPCs
		StartDialogue = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				NPCName = ByteNet.string;       -- Display name for the NPC
				Occupation = ByteNet.string;    -- NPC's occupation
				Personality = ByteNet.string;   -- NPC's personality type
				NPCId = ByteNet.string;         -- Unique NPC ID for relationship tracking
				ChronoId = ByteNet.uint16;      -- Chrono replication ID for finding client model
			})
		});

		NPCRelationship = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Action = ByteNet.string;
				NPCId = ByteNet.string;
				NPCName = ByteNet.optional(ByteNet.string);
				Occupation = ByteNet.optional(ByteNet.string);
				Personality = ByteNet.optional(ByteNet.string);
				Appearance = ByteNet.optional(ByteNet.unknown);
			})
		});

		NPCRelationshipSync = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				NPCId = ByteNet.string;
				Value = ByteNet.int16;
				Tier = ByteNet.string;
				IsBefriended = ByteNet.bool;
			})
		});

		Pickpocket = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				NPCId = ByteNet.string;
				Occupation = ByteNet.optional(ByteNet.string);
			})
		});
		PickpocketResult = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				Success = ByteNet.bool;
				Message = ByteNet.string;
				Money = ByteNet.optional(ByteNet.int32);
				Item = ByteNet.optional(ByteNet.string);
				GuardsSpawning = ByteNet.bool;
			})
		});

		-- InventoryAction enum: 0=equip, 1=unequip, 2=move, 3=drop, 4=use
		InventoryAction = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.struct({
				action = ByteNet.uint8; -- Optimized from string to uint8
				inventorySlot = ByteNet.optional(ByteNet.int16);
				hotbarSlot = ByteNet.optional(ByteNet.int8);
			})
		});

		-- ============================================
		-- TYPED VFX PACKETS (Optimized from generic Visuals)
		-- ============================================
		-- These replace high-frequency Visuals.send() calls that use ByteNet.unknown

		-- VFX_CameraShake: Most frequent VFX (6+ instances)
		-- 16 bytes vs 40+ with Visuals+unknown
		VFX_CameraShake = ByteNet.definePacket({
			reliabilityType = "unreliable"; -- VFX can be missed without breaking gameplay
			value = ByteNet.struct({
				Magnitude = ByteNet.float32;
				Roughness = ByteNet.float32;
				FadeInTime = ByteNet.float32;
				FadeOutTime = ByteNet.float32;
				Position = ByteNet.optional(ByteNet.vec3); -- Optional position for localized shake
			})
		});

		-- VFX_Dash: Dash visual effects (4+ instances)
		-- Direction enum: 0=Forward, 1=Back, 2=Left, 3=Right
		-- 2 bytes vs 20+ with Visuals+unknown
		VFX_Dash = ByteNet.definePacket({
			reliabilityType = "unreliable";
			value = ByteNet.struct({
				Character = ByteNet.inst;
				Direction = ByteNet.uint8;
			})
		});

		-- VFX_CombatStatus: Combat status indicators (stun, guard, parry, block)
		-- Status enum: 0=Stun, 1=Guard, 2=Parry, 3=Block, 4=Knockback
		-- 3-7 bytes vs 25+ with Visuals+unknown
		VFX_CombatStatus = ByteNet.definePacket({
			reliabilityType = "unreliable";
			value = ByteNet.struct({
				Character = ByteNet.inst;
				Status = ByteNet.uint8;
				Duration = ByteNet.optional(ByteNet.float32);
			})
		});

		-- VFX_Hit: Hit effects at position
		-- HitType enum: 0=Blood, 1=Spark, 2=Block, 3=Parry
		-- 13 bytes vs 30+ with Visuals+unknown
		VFX_Hit = ByteNet.definePacket({
			reliabilityType = "unreliable";
			value = ByteNet.struct({
				Position = ByteNet.vec3;
				HitType = ByteNet.uint8;
				Normal = ByteNet.optional(ByteNet.vec3); -- Optional hit normal for directional effects
			})
		});

		-- KnockbackFollowUp: Client -> Server (player presses M2 during knockback window)
		KnockbackFollowUp = ByteNet.definePacket({
			reliabilityType = "reliable";
			value = ByteNet.nothing;
		});

		-- ============================================
		-- ECS STATE SYNC PACKETS
		-- Server -> Client: Replicate ECS state changes
		-- ============================================

		-- StateSync: Sync a single state category for a character
		-- Category enum: 0=Actions, 1=Stuns, 2=IFrames, 3=Speeds, 4=Frames, 5=Status
		StateSync = ByteNet.definePacket({
			reliabilityType = "reliable"; -- State changes must be reliable
			value = ByteNet.struct({
				Character = ByteNet.inst;
				Category = ByteNet.uint8;
				States = ByteNet.array(ByteNet.string);
			})
		});

		-- PostureSync: Sync posture bar value to client for UI display
		-- Server -> Client: Updates the parry/posture bar in PlayerBars
		PostureSync = ByteNet.definePacket({
			reliabilityType = "unreliable"; -- Visual UI, next update corrects
			value = ByteNet.struct({
				Current = ByteNet.uint8; -- 0-100 posture value
				Max = ByteNet.uint8; -- Max posture (usually 100)
			})
		});

	};
end)