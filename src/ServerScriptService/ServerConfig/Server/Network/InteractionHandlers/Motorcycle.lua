local Handler = {}

Handler.OnInteract = function(Player, motorcycle)
	print("[Motorcycle] Player", Player.Name, "interacted with motorcycle")

	-- Add your motorcycle interaction logic here
	-- For example:
	-- - Mount the player on the motorcycle
	-- - Start vehicle controls
	-- - Play mounting animation
	-- etc.

	-- For now, just send a message to the player
	local character = Player.Character
	if character then
		print("[Motorcycle] Interaction successful!")
		-- You can add your custom logic here
	end
end

return Handler
