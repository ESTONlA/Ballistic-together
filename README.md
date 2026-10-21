<div align="center">

# Ballistic Together

**Bring a friend into the bunker.**

A two-player Steam multiplayer mod for **Ballistic.exe Demo**, by **RealEstonia**.

[Installation](#installation) · [Playing together](#playing-together) · [Troubleshooting](#troubleshooting) · [Building from source](#building-from-source)

</div>

---

## What it does

Host a bunker session, invite a friend through Steam, and see each other in the same space. Remote players use the game's textured bunker-keeper character, with their player name above their head.

- **Steam hosting and joining** through an in-game panel.
- **Steam invites** with an ID-based fallback.
- **Visible remote characters** that follow player position and rotation.
- **Overhead names** that turn toward your camera.
- **Disconnect cleanup** for player models and names.

**Current version: 0.1.2 · Early development · 2 players**

Two-PC connections have been confirmed by the project owner. The new character model and nameplates passed local in-game checks; their appearance in a two-PC session still needs confirmation. Characters currently use a fixed pose. Walking animations, visible held weapons, shared range travel, synchronized shots, targets and scores are not implemented.

## Before you install

Both players need:

| Requirement | Details |
| --- | --- |
| Game | The same version of **Ballistic.exe Demo** on Steam |
| Accounts | Two PCs with separate signed-in Steam accounts |
| Mod loader | A UE4SS build compatible with the game's Unreal Engine 5.7 build |
| Mod | The same Ballistic Together version on both PCs |
| Steam Overlay | Enabled for Steam invitations |

The local test setup uses **UE4SS 3.0.1 Beta** from the experimental builds. The [official experimental release page](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) provides the loader downloads and installation-layout notes. New experimental builds can change; keep a loader that already works with your game.

You do **not** need Unreal Editor or a `.pak` file to install the mod. The packaged download includes the native Steam invite bridge.

## Installation

Do these steps on **both PCs**, with the game fully closed.

### 1. Find the game folder

In your Steam Library, right-click **Ballistic.exe Demo** and choose **Manage → Browse local files**.

This opens the main game folder. It contains `Ballistic.exe`, a `Ballistic` folder and an `Engine` folder.

### 2. Install UE4SS

Skip this step if UE4SS is already installed and working.

1. Open the [UE4SS experimental downloads](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest).
2. Download the regular Windows x64 loader archive, rather than GitHub's **Source code** archives.
3. Extract the loader into:

   ```text
   <game folder>\Ballistic\Binaries\Win64\
   ```

4. Check that `dwmapi.dll` sits beside `Ballistic-Win64-Shipping.exe`, and that `UE4SS.dll` is inside the `ue4ss` subfolder:

   ```text
   Ballistic.exe Demo/
   ├── Ballistic.exe
   └── Ballistic/
       └── Binaries/
           └── Win64/
               ├── Ballistic-Win64-Shipping.exe
               ├── dwmapi.dll
               └── ue4ss/
                   ├── UE4SS.dll
                   └── Mods/
   ```

The loader goes beside the **Shipping executable**, not beside the top-level `Ballistic.exe` launcher. Preserve any existing mods when merging folders.

### 3. Install Ballistic Together

Use the packaged **`BallisticTogether-0.1.2-player-models.zip`**. Check the repository's [Releases](https://github.com/ESTONlA/Ballistic-together/releases) for packaged downloads. GitHub's **Code → Download ZIP** downloads the source project; it is not a ready-to-install mod and needs the build steps below.

1. Extract the mod ZIP into the **main game folder** from step 1.
2. Merge the included `Ballistic` folder with the existing one.
3. Check the installed mod has this layout:

   ```text
   Ballistic/Binaries/Win64/ue4ss/Mods/BallisticTogether/
   ├── enabled.txt
   ├── Native/
   │   └── BallisticSteamInvites.dll
   └── Scripts/
       ├── main.lua
       ├── config.lua
       ├── avatars/
       ├── lobby/
       ├── network/
       ├── shared/
       └── ui/
   ```

`enabled.txt` is intentionally empty: its presence enables the mod. Keep the subfolders intact. There is no need to add an entry to `mods.json` for this installation.

### 4. Enable Steam Overlay and launch

In the game's Steam **Properties → General**, enable Steam Overlay. Launch the game from Steam, then press **F8** to open Ballistic Together.

If F8 does nothing, start with the troubleshooting table below.

## Playing together

### Host

1. Launch the game through Steam and press **F8**.
2. Click **Host lobby**.
3. Wait for the bunker to load and the panel status to show **`hosting`**.
4. Open **F8** again and click **Invite friends (Steam)**.
5. Select your friend in Steam's invite picker.

The invite button is available when you are hosting, a player slot is free, and the Steam invite bridge is ready.

### Join a friend

1. Have the mod installed and your game **already running through Steam**.
2. Accept the host's invitation in Steam.
3. The mod connects automatically. Reopen **F8** to check for **`connected`** and **`2/2 players`**.

Invites do not currently support launching a closed game into the session. If you are already in another lobby, choose **Leave lobby** before accepting a new invitation.

### Join by ID instead

The host can share their **SteamID64**: a 17-digit number starting with `7656119`. This is different from their display name, friend code or custom profile URL.

The joining player opens **F8**, enters that number in the host field, and clicks **Join by ID (fallback)**. The host must already have an open session.

### Leave a session

Open **F8 → Leave lobby**. This returns you to the main menu. Closing the panel alone keeps you connected.

## Controls

| Control | Action |
| --- | --- |
| **F8** | Open or close the multiplayer panel |
| **Ctrl + F10** | Write connection and invite diagnostics to `UE4SS.log` |
| **Shift + Tab** | Open Steam Overlay with its default shortcut |

## Troubleshooting

| Problem | What to check |
| --- | --- |
| **F8 does nothing** | Check the folder layout above, confirm `enabled.txt` exists, and fully restart the game. Look for `[BallisticTogether]` in `UE4SS.log`. |
| **Invite friends is disabled** | Wait for `hosting`, check that the lobby is not full, and read the panel's Steam status. Both Steam and the game must be running normally. |
| **The invite picker does not open** | Enable Steam Overlay, restart the game through Steam, and check whether Shift + Tab opens the overlay. |
| **“Steam is not logged in for this game process”** | Close the game, sign in to Steam, and launch from your Steam Library. |
| **An accepted invite does nothing** | Start the recipient's game before accepting. Leave any existing lobby and ask the host for a fresh invite. Try the ID fallback if needed. |
| **Connecting times out or status says `failed`** | Confirm matching game/mod versions and an active host. Use Leave lobby before retrying, then collect the log if it persists. |
| **No other player model or name appears** | Check both panels show two players, confirm both installations include the `avatars` folder, and fully restart after updating. Report whether the problem affects one PC or both. |
| **Characters slide without walking** | The current model uses a fixed pose. Walking animations are not included yet. |
| **The invite DLL is missing** | Extract the complete packaged mod, including `Native/BallisticSteamInvites.dll`. A source-only download needs to be built first. |

The log is here:

```text
<game folder>\Ballistic\Binaries\Win64\ue4ss\UE4SS.log
```

For a bug report, reproduce the issue, press **Ctrl + F10**, then attach the relevant `[BallisticTogether]` log lines. Include the mod and UE4SS versions, whether you were hosting or joining, what each PC's panel showed, and a screenshot if the issue is visual. You can [open an issue on GitHub](https://github.com/ESTONlA/Ballistic-together/issues).

## Updating or uninstalling

**Update:** close the game on both PCs, extract the newer packaged ZIP into each main game folder, and replace the old mod files. Both players should restart with the same version. Keep a copy of `Scripts/config.lua` if you customized it; check for new settings before restoring your changes.

**Disable:** close the game and rename the mod's `enabled.txt` to `enabled.disabled.txt`.

**Uninstall:** close the game and remove only `Ballistic/Binaries/Win64/ue4ss/Mods/BallisticTogether/`. Leave UE4SS installed if other mods use it.

Ballistic Together does not merge or synchronize player saves.

## Configuration

Edit `Ballistic/Binaries/Win64/ue4ss/Mods/BallisticTogether/Scripts/config.lua` while the game is closed.

| Setting | Default | Purpose |
| --- | --- | --- |
| `HostSteamId` | `''` | Prefill the manual host ID field |
| `AvatarHeight` | `180` | Character height in centimetres |
| `AvatarYawOffset` | `-90` | Mesh rotation offset in degrees |
| `NameplateSize` | `14` | Name text size in world units |
| `NameplateHeight` | `24` | Name offset above the character |
| `AvatarRefreshMs` | `100` | Character and nameplate update interval |

Keep `LobbyMap`, `MaxPlayers = 2` and `Port = 7777` at their defaults for this version.

## Building from source

<details>
<summary><strong>Developer setup and project layout</strong></summary>

You need Windows, PowerShell, and Visual Studio 2022 or Build Tools with the **Desktop development with C++** workload and Windows SDK.

From the project directory:

```powershell
# Compile the native Steam invite bridge and run its local checks.
.\native\build.ps1 -Test

# Package the mod into dist/.
.\build.ps1
```

When this project is located at `<game folder>\Modding\BallisticTogether`, you can also deploy it directly:

```powershell
.\build.ps1 -Install
```

`-Install` resolves the game folder two directories above the project. If your checkout is elsewhere, use the generated ZIP and follow the installation steps instead. Fully restart the game after deployment.

| Path | Contents |
| --- | --- |
| `src/Scripts/` | Lua source for the panel, sessions, Steam transport and avatars |
| `native/` | C++ source and build script for Steam invites |
| `src/Native/` | Generated native DLL |
| `build.ps1` | Release packaging and local installation |
| `PATCHNOTES.txt` | Changes, one entry per line |
| `dev/` | Private diagnostics, captures and test artifacts |
| `dist/` | Generated release ZIPs |

Generated binaries, release packages and private test data are ignored by Git. The build output contains the mod files, README and patch notes; UE4SS and game assets are not bundled.

The Lua code selects the game's compiled Steam Sockets driver in memory. The native bridge uses the already-loaded Steam API for rich presence, the overlay invite picker and accepted-invite callbacks. It does not replace the game's Steam DLL or run a separate callback pump. Transport settings are restored when leaving the session.

</details>

## Contributing and license

Want to help? Fork the repository, make your changes and open a pull request. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and what to include in a bug report.

Ballistic Together uses a custom [source-available license](LICENSE). Personal use, private modifications, GitHub source forks and contributions are permitted. Separate mod uploads, mirrors, binary releases, modpacks and rebranded distributions require prior written permission from **RealEstonia**. Share a link to the official project instead of reuploading it.

GitHub source forks are an explicit exception to the redistribution restriction; public repositories also carry platform rights under [GitHub's licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository). This is not an open-source license.

---

Made by **RealEstonia**. Built with [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) and the game's existing assets. Unofficial community mod, not affiliated with the game's developers or Valve.
