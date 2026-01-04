--[[
    WandererDialogue.lua

    Dynamic dialogue generation for wandering citizen NPCs.
    Creates natural conversations based on occupation and personality.

    Personality mannerisms are woven throughout ALL dialogue, not just greetings.
    Each occupation has unique dialogue topics relevant to their profession.

    Extended with detailed follow-up responses for deeper conversations.
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

-- Default detailed topics for occupations that don't have specific ones
local defaultDetailedTopics = {
    work_detail_1 = {
        "My day starts early and ends late. {p_interject}there's always something to do.",
        "The routine varies, but {p_react}you learn to adapt to whatever comes.",
        "Each day brings new challenges. {p_interject}keeps things interesting.",
    },
    work_detail_2 = {
        "It has its moments. {p_react}but nothing worthwhile comes easy.",
        "Difficult? {p_interject}depends on the day. Some are harder than others.",
        "The work itself isn't hard once you know what you're doing. {p_react}it's the unexpected problems.",
    },
    work_detail_3 = {
        "Knowing I've done good work. {p_react}there's satisfaction in that.",
        "When things come together properly. {p_interject}that feeling never gets old.",
        "Helping people, in my own way. {p_react}that's what matters.",
    },
    town_detail_1 = {
        "Things have changed over the years. {p_interject}some for better, some for worse.",
        "I've seen this place go through many phases. {p_react}the current one is... interesting.",
        "It used to be different. {p_interject}quieter, maybe. Or maybe I just remember it that way.",
    },
    town_detail_2 = {
        "The main square is always lively. {p_react}good place to get a feel for the town.",
        "There's a tavern near the eastern gate. {p_interject}decent food, good conversation.",
        "The market district in the morning. {p_react}that's when you see the real life of this place.",
    },
    town_detail_3 = {
        "The back alleys at night. {p_react}nothing good happens there after dark.",
        "Be careful around the old district. {p_interject}not everyone there has honest intentions.",
        "Stay away from trouble and trouble will stay away from you. {p_react}usually.",
    },
    rumors_detail_1 = {
        "Here and there. {p_interject}you hear things if you listen.",
        "People talk. {p_react}I just happen to have good ears.",
        "Word gets around. {p_interject}especially in a place like this.",
    },
    rumors_detail_2 = {
        "Hard to say. {p_react}there's usually some truth to every rumor.",
        "I try not to believe everything I hear. {p_interject}but sometimes the stories add up.",
        "Who knows? {p_react}stranger things have turned out to be true.",
    },
    rumors_detail_3 = {
        "Always something. {p_interject}but most of it's probably just idle gossip.",
        "People say all sorts of things. {p_react}hard to know what's real anymore.",
        "There are whispers about... {p_interject}no, never mind. It's probably nothing.",
    },
    personal = {
        "I'm just trying to make an honest living. {p_react}nothing special about me.",
        "I do what I do because someone has to. {p_interject}and I'm not bad at it.",
        "Life isn't always what you planned. {p_react}but you make the best of it.",
    },
    personal_history = {
        "Long enough to call it home. {p_interject}though some days I wonder.",
        "I came here years ago. {p_react}stayed longer than I ever planned.",
        "Been here since I was young. {p_interject}can't imagine living anywhere else now.",
    },
    personal_family = {
        "Some. {p_react}we don't talk as much as we should.",
        "Family's complicated. {p_interject}isn't everyone's?",
        "A few people I care about. {p_react}that's enough for me.",
    },
    personal_hopes = {
        "A quiet life, eventually. {p_react}is that too much to ask?",
        "Just to keep doing what I do. {p_interject}and maybe see things improve.",
        "Hope? {p_react}I hope tomorrow is better than today. That's all anyone can ask.",
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
            work_detail_1 = {
                "My day starts with reviewing research notes. {p_interject}then laboratory work, sometimes field testing.",
                "Between experiments and military briefings, there's barely time to eat. {p_react}such is the life of a state alchemist.",
                "Mornings are for theory, afternoons for practical applications. {p_interject}evenings for documentation.",
            },
            work_detail_2 = {
                "Difficult? {p_react}that's an understatement. One wrong calculation could cost you more than just materials.",
                "The mental strain is immense. {p_interject}alchemy requires perfect focus. One slip and things go wrong... or worse.",
                "Years of study before feeling {p_emphasis}remotely competent. And I'm still learning every day.",
            },
            work_detail_3 = {
                "When a transmutation works perfectly... {p_react}there's nothing quite like it. Creating from understanding alone.",
                "Helping people with my research. {p_interject}knowing my work might save lives someday.",
                "The pursuit of truth. {p_emphasis}understanding the laws that govern our world.",
            },
            town = {
                "Central Command has been {p_emphasis}active lately. More alchemists being summoned for briefings.",
                "I've noticed increased security around the research facilities. {p_interject}something significant is happening.",
                "The library here has some interesting alchemical texts. Restricted access, unfortunately.",
            },
            town_detail_1 = {
                "Before the military's mobilization, it was quieter. {p_interject}research was the priority, not warfare.",
                "I've been here for years. The town has changed. {p_react}more soldiers, more restrictions.",
                "It used to be a place of learning. Now? {p_interject}it feels more like a staging ground.",
            },
            town_detail_2 = {
                "The central library is worth a visit. {p_interject}if you can get access, the alchemical section is remarkable.",
                "The market district has good supplies. {p_react}though materials have gotten expensive.",
                "There's a tea house near the eastern gate. {p_interject}quiet, good for thinking.",
            },
            town_detail_3 = {
                "The old factory district at night. {p_react}strange things happen there. Unexplained lights.",
                "Stay away from military restricted zones. {p_interject}they don't take kindly to curiosity.",
                "The underground tunnels beneath the old quarter. {p_react}rumors say they're not empty.",
            },
            rumors = {
                "There are whispers about forbidden transmutations. Human transmutation, specifically. {p_react}terrifying stuff.",
                "Some colleagues have been reassigned to classified projects. {p_interject}nobody knows what they're working on.",
                "The Philosopher's Stone... most think it's legend. But I've seen research notes that suggest otherwise.",
            },
            rumors_detail_1 = {
                "Other alchemists. Late night discussions when we think no one's listening. {p_react}dangerous topics.",
                "Research archives that were supposed to be sealed. {p_interject}I may have seen things I shouldn't have.",
                "Whispers in the corridors of Central Command. {p_react}the walls have ears there.",
            },
            rumors_detail_2 = {
                "I've seen things that make me wonder. {p_interject}the military's interest in certain research is... concerning.",
                "Part of me hopes it's all exaggeration. {p_react}but I've learned not to dismiss anything in alchemy.",
                "The truth often sounds impossible until you see proof. {p_interject}I try to keep an open mind.",
            },
            rumors_detail_3 = {
                "There are whispers about creatures that aren't quite human. Homunculi. {p_react}probably just stories.",
                "I've heard the Fuhrer himself takes special interest in certain alchemists. {p_interject}those people tend to disappear.",
                "Some say there's a network of tunnels connecting all major cities. {p_react}for what purpose, no one knows.",
            },
            personal = {
                "I devoted my life to understanding alchemy. {p_interject}it's more than a career, it's who I am.",
                "Being a State Alchemist means sacrifice. {p_react}friends, family, normal life... all secondary to research.",
                "I believe knowledge can change the world. {p_interject}that's what keeps me going.",
            },
            personal_history = {
                "I came here after passing the State Examination. {p_interject}that was many years ago now.",
                "Originally from a small town to the east. {p_react}alchemy was my path to something greater.",
                "I've been stationed here for five years. {p_interject}long enough to see the changes.",
            },
            personal_family = {
                "My work is my family now. {p_react}the others who understand this path.",
                "I have relatives back home. {p_interject}I write when I can, but research consumes my time.",
                "Fellow alchemists become like siblings. {p_react}we understand each other in ways others can't.",
            },
            personal_hopes = {
                "I hope to unlock secrets that benefit humanity. {p_react}not just military applications.",
                "Perhaps one day, alchemy can heal instead of destroy. {p_interject}that's my dream.",
                "I want to leave behind knowledge that helps future generations. {p_react}a legacy of understanding.",
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
            work_detail_1 = {
                "Up at dawn for drills. Patrol routes, guard duty, equipment maintenance. {p_interject}it's structured.",
                "Every day is scheduled. Training, patrols, briefings. {p_react}not much room for personal time.",
                "The routine keeps us ready. {p_interject}you never know when you'll be called to action.",
            },
            work_detail_2 = {
                "The physical part? {p_react}you get used to it. It's the mental discipline that's hard.",
                "Being away from family is the hardest part. {p_interject}but duty calls.",
                "The waiting is difficult. {p_react}you train and train, not knowing when it'll matter.",
            },
            work_detail_3 = {
                "Knowing I'm protecting people. {p_react}that's why I signed up.",
                "The camaraderie. {p_interject}soldiers become brothers and sisters.",
                "When a mission goes well and everyone comes home. {p_react}that's the best feeling.",
            },
            town = {
                "Things have been {p_emphasis}quiet lately. Maybe too quiet, if you ask me.",
                "There's been reports of suspicious activity near the east district. We're keeping an eye on it.",
                "Citizens seem nervous these days. {p_interject}I can't blame them with all the rumors flying around.",
            },
            town_detail_1 = {
                "Before the recent orders, it was more peaceful. {p_react}now there's tension in the air.",
                "I've seen this town change. {p_interject}more patrols, more checkpoints.",
                "The military presence has grown. {p_react}whether that's good or bad depends who you ask.",
            },
            town_detail_2 = {
                "The barracks has a decent mess hall. {p_interject}if you're looking for a meal.",
                "The training grounds are impressive. {p_react}state of the art facilities.",
                "The old tavern by the south gate. {p_interject}soldiers gather there off-duty.",
            },
            town_detail_3 = {
                "The eastern outskirts after dark. {p_react}we've had incidents there.",
                "Don't wander near the restricted zones. {p_interject}for your own safety.",
                "Some back alleys aren't regularly patrolled. {p_react}be cautious.",
            },
            rumors = {
                "Word in the barracks is that reinforcements are being mobilized. {p_react}nobody knows for what.",
                "Some of the brass have been talking about 'the eastern situation' again. {p_interject}not good news.",
                "I've heard whispers about special operations. Black ops stuff. Above my pay grade.",
            },
            rumors_detail_1 = {
                "Fellow soldiers, mostly. {p_react}we talk during downtime.",
                "Bits and pieces from different units. {p_interject}you piece things together.",
                "The sergeants sometimes let things slip. {p_react}especially after a few drinks.",
            },
            rumors_detail_2 = {
                "Hard to say. {p_interject}but when the brass gets nervous, something's happening.",
                "I've learned not to ask too many questions. {p_react}orders are orders.",
                "There's usually truth to military rumors. {p_interject}we just don't get the full picture.",
            },
            rumors_detail_3 = {
                "There's talk of increased activity at the borders. {p_react}but that's classified.",
                "Some say there are threats from within Amestris itself. {p_interject}internal enemies.",
                "I've heard things about experiments. {p_react}probably just rumors though.",
            },
            personal = {
                "I joined to serve my country. {p_react}simple as that.",
                "Military life isn't for everyone. {p_interject}but it's given me purpose.",
                "I do my duty and I do it well. {p_react}that's all anyone can ask.",
            },
            personal_history = {
                "Grew up in a military family. {p_interject}service was expected.",
                "I've been stationed in three different posts. {p_react}this one's the longest.",
                "Enlisted young, worked my way up. {p_interject}still have a long way to go.",
            },
            personal_family = {
                "Parents still write letters. {p_react}haven't seen them in months.",
                "My squad is my family now. {p_interject}we look out for each other.",
                "Left someone behind when I enlisted. {p_react}hope they're still waiting.",
            },
            personal_hopes = {
                "To serve with honor and retire with dignity. {p_react}that's the dream.",
                "Maybe peace someday. {p_interject}so the next generation doesn't have to fight.",
                "I hope to make a difference. {p_react}even a small one.",
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
            work_detail_1 = {
                "Consultations in the morning, surgeries in the afternoon. {p_interject}maintenance appointments throughout.",
                "Each automail piece is custom. {p_react}measuring, designing, fitting... it takes time.",
                "I spend hours in the workshop. {p_interject}crafting, adjusting, perfecting.",
            },
            work_detail_2 = {
                "The surgery itself is intense. {p_react}connecting nerves to metal isn't simple.",
                "Rehabilitation is the hard part for patients. {p_interject}learning to use a new limb takes months.",
                "The precision required is exhausting. {p_react}one millimeter off and the whole limb fails.",
            },
            work_detail_3 = {
                "Seeing someone walk for the first time after surgery. {p_react}nothing compares.",
                "When a client returns to their old life. {p_interject}that's why I do this.",
                "The gratitude in their eyes. {p_react}makes all the difficult cases worth it.",
            },
            town = {
                "Business has been steady. {p_interject}more veterans coming back from the east with injuries.",
                "The local metalsmith provides good materials. Quality steel makes quality automail.",
                "I've seen more civilian clients lately too. Factory accidents, you know how it is.",
            },
            town_detail_1 = {
                "When I first set up shop, business was slow. {p_react}now I can barely keep up.",
                "The war changed everything. {p_interject}suddenly every town needed an automail engineer.",
                "This place has grown around the military presence. {p_react}for better or worse.",
            },
            town_detail_2 = {
                "The metalsmith on the west side has the best materials. {p_interject}expensive but worth it.",
                "There's a rehabilitation center near the hospital. {p_react}we work closely with them.",
                "The market has basic supplies. {p_interject}specialized parts I have to order.",
            },
            town_detail_3 = {
                "Some areas have unstable power. {p_react}bad for automail with electronic components.",
                "The old industrial district has scrap, but also danger. {p_interject}not worth the risk.",
                "Be careful with automail near the lake. {p_react}water damage is expensive to fix.",
            },
            rumors = {
                "They say there's an engineer out east who can do full-body automail. {p_react}seems impossible, but who knows.",
                "I've heard whispers about military-grade automail with built-in weapons. {p_interject}scary to think about.",
                "Word is the Rockbells in Resembool are the best in the country. I'd love to study their techniques.",
            },
            rumors_detail_1 = {
                "Other engineers. {p_react}we share techniques and gossip at conferences.",
                "Patients tell stories. {p_interject}you hear a lot when you're fitting someone for a limb.",
                "Trade publications, mostly. {p_react}and word of mouth.",
            },
            rumors_detail_2 = {
                "The Rockbell claims are probably true. {p_react}their work is legendary.",
                "Weapon-integrated automail? {p_interject}I've seen military prototypes. They're real.",
                "Full-body automail seems impossible. {p_react}but alchemy keeps surprising us.",
            },
            rumors_detail_3 = {
                "There's talk of automail that can sense touch. {p_react}revolutionary if true.",
                "Some say the military is developing combat automail. {p_interject}soldiers who are part machine.",
                "I've heard of experimental nerve interfaces. {p_react}direct brain control.",
            },
            personal = {
                "I became an engineer because I wanted to help people. {p_react}medicine takes too long.",
                "Every limb I create is a second chance. {p_interject}that's how I see it.",
                "It's not just a job. {p_react}it's a calling.",
            },
            personal_history = {
                "Apprenticed under a master engineer for years. {p_interject}came here to open my own shop.",
                "I've been here since the early days of the conflict. {p_react}plenty of work, sadly.",
                "Trained in Rush Valley originally. {p_interject}the automail capital.",
            },
            personal_family = {
                "My parents were engineers too. {p_react}it's in the blood.",
                "Too busy for much personal life. {p_interject}my clients are like family.",
                "I have siblings elsewhere. {p_react}we write occasionally.",
            },
            personal_hopes = {
                "I want to advance the field. {p_react}make automail better, more accessible.",
                "Someday, automail that's indistinguishable from real limbs. {p_interject}that's the goal.",
                "I hope to train the next generation. {p_react}pass on what I've learned.",
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

-- Get topic response for an occupation (supports detailed follow-ups)
function WandererDialogue.getTopicResponse(occupation, topic, personality)
    local occupationData = WandererDialogue.Occupations[occupation]

    -- First check occupation-specific topics
    if occupationData and occupationData.topics and occupationData.topics[topic] then
        local response = randomChoice(occupationData.topics[topic])
        return WandererDialogue.processText(response, personality)
    end

    -- Then check default detailed topics
    if defaultDetailedTopics[topic] then
        local response = randomChoice(defaultDetailedTopics[topic])
        return WandererDialogue.processText(response, personality)
    end

    return "I don't have much to say about that."
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

-- Get personal intro for an occupation
function WandererDialogue.getPersonalIntro(occupation, personality)
    local occupationData = WandererDialogue.Occupations[occupation]

    if occupationData and occupationData.topics and occupationData.topics.personal then
        local response = randomChoice(occupationData.topics.personal)
        return WandererDialogue.processText(response, personality)
    end

    local response = randomChoice(defaultDetailedTopics.personal)
    return WandererDialogue.processText(response, personality)
end

return WandererDialogue
