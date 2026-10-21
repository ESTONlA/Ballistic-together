# Ballistic Together

Play **Ballistic.exe Demo** with a friend over Steam.

**0.2.6-beta · 2 players · By RealEstonia**

Host a bunker session, send a Steam invite and head to the range together. See your friend's character, name and equipped gun, with walking animations and smoother movement.

[Install](#installation) · [Play together](#playing-together) · [Troubleshooting](#troubleshooting) · [Build from source](#building-from-source)

## What's included

- Steam hosting, invites and joining by Steam ID.
- A player list with names, ping, ready/away status and a three-second range countdown.
- Session chat, quick messages and unread counts.
- Shared rally markers with distance labels.
- A session HUD, saved display settings and reconnect to your last host.
- Host controls to choose a range, travel together, return to the bunker or remove a guest.
- Animated player models with overhead names.
- Visible equipped guns and attachments, up to 32 static-mesh parts.

Gun models are visual copies. Firing, ammo, damage, targets, scores and saves aren't synchronized.

## Installation

Install the same version on **both PCs** and close the game before updating files. You'll each need your own Steam account, the same game version and a working UE4SS installation.

### 1. Find your game folder

In Steam, right-click **Ballistic.exe Demo → Manage → Browse local files**.

### 2. Install UE4SS

Skip this if your other UE4SS mods already work.

Download the Windows x64 loader from the [official experimental releases](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest). Extract it into:

```text
<game folder>\Ballistic\Binaries\Win64\
```

Your files should look like this:

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

Put the loader beside **Ballistic-Win64-Shipping.exe**. Keep your existing mods when merging folders.

### 3. Install the mod

Get **BallisticTogether-0.2.6-beta.zip** from [Releases](https://github.com/ESTONlA/Ballistic-together/releases).

1. Extract it into your **main game folder**, where `Ballistic.exe` is.
2. Merge the included `Ballistic` folder and replace old mod files if asked.
3. Check that you have:

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

The empty `enabled.txt` enables the mod. Keep all the subfolders and the DLL. You don't need to edit `mods.json` or install a `.pak`.

**Code → Download ZIP** gives you the source code. Use a release ZIP for installation, or follow the build instructions below.

### 4. Launch through Steam

Enable **Steam Overlay** in the game's Steam properties, launch the game and press **F8**.

## Playing together

### Host

1. Press **F8 → Host session**.
2. Wait for the bunker to load.
3. Open **F8 → Invite friend** and pick your friend in Steam.

### Join

Start your game through Steam, then accept the invite. Open **F8** after connecting to see both players.

Keep the game running before accepting an invite. If you're already in a session, leave it first.

### Join by Steam ID

Ask the host for their **SteamID64**, the 17-digit account ID. Open **F8**, paste it into the **Host SteamID64** field and click **Join session**. The host needs to have a session open already.

### Head to a range

1. Prepare and save your weapon and ammo using the normal workshop.
2. Both players click **Ready** in the F8 menu, or press **F9**. Changing the destination means readying up again.
3. The host uses **Change range** to pick a destination, then clicks **Enter range**. A three-second countdown starts; use **Cancel countdown** to stop it.
4. Use **Back to bunker** to return together.

You can visit **Azure Swimming Pool** and **Training sequence** when the host has unlocked them. Use the F8 controls for group travel; the original single-player menus still work separately.

The host can click **Remove guest** to disconnect the other player. To leave, choose **F8 → Leave session**. Closing the menu keeps you connected.

## Chat, markers and settings

Open **F8 → Chat**, or press **Shift + F8**, to message your friend. Use the quick-message buttons when you don't feel like typing. Chat stays with the current session; **Clear local chat** only clears your view.

Press **F7** to mark where you're standing. Your friend sees a rally point and its distance for 25 seconds. **Shift + F7** clears it. Nearby markers stay hidden so the label doesn't cover your view.

Choose **Away** in the lobby when you're taking a break. It clears your ready status; clicking **Ready** brings you back.

In **Settings**, toggle player names, friend guns, rally markers, the session HUD, distance labels or incoming-chat mute. Your choices are saved between launches. You can also copy your Steam ID or save a connection report there.

To rejoin someone, use **Reconnect to last host** on the connection screen. The host needs to have a session open.

## Controls

| Key | Action |
| --- | --- |
| **F8** | Open or close the multiplayer menu |
| **Shift + F8** | Open session chat |
| **F9** | Toggle ready status |
| **F7** | Place a rally marker at your position |
| **Shift + F7** | Clear your rally marker |
| **Ctrl + F10** | Log connection details and save a report |
| **Shift + Tab** | Open Steam Overlay with its default shortcut |

## Troubleshooting

| Problem | Try this |
| --- | --- |
| F8 does nothing | Check the folder layout and `enabled.txt`, then fully restart. Look for `[BallisticTogether]` in `UE4SS.log`. |
| Invite friend is disabled | Wait for the bunker to load and check there's a free player slot. Use Ctrl + F10 to check Steam status. |
| Steam's invite picker doesn't open | Enable Steam Overlay and restart through Steam. Check that Shift + Tab opens it. |
| Accepting an invite does nothing | Start your game before accepting, leave any existing session and ask for a fresh invite. You can also join by Steam ID. |
| Connection times out | Check that the host is still in their session and you're both using the same game and mod versions. |
| Ready status doesn't match | Update the complete mod on both PCs, including the native DLL, and restart. |
| Enter range is disabled | Everyone needs to be ready, and the host needs to have that range unlocked. |
| Your friend's model or name is missing | Check both players appear in the menu and both installations have the `avatars` folder. Restart after updating. |
| Characters don't animate | Use `AvatarModel = 'Knight'`. The optional Keeper model has a fixed pose. |
| Your friend's gun is missing | They need to have a weapon equipped. Check that both PCs have the same mod version and native DLL. |

Find the log at:

```text
<game folder>\Ballistic\Binaries\Win64\ue4ss\UE4SS.log
```

Still stuck? Press **Ctrl + F10** to save `Native/diagnostics.txt` inside the mod folder, then [open an issue](https://github.com/ESTONlA/Ballistic-together/issues) with the relevant log lines. Include your mod and UE4SS versions, who was hosting, what happened on each PC and a screenshot if it helps.

## Updating or removing the mod

**Update:** close the game on both PCs, extract the new release and replace the old files. Keep a copy of `Scripts/config.lua` if you've changed it.

**Disable:** rename `enabled.txt` to `enabled.disabled.txt` while the game is closed.

**Uninstall:** remove `Ballistic/Binaries/Win64/ue4ss/Mods/BallisticTogether/`. Keep UE4SS if you use it for other mods.

## Configuration

Edit `Scripts/config.lua` inside the installed mod folder with the game closed.

| Setting | Default | What it changes |
| --- | --- | --- |
| `HostSteamId` | `''` | Prefills the host ID field |
| `AvatarModel` | `'Knight'` | Use `'Keeper'` for the older fixed-pose model |
| `SmoothingSpeed` | `14` | How quickly remote movement catches up |
| `InterpolationDelayMs` | `60` | Base movement buffer delay in milliseconds |
| `MaxInterpolationDelayMs` | `140` | Maximum delay while smoothing uneven updates |
| `MaxExtrapolationMs` | `80` | Maximum prediction time during a brief update gap |
| `TeleportSnapDistance` | `500` | Snap distance in centimetres |
| `AvatarHeight` | `180` | Character height in centimetres |
| `AvatarYawOffset` | `-90` | Character rotation offset |
| `NameplateSize` | `14` | Name text size |
| `NameplateHeight` | `24` | Name height above the character |
| `AvatarRefreshMs` | `16` | Visual update interval in milliseconds |

Leave `LobbyMap`, `MaxPlayers = 2` and `Port = 7777` at their defaults.

## Building from source

You'll need Windows, PowerShell and Visual Studio 2022 or Build Tools with **Desktop development with C++** and the Windows SDK.

Run these from the project folder:

```powershell
.\native\build.ps1 -Test
.\build.ps1
```

The ZIP goes into `dist/`. If your checkout is at `<game folder>\Modding\BallisticTogether`, you can install it directly:

```powershell
.\build.ps1 -Install
```

Restart the game after installing.

| Folder | Contents |
| --- | --- |
| `src/Scripts/` | Lua code for the menu, sessions, Steam transport and player visuals |
| `native/` | C++ source for Steam invites and lobby data |
| `src/Native/` | Generated DLL |
| `dev/` | Local diagnostics and captures, ignored by Git |
| `dist/` | Release ZIPs, ignored by Git |

See [CODEBASE.md](CODEBASE.md) for the module layout and [PATCHNOTES.txt](PATCHNOTES.txt) for release changes.

## Contributing

Fork the repo, make your changes and open a pull request. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow.

You can use the mod, make private changes and fork the source on GitHub. Ask **RealEstonia** before uploading separate builds, mirrors, modpacks or rebranded versions. Share the official project link instead of reuploading it. See [LICENSE](LICENSE) for the full terms.

---

Made by **RealEstonia**, using [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS). Unofficial community mod.
