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
- macOS 10.9 or later (tested on Tahoe 26.3.1, MacBookPro16,2)
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

| Script | Version | Purpose |
|---|---|---|
| `spmc-initial-setup.sh` | v0.10 | One-time setup: Xcode CLT, Homebrew, 16 packages, ROM validation |
| `spmc-build.sh` | v0.12 | Clone upstream, configure cmake+Ninja, extract assets, compile |
| `spmc-bundle.sh` | v0.10 | Wrap binary as `SpaghettiKart MacCheese.app` |
| `spmc-package.sh` | v0.10 | Create distributable `.dmg` |
| `run-spmc-macos.sh` | v0.15 | Launch game (OpenGL backend patch, config backup) |
| `spmc-sysinfo.sh` | v0.10 | System snapshot for bug reports |
| `spmc-collect-crash.sh` | v0.10 | Collect macOS crash reports |

---

## Config File Location

> **This is the single most important thing to know when debugging SpaghettiKart on macOS.**

The game's config file lives at **`~/spaghettify.cfg.json`** (your home directory),
**NOT** in the build folder. This is because the game is built with `NON_PORTABLE=OFF`.
There may be stale copies at other locations that the game ignores:

```zsh
# Find ALL config files — the game reads from ~/ on macOS
find ~ -maxdepth 3 -name "spaghettify.cfg.json" 2>/dev/null
```

The run script automatically patches `~/spaghettify.cfg.json` to force OpenGL
before each launch. Backups are stored in `logs/spaghettify.cfg.json.backup-<timestamp>`.

---

## Graphics Backend

SpaghettiKart supports both **OpenGL** and **Metal** on macOS. The backend enum
values come from `libultraship/include/ship/window/Window.h`:

```cpp
enum class WindowBackend { FAST3D_DXGI_DX11, FAST3D_SDL_OPENGL, FAST3D_SDL_METAL, WINDOW_BACKEND_COUNT };
```

| Backend | Id | Config key | Notes |
|---|---|---|---|
| DX11 | 0 | `"Id": 0` | Windows only |
| **OpenGL** | **1** | **`"Id": 1`** | **Default for Intel Mac** — safest on Intel GPUs |
| Metal | 2 | `"Id": 2` | Upstream macOS default — crashes on Intel Iris Plus |

> **Important:** The config JSON key is `"Id"` (capital I), not `"id"`.
> The game ignores lowercase `"id"`. The config path is `Window.Backend.Id` in
> the dot-notation used by libultraship's config system internally.

The run script defaults to OpenGL and patches `~/spaghettify.cfg.json` before
launch. Switch backends with flags:

```zsh
./run-spmc-macos.sh              # OpenGL (default)
./run-spmc-macos.sh --metal      # try Metal
./run-spmc-macos.sh --opengl     # explicitly force OpenGL
```

To edit manually: open `~/spaghettify.cfg.json` and change `"Window"` → `"Backend"` → `"Id"` value.

---

## ROM Handling

The ROM goes in `roms/mk64.us.z64` in the wrapper repo root. The build script
copies it to `SpaghettiKart/baserom.us.z64` — the exact filename the upstream
Torch asset extractor expects. Do not rename it to anything else in the
SpaghettiKart directory.

```
roms/mk64.us.z64                        ← you place it here
  ↓ (copied by spmc-build.sh)
SpaghettiKart/baserom.us.z64            ← Torch reads it from here
  ↓ (ExtractAssets cmake target)
SpaghettiKart/build-cmake/mk64.o2r      ← extracted game assets
SpaghettiKart/build-cmake/spaghetti.o2r ← engine assets
```

---

## Build Notes

### SDL2 Framework Conflict

If you have `SDL2.framework` installed at `/Library/Frameworks/` (e.g. from
perfectdark-macvanta or another project), its bundled `sdl2-config.cmake`
references `/Library/Headers` which doesn't exist on modern macOS. The build
script works around this with:

```
-DCMAKE_PREFIX_PATH=$(brew --prefix)
-DCMAKE_FIND_FRAMEWORK=LAST
```

This forces cmake to find the Homebrew `sdl2` package first, avoiding the
broken framework config.

### Build Times

First build: ~20–30 minutes (Torch + libultraship + SpaghettiKart, 549 compilation units).
Subsequent rebuilds with `--skip-deps`: ~2–5 minutes (only changed files recompile).

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

> **Note:** The bundled `.app` still reads config from `~/spaghettify.cfg.json`
> at runtime (NON_PORTABLE=OFF build). The config file in the bundle is a
> reference copy only.

---

## WIP Discord Build Testing

A WIP macOS Intel build (`spaghetti-mac-intel-x64.zip`, version `1.0.0-15-g7dba3c3c8`)
was shared on the HarbourMasters Discord for testing. Results on MacBookPro16,2
(Intel Iris Plus, Tahoe 26.3) are identical to source and nightly CI builds:

