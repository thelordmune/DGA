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
--   {work_followup} - Follow-up question about work
--   {town_followup} - Follow-up question about town
--   {rumors_followup} - Follow-up question about rumors

return {
	NPCName = "Wanderer",

	Nodes = {
		{
			Name = "Root",
			Type = "DialogueRoot",
			Priority = 0,
			Outputs = {"Greeting"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- MAIN GREETING - First interaction
		-- ═══════════════════════════════════════════════════════════════
		{
			Name = "Greeting",
			Type = "Prompt",
			Priority = 0,
			Text = "{greeting}{intro}",
			Outputs = {"AskAboutWork", "AskAboutTown", "AskAboutRumors", "AskAboutThemselves", "TryPickpocket", "Farewell"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- MAIN CONVERSATION TOPICS
		-- ═══════════════════════════════════════════════════════════════

		-- WORK BRANCH
		{
			Name = "AskAboutWork",
			Type = "Response",
			Priority = 0,
			Text = "{ask_work}",
			Outputs = {"WorkResponse"}
		},

		{
			Name = "WorkResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "{work_response}",
			Outputs = {"WorkFollowup1", "WorkFollowup2", "ChangeTopicFromWork", "ThanksFarewellFromWork"}
		},

		{
			Name = "WorkFollowup1",
			Type = "Response",
			Priority = 0,
			Text = "That sounds interesting. Tell me more about your daily routine.",
			Outputs = {"WorkDetail1"}
		},

		{
			Name = "WorkDetail1",
			Type = "Prompt",
			Priority = 0,
			Text = "{work_detail_1}",
			Outputs = {"WorkFollowup3", "ChangeTopicFromWorkDetail", "ThanksFarewellFromWorkDetail"}
		},

		{
			Name = "WorkFollowup2",
			Type = "Response",
			Priority = 1,
			Text = "Is it difficult work?",
			Outputs = {"WorkDetail2"}
		},

		{
			Name = "WorkDetail2",
			Type = "Prompt",
			Priority = 0,
			Text = "{work_detail_2}",
			Outputs = {"WorkFollowup3", "ChangeTopicFromWorkDetail", "ThanksFarewellFromWorkDetail"}
		},

		{
			Name = "WorkFollowup3",
			Type = "Response",
			Priority = 0,
			Text = "What's the most rewarding part?",
			Outputs = {"WorkDetail3"}
		},

		{
			Name = "WorkDetail3",
			Type = "Prompt",
			Priority = 0,
			Text = "{work_detail_3}",
			Outputs = {"ChangeTopicFromWorkDetail", "ThanksFarewellFromWorkDetail"}
		},

		{
			Name = "ChangeTopicFromWork",
			Type = "Response",
			Priority = 2,
			Text = "I'd like to ask about something else.",
			Outputs = {"ReturnToMainTopics"}
		},

		{
			Name = "ChangeTopicFromWorkDetail",
			Type = "Response",
			Priority = 1,
			Text = "Let me ask about something else.",
			Outputs = {"ReturnToMainTopics"}
		},

		{
			Name = "ThanksFarewellFromWork",
			Type = "Response",
			Priority = 3,
			Text = "Thanks for sharing. I should get going.",
			Outputs = {"Goodbye"}
		},

		{
			Name = "ThanksFarewellFromWorkDetail",
			Type = "Response",
			Priority = 2,
			Text = "Interesting. Well, I must be off.",
			Outputs = {"Goodbye"}
		},

		-- TOWN BRANCH
		{
			Name = "AskAboutTown",
			Type = "Response",
			Priority = 1,
			Text = "{ask_town}",
			Outputs = {"TownResponse"}
		},

		{
			Name = "TownResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "{town_response}",
			Outputs = {"TownFollowup1", "TownFollowup2", "ChangeTopicFromTown", "ThanksFarewellFromTown"}
		},

		{
			Name = "TownFollowup1",
			Type = "Response",
			Priority = 0,
			Text = "Has it always been like this?",
			Outputs = {"TownDetail1"}
		},

		{
			Name = "TownDetail1",
			Type = "Prompt",
			Priority = 0,
			Text = "{town_detail_1}",
			Outputs = {"TownFollowup3", "ChangeTopicFromTownDetail", "ThanksFarewellFromTownDetail"}
		},

		{
			Name = "TownFollowup2",
			Type = "Response",
			Priority = 1,
			Text = "Where should I visit around here?",
			Outputs = {"TownDetail2"}
		},

		{
			Name = "TownDetail2",
			Type = "Prompt",
			Priority = 0,
			Text = "{town_detail_2}",
			Outputs = {"TownFollowup3", "ChangeTopicFromTownDetail", "ThanksFarewellFromTownDetail"}
		},

		{
			Name = "TownFollowup3",
			Type = "Response",
			Priority = 0,
			Text = "Any places I should avoid?",
			Outputs = {"TownDetail3"}
		},

		{
			Name = "TownDetail3",
			Type = "Prompt",
			Priority = 0,
			Text = "{town_detail_3}",
			Outputs = {"ChangeTopicFromTownDetail", "ThanksFarewellFromTownDetail"}
		},

		{
			Name = "ChangeTopicFromTown",
			Type = "Response",
			Priority = 2,
			Text = "I'd like to ask about something else.",
			Outputs = {"ReturnToMainTopics"}
		},

		{
			Name = "ChangeTopicFromTownDetail",
			Type = "Response",
			Priority = 1,
			Text = "Let me ask about something else.",
			Outputs = {"ReturnToMainTopics"}
		},

		{
			Name = "ThanksFarewellFromTown",
			Type = "Response",
			Priority = 3,
			Text = "Good to know. I should get going.",
			Outputs = {"Goodbye"}
		},

		{
			Name = "ThanksFarewellFromTownDetail",
			Type = "Response",
			Priority = 2,
			Text = "I'll keep that in mind. Farewell.",
			Outputs = {"Goodbye"}
		},

		-- RUMORS BRANCH
		{
			Name = "AskAboutRumors",
			Type = "Response",
			Priority = 2,
			Text = "{ask_rumors}",
			Outputs = {"RumorsResponse"}
		},

		{
			Name = "RumorsResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "{rumors_response}",
			Outputs = {"RumorsFollowup1", "RumorsFollowup2", "ChangeTopicFromRumors", "ThanksFarewellFromRumors"}
		},

		{
			Name = "RumorsFollowup1",
			Type = "Response",
			Priority = 0,
			Text = "Where did you hear that?",
			Outputs = {"RumorsDetail1"}
		},

		{
			Name = "RumorsDetail1",
			Type = "Prompt",
			Priority = 0,
			Text = "{rumors_detail_1}",
			Outputs = {"RumorsFollowup3", "ChangeTopicFromRumorsDetail", "ThanksFarewellFromRumorsDetail"}
		},

		{
			Name = "RumorsFollowup2",
			Type = "Response",
			Priority = 1,
			Text = "Do you believe it's true?",
			Outputs = {"RumorsDetail2"}
		},

		{
			Name = "RumorsDetail2",
			Type = "Prompt",
			Priority = 0,
			Text = "{rumors_detail_2}",
			Outputs = {"RumorsFollowup3", "ChangeTopicFromRumorsDetail", "ThanksFarewellFromRumorsDetail"}
		},

		{
			Name = "RumorsFollowup3",
			Type = "Response",
			Priority = 0,
			Text = "Have you heard anything else strange?",
			Outputs = {"RumorsDetail3"}
		},

		{
			Name = "RumorsDetail3",
			Type = "Prompt",
			Priority = 0,
			Text = "{rumors_detail_3}",
			Outputs = {"ChangeTopicFromRumorsDetail", "ThanksFarewellFromRumorsDetail"}
		},

		{
			Name = "ChangeTopicFromRumors",
			Type = "Response",
			Priority = 2,
			Text = "I'd like to ask about something else.",
			Outputs = {"ReturnToMainTopics"}
		},

		{
			Name = "ChangeTopicFromRumorsDetail",
			Type = "Response",
			Priority = 1,
			Text = "Let me ask about something else.",
			Outputs = {"ReturnToMainTopics"}
		},

		{
			Name = "ThanksFarewellFromRumors",
			Type = "Response",
			Priority = 3,
			Text = "Interesting rumors. I should go.",
			Outputs = {"Goodbye"}
		},

		{
			Name = "ThanksFarewellFromRumorsDetail",
			Type = "Response",
			Priority = 2,
			Text = "I'll look into that. Goodbye.",
			Outputs = {"Goodbye"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- PERSONAL QUESTIONS BRANCH
		-- ═══════════════════════════════════════════════════════════════
		{
			Name = "AskAboutThemselves",
			Type = "Response",
			Priority = 3,
			Text = "Tell me about yourself.",
			Outputs = {"PersonalResponse"}
		},

		{
			Name = "PersonalResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "{personal_intro}",
			Outputs = {"PersonalFollowup1", "PersonalFollowup2", "ChangeTopicFromPersonal", "ThanksFarewellFromPersonal"}
		},

		{
			Name = "PersonalFollowup1",
			Type = "Response",
			Priority = 0,
			Text = "How long have you lived here?",
			Outputs = {"PersonalDetail1"}
		},

		{
			Name = "PersonalDetail1",
			Type = "Prompt",
			Priority = 0,
			Text = "{personal_history}",
			Outputs = {"PersonalFollowup3", "ChangeTopicFromPersonalDetail", "ThanksFarewellFromPersonalDetail"}
		},

		{
			Name = "PersonalFollowup2",
			Type = "Response",
			Priority = 1,
			Text = "Do you have family here?",
			Outputs = {"PersonalDetail2"}
		},

		{
			Name = "PersonalDetail2",
			Type = "Prompt",
			Priority = 0,
			Text = "{personal_family}",
			Outputs = {"PersonalFollowup3", "ChangeTopicFromPersonalDetail", "ThanksFarewellFromPersonalDetail"}
		},

		{
			Name = "PersonalFollowup3",
			Type = "Response",
			Priority = 0,
			Text = "What are your hopes for the future?",
			Outputs = {"PersonalDetail3"}
		},

		{
			Name = "PersonalDetail3",
			Type = "Prompt",
			Priority = 0,
			Text = "{personal_hopes}",
			Outputs = {"ChangeTopicFromPersonalDetail", "ThanksFarewellFromPersonalDetail"}
		},

		{
			Name = "ChangeTopicFromPersonal",
			Type = "Response",
			Priority = 2,
			Text = "I'd like to ask about something else.",
			Outputs = {"ReturnToMainTopics"}
		},

		{
			Name = "ChangeTopicFromPersonalDetail",
			Type = "Response",
			Priority = 1,
			Text = "Let me ask about something else.",
			Outputs = {"ReturnToMainTopics"}
		},

		{
			Name = "ThanksFarewellFromPersonal",
			Type = "Response",
			Priority = 3,
			Text = "Nice meeting you. Farewell.",
			Outputs = {"Goodbye"}
		},

		{
			Name = "ThanksFarewellFromPersonalDetail",
			Type = "Response",
			Priority = 2,
			Text = "It was good talking to you.",
			Outputs = {"Goodbye"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- RETURN TO MAIN TOPICS (Hub node)
		-- ═══════════════════════════════════════════════════════════════
		{
			Name = "ReturnToMainTopics",
			Type = "Prompt",
			Priority = 0,
			Text = "What else would you like to know?",
			Outputs = {"AskAboutWorkReturn", "AskAboutTownReturn", "AskAboutRumorsReturn", "AskAboutThemselvesReturn", "TryPickpocket", "FarewellReturn"}
		},

		{
			Name = "AskAboutWorkReturn",
			Type = "Response",
			Priority = 0,
			Text = "{ask_work}",
			Outputs = {"WorkResponse"}
		},

		{
			Name = "AskAboutTownReturn",
			Type = "Response",
			Priority = 1,
			Text = "{ask_town}",
			Outputs = {"TownResponse"}
		},

		{
			Name = "AskAboutRumorsReturn",
			Type = "Response",
			Priority = 2,
			Text = "{ask_rumors}",
			Outputs = {"RumorsResponse"}
		},

		{
			Name = "AskAboutThemselvesReturn",
			Type = "Response",
			Priority = 3,
			Text = "Tell me more about yourself.",
			Outputs = {"PersonalResponse"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- PICKPOCKET OPTION
		-- ═══════════════════════════════════════════════════════════════
		{
			Name = "TryPickpocket",
			Type = "Response",
			Priority = 10,
			Text = "*Pickpocket*",
			Outputs = {"PickpocketAttempt"}
		},

		{
			Name = "PickpocketAttempt",
			Type = "Prompt",
			Priority = 0,
			Text = "{pickpocket_result}",
			Quest = {
				Action = "Pickpocket",
			},
			AutoClose = true,
			Outputs = {}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- FAREWELL OPTIONS
		-- ═══════════════════════════════════════════════════════════════
		{
			Name = "Farewell",
			Type = "Response",
			Priority = 4,
			Text = "I should get going.",
			Outputs = {"Goodbye"}
		},

		{
			Name = "FarewellReturn",
			Type = "Response",
			Priority = 11,
			Text = "That's all. Goodbye.",
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
