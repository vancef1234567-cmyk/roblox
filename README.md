# roblox

## Roblox Studio MCP server

`.mcp.json` registers the Roblox Studio MCP server (`Roblox_Studio`) for Claude Code
and other MCP clients opened in this project.

Requirements (Windows only):

- Roblox Studio installed, with the Studio MCP server set up so that
  `%LOCALAPPDATA%\Roblox\mcp.bat` exists.
- Roblox Studio running with the MCP plugin enabled while you use the tools.

When you open this project in Claude Code, approve the `Roblox_Studio` server when
prompted, then check it with `/mcp`.
