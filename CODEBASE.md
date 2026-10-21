# Working on Ballistic Together

Start at `src/Scripts/app.lua`. `main.lua` only loads configuration and starts the app.

| Area | Responsibility |
| --- | --- |
| `release.lua` | Version and application protocol identifier; the packager reads the version here |
| `app.lua` | Game-thread scheduling, input bindings, subsystem retries and travel cleanup |
| `lobby/session.lua` | Hosting/joining, session state and public actions |
| `lobby/players.lua` | Native PlayerState discovery, roster and membership changes |
| `lobby/travel.lua` | Host-only range selection, readiness gates, travel and kicking |
| `lobby/countdown.lua` | Countdown state machine, with an injectable clock |
| `lobby/social.lua` | Bounded chat history, unread state, rally markers and snapshot ordering |
| `network/steam.lua` | Steam driver configuration and address validation |
| `network/identity.lua` | Native unique-ID conversion; keep opaque structs inside the hook |
| `network/metadata.lua` | Lua/native handoff and applying accepted peer snapshots |
| `network/protocol.lua` | Length-prefixed application messages; no evaluation or arbitrary asset paths |
| `network/quality.lua` | Monotonic peer-data freshness and application revision counters |
| `network/invites.lua` | Steam invite lifecycle |
| `shared/` | Local storage, preferences, text handling, diagnostics and Unreal helpers |
| `ui/widgets.lua` | Shared native widget construction and game typography |
| `ui/panel.lua` | Lobby/chat/settings views and menu actions |
| `ui/hud.lua` | Non-interactive session overlay and notifications |
| `avatars/` | Cosmetic player/weapon proxies, nameplates, markers and interpolation |
| `avatars/buffer.lua` | Bounded pose history, adaptive interpolation delay, capped extrapolation and teleport reset |
| `native/` | Steam callback/P2P bridge and the Windows clipboard action |

Keep protocol and state-machine changes independent of Unreal when possible. Run `lua tests/core.lua` and `lua tests/netcode.lua` from this folder with Lua 5.4, then `native/build.ps1 -Test` for the bridge checks. Native rendering and travel changes also need a game run.

The auxiliary Steam channel uses reliable messages capped at 24 KiB, with 64 KiB queue backpressure. Full weapon descriptions repeat until the peer acknowledges that revision, then snapshots omit the mesh data. Chat stays queued until acknowledged, up to eight waiting messages. Both acknowledgements are bound to the sender's current nonce. Idle state emits a new heartbeat once per second; only newly accepted revisions renew the three-second readiness lease. Skipped application revisions can result from coalescing and must not be reported as measured packet loss. Queue/relay counters describe this auxiliary channel, not the game's Steam Sockets movement transport.

Lua wrappers do not keep Unreal assets alive. Resolve inactive animations immediately before playback; don't cache unused UObject wrappers across garbage collection. Before travel, clear local visual actors and discard old-world references. Cosmetic failures must not stop session networking.

Preferences and reports live in the installed mod's `Native/` folder. Don't put runtime data, saves, diagnostics or captures in a release. `build.ps1` packages production Lua, the bridge DLL and the release documents.
