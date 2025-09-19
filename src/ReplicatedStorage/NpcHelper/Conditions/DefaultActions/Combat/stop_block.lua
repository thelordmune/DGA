local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
local Library = Server.Library
return function(actor: Actor, mainConfig: table)
	--print("Moving to target...")



	local npc_states = mainConfig.getState()

	if not npc_states then
		return false
	end

	if not Library.GetSpecificState(mainConfig.getNpc(),"Block")  then
		return false
	end
	--print(debug.info(2, "sl"))
	
	mainConfig.InitiateBlock(false)

	return true
end