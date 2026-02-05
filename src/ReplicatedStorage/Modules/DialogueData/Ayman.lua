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
            Text = "hi, welcome to the weapon shop. Please have a look around and come back to me with any questions",
            Outputs = {"Okay", "Question"}
        },
        {
            Name = "Okay",
            Type = "Response",
            Priority = 0,
            Text = "Okay thanks",
            Outputs = {},
            AutoClose = true
        },
        {
            Name = "Question",
            Type = "Response",
            Priority = 0,
            Text = "Why do you look like a cat...",
            Outputs = {"Answer"} -- , "Quest"
        },
        {
            Name = "Answer",
            Type = "Prompt",
            Priority = 0,
            Text = "Theres a lot about this world you dont know yet. Come back to me once you're well versed in the world of alchemy and I can reveal the secrets of my appearance",
            Outputs = {"Weirdo"},
            AutoClose = true
        },
        {
            Name = "Weirdo",
            Type = "Response",
            Priority = 0,
            Text = "Whatever weirdo...",
            Outputs = {},
            AutoClose = true
        }
    }
}

