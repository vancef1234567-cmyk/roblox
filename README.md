# Steal the Store

A Roblox heist game. Players get 5 minutes inside a supermarket to steal the most
valuable loot and escape without getting caught.

- **Steal** items off the shelves (rarer items take longer to grab and get announced to the server).
- **Escape** through the Front Door, Loading Dock or Fire Exit to turn loot into Cash.
- **Avoid** security guards (they chase anyone they see carrying loot) and blinking red lasers (they set off an alarm).
- **Get caught** and you lose everything you're carrying and sit in jail for 10 seconds.
- **Rob** other players: walk up to someone carrying loot and hold E to take an item.
- **Upgrade** your backpack size and speed in the UPGRADES shop. Progress saves.

Loot ranges from $5 bubble gum up to the $1,000,000 Diamond Cereal.

## Files

| File | Goes in Studio as | What it does |
| --- | --- | --- |
| `src/ReplicatedStorage/Config.luau` | ModuleScript `Config` in ReplicatedStorage | All the numbers: items, prices, timers, guard speed |
| `src/ServerScriptService/Main.server.luau` | Script `Main` in ServerScriptService | Rounds, stealing, escaping, robbing, shop |
| `src/ServerScriptService/MapBuilder.luau` | ModuleScript `MapBuilder` in ServerScriptService | Builds the store, lobby and jail |
| `src/ServerScriptService/GuardAI.luau` | ModuleScript `GuardAI` in ServerScriptService | Guard patrol and chase |
| `src/ServerScriptService/DataService.luau` | ModuleScript `DataService` in ServerScriptService | Saves cash and upgrades |
| `src/StarterPlayer/StarterPlayerScripts/ClientUI.client.luau` | LocalScript `ClientUI` in StarterPlayer > StarterPlayerScripts | Timer, backpack, messages, shop |

## Put it in Roblox Studio with Claude

1. Open Roblox Studio and create a new **Baseplate** place.
2. In PowerShell, `cd roblox`, run `git pull`, then `claude`.
3. Paste this to Claude:

   > Read every file in the src folder and create them in my open Roblox Studio place using the
   > Roblox_Studio tools. Follow the "Files" table in README.md for where each one goes and what type
   > it is. Name each script after its file name without the extensions (for example Main.server.luau
   > becomes a Script named Main). Set each script's Source to the exact file contents.

4. Press **Play** in Studio. The map builds itself when the game starts.

To save progress while testing in Studio, turn on **Game Settings > Security >
Enable Studio Access to API Services**.

## Change the game

Most balancing is in `Config.luau`: round length, item values, upgrade prices, guard
speed and sight range. If you want to decorate the store by hand, play once, copy the
`StealTheStoreMap` model from Workspace, stop, and paste it back in. The game will use
your edited copy instead of building a new one.

## Roblox Studio MCP server

`.mcp.json` registers the Roblox Studio MCP server (`Roblox_Studio`) for Claude Code.
It needs Windows with Roblox Studio installed (`%LOCALAPPDATA%\Roblox\mcp.bat`).
Approve it when Claude Code asks, and check it with `/mcp`.

Rojo users can sync with `default.project.json` instead.