| Build | Version | Backend | Menus | Track Load |
|---|---|---|---|---|
| Source build | `1.0.0-13-gf7aab65da` | OpenGL (Id 1) | OK | SIGFPE |
| Source build | `1.0.0-13-gf7aab65da` | Metal (Id 2) | Black screen | SIGFPE |
| Nightly CI | — | OpenGL (Id 1) | OK | SIGFPE |
| Nightly CI | — | Metal (Id 2) | Black screen | SIGFPE |
| WIP Discord | `1.0.0-15-g7dba3c3c8` | OpenGL (Id 1) | OK | SIGFPE |
| WIP Discord | `1.0.0-15-g7dba3c3c8` | Metal (Id 2) | Black screen | SIGFPE |

The crash occurs at the same point in all builds — after `Setup Race!` and
`[Track] Loading... mk:luigi_raceway`, the process exits with
`floating point exception`. The WIP build does not resolve the Intel Iris Plus
rendering issue.

> **Note:** The WIP zip is a portable build and reads config from its own
> directory, not `~/spaghettify.cfg.json`. The `wip-test/` directory inside
> this repo is gitignored and used for isolated testing.

Full details and crash logs:
[HarbourMasters/SpaghettiKart#681](https://github.com/HarbourMasters/SpaghettiKart/issues/681)

---

## Known Issues (Intel Mac)

| Issue | Backend | Status |
|---|---|---|
| Black screen + SIGFPE crash on track load | Metal (Id 2) | Upstream bug — Metal rendering fails on Intel Iris Plus |
| Crash on track load (menus render fine) | OpenGL (Id 1) | Upstream bug — OpenGL rendering hits crash on track geometry load |
| `gamecontrollerdb.txt` not found warning | Both | Cosmetic — does not affect gameplay |
| Settings menu greyed out with Metal | Metal | Cannot switch backend in-game when Metal fails to render |

Both rendering crashes are upstream issues in HarbourMasters/SpaghettiKart and
cannot be fixed in the wrapper scripts. File bug reports at:
https://github.com/HarbourMasters/SpaghettiKart/issues

Attach the output of `./spmc-collect-crash.sh` (bundles crash reports + system info).

---

## Troubleshooting

```
❌ No ROM       → cp /path/to/mk64.z64 roms/mk64.us.z64
❌ Build fails  → tail -40 logs/build-*.log
❌ SDL2 cmake   → brew reinstall sdl2 (framework conflict handled by build script)
❌ Black screen → Metal on Intel — run script forces OpenGL automatically
❌ Track crash  → Upstream bug on Intel GPUs — file issue with crash report
❌ dyld error   → brew reinstall sdl2 glew
❌ Gatekeeper   → xattr -cr "/path/to/SpaghettiKart MacCheese.app"
❌ Stale config → ./run-spmc-macos.sh --restore-cfg
❌ Wrong config → find ~ -maxdepth 3 -name "spaghettify.cfg.json"
❌ Still Metal  → Check ~/spaghettify.cfg.json has "Id": 1 (capital I, value 1)
```

Logs live in `logs/` at the project root (not inside `SpaghettiKart/`).
Config lives at `~/spaghettify.cfg.json` (not in the build folder).

```zsh
ls -lt logs/*.log | head -5       # list latest logs
tail -20 logs/build-*.log         # build issues
file SpaghettiKart/build-cmake/Spaghettify   # should be: Mach-O 64-bit x86_64
cat ~/spaghettify.cfg.json | python3 -m json.tool | grep -A2 Backend  # verify backend
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

## Lessons Learned

Notes from the debugging process that may help future ports:

1. **libultraship config path**: With `NON_PORTABLE=OFF`, config writes to `~/`, not the build directory. Multiple stale config files at different paths will cause confusion.
2. **Backend enum values**: Don't trust the upstream README — read the actual enum in `libultraship/include/ship/window/Window.h`. The values are `{DX11=0, OpenGL=1, Metal=2}`, not `{DX11=2, OpenGL=3, Metal=4}` as the README suggests.
3. **Config key capitalization**: `"Id"` (capital I), not `"id"`. The game silently ignores lowercase.
4. **SDL2 framework vs Homebrew**: `/Library/Frameworks/SDL2.framework` has a broken `sdl2-config.cmake` on modern macOS. Use `CMAKE_FIND_FRAMEWORK=LAST` to prefer Homebrew.
5. **ROM filename**: Upstream Torch expects `baserom.us.z64` in the repo root — not `mk64.us.z64` or any other name.
6. **Metal on Intel**: Metal "supports" Intel Iris Plus but renders a black screen and crashes with `EXC_ARITHMETIC (SIGFPE)` on track load. Always default to OpenGL on Intel Macs.

---

## Credits

- Port: [HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart)
- Maintainers: [MegaMech](https://github.com/MegaMech), [Coco](https://github.com/coco875), [Kirito](https://github.com/KiritoDv)
- Powered by: [libultraship](https://github.com/Kenix3/libultraship)
- macOS scripts: [mkoterski](https://github.com/mkoterski)