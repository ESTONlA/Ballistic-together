# Ballistic Together — lobby prototype

Author: RealEstonia. Version 0.1.2 adds a textured human character and overhead player names to the two-player Steam bunker lobby. The user confirmed that connections work in their two-PC setup on 0.1.1. The new character and nameplates passed local runtime checks; their appearance in a real two-PC session still needs user testing.

Both players need the same Ballistic.exe Demo build, UE4SS, this mod, and separate logged-in Steam accounts/PCs. Extract the ZIP into the main game folder on both PCs and fully restart. Start both games through Steam with Steam Overlay enabled. Open the panel with **F8**. The host clicks **Host lobby**, waits for `hosting`, then opens F8 and clicks **Invite friends (Steam)**. Choose a friend in Steam's invite picker; the friend accepts the invite with their game already running. The mod reads the accepted invite and joins the host automatically. No SteamID typing is needed for that flow. **Join by ID (fallback)** remains available. **Ctrl+F10** writes world, driver, player count and invite status to UE4SS.log. This is direct Steam transport with rich-presence invites, not public lobby discovery or an IP/LAN fallback. Invites with the recipient's game closed are not implemented.

Steam invites use a small bundled x64 native bridge, `Native/BallisticSteamInvites.dll`, loaded by Lua. It uses the game's already-loaded Steam API, publishes join information only while a host has a free slot, opens Steam's own invite picker only when requested, and receives accepted-invite callbacks. It does not initialize/shut down Steam, replace steam_api64.dll, or pump/consume the game's callback queue. The game must already have a working Steam connection. Join information is cleared on leaving, losing the host connection, or filling the lobby. A validated connection handoff and readable status are stored locally beside the bridge; neither is a game save. Only `steam.<17-digit individual SteamID>:7777` addresses are accepted. The native bridge stays loaded until the game exits so registered callbacks never point into an unloaded DLL.

The panel should report `hosting` or `connected` with two players only after a Steam net driver exists in the bunker. A textured copy of the game's bunker-keeper character follows each remote replicated pawn, with its replicated player name displayed above its head and facing your camera. Names fall back to Player when empty. The model currently uses a fixed pose; walking, aiming and weapon animations are not implemented. Character height, mesh-facing offset and nameplate size/height can be adjusted in config.lua. If both PCs do not show the other player moving, the first milestone is not complete. Weapon firing, shared targets, workshop edits, inventory, saves and score synchronization are out of scope. The mod does not copy or merge player saves.

The mod changes the in-memory GameNetDriver definition only when hosting/joining, uses the compiled SteamSocketsNetDriver, and restores the original definition when Leave is chosen. It does not overwrite Engine.ini or substitute another Steam App ID. The preview uses port 7777. Keep the game/Steam running normally; do not assume an agent-launched hidden process has the same Steam login context.

## Code layout

`src/` is the only source of release code. `build.ps1 -Install` copies it to the installed mod and creates the ZIP. Edit source here, not the installed copy. Restart the game after installing changes.

| Location | Responsibility |
| --- | --- |
| `src/Scripts/main.lua` | Startup, keybinds and bounded game-thread update loop |
| `src/Scripts/config.lua` | Map, Steam host ID and fixed two-player preview settings |
| `src/Scripts/shared/runtime.lua` | UObject checks and game API access |
| `src/Scripts/network/steam.lua` | Steam address validation and runtime driver setup/restore |
| `src/Scripts/network/invites.lua` | Native bridge loading, accepted-invite routing and host availability |
| `native/invites.cpp` | Steam rich presence, overlay invite picker and accepted-invite callback |
| `native/build.ps1` | MSVC x64 bridge build; `-Test` runs callback handoff checks |
| `src/Native/BallisticSteamInvites.dll` | Generated bridge included in the installed mod |
| `src/Scripts/lobby/session.lua` | Host/join/leave state, errors and player roster |
| `src/Scripts/avatars/proxies.lua` | Textured skeletal character creation, following and cleanup |
| `src/Scripts/avatars/nameplates.lua` | Sanitized overhead player names and camera-facing text |
| `src/Scripts/ui/panel.lua` | In-game host/join panel |
| `dev/` | Private diagnostics and local test evidence; never packaged |
| `dist/` | Generated prototype ZIP |

## Verification status

Confirmed in the installed game's runtime: the Steam Sockets driver class is compiled and loaded; the original GameNetDriver references the legacy Steam driver; the bunker is `/Game/Maps/Bunker/Bunker_Main`; its BunkerPlayerPawn is an Unreal Character with actor and movement replication enabled. Those are useful prerequisites, not proof that the bunker controller supports multiple clients correctly.

Early agent-launched listen attempts returned to BallisticMain with no active driver. These attempts do not establish a working Steam host. Further diagnostic results are recorded in MODDING_MEMORY.md and dev/. The user subsequently confirmed that connections work on their two-PC setup. That report does not establish every invite/reconnect path, shared gameplay or the new model/nameplate appearance.

The same agent context can open the bunker without networking. A separate preflight against the bundled Steam API returns `Could not determine Steam client install directory`; launching via the running Steam client's command line from this context did not start the game either. The native invite bridge loads in the installed UE4SS runtime and reports `Steam is not logged in for this game process. Launch through Steam.` Its native address-validation/callback-handoff tests pass. Runtime tests pass for accepted-invite Lua routing, duplicate/malformed/busy rejection, the five-button UI, driver configuration and marker creation/follow/cleanup. The user has since confirmed that connections work. Real invite delivery and every reconnect/replication case have not been independently verified. This is not evidence that Steam hosting will succeed from a normal desktop, and it does not replace the two-account test.

References: [Epic Steam Sockets](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-steam-sockets-in-unreal-engine), [Valve Steam Friends API](https://partner.steamgames.com/doc/api/ISteamFriends#ActivateGameOverlayInviteDialogConnectString). Version 0.1.2 uses Steam transport and rich-presence invitations without implementing Valve matchmaking lobbies. To rebuild from source, run `native/build.ps1 -Test` with MSVC x64 build tools installed, then `build.ps1 -Install`.

0.1.2 local runtime checks passed: actual Keeper mesh and animation assets load, human-height mesh scale, capsule-based feet alignment, overhead player text, camera-facing rotation, position/name updates, name sanitizing, disconnect cleanup and recreation. A delayed in-bunker screenshot confirmed the textured human model and visible overhead name. The fixed pose is sampled from the existing thumbs-up animation at its initial frame; no NPC Blueprint or interaction logic is spawned.
"# Ballistic-together" 
