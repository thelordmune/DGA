return {
    NPCName = "Sam",
    Nodes = {
        {
            Name = "Root",
            Type = "DialogueRoot",
            Priority = 0,
            Outputs = {"NonMilitaryGreeting"}
        },
        
        {
            Name = "NonMilitaryGreeting",
            Type = "Prompt",
            Priority = 0,
            Text = "You wanna become a dog of the military? I guess that works, but I wanna find out how your mind works first.",
            Outputs = {"YesResponse", "NoResponse"}
        },
        {
            Name = "YesResponse",
            Type = "Response",
            Priority = 0,
            Text = "Sure, go ahead",
            Outputs = {"Question"}
        },
        {
            Name = "NoResponse",
            Type = "Response",
            Priority = 0,
            Text = "I'm not interested",
            Outputs = {"Goodbye"}
        },
        {
            Name = "Question",
            Type = "Prompt",
            Priority = 0,
            Text = "Imagine I have a pen and I want you to make it disappear. How would you go about doing that?",
            Outputs = {"Break", "Transmute", "Hide"}
        },
        {
            Name = "Break",
            Type = "Response",
            Priority = 0,
            Text = "I'd break it",
            Outputs = {"BreakAnswer"}
        },
        {
            Name = "Transmute",
            Type = "Response",
            Priority = 0,
            Text = "I'd transmute it",
            Outputs = {"TransmuteAnswer"}
        },
        {
            Name = "Hide",
            Type = "Response",
            Priority = 0,
            Text = "I'd hide it",
            Outputs = {"HideAnswer"}
        },
        {
            Name = "BreakAnswer",
            Type = "Prompt",
            Priority = 0,
            Text = "Interesting choice, I suppose that works... Head over to central command center to begin your exam; heres a pass.",
            Outputs = {},
            AutoClose = true
        },
        {
            Name = "TransmuteAnswer",
            Type = "Prompt",
            Priority = 0,
            Text = "Alchemy huh... Your mind works well. Take this pass and head over to the central command center to start your journey.",
            Outputs = {},
            AutoClose = true
        },
        {
            Name = "HideAnswer",
            Type = "Prompt",
            Priority = 0,
            Text = "Good answer, I think that works well enough for me. Head over to central command center and show them the pass I've given you",
            Outputs = {},
            AutoClose = true
        },
        {
            Name = "Goodbye",
            Type = "Prompt",
            Priority = 0,
            Text = "Goodbye",
            Outputs = {},
            AutoClose = true
        }
    }
}