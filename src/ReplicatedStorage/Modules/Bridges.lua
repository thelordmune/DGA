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
	UpdateMoney = bridgeNet2.ReferenceBridge("UpdateMoney"),
	UpdateInfluence = bridgeNet2.ReferenceBridge("UpdateInfluence"),
	UpdateStamina = bridgeNet2.ReferenceBridge("UpdateStamina"),
	NenAbility = bridgeNet2.ReferenceBridge("NenAbility"),
	NenNotification = bridgeNet2.ReferenceBridge("NenNotification"),
	NenExhausted = bridgeNet2.ReferenceBridge("NenExhausted"),
	NenStaminaDrain = bridgeNet2.ReferenceBridge("NenStaminaDrain"),
	EnDetection = bridgeNet2.ReferenceBridge("EnDetection"),
	NightTransition = bridgeNet2.ReferenceBridge("NightTransition"),
	JailPlayer = bridgeNet2.ReferenceBridge("JailPlayer"),
	InventoryAction = bridgeNet2.ReferenceBridge("InventoryAction"),
	JailEscape = bridgeNet2.ReferenceBridge("JailEscape"),
	TruthReturn = bridgeNet2.ReferenceBridge("TruthReturn"),
}

return bridgeTree