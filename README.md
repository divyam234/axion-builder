# axion-builder

Build **AxionOS 2.9 / Android 16, OnePlus 9R (`lemonades`), userdebug + full GMS**
on an **ARM64 Linux host** using rootless Podman and DesktopECHO/ika's native-host
toolchain work. This is an unofficial builder, not an official Axion release.

One successful build is recorded in [docs/known-good.md](docs/known-good.md).
Boot, camera, telephony, updates, and Play Integrity have **not** been verified on
hardware. The camera application comes from a third-party repository.

## Layout

```text
axion-builder               host CLI (Podman)
docker/Dockerfile           Ubuntu 24.04 ARM64 build dependencies
manifests/known-good.xml    pinned Android source + device/kernel/vendor revisions
patches/ika/               16 selected upstream patches (one kernel-only excerpt)
patches/custom/             9 local patch files, separate from ika
patches/series.json         exact application order and target projects
scripts/                   patch, provisioning, and build entry points
tests/check-patches.py      reconstruct patches against a local source checkout
```

`work/`, `.cache/`, `logs/`, all keys, and binaries are ignored. No proprietary
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
./axion-builder image
./axion-builder sync
./axion-builder patches
./axion-builder provision
./axion-builder build
```

Sync defaults to the pinned manifest, including `device/oneplus/lemonades`,
`sm8250-common`, `hardware/oplus`, kernel, both OnePlus vendor trees, and camera.
The existing checkout's manifest is never replaced automatically. Re-syncing a
patched tree may conflict: do not reset source edits to resolve that blindly.

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
python3 scripts/apply-patches.py "$AXION_WORK" --check
python3 tests/check-patches.py "$AXION_WORK"
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
`gk -s` on every retry. Back up `work/vendor/lineage-priv/keys` **privately** before
flashing. Do not publish it. Never regenerate keys for an installed ROM's updates
without planning the signing-key migration.

Output: `work/out/target/product/lemonades/axion-*.zip`.
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
