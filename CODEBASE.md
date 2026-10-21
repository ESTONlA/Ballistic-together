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
| `gameplay/engine.lua` | Host authority, range epochs, peer handshake, shot identities and session scoring |
| `gameplay/hooks.lua` | Loaded-function hooks for actual firing, bullet impacts, valid target hits and magazine release |
| `gameplay/targets.lua` | Target catalog, acknowledged revision batches, primary-mesh state and native cosmetic hit reactions |
| `gameplay/journal.lua` | Bounded event queue with contiguous acknowledgement and duplicate suppression |
| `gameplay/round.lua` | Countdown, play, settling, result/cancel states, rematches and timestamp-aware scoring |
| `gameplay/clock.lua` | Echo-based peer clock offset, bounded timestamp conversion and freshness |
| `gameplay/target_motion.lua` | Bounded primary-mesh pose history with shortest-angle interpolation |
| `gameplay/audio.lua` | Whitelisted built-in shot/manipulation cues, cartridge matching and spatial playback |
| `gameplay/effects.lua` | World-scoped muzzle flashes, tracers, impacts and cleanup |
| `gameplay/recovery.lua` | Host-authorized teleport to arrival positions and range restart |
| `gameplay/wire.lua` | Bounded range payload framing and numeric validation |
| `network/steam.lua` | Steam driver configuration and address validation |
| `network/identity.lua` | Native unique-ID conversion; keep opaque structs inside the hook |
| `network/metadata.lua` | Lua/native handoff and applying accepted peer snapshots |
| `network/protocol.lua` | Length-prefixed application messages; no evaluation or arbitrary asset paths |
| `network/quality.lua` | Monotonic peer-data freshness and application revision counters |
| `network/invites.lua` | Steam invite lifecycle |
| `shared/` | Local storage, preferences, text handling, diagnostics and Unreal helpers |
| `ui/widgets.lua` | Shared native widget construction and game typography |
| `ui/panel.lua` | Lobby/range/chat/settings views and menu actions |
| `ui/hud.lua` | Non-interactive session overlay and notifications |
| `avatars/` | Cosmetic player/weapon proxies, nameplates, markers and interpolation |
| `avatars/buffer.lua` | Bounded pose history, adaptive interpolation delay, capped extrapolation and teleport reset |
| `native/` | Steam callback/P2P bridge and the Windows clipboard action |

Keep protocol and state-machine changes independent of Unreal when possible. Run `lua tests/core.lua`, `lua tests/netcode.lua`, `lua tests/gameplay.lua` and `lua tests/gameplay-session.lua` from this folder with Lua 5.4, then `native/build.ps1 -Test` for bridge changes. Native rendering and travel changes also need a game run.

The auxiliary Steam channel uses reliable messages capped at 24 KiB, with 64 KiB queue backpressure. Full weapon descriptions repeat until the peer acknowledges that revision, then snapshots omit the mesh data. Chat stays queued until acknowledged, up to eight waiting messages. Both acknowledgements are bound to the sender's current nonce. Idle state emits a new heartbeat once per second; only newly accepted revisions renew the three-second readiness lease. Skipped application revisions can result from coalescing and must not be reported as measured packet loss. Queue/relay counters describe this auxiliary channel, not the game's Steam Sockets movement transport.

Lua wrappers do not keep Unreal assets alive. Resolve inactive animations immediately before playback; don't cache unused UObject wrappers across garbage collection. Before travel, clear local visual actors and discard old-world references. Cosmetic failures must not stop session networking.

Range events share the reliable auxiliary channel. Full gear is capped at 13,000 bytes, range data at 7,000 and the aggregate packet at 23,000. Range events persist until acknowledged within the current host epoch; exact target-batch acknowledgements advance only the revisions contained in that batch. Restart/travel retires old epochs. The host owns round state, turn eligibility and points; client hit requests reference known shots and targets and must land near the target. Do not replay native reward functions on the other player. Session points use the captured base HitValue, rather than sampling the native calculator after it may have decayed on the host. Session points are separate from saved currency. Target snapshots cover the actor and primary physical mesh, not the full skeletal ragdoll. Never assume generated target actor names match between PCs.

Unwrap TArray component entries immediately with `shared.runtime.object`: RemoteUnrealParam may forward `IsValid` while its parameter storage is still temporary. Retain the resulting UObject, not the parameter wrapper. Blueprint `/Game/` RegisterHook callbacks run after the function; correlate target OnHit with its enclosing Hit callback before assigning a projectile ID.

Preferences and reports live in the installed mod's `Native/` folder. Don't put runtime data, saves, diagnostics or captures in a release. `build.ps1` packages production Lua, the bridge DLL and the release documents.

The updated 0.3.0 build uses BT030R2 so older 0.3.0 installs are rejected. Keep the public version at 0.3.0-beta as requested. The menu and reports identify build 2. The 7,000-byte gameplay field now budgets 2,000 bytes for events, 450 for round state, 2,200 for target baselines, 200 for pose/clock/ready fields and 1,800 for compact motion, plus framing and identifiers.

Range sampling/transport runs at a nominal 100ms interval. Weapon collection and roster discovery remain at 250ms. Sample at most 32 catalog entries plus 32 active entries per tick. Prioritize unacknowledged baseline records; compact motion carries pose revisions separately and rotates through active targets. Guest rendering interpolates the actor and primary mesh with a 120ms buffer. Position samples are copied into Lua scalars immediately; don't retain returned struct wrappers across subsequent native getters.

Challenges require two fresh, synchronized, ready players. Start with a 3-second countdown. Cancel active challenges if the peer leaves, becomes unready, or loses range or clock freshness. Preserve scores for display; rematch starts a new countdown. Clock echo samples estimate the remote offset; accept converted event timestamps only within the bounded 1.25s age / 100ms future tolerance. Timed rounds settle for 1 second after the deadline, accepting only hits timestamped before it. Races settle for 1 second and compare threshold-crossing timestamps; crossings less than 25ms apart draw. This is bounded deadline compensation, not physics rewind or anti-cheat.

Prefer LoopInGameThreadWithDelay for the app update loop when exposed by the loader; older builds retain the LoopAsync/ExecuteInGameThread fallback. The installed experimental loader exposes the newer API. Avoid multiple overlapping legacy action queues in the runtime harness; UE4SS issue #1180 documents reentry/stack corruption in that path: https://github.com/UE4SS-RE/RE-UE4SS/issues/1180 . Native arrays returned through output parameters must be completely unwrapped before making further reflected calls. Validate pose scalars before serialization and isolate transient per-target read failures.
