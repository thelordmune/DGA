-- Truth Dialogue - The Gate of Truth entity from the Truth dimension
-- This dialogue is triggered after the player uses the Truth alchemy move
-- Ends with the player losing an organ/limb as payment for forbidden knowledge

return {
	NPCName = "Truth",

	Nodes = {
		{
			Name = "Root",
			Type = "DialogueRoot",
			Priority = 0,
			Outputs = {"Greeting"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- INITIAL ENCOUNTER
		-- ═══════════════════════════════════════════════════════════════
		{
			Name = "Greeting",
			Type = "Prompt",
			Priority = 0,
			Text = "Ahh... another one who dares to open the gate. I am what you call the world. Or perhaps the universe. Or perhaps God. Or perhaps Truth. Or perhaps all. Or perhaps one. And I am also... you.",
			Outputs = {"AskWhoAreYou", "AskWhereAmI", "AskWhatIsThis", "DemandToLeave"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- INQUIRY BRANCHES
		-- ═══════════════════════════════════════════════════════════════

		-- WHO ARE YOU?
		{
			Name = "AskWhoAreYou",
			Type = "Response",
			Priority = 0,
			Text = "Who... are you?",
			Outputs = {"WhoResponse"}
		},

		{
			Name = "WhoResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "I have no form. I have no name. I am the truth that exists at the center of all things. I am the one who waits beyond the gate. I am the price... and the reward.",
			Outputs = {"AskAboutGate", "AskAboutPrice", "AcceptFate"}
		},

		-- WHERE AM I?
		{
			Name = "AskWhereAmI",
			Type = "Response",
			Priority = 1,
			Text = "Where am I?",
			Outputs = {"WhereResponse"}
		},

		{
			Name = "WhereResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "You stand before the Gate of Truth. This is the space between spaces. The moment between moments. Here, all knowledge exists... and all debts are collected.",
			Outputs = {"AskAboutGate", "AskAboutPrice", "AcceptFate"}
		},

		-- WHAT IS THIS?
		{
			Name = "AskWhatIsThis",
			Type = "Response",
			Priority = 2,
			Text = "What is this place?",
			Outputs = {"WhatResponse"}
		},

		{
			Name = "WhatResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "This is the realm of equivalent exchange. You sought knowledge beyond mortal bounds. You opened the gate. Now... you must pay the toll.",
			Outputs = {"AskAboutPrice", "RefusePayment", "AcceptFate"}
		},

		-- DEMAND TO LEAVE
		{
			Name = "DemandToLeave",
			Type = "Response",
			Priority = 3,
			Text = "Send me back. Now.",
			Outputs = {"DemandResponse"}
		},

		{
			Name = "DemandResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "Hahahaha... such arrogance. You opened the gate of your own will. Did you think knowledge comes without cost? The law of equivalent exchange is absolute. You WILL pay.",
			Outputs = {"AskAboutPrice", "RefusePayment", "AcceptFate"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- DEEPER INQUIRY
		-- ═══════════════════════════════════════════════════════════════

		-- ASK ABOUT THE GATE
		{
			Name = "AskAboutGate",
			Type = "Response",
			Priority = 0,
			Text = "What is the Gate of Truth?",
			Outputs = {"GateResponse"}
		},

		{
			Name = "GateResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "The gate contains all knowledge. Every secret of alchemy. Every truth of the universe. Those who glimpse it are forever changed. Those who seek to master it... pay dearly.",
			Outputs = {"AskAboutPrice", "AcceptFate"}
		},

		-- ASK ABOUT THE PRICE
		{
			Name = "AskAboutPrice",
			Type = "Response",
			Priority = 1,
			Text = "What must I pay?",
			Outputs = {"PriceResponse"}
		},

		{
			Name = "PriceResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "Equivalent exchange. Something of equal value to what you gained. Your flesh. Your blood. A piece of your very being. The gate has already chosen what it will take...",
			Outputs = {"BegForMercy", "AcceptFate", "RefusePayment"}
		},

		-- REFUSE PAYMENT
		{
			Name = "RefusePayment",
			Type = "Response",
			Priority = 2,
			Text = "I refuse to pay!",
			Outputs = {"RefuseResponse"}
		},

		{
			Name = "RefuseResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "You cannot refuse. The toll has already been set. The moment you opened the gate, the exchange was sealed. Your defiance... is meaningless.",
			Outputs = {"BegForMercy", "AcceptFate"}
		},

		-- BEG FOR MERCY
		{
			Name = "BegForMercy",
			Type = "Response",
			Priority = 0,
			Text = "Please... isn't there another way?",
			Outputs = {"MercyResponse"}
		},

		{
			Name = "MercyResponse",
			Type = "Prompt",
			Priority = 0,
			Text = "Mercy? I do not deal in mercy. I deal in truth. In balance. In the immutable law that governs all existence. Your plea changes nothing. The price... will be paid.",
			Outputs = {"AcceptFate"}
		},

		-- ═══════════════════════════════════════════════════════════════
		-- FINAL ACCEPTANCE - TRIGGERS ORGAN LOSS
		-- ═══════════════════════════════════════════════════════════════
		{
			Name = "AcceptFate",
			Type = "Response",
			Priority = 3,
			Text = "Extract the toll.",
			Outputs = {"FinalJudgment"}
		},

		{
			Name = "FinalJudgment",
			Type = "Prompt",
			Priority = 0,
			Text = "So be it. The toll is collected. Remember this pain, alchemist. Remember the price of hubris. Remember... that Truth always collects its due.",
			Quest = {
				Action = "TruthPayment",
			},
			AutoClose = true,
			Outputs = {}
		}
	}
}
