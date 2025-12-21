--[[
    WandererDialogue.lua

    Dynamic dialogue generation for wandering citizen NPCs.
    Creates natural conversations based on occupation and personality.

    Personality mannerisms are woven throughout ALL dialogue, not just greetings.
    Each occupation has unique dialogue topics relevant to their profession.
]]

local WandererDialogue = {}

-- Personality-specific text modifiers that appear THROUGHOUT conversations
-- Use {p_greeting}, {p_interject}, {p_emphasis}, {p_react}, {p_farewell} in dialogue
WandererDialogue.PersonalityText = {
    Friendly = {
        greetings = {
            "Oh, hello there! ",
            "Hey, friend! ",
            "Good to see a friendly face! ",
            "Well hello! ",
        },
        interjections = {
            "you know, ",
            "honestly, ",
            "between you and me, ",
            "I gotta say, ",
        },
        emphasis = {
            "really ",
            "absolutely ",
            "truly ",
            "definitely ",
        },
        reactions = {
            "That's wonderful! ",
            "How lovely! ",
            "Oh, that's nice! ",
            "Isn't that something! ",
        },
        affirmatives = {
            "Of course! ",
            "Absolutely! ",
            "Happy to help! ",
        },
        farewells = {
            "Take care, friend!",
            "Stay safe out there!",
            "Hope to see you again!",
            "Bye now, take care!",
        },
    },
    Grumpy = {
        greetings = {
            "What do you want? ",
            "Hmph. You again? ",
            "Can't get some peace around here... ",
            "*sigh* Yes? ",
        },
        interjections = {
            "look, ",
            "I'll tell you what, ",
            "not that anyone cares, but ",
            "if you must know, ",
        },
        emphasis = {
            "barely ",
            "hardly ",
            "supposedly ",
            "allegedly ",
        },
        reactions = {
            "Figures. ",
            "Of course. ",
            "Typical. ",
            "What else is new. ",
        },
        affirmatives = {
            "Fine, fine. ",
            "If I must. ",
            "Whatever. ",
        },
        farewells = {
            "Finally, some peace.",
            "Don't let me keep you.",
            "Yeah, yeah, goodbye.",
            "About time.",
        },
    },
    Nervous = {
        greetings = {
            "O-oh! You startled me... ",
            "Ah! I didn't see you there... ",
            "Oh my, h-hello... ",
            "E-excuse me? Oh, hello... ",
        },
        interjections = {
            "um, w-well, ",
            "I-I mean, ",
            "if you don't mind me saying, ",
            "n-not to be weird, but ",
        },
        emphasis = {
            "quite ",
            "rather ",
            "v-very ",
            "somewhat ",
        },
        reactions = {
            "Oh dear... ",
            "That's... concerning. ",
            "I-I see... ",
            "Oh my... ",
        },
        affirmatives = {
            "Y-yes, of course! ",
            "I-I'll try my best! ",
            "O-okay! ",
        },
        farewells = {
            "S-stay safe out there...",
            "P-please be careful!",
            "G-goodbye now...",
            "T-take care of yourself...",
        },
    },
    Professional = {
        greetings = {
            "Good day. ",
            "Greetings. ",
            "How may I assist you? ",
            "Yes, how can I help? ",
        },
        interjections = {
            "as a matter of fact, ",
            "to be precise, ",
            "in my experience, ",
            "speaking professionally, ",
        },
        emphasis = {
            "certainly ",
            "indeed ",
            "precisely ",
            "thoroughly ",
        },
        reactions = {
            "I see. ",
            "Noted. ",
            "Understood. ",
            "Interesting. ",
        },
        affirmatives = {
            "Certainly. ",
            "Of course. ",
            "As you wish. ",
        },
        farewells = {
            "Until next time.",
            "Good day to you.",
            "Farewell.",
            "Take care.",
        },
    },
    Curious = {
        greetings = {
            "Hmm, interesting... A traveler? ",
            "Oh? What brings you here? ",
            "Fascinating, a new face! ",
            "Ooh, hello there! ",
        },
        interjections = {
            "now here's the thing, ",
            "I've been wondering, ",
            "you might find this interesting, ",
            "speaking of which, ",
        },
        emphasis = {
            "particularly ",
            "especially ",
            "remarkably ",
            "notably ",
        },
        reactions = {
            "How fascinating! ",
            "Intriguing... ",
            "That raises questions... ",
            "Ooh, really? ",
        },
        affirmatives = {
            "Oh, certainly! ",
            "I'd love to! ",
            "How exciting! ",
        },
        farewells = {
            "I hope to hear more from you!",
            "Do come back with stories!",
            "There's always more to discover!",
            "Until our next conversation!",
        },
    },
}

