-- Wanderer Dialogue - Dynamic dialogue for wandering citizen NPCs
-- Uses dynamic content based on occupation and personality
--
-- Placeholders:
--   {name} - NPC's display name
--   {occupation} - NPC's occupation title
--   {greeting} - Personality-based greeting (from WandererDialogue)
--   {intro} - Occupation-specific introduction (from WandererDialogue)
--   {work_response} - Occupation-specific work topic (from WandererDialogue)
--   {town_response} - Occupation-specific town topic (from WandererDialogue)
--   {rumors_response} - Occupation-specific rumors topic (from WandererDialogue)
--   {farewell} - Personality-based farewell (from WandererDialogue)
--   {ask_work} - Occupation-specific question text for work
--   {ask_town} - Occupation-specific question text for town
--   {ask_rumors} - Occupation-specific question text for rumors

return {
	NPCName = "Wanderer",

	Nodes = {
		{
			Name = "Root",
			Type = "DialogueRoot",
			Priority = 0,
			Outputs = {"Greeting"}
		},

		-- Main greeting - uses occupation intro with personality prefix
		{
			Name = "Greeting",
			Type = "Prompt",
			Priority = 0,
			Text = "{greeting}{intro}",
			Outputs = {"AskAboutWork", "AskAboutTown", "AskAboutRumors", "Farewell"}
		},

		-- Occupation-specific question options
		{
			Name = "AskAboutWork",
			Type = "Response",
			Priority = 0,
			Text = "{ask_work}",
			Outputs = {"WorkResponse"}
		},

		{
			Name = "AskAboutTown",
			Type = "Response",
			Priority = 1,
			Text = "{ask_town}",
			Outputs = {"TownResponse"}
		},

		{
			Name = "AskAboutRumors",
			Type = "Response",
			Priority = 2,
			Text = "{ask_rumors}",
			Outputs = {"RumorsResponse"}
		},

		{
			Name = "Farewell",
			Type = "Response",
			Priority = 3,
			Text = "I should get going.",
			Outputs = {"Goodbye"}
		},

		-- Topic responses - pull from occupation-specific content
		{
			Name = "WorkResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "{work_response}",
			Outputs = {"AskMore", "ThanksFarewell"}
		},

		{
			Name = "TownResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "{town_response}",
			Outputs = {"AskMore", "ThanksFarewell"}
		},

		{
			Name = "RumorsResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "{rumors_response}",
			Outputs = {"AskMore", "ThanksFarewell"}
		},

		-- Continue conversation options
		{
			Name = "AskMore",
			Type = "Response",
			Priority = 0,
			Text = "Tell me more.",
			Outputs = {"Greeting"}
		},

		{
			Name = "ThanksFarewell",
			Type = "Response",
			Priority = 1,
			Text = "Thanks for the info.",
			Outputs = {"Goodbye"}
		},

		-- Goodbye with personality farewell
		{
			Name = "Goodbye",
			Type = "Prompt",
			Priority = 0,
			Text = "{farewell}",
			AutoClose = true,
			Outputs = {}
		}
	}
}
