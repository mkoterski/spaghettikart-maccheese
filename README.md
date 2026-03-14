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
- A legally obtained Mario Kart 64 US ROM (see above)

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

## Graphics Backend

SpaghettiKart supports both **OpenGL** and **Metal** on macOS.

| Backend | id | Notes |
|---|---|---|
| OpenGL | 3 | **Default for Intel Mac** — safest on older Intel GPUs |
| Metal | 4 | Upstream macOS default — may have issues on some Intel GPUs |

The run script defaults to OpenGL and patches `spaghettify.cfg.json` before
launch. Switch backends with flags:

```zsh
./run-spmc-macos.sh              # OpenGL (default)
./run-spmc-macos.sh --metal      # try Metal
./run-spmc-macos.sh --opengl     # explicitly force OpenGL
```

If the game crashes on startup, try the other backend. You can also edit
`spaghettify.cfg.json` directly — change the `"Backend"` → `"id"` value.

---

## Custom Assets / Mods

Custom assets are packed in `.o2r` or `.zip` files. Place them in the `mods/`
directory inside the build folder (`SpaghettiKart/build-cmake/mods/`) or inside
the app bundle at `Contents/Resources/mods/`.

> **Note:** `.otr` archives are not supported — only `.o2r` and `.zip`.

---

## Config Backup & Restore

The run script backs up `spaghettify.cfg.json` before every launch and
restores it on exit (clean, Ctrl-C, or crash). To manually restore:

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

## Troubleshooting

```
❌ No ROM       → cp /path/to/mk64.z64 roms/mk64.us.z64
❌ Build fails  → tail -40 logs/build-*.log
❌ Crash on run → ./run-spmc-macos.sh --metal   (or --opengl)
❌ dyld error   → brew reinstall sdl2 glew
❌ Gatekeeper   → xattr -cr "/path/to/SpaghettiKart MacCheese.app"
❌ Stale config → ./run-spmc-macos.sh --restore-cfg
```

Logs live in `logs/` at the project root (not inside `SpaghettiKart/`):

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

---

## Credits

- Port: [HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart)
- Maintainers: [MegaMech](https://github.com/MegaMech), [Coco](https://github.com/coco875), [Kirito](https://github.com/KiritoDv)
- Powered by: [libultraship](https://github.com/Kenix3/libultraship)
- macOS scripts: [mkoterski](https://github.com/mkoterski)