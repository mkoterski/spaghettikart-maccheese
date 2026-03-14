# spaghettikart-maccheese

macOS Intel build, bundle, and packaging scripts for the
[HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart)
Mario Kart 64 PC port — targeting **Intel Macs (x86_64) on macOS Tahoe and later**.

Follows the same conventions as
[perfectdark-macvanta](https://github.com/mkoterski/perfectdark-macvanta) and
[starship-macalfa](https://github.com/mkoterski/starship-macalfa).

> ⚠️ You need a legally obtained Mario Kart 64 N64 ROM to use this.
> The only supported version is **US** (`SHA-1: 579C48E211AE952530FFC8738709F078D5DD215E`).
> The ROM must be in `.z64` format. Convert `.n64` with [this tool](https://hack64.net/tools/swapper.php) if needed.

---

## Requirements

- Intel Mac (x86_64)
- macOS 10.9 or later (tested on Tahoe 26.x)
- Internet connection (first run only)
- A Mario Kart 64 US ROM (see above)

All other dependencies (Homebrew, cmake, ninja, SDL2, etc.) are installed
automatically by the setup script.

---

## Quick Start

```zsh
git clone https://github.com/mkoterski/spaghettikart-maccheese.git
cd spaghettikart-maccheese
chmod +x spmc-*.sh run-spmc-macos.sh

# 1. Install dependencies (run once)
./spmc-initial-setup.sh

# 2. Place your ROM
mkdir -p roms
cp /path/to/your/mk64.z64 roms/mk64.us.z64

# 3. Build (clone → extract assets → compile)
./spmc-build.sh

# 4. Run
./run-spmc-macos.sh
```

---

## Scripts

| Script | Purpose |
|---|---|
| `spmc-initial-setup.sh` | One-time setup: Xcode CLT, Homebrew, packages, ROM validation |
| `spmc-build.sh` | Clone upstream, configure cmake+Ninja, extract assets, compile |
| `spmc-bundle.sh` | Wrap binary as `SpaghettiKart MacCheese.app` |
| `spmc-package.sh` | Create distributable `.dmg` |
| `run-spmc-macos.sh` | Launch game (config backup, backend selection) |
| `spmc-sysinfo.sh` | System snapshot for bug reports |
| `spmc-collect-crash.sh` | Collect macOS crash reports |

---

## Config File Location

The game's config file lives at **`~/spaghettify.cfg.json`** (your home directory),
NOT in the build folder. This is because the game is built with `NON_PORTABLE=OFF`.

The run script automatically patches this file to force OpenGL before each launch.
Backups are stored in `logs/spaghettify.cfg.json.backup-<timestamp>`.

> **Finding the config:** If the game ignores your settings, check for duplicate
> config files:
> ```zsh
> find ~ -maxdepth 3 -name "spaghettify.cfg.json" 2>/dev/null
> ```
> The game reads whichever file libultraship resolves first — typically `~/`.

---

## Graphics Backend

SpaghettiKart supports both **OpenGL** and **Metal** on macOS. The backend enum
values come from `libultraship/include/ship/window/Window.h`:

| Backend | Id | Notes |
|---|---|---|
| DX11 | 0 | Windows only |
| OpenGL | 1 | **Default for Intel Mac** — safest on older Intel GPUs |
| Metal | 2 | Upstream macOS default — crashes on Intel Iris Plus GPUs |

The run script defaults to OpenGL and patches `spaghettify.cfg.json` before
launch. Switch backends with flags:

```zsh
./run-spmc-macos.sh              # OpenGL (default)
./run-spmc-macos.sh --metal      # try Metal
./run-spmc-macos.sh --opengl     # explicitly force OpenGL
```

If the game crashes on startup, try the other backend. You can also edit
`~/spaghettify.cfg.json` directly — change `"Backend"` → `"Id"` value (capital I).

> **Note:** The config file lives at `~/spaghettify.cfg.json` (your home
> directory), not in the build folder. This is because the game is built with
> `NON_PORTABLE=OFF`.

---

## Custom Assets / Mods

Custom assets are packed in `.o2r` or `.zip` files. Place them in the `mods/`
directory inside the build folder (`SpaghettiKart/build-cmake/mods/`) or inside
the app bundle at `Contents/Resources/mods/`.

> **Note:** `.otr` archives are not supported — only `.o2r` and `.zip`.

---

## Config Backup & Restore

The run script backs up `~/spaghettify.cfg.json` before every launch. The
backend patch (OpenGL) persists across runs — no auto-restore on exit.
To manually restore a previous config:

```zsh
./run-spmc-macos.sh --restore-cfg
```

---

## Packaging & Distribution

After building, create a distributable `.dmg`:

```zsh
./spmc-bundle.sh       # wrap binary as .app
./spmc-package.sh      # create styled DMG → dist/
```

The DMG features a drag-to-Applications layout with a tomato-red/black
spaghetti-themed background.

---

## Known Issues (Intel Mac)

| Issue | Backend | Status |
|---|---|---|
| Black screen + SIGFPE crash on track load | Metal (Id 2) | Upstream bug — Metal rendering fails on Intel Iris Plus |
| Crash on track load (menus render fine) | OpenGL (Id 1) | Upstream bug — OpenGL context may hit deprecated codepath on Tahoe |
| `gamecontrollerdb.txt` not found warning | Both | Cosmetic — does not affect gameplay |

Both rendering crashes are upstream issues in HarbourMasters/SpaghettiKart and
cannot be fixed in the wrapper scripts. File bug reports at:
https://github.com/HarbourMasters/SpaghettiKart/issues

Attach the output of `./spmc-collect-crash.sh` (bundles crash reports + system info).

---

## Troubleshooting

```
❌ No ROM       → cp /path/to/mk64.z64 roms/mk64.us.z64
❌ Build fails  → tail -40 logs/build-*.log
❌ Black screen → Metal on Intel — game forces OpenGL via run script
❌ Track crash  → Upstream bug on Intel GPUs — file issue with crash report
❌ dyld error   → brew reinstall sdl2 glew
❌ Gatekeeper   → xattr -cr "/path/to/SpaghettiKart MacCheese.app"
❌ Stale config → ./run-spmc-macos.sh --restore-cfg
❌ Wrong config → find ~ -maxdepth 3 -name "spaghettify.cfg.json"
```

Logs live in `logs/` at the project root (not inside `SpaghettiKart/`).
Config lives at `~/spaghettify.cfg.json` (not in the build folder).

```zsh
ls -lt logs/*.log | head -5       # list latest logs
tail -20 logs/build-*.log         # build issues
file SpaghettiKart/build-cmake/Spaghettify   # should be: Mach-O 64-bit x86_64
```

For bug reports, collect crash data and system info:

```zsh
./spmc-collect-crash.sh           # grabs crash reports + sysinfo
```

Attach the output folder (`logs/crash-<timestamp>/`) when filing issues at
[HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart/issues).

---

## Versioning

Scripts start at `v0.10` and will reach `v1.0` after confirmed end-to-end
working on a clean Intel Mac running macOS Tahoe.

**Current status:** All scripts functional. Build pipeline works end-to-end
(setup → build → extract → compile → launch with OpenGL). Game menus render
correctly with OpenGL backend. Track-load crash is an upstream rendering bug
on Intel Iris Plus GPUs — pending fix from HarbourMasters.

---

## Credits

- Port: [HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart)
- Maintainers: [MegaMech](https://github.com/MegaMech), [Coco](https://github.com/coco875), [Kirito](https://github.com/KiritoDv)
- Powered by: [libultraship](https://github.com/Kenix3/libultraship)
- macOS scripts: [mkoterski](https://github.com/mkoterski)