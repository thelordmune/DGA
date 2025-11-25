# Multiplace Deployment Checklist

## ✅ Pre-Deployment Checklist

### 1. Verify Place IDs
- [ ] Main Menu Place ID: `138824307106116`
- [ ] Main Game Place ID: `134137392851607`

### 2. Check Files Exist

**Main Menu:**
- [ ] `src/MainMenu/StarterPack/TeleportHandler.client.lua`
- [ ] `src/MainMenu/ServerScriptService/TeleportService.server.lua`
- [ ] `src/MainMenu/StarterPack/LocalScript.client.lua` (camera/UI)

**Main Game:**
- [ ] `src/ServerScriptService/AccessControl.server.lua`
- [ ] `src/ServerScriptService/TeleportDataHandler.server.lua`

**Configuration:**
- [ ] `menu.project.json` (includes ServerScriptService)
- [ ] `default.project.json` (main game)

### 3. Verify Configuration

**In `TeleportService.server.lua`:**
```lua
local MAIN_GAME_PLACE_ID = 134137392851607 ✓
```

**In `AccessControl.server.lua`:**
```lua
local MAIN_MENU_PLACE_ID = 138824307106116 ✓
```

## 🔨 Build Process

### Step 1: Build Main Menu
```bash
rojo build menu.project.json -o MainMenu.rbxl
```
- [ ] Build completed without errors
- [ ] `MainMenu.rbxl` file created

### Step 2: Build Main Game
```bash
rojo build default.project.json -o MainGame.rbxl
```
- [ ] Build completed without errors
- [ ] `MainGame.rbxl` file created

## 📤 Publishing

### Step 1: Publish Main Menu
1. [ ] Open `MainMenu.rbxl` in Roblox Studio
2. [ ] File → Publish to Roblox
3. [ ] Select existing place: `138824307106116`
4. [ ] Verify ServerScriptService contains `TeleportService`
5. [ ] Verify StarterPack contains `TeleportHandler`
6. [ ] Publish

### Step 2: Publish Main Game
1. [ ] Open `MainGame.rbxl` in Roblox Studio
2. [ ] File → Publish to Roblox
3. [ ] Select existing place: `134137392851607`
4. [ ] Verify ServerScriptService contains `AccessControl`
5. [ ] Verify ServerScriptService contains `TeleportDataHandler`
6. [ ] Publish

### Step 3: Verify Game Settings
1. [ ] Both places are under the same game/universe
2. [ ] TeleportService is enabled (should be by default)
3. [ ] Both places are published (not private)

## 🧪 Testing

### Test 1: Studio Testing (Main Menu)
1. [ ] Open Main Menu in Studio
2. [ ] Run `.\serve-both.ps1` or start Rojo manually
3. [ ] Connect to `localhost:34873`
4. [ ] Press Play in Studio
5. [ ] Check Output for:
   - `[MenuTeleportService] Ready`
   - `[TeleportHandler] Initialized and ready`
6. [ ] Click Play button
7. [ ] Should see: `[MenuTeleportService] Teleport request from [YourName]`

### Test 2: Studio Testing (Main Game)
1. [ ] Open Main Game in Studio
2. [ ] Connect to `localhost:34872`
3. [ ] Press Play in Studio
4. [ ] Check Output for:
   - `[AccessControl] Initialized`
   - `[AccessControl] Studio mode - allowing all joins`
5. [ ] Should be able to play normally

### Test 3: Production Testing (Main Menu)
1. [ ] Join Main Menu from Roblox website
2. [ ] Wait for menu to load
3. [ ] Click Play button
4. [ ] Should see "Entering Ironveil..." loading screen
5. [ ] Should teleport to Main Game within 2-3 seconds

### Test 4: Production Testing (Access Control)
1. [ ] Try to join Main Game directly from Roblox website
2. [ ] Should see message: "Please join from the Main Menu"
3. [ ] Should be teleported back to Main Menu
4. [ ] Click Play in menu
5. [ ] Should successfully join Main Game

