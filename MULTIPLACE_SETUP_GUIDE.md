# Multiplace Setup Guide for Ironveil

This guide explains how to set up and manage the multiplace configuration for Ironveil (Main Menu + Main Game).

## Project Structure

```
ironveil/
├── default.project.json          # Main game place
├── menu.project.json             # Main menu place
├── src/
│   ├── ReplicatedStorage/        # Main game code (current)
│   ├── ServerScriptService/      # Main game server code
│   ├── ServerStorage/            # Main game storage
│   ├── StarterPlayer/            # Main game player scripts
│   ├── MainMenu/                 # Main menu specific code (create this)
│   │   ├── ReplicatedFirst/      # Menu loading scripts
│   │   ├── StarterGui/           # Menu UI
│   │   ├── StarterPlayer/        # Menu player scripts
│   │   └── Lighting/             # Menu lighting settings
│   └── Shared/                   # Shared code between places (optional)
│       └── ReplicatedStorage/    # Shared modules
```

## Setup Steps

### 1. Create Main Menu Folders

Create the following folder structure:
```
src/MainMenu/
├── ReplicatedFirst/
├── StarterGui/
├── StarterPlayer/
└── Lighting/
```

### 2. Build Each Place Separately

**For Main Game:**
```bash
rojo build default.project.json -o MainGame.rbxl
```

**For Main Menu:**
```bash
rojo build menu.project.json -o MainMenu.rbxl
```

### 3. Serve During Development

**For Main Game:**
```bash
rojo serve default.project.json
```

**For Main Menu:**
```bash
rojo serve menu.project.json --port 34873
```
(Use a different port for the menu to run both simultaneously)

### 4. Upload to Roblox

1. Open `MainMenu.rbxl` in Roblox Studio
2. Publish to Roblox as a new place (this will be your main menu)
3. Open `MainGame.rbxl` in Roblox Studio
4. Publish to Roblox as a new place (this will be your main game)
5. In Roblox Studio, go to Game Settings → Places to link them to the same game

## Teleporting Between Places

**✅ COMPLETE TELEPORT SYSTEM IMPLEMENTED!**

See **`MULTIPLACE_TELEPORT_SETUP.md`** for the complete teleportation system documentation.

The system includes:
- ✅ Main Menu → Main Game teleportation with Play button
- ✅ Access control (prevents direct joins to main game)
- ✅ Studio testing bypass (always allowed in Studio)
- ✅ Data persistence across places
- ✅ Loading screens and error handling

### Quick Reference

**Place IDs:**
- Main Menu: `138824307106116`
- Main Game: `134137392851607`

**Files:**
- Main Menu: `src/MainMenu/StarterPack/TeleportHandler.client.lua`
- Main Game: `src/ServerScriptService/AccessControl.server.lua`
- Main Game: `src/ServerScriptService/TeleportDataHandler.server.lua`

## Sharing Code Between Places

If you want to share code (like utility modules) between both places:

### Option 1: Duplicate in Both Projects
Keep the code in both `src/ReplicatedStorage` and `src/MainMenu/ReplicatedFirst` or wherever needed.

### Option 2: Use Shared Folder
1. Create `src/Shared/ReplicatedStorage/`
2. Move shared modules there
3. Update both project files to include it:

```json
"ReplicatedStorage": {
  "$className": "ReplicatedStorage",
  "$ignoreUnknownInstances": true,
  "$path": "src/Shared/ReplicatedStorage"
}
```

### Option 3: Use Wally Packages
Publish shared code as Wally packages and include them in both places.

## Best Practices

1. **Keep Menu Lightweight**: The main menu should load quickly, so only include essential code
2. **Use ReplicatedFirst**: Put loading screens and essential menu code in ReplicatedFirst
3. **Separate Assets**: Keep menu assets separate from game assets to reduce initial load time
4. **Test Both Places**: Always test teleportation between places before publishing
5. **Version Control**: Commit both project files to git

## Common Issues

### Issue: Can't teleport between places
**Solution**: Make sure both places are published under the same game and you're using the correct place IDs.

### Issue: Shared code not updating
**Solution**: Make sure both project files point to the correct shared folder path.

### Issue: Rojo serve conflicts
**Solution**: Use different ports for each place when serving simultaneously:
- Main Game: `rojo serve default.project.json` (default port 34872)
- Main Menu: `rojo serve menu.project.json --port 34873`

## Getting Place IDs

After publishing your places:
1. Go to https://create.roblox.com/
2. Navigate to your game
3. Click on the "Places" tab
4. Copy the Place ID for each place
5. Use these IDs in your teleport scripts

