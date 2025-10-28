return {
	NPCName = "Shopkeeper",
	
	Nodes = {
		-- Root
		{
			Name = "Root",
			Type = "DialogueRoot",
			Priority = 0,
			Outputs = {"Greeting"}
		},
		
		-- Greeting
		{
			Name = "Greeting",
			Type = "Dialogue",
			Priority = 0,
			Text = "Welcome to my shop! What can I get for you today?",
			Outputs = {"MainMenu"}
		},
		
		-- Main menu
		{
			Name = "MainMenu",
			Type = "Response",
			Priority = 0,
			Text = "What would you like?",
			Responses = {
				{
					Text = "I'd like to buy something.",
					Outputs = {"ShowShop"}
				},
				{
					Text = "Do you have any quests?",
					Outputs = {"NoQuests"}
				},
				{
					Text = "Goodbye.",
					Outputs = {"Goodbye"}
				}
			}
		},
		
		-- Show shop
		{
			Name = "ShowShop",
			Type = "Dialogue",
			Priority = 0,
			Text = "Here's what I have in stock! Take a look around.",
			Outputs = {} -- End dialogue, open shop UI
		},
		
		-- No quests
		{
			Name = "NoQuests",
			Type = "Dialogue",
			Priority = 0,
			Text = "Sorry, I don't have any quests right now. Just selling goods!",
			Outputs = {"MainMenu"} -- Loop back to menu
		},
		
		-- Goodbye
		{
			Name = "Goodbye",
			Type = "Dialogue",
			Priority = 0,
			Text = "Come back anytime! Safe travels!",
			Outputs = {} -- End dialogue
		}
	}
}

