# Quick Start - Multiplace System

## 🚀 Serving Both Places

Run this script to start both servers:
```bash
.\serve-both.ps1
```
Or:
```bash
.\serve-both.bat
```

This will start:
- **Main Game** on `localhost:34872`
- **Main Menu** on `localhost:34873`

## 📦 Building for Production

Build both places:
```bash
# Main Game
rojo build default.project.json -o MainGame.rbxl

# Main Menu
rojo build menu.project.json -o MainMenu.rbxl
```

Then publish both to Roblox under the same game.

## 🎮 Place IDs

- **Main Menu**: `138824307106116`
- **Main Game**: `134137392851607`

## ✅ What's Already Set Up

### Main Menu
- ✅ Play button requests server teleport
- ✅ Server-side teleportation (secure)
- ✅ Loading screen during teleport
- ✅ Error handling and timeout protection

### Main Game
- ✅ Access control (blocks direct joins)
- ✅ Studio testing always allowed
- ✅ Data persistence across places
- ✅ Auto-redirect to menu if unauthorized

## 📁 Key Files

### Main Menu
```
src/MainMenu/
├── StarterPack/
│   ├── LocalScript.client.lua         (Camera & UI)
│   └── TeleportHandler.client.lua     (Play button → Request teleport)
├── ServerScriptService/
│   └── TeleportService.server.lua     (Server-side teleportation)
├── ReplicatedFirst/
├── StarterGui/
└── StarterPlayer/
```

### Main Game
```
src/ServerScriptService/
├── AccessControl.server.lua         (Blocks direct joins)
├── TeleportDataHandler.server.lua   (Saves data on teleport)
└── ServerConfig/
    └── Server/
        └── Data/
            └── Template.lua         (Player data structure)
```

## 🧪 Testing Checklist

### In Studio
- [ ] Main menu loads correctly
- [ ] Play button appears
- [ ] Camera effects work
- [ ] Main game loads in Studio (access control disabled)

### In Production
- [ ] Publish both places to same game
- [ ] Join main menu from Roblox
- [ ] Click Play button
- [ ] Teleport to main game works
- [ ] Try joining main game directly (should redirect to menu)
- [ ] Data persists (level, items, etc.)

## 🔧 Common Commands

### Start Development
```bash
# Terminal 1 - Main Game
rojo serve default.project.json

# Terminal 2 - Main Menu
rojo serve menu.project.json --port 34873
```

### Stop All Servers
```bash
.\stop-servers.ps1
```

### Build Both Places
```bash
rojo build default.project.json -o MainGame.rbxl
rojo build menu.project.json -o MainMenu.rbxl
```

## 📚 Full Documentation

- **Complete Setup**: `MULTIPLACE_SETUP_GUIDE.md`
- **Teleport System**: `MULTIPLACE_TELEPORT_SETUP.md`

## ⚠️ Important Notes

1. **Studio Testing**: Access control is automatically disabled in Studio
2. **Data Persistence**: Both places use the same DataStore (same game)
3. **Direct Joins**: Players cannot join main game directly (except in Studio)
4. **Place IDs**: Must be correct in all teleport scripts

## 🐛 Quick Troubleshooting

**Teleport fails?**
- Check place IDs are correct
- Verify both places are published
- Check output for errors

**Data not saving?**
- Both places must be under same game
- Check ProfileService is working
- Verify DataStore access

**Access control not working?**
- Only works in published game (not Studio)
- Check place IDs match
- Verify AccessControl.server.lua is running

**Players stuck in redirect loop?**
- Check MAIN_MENU_PLACE_ID is correct
- Verify menu place is published
- Check for script errors

## 🎯 Next Steps

1. Create main menu UI in `src/MainMenu/StarterGui/`
2. Add menu music/sounds
3. Customize loading screens
4. Add character preview in menu
5. Implement settings menu
6. Add news/updates display