-- Occupation-specific dialogue - each occupation has unique content
WandererDialogue.Occupations = {
    -- MILITARY OCCUPATIONS --
    ["State Alchemist"] = {
        intro = "I'm a State Alchemist. {p_interject}it's demanding work, but the research access makes it worthwhile.",
        topics = {
            work = {
                "Alchemy isn't just transmutation circles. It's understanding the world's fundamental laws. {p_interject}most people don't realize how much study is involved.",
                "The State Certification exam is {p_emphasis}grueling. They push you to your limits to see what you're made of.",
                "Research funding comes with... obligations. The military doesn't invest in us for nothing.",
            },
            town = {
                "Central Command has been {p_emphasis}active lately. More alchemists being summoned for briefings.",
                "I've noticed increased security around the research facilities. {p_interject}something significant is happening.",
                "The library here has some interesting alchemical texts. Restricted access, unfortunately.",
            },
            rumors = {
                "There are whispers about forbidden transmutations. Human transmutation, specifically. {p_react}terrifying stuff.",
                "Some colleagues have been reassigned to classified projects. {p_interject}nobody knows what they're working on.",
                "The Philosopher's Stone... most think it's legend. But I've seen research notes that suggest otherwise.",
            },
        },
        askWork = "Tell me about alchemy.",
        askTown = "What's the situation here?",
        askRumors = "Heard any interesting rumors?",
    },

    ["Soldier"] = {
        intro = "Soldier of Amestris, at your service. {p_interject}we keep the peace around here.",
        topics = {
            work = {
                "Patrol duty isn't glamorous, but {p_interject}someone has to keep order. The streets won't watch themselves.",
                "Training never stops. Early morning drills, combat exercises... {p_react}it keeps us sharp.",
                "The chain of command is absolute. Orders come from Central, we follow. Simple as that.",
            },
            town = {
                "Things have been {p_emphasis}quiet lately. Maybe too quiet, if you ask me.",
                "There's been reports of suspicious activity near the east district. We're keeping an eye on it.",
                "Citizens seem nervous these days. {p_interject}I can't blame them with all the rumors flying around.",
            },
            rumors = {
                "Word in the barracks is that reinforcements are being mobilized. {p_react}nobody knows for what.",
                "Some of the brass have been talking about 'the eastern situation' again. {p_interject}not good news.",
                "I've heard whispers about special operations. Black ops stuff. Above my pay grade.",
            },
        },
        askWork = "How's military life?",
        askTown = "Is the town safe?",
        askRumors = "What are soldiers talking about?",
    },

    ["Military Police"] = {
        intro = "Military Police. {p_interject}someone has to enforce the law around here.",
        topics = {
            work = {
                "Law enforcement in Amestris is {p_emphasis}complicated. We answer to both civilian and military authority.",
                "Paperwork. Endless paperwork. {p_react}but records are important. Evidence wins cases.",
                "We work with regular soldiers on major cases. Coordination between divisions isn't always smooth.",
            },
            town = {
                "Crime rates are manageable. A few thefts, some disturbances. {p_interject}nothing we can't handle.",
                "The market district could use more patrols. Too many blind spots where trouble brews.",
                "We've been keeping tabs on some newcomers. Standard procedure for anyone acting suspicious.",
            },
            rumors = {
                "There's word of a smuggling ring operating in the city. {p_react}we're building a case.",
                "{p_interject}some people have reported strange lights at night near the old factory district.",
                "I've heard complaints about certain 'businesses' operating after hours. Investigations pending.",
            },
        },
        askWork = "What's police work like?",
        askTown = "Any crime I should know about?",
        askRumors = "Any suspicious activity?",
    },

    ["Intelligence Agent"] = {
        intro = "I work in... information services. {p_interject}let's leave it at that.",
        topics = {
            work = {
                "Information is {p_emphasis}more valuable than gold. Know the right things, and doors open.",
                "My job is to listen, observe, and report. {p_interject}you'd be surprised what people say openly.",
                "Trust is a currency I don't spend lightly. It takes years to build, seconds to destroy.",
            },
            town = {
                "This town has layers. {p_react}everyone has secrets they think nobody knows about.",
                "Information flows through here like water. Many travelers, many stories. I just... collect them.",
                "I've noticed patterns. Who meets whom, when, and where. {p_interject}it paints a picture.",
            },
            rumors = {
                "Rumors? I deal in facts. But... there are whispers about entities called homunculi. {p_react}probably myths.",
                "I've heard things that would concern you. {p_interject}but some information is too dangerous to share.",
                "The deeper you dig, the more dangerous it gets. Some truths are buried for good reason.",
            },
        },
        askWork = "What exactly do you do?",
        askTown = "What do you know about this town?",
        askRumors = "What secrets have you heard?",
    },

    -- CIVILIAN OCCUPATIONS --
    ["Automail Engineer"] = {
        intro = "I'm an automail engineer! {p_interject}prosthetic limbs, nerve connections, the works.",
        topics = {
            work = {
                "Automail is {p_emphasis}more than just prosthetics. We're giving people their mobility, their independence back.",
                "The nerve connection process is delicate. One wrong wire and... {p_react}well, let's just say precision matters.",
                "I trained for years before I could work independently. Each client's needs are different.",
            },
            town = {
                "Business has been steady. {p_interject}more veterans coming back from the east with injuries.",
                "The local metalsmith provides good materials. Quality steel makes quality automail.",
                "I've seen more civilian clients lately too. Factory accidents, you know how it is.",
            },
            rumors = {
                "They say there's an engineer out east who can do full-body automail. {p_react}seems impossible, but who knows.",
                "I've heard whispers about military-grade automail with built-in weapons. {p_interject}scary to think about.",
                "Word is the Rockbells in Resembool are the best in the country. I'd love to study their techniques.",
            },
        },
        askWork = "How does automail work?",
        askTown = "How's business going?",
        askRumors = "Any engineering news?",
    },

    ["Merchant"] = {
        intro = "Merchant by trade! {p_interject}I deal in goods from all across Amestris.",
        topics = {
            work = {
                "Trade routes have been {p_emphasis}profitable lately. Goods from Xing especially.",
                "The secret to good business? {p_interject}know what people need before they do.",
                "Supply and demand, my friend. {p_react}that's what makes the world go round.",
            },
            town = {
                "The market here is competitive, but fair. Most traders follow the unwritten rules.",
                "Foot traffic has picked up since the military started their exercises. {p_interject}soldiers need supplies too.",
                "The local tavern is the best place to hear what's selling and what's not.",
            },
            rumors = {
                "I've heard caravans from the west are carrying unusual cargo. {p_react}very secretive about it too.",
                "Word is there's a collector in the city who pays premium for antiques. {p_interject}especially alchemical artifacts.",
                "There's always talk of buried treasure from the old wars. {p_react}probably just stories, but who knows.",
            },
        },
        askWork = "How's the trading business?",
        askTown = "What's the market like?",
        askRumors = "Any merchant gossip?",
    },

    ["Blacksmith"] = {
        intro = "I'm the local blacksmith. {p_interject}weapons, tools, anything metal, I can forge it.",
        topics = {
            work = {
                "The forge runs hot all day. {p_emphasis}good steel needs proper treatment and patience.",
                "I've been shaping metal for decades. {p_react}each piece I make tells a story.",
                "There's something {p_emphasis}pure about crafting with your own hands. No shortcuts, just skill.",
            },
            town = {
                "The military keeps me busy. {p_interject}soldiers always need repairs and replacements.",
                "Local farmers bring their tools in weekly. Honest work for honest pay.",
                "Factory-made goods are cheaper, but handcrafted is {p_emphasis}still better. Ask anyone who knows.",
            },
            rumors = {
                "They say alchemists can transmute perfect blades instantly. {p_react}where's the craft in that?",
                "I've heard legends of a smith who forged a blade that could cut through anything. {p_interject}probably just a story.",
                "Word is the military is commissioning special weapons. Very hush-hush about the specifications.",
            },
        },
        askWork = "What do you forge?",
        askTown = "Who are your customers?",
        askRumors = "Any smithing legends?",
    },

    ["Doctor"] = {
        intro = "I'm a doctor here. {p_interject}I do what I can to keep people healthy.",
        topics = {
            work = {
                "Medicine has come far, but {p_interject}there's still so much we don't understand about the human body.",
                "I see all kinds of patients. From common colds to... {p_react}well, worse things.",
                "The Hippocratic oath guides me. First, do no harm. {p_emphasis}sometimes that's harder than it sounds.",
            },
            town = {
                "Public health here is {p_emphasis}decent. Clean water is key to preventing disease.",
                "The clinic stays busy. {p_interject}there's always someone who needs care.",
                "I work with the automail engineers sometimes. Recovery is a team effort.",
            },
            rumors = {
                "There are whispers about alchemists who can heal with transmutation. {p_react}miraculous if true.",
                "{p_interject}I've heard rumors of illness spreading in the south. I hope it doesn't reach here.",
                "They say the military has special medical units with techniques we civilians never see.",
            },
        },
        askWork = "What's being a doctor like?",
        askTown = "How's public health here?",
        askRumors = "Any medical news?",
    },

    ["Librarian"] = {
        intro = "I'm the librarian here. {p_interject}keeper of knowledge and old texts.",
        topics = {
            work = {
                "Books contain the wisdom of ages. {p_react}if only more people took time to read them.",
                "I catalog and preserve knowledge. Some texts here are {p_emphasis}centuries old.",
                "Research is my passion. {p_interject}there's always something new to discover in old pages.",
            },
            town = {
                "The library sees many visitors. Students, scholars, and {p_emphasis}curious minds like yourself.",
                "We have records going back generations. The history of this town and beyond.",
                "Some sections are restricted. Military orders. {p_react}very frustrating for researchers.",
            },
            rumors = {
                "There are references to forbidden alchemy texts. Supposedly destroyed, but {p_interject}who really knows.",
                "I've found mentions of ancient civilizations that practiced strange arts. {p_react}fascinating reading.",
                "They say certain books contain coded messages. Hidden knowledge for those who can find it.",
            },
        },
        askWork = "Tell me about the library.",
        askTown = "What knowledge do you keep?",
        askRumors = "Any mysterious texts?",
    },

    ["Farmer"] = {
        intro = "I work the land around here. {p_interject}farming is honest work.",
        topics = {
            work = {
                "The land provides if you treat it right. {p_emphasis}hard work pays off at harvest time.",
                "My family's been farming here for generations. {p_react}we know every inch of this soil.",
                "Weather's been strange lately. {p_interject}makes planning the season difficult.",
            },
            town = {
                "The market pays fair prices for quality produce. {p_react}no complaints there.",
                "We supply the town with most of its vegetables. Fresh from the fields every morning.",
                "City folk don't always understand where their food comes from. {p_interject}should spend a day on the farm.",
            },
            rumors = {
                "Old timers say the soil here was blessed by an alchemist long ago. {p_react}who knows if it's true.",
                "I've heard tell of strange circles appearing in fields to the north. {p_interject}probably just animals.",
                "Word is the military buys produce at premium for their eastern campaign. Good for business.",
            },
        },
        askWork = "How's the farming life?",
        askTown = "Who do you sell to?",
        askRumors = "Any old farmer's tales?",
    },
}

