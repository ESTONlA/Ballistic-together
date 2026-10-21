# Contributing to Ballistic Together

Bug fixes, improvements and reproducible bug reports are welcome.

## Submit a change

1. Fork the [official repository](https://github.com/ESTONlA/Ballistic-together) on GitHub.
2. Create a branch for your change.
3. Edit the Lua source in `src/Scripts/` or the native bridge in `native/`.
4. Build and check the change using the [README instructions](README.md#building-from-source).
5. Open a pull request describing what changed, why, how you tested it, and any remaining limitations. For networking changes, say whether you tested on two PCs/accounts.

Keep changes focused. Never include game assets, saves, private logs, generated DLLs or release ZIPs in your pull request. Screenshots are useful for visual changes; remove personal information before sharing them. Preserve existing credits and the license.

## Report a bug

Include the game/mod/UE4SS versions, steps to reproduce, whether you were hosting or joining, and what happened on each PC. Press **Ctrl + F10** in-game to write multiplayer diagnostics to `UE4SS.log`, then include the relevant lines.

## Forks and distribution

The [license](LICENSE) permits personal use, private modifications, GitHub source forks and contributions. It restricts redistribution: do not publish separate mod downloads, binary releases, mirrors, modpacks or rebranded versions without prior written permission from **RealEstonia**. Link people to the official downloads instead.

By intentionally submitting a contribution for inclusion, you accept the contribution terms in section 5 of the license. You keep copyright in your work and allow it to be used and distributed as part of the official project under that license.
