# Teleportation System Architecture

## Complete System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           MAIN MENU PLACE                               │
│                         (ID: 138824307106116)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ CLIENT SIDE (TeleportHandler.client.lua)                          │ │
│  ├───────────────────────────────────────────────────────────────────┤ │
│  │                                                                   │ │
│  │  1. Player clicks Play button                                    │ │
│  │     ↓                                                             │ │
│  │  2. Show loading screen: "Entering Ironveil..."                  │ │
│  │     ↓                                                             │ │
│  │  3. Fire RemoteEvent                                             │ │
│  │     teleportRemote:FireServer()                                  │ │
│  │     ↓                                                             │ │
│  │  4. Wait for response or timeout (10s)                           │ │
│  │     ↓                                                             │ │
│  │  5. If error received: Show error message                        │ │
│  │                                                                   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                │                                        │
│                                │ RemoteEvent: "RequestTeleport"         │
│                                ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ SERVER SIDE (TeleportService.server.lua)                          │ │
│  ├───────────────────────────────────────────────────────────────────┤ │
│  │                                                                   │ │
│  │  1. Receive teleport request from client                         │ │
│  │     ↓                                                             │ │
│  │  2. Validate player                                              │ │
│  │     • Player exists?                                             │ │
│  │     • Already teleporting?                                       │ │
│  │     ↓                                                             │ │
│  │  3. Check cooldown (2 seconds)                                   │ │
│  │     ↓                                                             │ │
│  │  4. Mark player as teleporting                                   │ │
│  │     teleportingPlayers[userId] = true                            │ │
│  │     ↓                                                             │ │
│  │  5. Create TeleportOptions                                       │ │
│  │     ↓                                                             │ │
│  │  6. Call TeleportService:TeleportAsync()                         │ │
│  │     TeleportAsync(134137392851607, {player})                     │ │
│  │     ↓                                                             │ │
│  │  7. Handle result                                                │ │
│  │     • Success: Player teleports                                  │ │
│  │     • Failure: Send error to client                              │ │
│  │                                                                   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                │                                        │
└────────────────────────────────┼────────────────────────────────────────┘
                                 │
                                 │ TeleportService:TeleportAsync()
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           MAIN GAME PLACE                               │
│                         (ID: 134137392851607)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ SERVER SIDE (AccessControl.server.lua)                            │ │
│  ├───────────────────────────────────────────────────────────────────┤ │
│  │                                                                   │ │
│  │  1. Player joins                                                 │ │
│  │     ↓                                                             │ │
│  │  2. Check if Studio                                              │ │
│  │     • YES → Allow (bypass all checks)                            │ │
│  │     • NO  → Continue to step 3                                   │ │
│  │     ↓                                                             │ │
│  │  3. Get join data                                                │ │
│  │     joinData = player:GetJoinData()                              │ │
│  │     ↓                                                             │ │
│  │  4. Check source place ID                                        │ │
│  │     • From Menu (138824307106116) → Allow                        │ │
│  │     • From Game (134137392851607) → Allow (server hop)           │ │
│  │     • Other/Direct → Redirect to menu                            │ │
│  │     ↓                                                             │ │
│  │  5. If unauthorized:                                             │ │
│  │     • Show "Join from Main Menu" message                         │ │
│  │     • Teleport back to menu                                      │ │
│  │                                                                   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ SERVER SIDE (TeleportDataHandler.server.lua)                      │ │
│  ├───────────────────────────────────────────────────────────────────┤ │
│  │                                                                   │ │
│  │  • Ensures data is saved before teleporting                      │ │
│  │  • Syncs Replion data to ProfileService                          │ │
│  │  • Handles PlayerRemoving event                                  │ │
│  │                                                                   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌──────────────┐
│ Main Menu    │
│ Player Data  │
└──────┬───────┘
       │
       │ ProfileService loads: "Player_{UserId}"
       │
       ▼
┌──────────────┐
│ Data Loaded  │
│ (if exists)  │
└──────┬───────┘
       │
       │ Player clicks Play
       │
       ▼
┌──────────────┐
│ Data Synced  │
│ to Profile   │
└──────┬───────┘
       │
       │ TeleportAsync
       │
       ▼
┌──────────────┐
│ Main Game    │
│ Player Joins │
└──────┬───────┘
       │
       │ ProfileService loads: "Player_{UserId}" (same key!)
       │
       ▼
┌──────────────┐
│ Data Loaded  │
│ (persisted)  │
└──────────────┘
```

## Security Layers

```
Layer 1: Client Request
├─ Client can only REQUEST teleport
├─ Cannot force teleportation
└─ Cannot bypass server validation

Layer 2: Server Validation
├─ Player exists check
├─ Cooldown enforcement (2s)
├─ Already teleporting check
└─ Rate limiting

Layer 3: Access Control (Main Game)
├─ Studio bypass (for testing)
├─ Source place validation
├─ Automatic redirect if unauthorized
└─ Cannot join directly from website

Layer 4: Data Integrity
├─ ProfileService session locking
├─ Data sync before teleport
├─ Same DataStore across places
└─ Automatic save on leave
```

## Error Handling Flow

```
Client Request
    ↓
Server Validation
    ├─ PASS → Continue
    └─ FAIL → Return (silent)
    ↓
Teleport Attempt
    ├─ SUCCESS → Player teleports
    └─ FAILURE ↓
              ├─ Server logs error
              ├─ Fire error to client
              └─ Client shows error message
              ↓
Client Timeout (10s)
    └─ If no response → Show timeout error
```

## RemoteEvent Communication

```
CLIENT                          SERVER
  │                               │
  │  RequestTeleport:FireServer() │
  ├──────────────────────────────>│
  │                               │
  │                          Validate
  │                          Teleport
  │                               │
  │  (If error)                   │
  │  TeleportError:FireClient()   │
  │<──────────────────────────────┤
  │                               │
  │  Show error message           │
  │                               │
```

## File Responsibilities

### Main Menu

**Client (`TeleportHandler.client.lua`)**
- UI/UX (loading screen, errors)
- Request teleportation
- Handle user feedback

**Server (`TeleportService.server.lua`)**
- Validate requests
- Enforce cooldowns
- Execute teleportation
- Handle errors

### Main Game

**Server (`AccessControl.server.lua`)**
- Validate join source
- Redirect unauthorized players
- Studio bypass

**Server (`TeleportDataHandler.server.lua`)**
- Save data before teleport
- Sync Replion to Profile
- Handle player leaving

## Key Concepts

### 1. Server Authority
- Server makes all final decisions
- Client only requests and displays UI
- Cannot be exploited

### 2. RemoteEvent Pattern
- Client → Server: Request only
- Server → Client: Errors only
- No sensitive data transmitted

### 3. Cooldown System
- Prevents spam
- Per-player tracking
- Automatic cleanup

### 4. Data Persistence
- Same DataStore key across places
- ProfileService handles locking
- Automatic save on leave

### 5. Access Control
- Multi-layer validation
- Studio testing friendly
- Automatic enforcement

## Summary

This architecture provides:
- ✅ **Security**: Server-authoritative, cannot be exploited
- ✅ **Reliability**: Proper error handling at every step
- ✅ **Scalability**: Easy to extend with new features
- ✅ **Maintainability**: Clear separation of concerns
- ✅ **User Experience**: Smooth loading screens and error messages
- ✅ **Data Safety**: Proper persistence across places

