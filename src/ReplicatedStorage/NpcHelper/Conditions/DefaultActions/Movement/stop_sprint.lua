local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
local Library = Server.Library
return function(actor: Actor, mainConfig: table)
	-- Stop sprinting when conditions are no longer met
	local npc = mainConfig.getNpc()
	if not npc then
		return false
	end

	-- Only stop sprint if we're currently running
	if mainConfig.Run.IsRunning then
		---- print(`[NPC Sprint] {npc.Name} stopping sprint`)
		mainConfig.InitiateRun(false)
	end

	return true
end