local SwagText = require(script.Parent.Parent)
local use = "normal, <red>red</red>, <blue>blue</blue>, <color=#00ff00>green</color>, <bold>bold</bold>, <italic>italic</italic>, <red><bold><shake>impact</shake></red></bold>, <wave><rainbow>chroma</wave></warp>, <wave>wave</wave>, <color=#aaaaaa><pause=0.5>slow</pause></color>, <noanim><pause=0>appear</pause></noanim>"

-- == EXAMPLE HERE == --
SwagText.AnimateText(use, script.Parent.Frame, 0.04, Enum.Font.BuilderSans, "fade sizeright shake", 1, nil, nil, nil, nil, true)
wait(5)
SwagText.ClearText(script.Parent.Frame)
SwagText.AnimateText("<wave>this is some <rainbow>text thats gonna</rainbow> warp for a hot while, okay ??</wave>", script.Parent.Frame, 0, Enum.Font.BuilderSans, "fade sizeright shake", 0)
--SwagText.ClearText(script.Parent.Frame)
--SwagText.AnimateText("long bunch of text thats quick because i  havent implemented instant text yet, but soon", script.Parent.Frame, 0)