-- Get a random element from a table
local function randomChoice(tbl)
    if not tbl or #tbl == 0 then return "" end
    return tbl[math.random(#tbl)]
end

-- Process text by replacing personality placeholders
function WandererDialogue.processText(text, personality)
    if not text then return "" end
    if not personality then personality = "Professional" end

    local personalityData = WandererDialogue.PersonalityText[personality]
    if not personalityData then
        personalityData = WandererDialogue.PersonalityText.Professional
    end

    -- Replace all personality placeholders
    local processed = text
    processed = processed:gsub("{p_greeting}", randomChoice(personalityData.greetings) or "Hello. ")
    processed = processed:gsub("{p_interject}", randomChoice(personalityData.interjections) or "")
    processed = processed:gsub("{p_emphasis}", randomChoice(personalityData.emphasis) or "")
    processed = processed:gsub("{p_react}", randomChoice(personalityData.reactions) or "")
    processed = processed:gsub("{p_affirm}", randomChoice(personalityData.affirmatives) or "Yes. ")
    processed = processed:gsub("{p_farewell}", randomChoice(personalityData.farewells) or "Goodbye.")

    return processed
end

-- Get greeting for an occupation and personality
function WandererDialogue.getGreeting(name, occupation, personality)
    local personalityData = WandererDialogue.PersonalityText[personality]
    if not personalityData then
        personalityData = WandererDialogue.PersonalityText.Professional
    end

    local greeting = randomChoice(personalityData.greetings)

    local occupationData = WandererDialogue.Occupations[occupation]
    if occupationData and occupationData.intro then
        local intro = WandererDialogue.processText(occupationData.intro, personality)
        return greeting .. intro
    end

    -- Fallback
    return greeting .. "I'm " .. name .. ". What can I do for you?"
end

-- Get topic response for an occupation
function WandererDialogue.getTopicResponse(occupation, topic, personality)
    local occupationData = WandererDialogue.Occupations[occupation]
    if not occupationData or not occupationData.topics or not occupationData.topics[topic] then
        return "I don't have much to say about that."
    end

    local response = randomChoice(occupationData.topics[topic])
    return WandererDialogue.processText(response, personality)
end

-- Get farewell for a personality
function WandererDialogue.getFarewell(personality)
    local personalityData = WandererDialogue.PersonalityText[personality]
    if not personalityData then
        personalityData = WandererDialogue.PersonalityText.Professional
    end
    return randomChoice(personalityData.farewells)
end

-- Get ask option text for an occupation
function WandererDialogue.getAskOptions(occupation)
    local occupationData = WandererDialogue.Occupations[occupation]
    if not occupationData then
        return {
            work = "Tell me about your work.",
            town = "What's happening around here?",
            rumors = "Heard any interesting rumors?",
        }
    end

    return {
        work = occupationData.askWork or "Tell me about your work.",
        town = occupationData.askTown or "What's happening around here?",
        rumors = occupationData.askRumors or "Heard any interesting rumors?",
    }
end

return WandererDialogue
