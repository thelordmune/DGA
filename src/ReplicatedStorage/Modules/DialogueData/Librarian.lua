return {
    NPCName = "Librarian",
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
            Text = "Welcome to the library. Would you like to explore our vast collection of knowledge?",
            Outputs = {"Yes", "No"}
        },
        {
            Name = "Yes",
            Type = "Response",
            Priority = 0,
            Text = "Yes please.",
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
            Text = "Wonderful! Feel free to explore and discover what knowledge the library has to offer. Remember to be respectful of the books and other visitors.",
            Quest = {
                Action = "Start",
                QuestName = "Explore"
            },
            Outputs = {},
            AutoClose = true
        },
        {
            Name = "Decline",
            Type = "Prompt",
            Priority = 0,
            Text = "No worries, come back if you change your mind.",
            Outputs = {},
            AutoClose = true
        }
    }
}

