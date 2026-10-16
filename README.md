# axion-builder

Build AxionOS **Android 16** natively on ARM64 Linux using Podman and
[ika's host toolchains](https://github.com/DesktopECHO/ika/blob/6a04063fdf107bf0c2b51f950291a9703b3a8070/BuildingOnARM64.md).
No x86 emulation. Android 17/crDroid is not covered.

**Build-verified:** OnePlus 9R (`lemonades`), Axion 2.9, `userdebug gms`.
Other devices need compatible trees/vendor blobs and possibly additional patches.
Device boot, camera, telephony, updates and Play Integrity remain untested;
the lemonades camera apps come from a third-party repo. These are unofficial
local builds, even when upstream filenames contain `OFFICIAL`.

## Requirements

- ARM64 Linux, Git, rootless Podman and internet access throughout the build.
- Tested host: NixOS, 12 vCPUs, 24 GiB RAM, 32 GiB swap, 4 KiB pages.
- Plan for 350–450 GiB free, plus space for swap and host workloads.
- Build dependencies are in the container; host swap is not configured for you.

## Build

```bash
git clone https://github.com/divyam234/axion-builder.git
cd axion-builder
export DEVICE=lemonades VARIANT=userdebug GMS=gms

./axion-builder pull
./axion-builder sync
./axion-builder patches
./axion-builder provision
./axion-builder build
```

Keep the same exported selection for each command. Sources, objects and cache
persist in `work/<device>/`; logs go to `logs/`. Commands stop on failure without
resetting source edits or regenerating existing keys. Re-syncing a patched tree
can conflict; review conflicts rather than resetting your changes.

| Setting | Default | Options / purpose |
|---|---|---|
| `DEVICE` | `lemonades` | Device codename; separate work directory per device |
| `VARIANT` | `userdebug` | `user`, `userdebug`, `eng` |
| `GMS` | `gms` | `gms`/`full`, `pico`, `core`, `va`/`vanilla` |
| `BUILD_JOBS` | `6` | Compile concurrency |
| `AXION_WORK` | `work/<device>` | Reuse an existing checkout |
| `DEVICE_MANIFEST` | unset | Absolute path to a device/kernel/vendor repo manifest |
| `AXION_IMAGE` | `ghcr.io/divyam234/axion-builder:latest` | Container image |
| `SKIP_GLOBS` | `0` | Set `1` only for edits to existing source-file contents |

**Skip-globs also skips Soong graph generation.** Leave it off after changing
build files, patches, toolchains, dependencies or file lists. A new variant/GMS
selection forces graph generation. `ax -br` still recreates image staging while
reusing compiled objects. Cumulative `.ninja_log` rows are not a whole-build percentage.

## Devices and commands

Lemonades sync includes its pinned device/common/kernel, OPlus hardware, vendor
and camera repos. Other devices use the common platform plus their own manifest;
OnePlus-only patches are never applied to them. Axion's CLI fetches dependencies
it knows, but missing proprietary blobs must come from the device maintainer.
See [device setup and adding profiles](docs/devices.md).

| Command | Action |
|---|---|
| `pull` / `image` | Pull the published container / build it locally |
| `sync` | Sync selected sources; preserve an existing checkout's manifest |
| `patches` | Apply common then device patches; recognize already-applied changes |
| `provision` | Install native ARM64 toolchains |
| `configure` | Run `axion "$DEVICE" "$VARIANT" "$GMS"` without compiling |
| `build` | Configure, then compile with Axion's `ax -br` |
| `shell` / `status` | Open the container / show recent errors and output zips |

For an existing checkout, export `AXION_WORK=/absolute/path/to/source`.
Never run concurrent builds in one work directory. To build in zellij:

```bash
zellij attach --create-background axion-build -- bash "$PWD/axion-builder" build
zellij attach axion-build
```

## Output and keys

- ROM: `$AXION_WORK/out/target/product/$DEVICE/axion-*.zip`
- Keys: `$AXION_WORK/vendor/lineage-priv/keys` — back up privately; do not regenerate for updates without a migration plan.
- Without `AXION_WORK`, these paths are under `work/<device>/`.

No ROMs, proprietary binaries, Google apps, keys or caches are published here;
external repositories retain their own distribution terms.

## Container publishing

**Actions → Publish ARM64 builder image → Run workflow** publishes only
`ghcr.io/divyam234/axion-builder:latest`, not a ROM. It uses a native ARM64 runner,
cached layers, smoke tests, major action versions and `GITHUB_TOKEN` with
`packages: write`; no registry secret is needed. If a new package starts private,
set its visibility to Public or authenticate to GHCR.

## Patches and verification

| Path | Contents |
|---|---|
| `manifests/common.xml` | Pinned Android platform |
| `manifests/devices/` | Device-specific source manifests |
| `manifests/known-good.xml` | Original successful-build snapshot |
| `patches/ika/` | 16 upstream patch entries |
| `patches/custom/` | 5 common local fixes |
| `patches/devices/` | Device-only fixes; 4 for lemonades |
| `patches/series.json` | Common patch order; device series is applied afterward |

Every build repeats ika's ARM64 configuration and LLVM exports, with
`THINLTO_USE_MLGO=false`. Toolchain pins: ika `6a04063`, Clang `r584948b`/LLVM 22,
Rust 1.88.0; native Go, CMake and Temurin 8/21. JDK endpoints, Ubuntu packages and
the repo launcher are moving inputs, so builds are not bit-for-bit hermetic.

```bash
python3 tests/test-builder.py
# Against the original known-good lemonades checkout:
python3 tests/check-patches.py /path/to/source
# Read-only patch check for your selected device:
python3 scripts/apply-patches.py /path/to/source --device "$DEVICE" --check
```

The reorganized runner has not completed a new clean-room build.
[Build record and checksum](docs/known-good.md) · [Patch details](patches/README.md)
· [Device profiles](docs/devices.md).

Original scripts/docs: [MIT](LICENSE). Patches retain upstream source licenses;
see [ika's notices](docs/ika-LICENSE.txt) and the patched files' headers.
