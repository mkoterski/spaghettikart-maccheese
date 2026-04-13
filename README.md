# spaghettikart-maccheese

macOS Intel build, bundle, and packaging scripts for the
[HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart)
Mario Kart 64 PC port - targeting **Intel Macs (x86_64) on macOS Tahoe and later**.

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

# 3. Build (clone -> extract assets -> compile)
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
# Find ALL config files - the game reads from ~/ on macOS
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
| **OpenGL** | **1** | **`"Id": 1`** | **Default for Intel Mac** - safest on Intel GPUs |
| Metal | 2 | `"Id": 2` | Upstream macOS default - crashes on Intel Iris Plus |

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

To edit manually: open `~/spaghettify.cfg.json` and change `"Window"` -> `"Backend"` -> `"Id"` value.

---

## ROM Handling

The ROM goes in `roms/mk64.us.z64` in the wrapper repo root. The build script
copies it to `SpaghettiKart/baserom.us.z64` - the exact filename the upstream
Torch asset extractor expects. Do not rename it to anything else in the
SpaghettiKart directory.

```
roms/mk64.us.z64                        <- you place it here
  | (copied by spmc-build.sh)
SpaghettiKart/baserom.us.z64            <- Torch reads it from here
  | (ExtractAssets cmake target)
SpaghettiKart/build-cmake/mk64.o2r      <- extracted game assets
SpaghettiKart/build-cmake/spaghetti.o2r <- engine assets
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

First build: ~20-30 minutes (Torch + libultraship + SpaghettiKart, 549 compilation units).
Subsequent rebuilds with `--skip-deps`: ~2-5 minutes (only changed files recompile).

---

## Custom Assets / Mods

Custom assets are packed in `.o2r` or `.zip` files. Place them in the `mods/`
directory inside the build folder (`SpaghettiKart/build-cmake/mods/`) or inside
the app bundle at `Contents/Resources/mods/`.

> **Note:** `.otr` archives are not supported - only `.o2r` and `.zip`.

---

## Config Backup & Restore

The run script backs up `~/spaghettify.cfg.json` before every launch. The
backend patch (OpenGL) persists across runs - no auto-restore on exit.
To manually restore a previous config:

```zsh
./run-spmc-macos.sh --restore-cfg
```

---

## Packaging & Distribution

After building, create a distributable `.dmg`:

```zsh
./spmc-bundle.sh       # wrap binary as .app
./spmc-package.sh      # create styled DMG -> dist/
```

The DMG features a drag-to-Applications layout with a tomato-red/black
spaghetti-themed background.

> **Note:** The bundled `.app` still reads config from `~/spaghettify.cfg.json`
> at runtime (NON_PORTABLE=OFF build). The config file in the bundle is a
> reference copy only.

---

## Upstream Issue Tracking

Active upstream issue:
[HarbourMasters/SpaghettiKart#681](https://github.com/HarbourMasters/SpaghettiKart/issues/681) -
macOS Intel Iris Plus crashes on track load.

Submitted PR:
[HarbourMasters/SpaghettiKart#686](https://github.com/HarbourMasters/SpaghettiKart/pull/686) -
Add CoreAudio to audio backend combobox map.

### Issue timeline and findings

Three separate issues have been identified through debugging, each blocking
the next:

**1. SIGFPE on track load (fixed upstream)**

All builds prior to PR [#685](https://github.com/HarbourMasters/SpaghettiKart/pull/685)
crash with `EXC_ARITHMETIC (SIGFPE)` when loading any track. Menus render
correctly under OpenGL; Metal shows a black screen from launch. The
libultraship update in #685 (merged 2026-04-07) resolves this.

**2. CoreAudio combobox crash (fix submitted as PR [#686](https://github.com/HarbourMasters/SpaghettiKart/pull/686))**

After #685, the game crashes immediately on the first frame draw with
`unordered_map::at: key not found`. Debug build + lldb revealed the cause:
the Audio API dropdown in `src/port/ui/MenuTypes.h` maps only `SDL` and
`WASAPI`, but macOS defaults to `COREAUDIO`. Adding
`{ Ship::AudioBackend::COREAUDIO, "CoreAudio" }` to the map fixes this.

**3. Missing `f3d.o2r` shader archive (open)**

After patching the CoreAudio issue, the OpenGL renderer fails with:
`Failed to load default fragment shader, missing f3d.o2r?`

This is a new libultraship dependency introduced by the #685 update. The file
doesn't exist in the repo, has no cmake build target, and isn't generated by
`ExtractAssets`. The same issue was reported and resolved for Starship
([HarbourMasters/Starship#214](https://github.com/HarbourMasters/Starship/issues/214)).
CI builds may include it, but local source builds do not.

### Build comparison

| Build | Version | SIGFPE | CoreAudio crash | f3d.o2r |
|---|---|---|---|---|
| Pre-#685 (source, nightly, WIP) | `1.0.0-13` to `1.0.0-15` | Crashes on track load | N/A (old libultraship) | Not needed |
| Post-#685 (source) | `1.0.0-16-gf93dce2be` | Fixed | Crashes on menu draw | Missing |
| Post-#685 + CoreAudio patch | `1.0.0-16-gf93dce2be` | Fixed | Fixed | Missing |
| Nightly (2026-04-12) | `1.0.0-16-gf93dce2be` | Still has SIGFPE | N/A | Not included |

The 2026-04-12 nightly is not yet built from post-#685 main.

---

## WIP Discord Build Testing

A WIP macOS Intel build (`spaghetti-mac-intel-x64.zip`, version `1.0.0-15-g7dba3c3c8`)
was shared on the HarbourMasters Discord for testing. Results on MacBookPro16,2
(Intel Iris Plus, Tahoe 26.3) are identical to source and nightly CI builds.

> **Note on Gatekeeper:** Downloaded WIP/nightly binaries are unsigned and will
> be killed by macOS Gatekeeper on Tahoe. Fix with:
> ```zsh
> xattr -cr .
> codesign --sign - --force --deep Spaghettify
> ```
> The `xattr -cr` alone is not sufficient on Tahoe - ad-hoc signing is required.

> **Note on config:** The WIP zip is a portable build and reads config from its
> own directory, not `~/spaghettify.cfg.json`. The `wip-test/` directory inside
> this repo is gitignored and used for isolated testing.

---

## Known Issues (Intel Mac)

| Issue | Backend | Status |
|---|---|---|
| ~~SIGFPE crash on track load~~ | Both | Fixed upstream by [#685](https://github.com/HarbourMasters/SpaghettiKart/pull/685) (libultraship update) |
| ~~CoreAudio combobox crash~~ | Both | Fix submitted as [PR #686](https://github.com/HarbourMasters/SpaghettiKart/pull/686) |
| Missing `f3d.o2r` shader archive | Both | New libultraship dependency - no build target yet (see [Starship#214](https://github.com/HarbourMasters/Starship/issues/214)) |
| Black screen with Metal | Metal (Id 2) | Metal rendering fails on Intel Iris Plus - use OpenGL |
| `gamecontrollerdb.txt` not found warning | Both | Cosmetic - copy file into build-cmake/ to suppress |
| Settings menu greyed out with Metal | Metal | Cannot switch backend in-game when Metal fails to render |

---

## Troubleshooting

```
No ROM        -> cp /path/to/mk64.z64 roms/mk64.us.z64
Build fails   -> tail -40 logs/build-*.log
SDL2 cmake    -> brew reinstall sdl2 (framework conflict handled by build script)
Black screen  -> Metal on Intel - run script forces OpenGL automatically
Track crash   -> Pre-#685: upstream SIGFPE. Post-#685: check CoreAudio + f3d.o2r
dyld error    -> brew reinstall sdl2 glew
Gatekeeper    -> xattr -cr . && codesign --sign - --force --deep Spaghettify
Stale config  -> ./run-spmc-macos.sh --restore-cfg
Wrong config  -> find ~ -maxdepth 3 -name "spaghettify.cfg.json"
Still Metal   -> Check ~/spaghettify.cfg.json has "Id": 1 (capital I, value 1)
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
(setup -> build -> extract -> compile -> launch with OpenGL). Game menus render
correctly with OpenGL backend on pre-#685 builds. Post-#685 builds require
the CoreAudio combobox fix ([PR #686](https://github.com/HarbourMasters/SpaghettiKart/pull/686))
and the `f3d.o2r` shader archive before the renderer can initialize.

---

## Lessons Learned

Notes from the debugging process that may help future ports:

1. **libultraship config path**: With `NON_PORTABLE=OFF`, config writes to `~/`, not the build directory. Multiple stale config files at different paths will cause confusion.
2. **Backend enum values**: Don't trust the upstream README - read the actual enum in `libultraship/include/ship/window/Window.h`. The values are `{DX11=0, OpenGL=1, Metal=2}`, not `{DX11=2, OpenGL=3, Metal=4}` as the README suggests.
3. **Config key capitalization**: `"Id"` (capital I), not `"id"`. The game silently ignores lowercase.
4. **SDL2 framework vs Homebrew**: `/Library/Frameworks/SDL2.framework` has a broken `sdl2-config.cmake` on modern macOS. Use `CMAKE_FIND_FRAMEWORK=LAST` to prefer Homebrew.
5. **ROM filename**: Upstream Torch expects `baserom.us.z64` in the repo root - not `mk64.us.z64` or any other name.
6. **Metal on Intel**: Metal "supports" Intel Iris Plus but renders a black screen and crashes with `EXC_ARITHMETIC (SIGFPE)` on track load. Always default to OpenGL on Intel Macs.
7. **CoreAudio backend**: The libultraship `AudioBackend` enum includes `COREAUDIO` for macOS, but port-specific UI maps may not include it. This causes `unordered_map::at` crashes when the menu tries to render the Audio API dropdown.
8. **f3d.o2r shader archive**: Newer libultraship versions require `f3d.o2r` for shader loading. CI builds may bundle it, but local source builds have no cmake target to generate it. Same issue affects other HarbourMasters ports ([Starship#214](https://github.com/HarbourMasters/Starship/issues/214)).
9. **Gatekeeper on Tahoe**: `xattr -cr` alone is no longer sufficient for unsigned binaries. Ad-hoc signing with `codesign --sign - --force --deep` is required.
10. **Debug builds for upstream reporting**: Building with `-DCMAKE_BUILD_TYPE=Debug` and using `lldb` with `bt` and `p` commands gives exact source files, line numbers, and variable values - invaluable for upstream bug reports.

---

## Credits

- Port: [HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart)
- Maintainers: [MegaMech](https://github.com/MegaMech), [Coco](https://github.com/coco875), [Kirito](https://github.com/KiritoDv)
- Powered by: [libultraship](https://github.com/Kenix3/libultraship)
- macOS scripts: [mkoterski](https://github.com/mkoterski)
