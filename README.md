# axion-builder

Build **AxionOS / Android 16 on an ARM64 Linux host**, with selectable device,
build variant, and Google-app flavor, using rootless Podman and DesktopECHO/ika's
native-host toolchain work. This is an unofficial builder, not an official Axion
release. **OnePlus 9R (`lemonades`), Axion 2.9, userdebug + full GMS is the only
build-verified profile so far.** Other devices require compatible trees/blobs and
may need their own patches; accepting a codename does not prove device support.

One successful build is recorded in [docs/known-good.md](docs/known-good.md).
Boot, camera, telephony, updates, and Play Integrity have **not** been verified on
hardware. The camera application comes from a third-party repository.

## Layout

```text
axion-builder               host CLI (Podman)
docker/Dockerfile           Ubuntu 24.04 ARM64 build dependencies
manifests/common.xml        pinned Android platform (no OnePlus device/vendor trees)
manifests/devices/          per-device manifests (lemonades included)
manifests/known-good.xml     historical flat snapshot of the successful build
patches/ika/               16 selected upstream patches (one kernel-only excerpt)
patches/custom/             5 common local compatibility patches
patches/devices/            device-only patches and per-device series files
patches/series.json         common application order (21 entries)
scripts/                   patch, provisioning, and build entry points
tests/check-patches.py      reconstruct patches against a local source checkout
```

`work/<device>/`, `.cache/`, `logs/`, all keys, and binaries are ignored. No proprietary
blobs, Google apps, signing keys, ROM images, or caches are distributed here.
The manifest references external repositories; you are responsible for any
applicable terms when fetching them.

## Requirements

- ARM64 Linux, Git, Podman (rootless user namespaces configured).
- Tested: NixOS host, 12 vCPUs, 24 GiB RAM, 32 GiB disk swap, 4 KiB pages.
- Allow at least 350–450 GiB free for sources, intermediate objects and cache;
  actual usage varies. Maintain additional space for swap and host workloads.
- Internet access during sync and provisioning, and potentially during builds.
- Native `libssl-dev`, `pahole`, `lz4`, Python and other tools are in the container.
  Host swap is **not** created or modified by this builder.

## Fresh build

```bash
git clone https://github.com/divyam234/axion-builder.git
cd axion-builder
./axion-builder pull
./axion-builder sync
./axion-builder patches
./axion-builder provision
./axion-builder build
```

The default image is `ghcr.io/divyam234/axion-builder:latest`.
Use `./axion-builder image` only when you want to build it locally.

### Publishing the container image

Open **Actions → Publish ARM64 builder image → Run workflow**. It runs only on
`workflow_dispatch` (not every push), builds natively on `ubuntu-24.04-arm`,
smoke-tests the ARM64 tools and Python SSL, then pushes to GHCR using the
workflow's `GITHUB_TOKEN` with `packages: write`. No extra registry secret is needed.
Only the `latest` tag is published. Actions use major-version references;
BuildKit layers are cached between runs.

After first publication, check the GHCR package's **Package settings → Change
visibility → Public** if anonymous pulls fail: GitHub can initially create
packages as private, even for a public source repository. Alternatively log in
to GHCR with an account/token allowed to read the package.

This workflow publishes the **container dependencies only**, not a complete ROM.
The Android source sync, patches, toolchain provisioning and compile still run
locally with persistent storage and private signing keys.

Sync defaults to the pinned manifest, including `device/oneplus/lemonades`,
`sm8250-common`, `hardware/oplus`, kernel, both OnePlus vendor trees, and camera.
The existing checkout's manifest is never replaced automatically. Re-syncing a
patched tree may conflict: do not reset source edits to resolve that blindly.

### Device, variant and GMS selection

```bash
# Defaults (the known-good profile):
export DEVICE=lemonades VARIANT=userdebug GMS=gms

# All accepted build/flavor choices:
# VARIANT=user | userdebug | eng
# GMS=gms | full | pico | core | va | vanilla
```

Use the same exported selection for every command. `full` normalizes to `gms`,
`vanilla` to `va`. `configure` invokes `axion "$DEVICE" "$VARIANT" "$GMS"`
without compiling. `build` configures then calls Axion's `ax -br`.

Each device uses a separate `work/<codename>` by default. A work-directory marker
rejects switching devices in the same tree; use another directory instead.
Changing variant or GMS forces graph generation even if `SKIP_GLOBS=1` was set.

