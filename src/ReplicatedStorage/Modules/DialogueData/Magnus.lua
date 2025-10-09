
return {
	NPCName = "Magnus",
	
	Nodes = {
		{
			Name = "Root",
			Type = "DialogueRoot",
			Priority = 0,
			Outputs = {"DefaultGreeting", "QuestActiveGreeting", "QuestCompleteGreeting"}
		},
		
		{
			Name = "DefaultGreeting",
			Type = "Prompt",
			Priority = 0,
			Text = "Hello traveler! I've lost my precious pocketwatch somewhere in the city. Will you help me find it?",
			Outputs = {"AcceptResponse", "DeclineResponse"}
		},

		{
			Name = "AcceptResponse",
			Type = "Response",
			Priority = 0,
			Text = "Yes, I'll help you find it.",
			Outputs = {"Accept"}
		},

		{
			Name = "DeclineResponse",
			Type = "Response",
			Priority = 0,
			Text = "Sorry, I'm busy right now.",
			Outputs = {"Decline"}
		},
		
		{
			Name = "Accept",
			Type = "Prompt",
			Priority = 0,
			Text = "Thank you so much! I think I dropped it near one of the market stalls. Please check there!",
			Quest = {
				Action = "Accept",
				QuestName = "Missing Pocketwatch"
			},
			Outputs = {}
		},

		{
			Name = "Decline",
			Type = "Prompt",
			Priority = 0,
			Text = "I understand. If you change your mind, please come back.",
			Outputs = {}
		},

		{
			Name = "QuestActiveGreeting",
			Type = "Prompt",
			Priority = 1,
			Text = "Did you find my pocketwatch yet? Check the market stalls in the central plaza!",
			Condition = {
				Module = "HasActiveQuest",
				Args = {script.Name}
			},
			Outputs = {"StillLookingResponse1", "StillLookingResponse2"}
		},

		{
			Name = "StillLookingResponse1",
			Type = "Response",
			Priority = 1,
			Text = "I'm still looking for it.",
			Outputs = {"KeepLooking"}
		},

		{
			Name = "StillLookingResponse2",
			Type = "Response",
			Priority = 1,
			Text = "I need more time.",
			Outputs = {"KeepLooking"}
		},
		
		{
			Name = "KeepLooking",
			Type = "Prompt",
			Priority = 1,
			Text = "Please hurry! That pocketwatch is very important to me.",
			Outputs = {}
		},

		{
			Name = "QuestCompleteGreeting",
			Type = "Prompt",
			Priority = 2,
			Text = "You found it! My precious pocketwatch! Will you return it to me?",
			Condition = {
				Module = "HasQuestItem",
				Args = {"Magnus", "Missing Pocketwatch"}
			},
			Outputs = {"ReturnWatchResponse", "KeepWatchResponse"}
		},

		{
			Name = "ReturnWatchResponse",
			Type = "Response",
			Priority = 2,
			Text = "Here you go, I'm glad I could help.",
			Outputs = {"ReturnWatch"}
		},

		{
			Name = "KeepWatchResponse",
			Type = "Response",
			Priority = 2,
			Text = "Actually, I think I'll keep it.",
			Outputs = {"KeepWatch"}
		},

		{
			Name = "ReturnWatch",
			Type = "Prompt",
			Priority = 2,
			Text = "Thank you so much! You're a true hero. Here, take this as a reward, and a free level!",
			Quest = {
				Action = "CompleteGood",
				QuestName = "Missing Pocketwatch"
			},
			Outputs = {}
		},

		{
			Name = "KeepWatch",
			Type = "Prompt",
			Priority = 2,
			Text = "What?! You... you thief! I trusted you!",
			Quest = {
				Action = "CompleteEvil",
				QuestName = "Missing Pocketwatch"
			},
			Outputs = {}
		}
	}
}

