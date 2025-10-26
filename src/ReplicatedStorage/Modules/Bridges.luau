local bridgeNet2 = require(game.ReplicatedStorage.Modules.Shared.BridgeNet2)

local bridgeTree = {
	Server = bridgeNet2.ReferenceBridge("Server"),
	Client = bridgeNet2.ReferenceBridge("Client"),
	ClientUiHandle = bridgeNet2.ReferenceBridge("ClientUiHandle"),
	ServerFunction = bridgeNet2.ReferenceBridge("ServerFunction"),
	ECSClient = bridgeNet2.ReferenceBridge("ECSClient"),
	ECSServer = bridgeNet2.ReferenceBridge("ECSServer"),
	Dialogue = bridgeNet2.ReferenceBridge("Dialogue"),
	Inventory = bridgeNet2.ReferenceBridge("Inventory"),
	Quests = bridgeNet2.ReferenceBridge("Quests"),
	UpdateHotbar = bridgeNet2.ReferenceBridge("UpdateHotbar"),
	QuestCompleted = bridgeNet2.ReferenceBridge("QuestCompleted"),
	UpdateAdrenaline = bridgeNet2.ReferenceBridge("UpdateAdrenaline"),
}

return bridgeTree