### Test 5: Data Persistence
1. [ ] Join Main Menu
2. [ ] Teleport to Main Game
3. [ ] Make some progress (gain items, etc.)
4. [ ] Leave and rejoin from Main Menu
5. [ ] Verify data persisted

### Test 6: Error Handling
1. [ ] In Main Menu, click Play button rapidly
2. [ ] Should be rate-limited (2 second cooldown)
3. [ ] Should not spam teleport requests

## 🐛 Troubleshooting

### Issue: "RequestTeleport not found"
**Solution:**
- [ ] Verify `TeleportService.server.lua` is in ServerScriptService
- [ ] Check server output for initialization message
- [ ] Wait a few seconds for server to start

### Issue: Teleport doesn't work
**Solution:**
- [ ] Verify place IDs are correct
- [ ] Check both places are published
- [ ] Look for errors in server output
- [ ] Verify TeleportService is enabled

### Issue: Loading screen stays forever
**Solution:**
- [ ] Check server output for errors
- [ ] Verify Main Game place ID is correct
- [ ] Check if Main Game is published
- [ ] Look for TeleportInitFailed errors

### Issue: Can join Main Game directly
**Solution:**
- [ ] Verify `AccessControl.server.lua` is published
- [ ] Check Main Menu place ID is correct
- [ ] Look for errors in AccessControl output
- [ ] Verify script is enabled

### Issue: Data doesn't persist
**Solution:**
- [ ] Verify both places are in same game/universe
- [ ] Check ProfileService is working
- [ ] Look for data save errors
- [ ] Verify `TeleportDataHandler` is running

## 📊 Monitoring

### Server Output (Main Menu)
Expected messages:
```
[MenuTeleportService] Initializing...
[MenuTeleportService] Ready
[MenuTeleportService] Target Place ID: 134137392851607
[TeleportHandler] Initialized and ready
```

### Server Output (Main Game)
Expected messages:
```
[AccessControl] Initializing...
[AccessControl] Main Menu Place ID: 138824307106116
[AccessControl] Main Game Place ID: 134137392851607
[AccessControl] Initialized
```

### Client Output (Main Menu)
Expected messages:
```
[TeleportHandler] Initialized and ready
[TeleportHandler] Play button clicked
[TeleportHandler] Requesting teleport from server...
```

## ✅ Post-Deployment Verification

### Final Checks
- [ ] Players can join Main Menu from Roblox
- [ ] Play button teleports to Main Game
- [ ] Direct joins to Main Game are blocked
- [ ] Data persists across places
- [ ] No errors in server output
- [ ] Loading screens work correctly
- [ ] Error messages display properly
- [ ] Cooldown prevents spam

### Performance Checks
- [ ] Teleport completes in < 5 seconds
- [ ] No memory leaks
- [ ] No excessive warnings in output
- [ ] Server FPS is stable

## 🎉 Success Criteria

Your multiplace system is working correctly if:
- ✅ Players join Main Menu first
- ✅ Play button teleports to Main Game
- ✅ Direct joins are blocked and redirected
- ✅ Data persists across places
- ✅ No errors in production
- ✅ Smooth user experience

## 📝 Notes

### Development Workflow
1. Make changes to source files
2. Run `.\serve-both.ps1` to serve both places
3. Test in Studio with both places open
4. Build and publish when ready

### Common Commands
```bash
# Serve both places
.\serve-both.ps1

# Stop all servers
.\stop-servers.ps1

# Build menu
rojo build menu.project.json -o MainMenu.rbxl

# Build game
rojo build default.project.json -o MainGame.rbxl
```

### Important Files
- `TELEPORT_SERVER_SIDE_UPDATE.md` - What changed
- `SERVER_SIDE_TELEPORT_EXPLANATION.md` - Why server-side
- `TELEPORT_ARCHITECTURE.md` - System architecture
- `MULTIPLACE_TELEPORT_SETUP.md` - Complete setup guide

## 🆘 Support

If you encounter issues:
1. Check server output for errors
2. Review troubleshooting section above
3. Verify all checklist items are complete
4. Check documentation files for details

Good luck with your deployment! 🚀

