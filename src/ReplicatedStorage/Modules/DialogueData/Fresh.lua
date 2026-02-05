return {
    NPCName = "Fresh",
    Nodes = {
        {
            Name = "Root",
            Type = "DialogueRoot",
            Priority = 0,
            Outputs = {"Greeting"}
        },
        {
            Name = "Greeting",
            Type = "Prompt",
            Priority = 0,
            Text = "Welcome to the central command center, Would you like to travel to the library?",
            Outputs = {"Yes", "No"}
        },
        {
            Name = "Yes",
            Type = "Response",
            Priority = 0,
            Text = "Yes, but how do i get there?",
            Outputs = {"Granted"}
        },
        {
            Name = "No",
            Type = "Response",
            Priority = 0,
            Text = "No, thanks for the offer though.",
            Outputs = {"Decline"}
        },
        {
            Name = "Granted",
            Type = "Prompt",
            Priority = 0,
            Text = "I have my ways.",
            Quest = {
                Action = "Teleport",
                QuestName = "Library Access"
            },
            Outputs = {},
            AutoClose = true
        },
        {
            Name = "Decline",
            Type = "Prompt",
            Priority = 0,
            Text = "Stop wasting my time kizz",
            Outputs = {},
            AutoClose = true
        }
    }
}

