# Steal the Store

A Roblox heist game set in a giant ValueMart Supercenter. Players get 5 minutes to
steal real products and get away without getting caught.

- **Steal** real store products: groceries, coolers, produce, household, toys, clothing,
  shoes, electronics, TVs and jewelry. Each item is worth its real-life price, from a $2
  candy bar to a $15,000 diamond ring. Pricier items take longer to grab.
- **Get away** by reaching one of five getaway vans (two in the parking lot, the loading
  dock, and both fire lanes) to turn your loot into Cash.
- **Security** gets tougher the more players there are: 2 guards plus 1 per player (up to
  14), with backup called in when people join mid-round. Guards chase anyone they see
  carrying loot. Ceiling cameras sweep the aisles, and the security gates at the doors and
  the fire exits beep if you walk through with loot. Any alarm tells every guard where you are.
- **Get caught** and you lose everything you're carrying and sit in the county jail for 10 seconds.
- **Rob** other players: walk up to someone carrying loot and hold E to take an item.
- **Upgrade** your backpack (bag slots; big TVs take 3-4) and your speed. Progress saves.

The world is built in code: the store (aisles with stocked shelves, glass-door coolers,
produce bins, electronics, a TV wall, clothing racks, a shoe wall, a jewelry counter, a
pharmacy and 11 checkout lanes), a parking lot with cars, trees and light poles, a
loading dock with semi trucks, a road with a gas station, a burger place and a strip mall.
The lobby is a sealed crew hideout and the jail is a sealed cell, so you can't see the
store from either one.

## Files

| File | Goes in Studio as | What it does |
| --- | --- | --- |
| `src/ReplicatedStorage/Config.luau` | ModuleScript `Config` in ReplicatedStorage | Timers, guard counts, cameras, upgrade prices |
| `src/ServerScriptService/Main.server.luau` | Script `Main` in ServerScriptService | Rounds, stealing, escaping, robbing, security, shop |
| `src/ServerScriptService/Items.luau` | ModuleScript `Items` in ServerScriptService | Every product: name, price, 3D model |
| `src/ServerScriptService/MapBuilder.luau` | ModuleScript `MapBuilder` in ServerScriptService | Builds the store, surroundings, hideout, jail and lighting |
| `src/ServerScriptService/GuardAI.luau` | ModuleScript `GuardAI` in ServerScriptService | Guard patrol and chase |
| `src/ServerScriptService/DataService.luau` | ModuleScript `DataService` in ServerScriptService | Saves cash and upgrades |
| `src/StarterPlayer/StarterPlayerScripts/ClientUI.client.luau` | LocalScript `ClientUI` in StarterPlayer > StarterPlayerScripts | Timer, backpack, messages, shop |

## Put it in Roblox Studio with Claude

1. Open Roblox Studio and create a new **Baseplate** place (or open the one you already made).
2. In PowerShell, `cd roblox`, run `git pull`, then `claude`.
3. Paste this to Claude:

   > Read every file in the src folder and create them in my open Roblox Studio place using the
   > Roblox_Studio tools. Follow the "Files" table in README.md for where each one goes and what type
   > it is. Name each script after its file name without the extensions (for example Main.server.luau
   > becomes a Script named Main). Set each script's Source to the exact file contents. If a script
   > with that name already exists, replace its Source. Delete any old StealTheStoreMap model in
   > Workspace. Then set Lighting.Technology to Future.

4. Press **Play** in Studio. The map builds itself when the game starts (it takes a second or two).

To save progress while testing in Studio, turn on **Game Settings > Security >
Enable Studio Access to API Services**.

For the best look, make sure **Lighting > Technology** is set to **Future**. Scripts can't
always change that setting, so the prompt above asks Claude to set it in Studio.

## Change the game

Most balancing is in `Config.luau`: round length, guard count and speed, cameras and
upgrade prices. Product names, prices and how often they appear are in `Items.luau`.

If you want to decorate the store by hand, play once, copy the `StealTheStoreMap` model from Workspace, stop, and paste it back in. The game will use
your edited copy instead of building a new one.

## Roblox Studio MCP server

`.mcp.json` registers the Roblox Studio MCP server (`Roblox_Studio`) for Claude Code.
It needs Windows with Roblox Studio installed (`%LOCALAPPDATA%\Roblox\mcp.bat`).
Approve it when Claude Code asks, and check it with `/mcp`.

Rojo users can sync with `default.project.json` instead.