For another Android 16 device, use the common platform plus a reviewed
`DEVICE_MANIFEST=/absolute/file.xml` listing compatible device/kernel/vendor
repositories. Axion's CLI can fetch device dependencies it knows, but cannot
invent missing proprietary blobs. **No OnePlus patches or camera repositories
are applied to other devices.** See [docs/devices.md](docs/devices.md) for the
workflow and how to add a verified device profile.

Commands log to `logs/` and stop on failure. Neither failed patches nor failed
builds trigger resets, source deletions, or endless automatic retries.
The complete clean-room workflow has **not** been rebuilt from zero since the
scripts were reorganized; patch reconstruction and existing-tree checks are
separate from the original successful ROM build.

## Existing source tree / zellij

```bash
export AXION_WORK="$HOME/axion-lemonades/work"
# Never run two builds against the same work directory.
./axion-builder provision
./axion-builder build

# Run in a detached session, then attach to watch:
zellij attach --create-background axion-build -- env \
  AXION_WORK="$AXION_WORK" bash "$PWD/axion-builder" build
zellij attach axion-build
```

The new wrapper does not move or delete the original checkout. `patches` is
idempotent on its own patched files, but unrelated edits near a patch can cause
a deliberate conflict. For read-only patch checks:

```bash
python3 scripts/apply-patches.py "$AXION_WORK" --device "${DEVICE:-lemonades}" --check
python3 tests/check-patches.py "$AXION_WORK"
python3 tests/test-builder.py
```

## Incremental builds

Default concurrency is `BUILD_JOBS=6`; change it explicitly if your RAM permits.
Sources/objects/cache persist. Axion's `ax -br` runs its normal installclean step,
so image staging is recreated even when compile objects are reused.

```bash
# Only when changing contents of already-known source files:
SKIP_GLOBS=1 ./axion-builder build
```

**Important:** Axion's `skipGlobs` skips **Soong Ninja graph generation**, not just
wildcard scanning. Never use it after changing `Android.bp`, module definitions,
patches, toolchains, dependencies, or source file lists. Use `SKIP_GLOBS=0` (the
default) after setup or any build-graph change. Do not estimate whole-ROM progress
by dividing cumulative `.ninja_log` rows by one retry's action count: it counts
multiple outputs and previous runs, and that produced misleading figures during
the original session.

## Keys and output

Axion generates local keys once through `envsetup.sh`; this wrapper does not call
`gk -s` on every retry. Back up your work directory's signing keys **privately** before
flashing. Do not publish it. Never regenerate keys for an installed ROM's updates
without planning the signing-key migration.

Output: `work/<device>/out/target/product/<device>/axion-*.zip`
(or under your explicit `AXION_WORK`). Keys live in that same work directory's
`vendor/lineage-priv/keys`; keep backups separate for different devices.
Build completion is not proof of flash safety or device functionality. Despite
upstream version strings containing `OFFICIAL`, these are locally built images.

## ARM64 patch/runtime contract

ika is pinned to `6a04063fdf107bf0c2b51f950291a9703b3a8070`.
Provisioning calls its actual `configure_arm64_host_build`; every build repeats
that configuration and `export_active_llvm_env`, with `THINLTO_USE_MLGO=false`.
No x86 emulation, no ARM64 paths redirected to x86 binaries.

Toolchain: Clang `clang-r584948b` / LLVM 22, Rust 1.88.0 for this tree, native Go,
CMake and JDKs from ika's pinned defaults. JDK download endpoints still select
the latest Temurin 8/21 release: **this is not a bit-for-bit hermetic build**.
Ubuntu package repositories and the repo launcher are also moving inputs.

See [patches/README.md](patches/README.md) for the local fixes and provenance,
and [ika's ARM64 guide](https://github.com/DesktopECHO/ika/blob/6a04063fdf107bf0c2b51f950291a9703b3a8070/BuildingOnARM64.md)
for the upstream approach. Android 17/crDroid is out of scope for this snapshot.

## Licensing

Patches retain their upstream projects' licenses; bundling a diff does not
relicense the underlying source. See [docs/ika-LICENSE.txt](docs/ika-LICENSE.txt)
for ika's notices and individual source headers for the Android projects.
Original builder scripts/docs are provided under the [MIT license](LICENSE).
