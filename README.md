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
- macOS 10.9 or later (tested on Tahoe 26.4.1, MacBookPro16,2)
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
SpaghettiKart/build-cmake/spaghetti.o2r <- engine assets (shaders included)
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

### Stale `spaghetti.o2r` after upstream shader changes

When upstream modifies files under `SpaghettiKart/assets/shaders/` (e.g.
PR [#687](https://github.com/HarbourMasters/SpaghettiKart/pull/687) combined
the two OpenGL shader files into one), `cmake --build` does not always re-run
`GenerateO2R`, so the archive in `build-cmake/` can go stale relative to the
source tree. The symptom is a shader runtime error that looks like a missing
file but is actually an extension mismatch between what the archive contains
and what the binary looks up.

Workaround until upstream adds a dependency from `GenerateO2R` to the
`assets/` tree:

```zsh
cd SpaghettiKart
rm -f spaghetti.o2r build-cmake/spaghetti.o2r
cmake --build build-cmake --target GenerateO2R
# verify the archive now matches the current shader sources
unzip -l build-cmake/spaghetti.o2r | grep -i shader
```

`spmc-build.sh` will invoke `GenerateO2R` explicitly in a future version to
avoid this pitfall on fresh pulls.

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

### Closed

[HarbourMasters/SpaghettiKart#681](https://github.com/HarbourMasters/SpaghettiKart/issues/681) -
macOS Intel Iris Plus crashes on track load. **Closed 2026-04-21** after the
Intel Mac build was confirmed playable end-to-end on OpenGL.

### Merged PRs contributed

[HarbourMasters/SpaghettiKart#686](https://github.com/HarbourMasters/SpaghettiKart/pull/686) -
Add CoreAudio to audio backend combobox map for macOS. **Merged** as commit
`d2febf4`.

### Issue timeline and findings

Three separate issues were identified and resolved through debugging, each
blocking the next:

**1. SIGFPE on track load (fixed upstream by [#685](https://github.com/HarbourMasters/SpaghettiKart/pull/685))**

All builds prior to PR #685 crash with `EXC_ARITHMETIC (SIGFPE)` when loading
any track. Menus render correctly under OpenGL; Metal shows a black screen
from launch. The libultraship update in #685 (merged 2026-04-07) resolves this.

**2. CoreAudio combobox crash (fixed by [#686](https://github.com/HarbourMasters/SpaghettiKart/pull/686))**

After #685, the game crashes immediately on the first frame draw with
`unordered_map::at: key not found`. Debug build + lldb revealed the cause:
the Audio API dropdown in `src/port/ui/MenuTypes.h` maps only `SDL` and
`WASAPI`, but macOS defaults to `COREAUDIO`. Adding
`{ Ship::AudioBackend::COREAUDIO, "CoreAudio" }` to the map fixes this.
Submitted as #686 and merged upstream.

**3. OpenGL shader loading after libultraship PrismProcessor (fixed upstream by [#687](https://github.com/HarbourMasters/SpaghettiKart/pull/687))**

After the CoreAudio fix, the OpenGL renderer aborted with:
`Failed to load default fragment shader, missing f3d.o2r?`

The error message is misleading. There is no separate `f3d.o2r` file; all
shaders live inside `spaghetti.o2r`. The actual problem was a path extension
mismatch introduced by libultraship PR
[#972](https://github.com/Kenix3/libultraship/pull/972) ("Add PrismProcessor
for Dynamic Shader Loading"). PR #972 changed the OpenGL shader lookup from
`.fs`/`.vs` to `.glsl`, but the archive at the time still contained
`.fs`/`.vs` entries.

SpaghettiKart PR [#687](https://github.com/HarbourMasters/SpaghettiKart/pull/687)
("Combine OpenGL shaders into single .glsl file") resolves this by combining
the two separate shader files into a single `default.shader.glsl` under
`assets/shaders/opengl/`, matching the new lookup path. Only OpenGL was
affected - Metal (`.metal`) and DirectX (`.hlsl`) lookup paths and archive
contents already matched.

Note: after pulling #687, the `build-cmake/spaghetti.o2r` archive does not
auto-regenerate. See [Stale `spaghetti.o2r` after upstream shader
changes](#stale-spaghettio2r-after-upstream-shader-changes) in Build Notes
for the workaround.

### Open items

**4. Attract-mode demo crash (under investigation)**

After all three closed crashes were resolved, one further crash remains: the
title-screen attract-mode demo auto-starts after a few seconds of idle, and
the game terminates when it attempts to load the demo race. Workaround:
press Start (or any input) before the demo timer fires, which drops straight
into the menus and allows full normal play.

The game runs fine once you are past the attract mode. Logs and a backtrace
of the demo crash have not yet been captured; will file a separate issue
with debug-build details once there is actionable information.

### Build comparison

| Build | Version | SIGFPE | CoreAudio crash | OpenGL shader | Attract-mode demo |
|---|---|---|---|---|---|
| Pre-#685 (source, nightly, WIP) | `1.0.0-13` to `1.0.0-15` | Crashes on track load | N/A (old libultraship) | N/A (pre-#972) | N/A (blocked earlier) |
| Post-#685 (source) | `1.0.0-16-gf93dce2be` | Fixed | Crashes on menu draw | N/A (blocked earlier) | N/A (blocked earlier) |
| Post-#685 + #686 | `1.0.0-16-gf93dce2be` | Fixed | Fixed | Aborts on shader load | N/A (blocked earlier) |
| Post-#686 + #687 (fresh o2r) | `1.0.0-18-gd2febf460` | Fixed | Fixed | Fixed | Crashes (workaround: skip demo) |
| Nightly (2026-04-12) | `1.0.0-16-gf93dce2be` | Still has SIGFPE | N/A | N/A | N/A |

The 2026-04-12 nightly is pre-#685. Will retest on the next green
`GenerateBuilds` CI run - the one for `d2febf4` went red.

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
| ~~CoreAudio combobox crash~~ | Both | Fixed by [PR #686](https://github.com/HarbourMasters/SpaghettiKart/pull/686) (merged `d2febf4`) |
| ~~OpenGL shader extension mismatch~~ | OpenGL | Fixed upstream by [PR #687](https://github.com/HarbourMasters/SpaghettiKart/pull/687) (merged `90f0e3a`). Note: regenerate `spaghetti.o2r` after pulling - see build notes |
| Attract-mode demo crash | Both | Under investigation. Workaround: press Start before the demo timer fires to skip straight to the menus |
| Black screen with Metal | Metal (Id 2) | Metal rendering fails on Intel Iris Plus - use OpenGL |
| `gamecontrollerdb.txt` not found warning | Both | Cosmetic - copy file into build-cmake/ to suppress |
| Settings menu greyed out with Metal | Metal | Cannot switch backend in-game when Metal fails to render |

---

## Troubleshooting

```
No ROM          -> cp /path/to/mk64.z64 roms/mk64.us.z64
Build fails     -> tail -40 logs/build-*.log
SDL2 cmake      -> brew reinstall sdl2 (framework conflict handled by build script)
Black screen    -> Metal on Intel - run script forces OpenGL automatically
Track crash     -> Pre-#685: upstream SIGFPE. Post-#685: check items below.
Audio crash     -> unordered_map::at on first frame: pull post-#686 main
Shader abort    -> "missing f3d.o2r?" under OpenGL after pulling: regenerate spaghetti.o2r (see build notes)
Demo crash      -> Crash after idling on title screen: press Start before the attract-mode demo timer fires
dyld error      -> brew reinstall sdl2 glew
Gatekeeper      -> xattr -cr . && codesign --sign - --force --deep Spaghettify
Stale config    -> ./run-spmc-macos.sh --restore-cfg
Wrong config    -> find ~ -maxdepth 3 -name "spaghettify.cfg.json"
Still Metal     -> Check ~/spaghettify.cfg.json has "Id": 1 (capital I, value 1)
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
working on a clean Intel Mac running macOS Tahoe, on both a source build and
a nightly CI build.

**Current status:** All scripts functional. Build pipeline works end-to-end
(setup -> build -> extract -> compile -> launch with OpenGL). Source build
from `d2febf460` (post-#686, post-#687) is playable end-to-end on Intel Mac
with OpenGL: menus render, track select works, races run with responsive
input and correct visuals. One remaining crash (attract-mode demo) has a
simple workaround and will be investigated separately. Nightly CI parity
retest pending the next green `GenerateBuilds` run.

| Menu | In-race gameplay |
|---|---|
| ![Menu rendering on Intel Mac with OpenGL](https://raw.githubusercontent.com/mkoterski/spaghettikart-maccheese/refs/heads/main/screenshot01.png) | ![In-race gameplay on Intel Mac with OpenGL](https://raw.githubusercontent.com/mkoterski/spaghettikart-maccheese/refs/heads/main/screenshot02.png) |

Captured on MacBookPro16,2 (Intel Iris Plus, macOS Tahoe 26.4.1), OpenGL
backend, source build `1.0.0-18-gd2febf460`.

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
8. **Misleading shader error messages**: The libultraship error `Failed to load default fragment shader, missing f3d.o2r?` is a hardcoded fallback printed whenever any shader resource load returns null, regardless of which file or path is actually missing. There is no separate `f3d.o2r` file; shaders live inside `spaghetti.o2r`. The real issue in this case was an OpenGL-specific path extension mismatch introduced by libultraship PR #972 and resolved by SpaghettiKart PR #687. Read the actual resource lookup path in the source, do not trust the error text.
9. **Stale asset archives after upstream shader changes**: `cmake --build` does not always re-run `GenerateO2R` when only files under `assets/shaders/` have changed. After pulling an upstream PR that renames or consolidates shader assets, remove `spaghetti.o2r` and re-run the target explicitly, or the binary will load a stale archive whose contents do not match what the code expects.
10. **Gatekeeper on Tahoe**: `xattr -cr` alone is no longer sufficient for unsigned binaries. Ad-hoc signing with `codesign --sign - --force --deep` is required.
11. **Debug builds for upstream reporting**: Building with `-DCMAKE_BUILD_TYPE=Debug` and using `lldb` with `bt` and `p` commands gives exact source files, line numbers, and variable values - invaluable for upstream bug reports. Release builds strip debug info and leave `source info` returning nothing, which stalls investigation of `unordered_map::at`-style crashes.
12. **`unordered_map::at` is a recurring pattern**: HarbourMasters UI code contains multiple hardcoded enum-to-string maps that can throw on platforms or backends the map's author did not test against (CoreAudio on macOS is one example). Grep for `unordered_map` and `.at(` in port UI headers is a useful preventive sweep when adding new platforms.
13. **CI does not execute binaries**: Missing platform-specific coverage (e.g., OpenGL on macOS) can let regressions ship undetected. The libultraship #972 shader-extension regression was merged 2026-04-05 and only surfaced through Intel Mac OpenGL testing.
14. **Test end-to-end, not just up to first frame**: A substantial portion of the Intel Mac crash chain only became visible after each earlier crash was fixed. Budget for multiple rounds of "fix, rebuild, hit the next layer" when onboarding a new platform, and document each layer as a distinct issue for future readers.

---

## Credits

- Port: [HarbourMasters/SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart)
- Maintainers: [MegaMech](https://github.com/MegaMech), [Coco](https://github.com/coco875), [Kirito](https://github.com/KiritoDv)
- Powered by: [libultraship](https://github.com/Kenix3/libultraship)
- macOS scripts: [mkoterski](https://github.com/mkoterski)
