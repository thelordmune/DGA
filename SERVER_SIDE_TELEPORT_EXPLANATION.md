# Server-Side Teleportation Explanation

## Why Server-Side?

Teleportation **must** be handled on the server because:

1. **Security**: Clients can be exploited. If teleportation was client-side, exploiters could:
   - Teleport other players without permission
   - Bypass access controls
   - Spam teleport requests
   - Manipulate teleport data

2. **Reliability**: Server-side teleportation ensures:
   - Consistent behavior for all players
   - Proper error handling
   - Data integrity
   - Rate limiting/cooldowns

3. **Roblox Best Practice**: TeleportService should always be called from the server for production games.

## How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        MAIN MENU                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CLIENT (TeleportHandler.client.lua)                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. Player clicks Play button                         │  │
│  │ 2. Show loading screen                               │  │
│  │ 3. Fire RemoteEvent to server                        │  │
│  │    teleportRemote:FireServer()                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          │ RemoteEvent                      │
│                          ▼                                  │
│  SERVER (TeleportService.server.lua)                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. Receive teleport request                          │  │
│  │ 2. Validate player (exists, not already teleporting) │  │
│  │ 3. Check cooldown                                    │  │
│  │ 4. Call TeleportService:TeleportAsync()              │  │
│  │ 5. Handle success/failure                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           │ TeleportAsync
                           ▼
                    ┌──────────────┐
                    │  MAIN GAME   │
                    └──────────────┘
```

### Code Flow

#### Client Side (`TeleportHandler.client.lua`)

```lua
-- 1. Wait for RemoteEvent
local teleportRemote = ReplicatedStorage:WaitForChild("RequestTeleport")

-- 2. When Play button clicked
playButton.Activated:Connect(function()
    -- Show loading screen
    showLoadingScreen()
    
    -- Request teleport from server
    teleportRemote:FireServer()
end)

-- 3. Listen for errors
teleportErrorRemote.OnClientEvent:Connect(function(errorMessage)
    showError(errorMessage)
end)
```

#### Server Side (`TeleportService.server.lua`)

```lua
-- 1. Create RemoteEvent
local teleportRemote = Instance.new("RemoteEvent")
teleportRemote.Name = "RequestTeleport"
teleportRemote.Parent = ReplicatedStorage

-- 2. Handle requests
teleportRemote.OnServerEvent:Connect(function(player)
    -- Validate
    if teleportingPlayers[player.UserId] then
        return -- Already teleporting
    end
    
    -- Mark as teleporting
    teleportingPlayers[player.UserId] = true
    
    -- Teleport
    local success = pcall(function()
        TeleportService:TeleportAsync(MAIN_GAME_PLACE_ID, {player})
    end)
    
    -- Handle result
    if not success then
        -- Send error to client
        errorRemote:FireClient(player, errorMessage)
    end
end)
```

## Security Features

### 1. Cooldown System
```lua
local TELEPORT_COOLDOWN = 2 -- seconds
local teleportingPlayers = {}

-- Prevent spam
if teleportingPlayers[player.UserId] then
    return -- Already teleporting
end

teleportingPlayers[player.UserId] = true

-- Clear after cooldown
task.delay(TELEPORT_COOLDOWN, function()
    teleportingPlayers[player.UserId] = nil
end)
```

### 2. Player Validation
```lua
-- Check if player still exists
if not player:IsDescendantOf(Players) then
    return -- Player left
end
```

### 3. Error Handling
```lua
-- Catch teleport failures
local success, result = pcall(function()
    return TeleportService:TeleportAsync(placeId, {player})
end)

if not success then
    -- Notify client of failure
    errorRemote:FireClient(player, result)
end
```

## RemoteEvent Communication

### Client → Server (Request)
```lua
-- Client sends request (no parameters needed)
teleportRemote:FireServer()
```

### Server → Client (Error)
```lua
-- Server sends error message
teleportErrorRemote:FireClient(player, "Error message here")
```

## Benefits of This Approach

1. **Secure**: Exploiters cannot bypass server validation
2. **Reliable**: Server has authority over teleportation
3. **Scalable**: Easy to add features like:
   - Reserved servers
   - Party/squad teleportation
   - Teleport analytics
   - Custom teleport data
4. **Maintainable**: Clear separation of client/server logic
5. **Debuggable**: Server logs all teleport attempts

## Common Patterns

### Adding Teleport Data
```lua
-- Server-side
local teleportOptions = Instance.new("TeleportOptions")
teleportOptions.TeleportData = {
    FromMenu = true,
    Timestamp = os.time(),
    CustomData = "anything you want"
}

TeleportService:TeleportAsync(placeId, {player}, teleportOptions)
```

### Group Teleportation
```lua
-- Server-side
local function teleportParty(players: {Player})
    local teleportOptions = Instance.new("TeleportOptions")
    
    local success = pcall(function()
        TeleportService:TeleportAsync(placeId, players, teleportOptions)
    end)
end
```

### Reserved Servers
```lua
-- Server-side
local code = TeleportService:ReserveServer(placeId)
local teleportOptions = Instance.new("TeleportOptions")
teleportOptions.ReservedServerAccessCode = code

TeleportService:TeleportAsync(placeId, {player}, teleportOptions)
```

## Testing

### In Studio
- Server-side code runs normally
- Client can request teleports
- Actual teleportation won't work (different place files)
- Test the request/response flow

### In Production
- Full teleportation works
- Test with multiple players
- Verify cooldowns work
- Check error handling

## Troubleshooting

### "RemoteEvent not found"
- Ensure server script runs before client script
- Check ReplicatedStorage for "RequestTeleport" and "TeleportError"

### "Teleport fails silently"
- Check server output for errors
- Verify place IDs are correct
- Ensure TeleportService is enabled in game settings

### "Players can spam teleport"
- Verify cooldown system is working
- Check `teleportingPlayers` table is being updated
- Increase `TELEPORT_COOLDOWN` if needed

## Summary

Server-side teleportation is:
- ✅ **Secure** - Cannot be exploited
- ✅ **Reliable** - Server has authority
- ✅ **Scalable** - Easy to extend
- ✅ **Best Practice** - Recommended by Roblox

The client's only job is to:
1. Request teleportation
2. Show UI feedback
3. Handle errors

The server's job is to:
1. Validate requests
2. Perform teleportation
3. Handle failures
4. Enforce rules (cooldowns, etc.)

This separation of concerns makes the system robust and maintainable!

