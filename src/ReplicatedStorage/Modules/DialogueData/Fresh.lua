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
            Type = "Dialogue",
            Priority = 0,
            Text = "Welcome to the central command center. ",
            Outputs = {}
        }
    }
}

