# Device selection and profiles

This snapshot targets **Axion lineage-23.2 / Android 16**. It does not port the
ARM64 toolchain to Android 17. Compatible device/vendor trees are required.

## Existing verified profile: lemonades

```bash
export DEVICE=lemonades VARIANT=userdebug GMS=gms
./axion-builder pull
./axion-builder sync
./axion-builder patches
./axion-builder provision
./axion-builder configure  # optional diagnostic; no compilation
./axion-builder build
```

`manifests/devices/lemonades.xml` includes the common platform and seven pinned
repositories (device, common, hardware/oplus, kernel, two vendor trees, camera).
`patches/devices/lemonades/series.json` adds four device-only fixes. The combined
source revisions and patches match the original known-good build. The new
parameterized runner has not performed an additional full build from scratch.

## Another Axion-compatible device

1. Prepare a local repo manifest listing compatible device/kernel/vendor repos.
   Prefer the device maintainer's documented manifest and revisions. Do not reuse
   OnePlus vendor blobs for another device.
2. Export your actual codename and manifest:

   ```bash
   export DEVICE=your_codename VARIANT=userdebug GMS=pico
   export DEVICE_MANIFEST="$HOME/manifests/your-device.xml"
   ./axion-builder pull
   ./axion-builder sync
   ./axion-builder patches
   ./axion-builder provision
   ./axion-builder configure
   ./axion-builder build
   ```

3. A device without a built-in manifest starts from `manifests/common.xml`.
   The supplied manifest is installed as
   `.repo/local_manifests/axion-builder-device.xml` before sync. It can define
   remotes, pinned project refs, and remove/replace projects as repo normally
   supports. A different existing file is **not** overwritten automatically.
4. Axion's `axion` CLI runs roomservice during configuration and may discover
   further dependencies. Missing vendor blobs still require a source/extraction
   from the maintainer. `configure` reports failure before any full compile.
5. If configuration fetched new files/dependencies, run `patches` again where
   appropriate and keep globs enabled. Device-specific changes belong in a new
   profile, not the common series.

The common ARM64 patches are a starting point, not a promise that every kernel,
SoC tool, vendor blob, or camera integration will compile or work at runtime.
`GMS=va` builds without Google services. Only lemonades `userdebug gms` has a
recorded successful build; other variants/flavors are selectable but unverified.

## Adding a repository profile

- Add `manifests/devices/<codename>.xml`, including `manifests/common.xml` and
  pinned device/vendor projects. The CLI selects it automatically for fresh sync.
- Optionally add `patches/devices/<codename>/series.json` (same format as the common
  series). Its patch paths are relative to `patches/`, e.g.
  `devices/<codename>/0001-example.patch`.
- Keep platform/host fixes under the common series only when genuinely generic.
- Record build success separately from device boot/camera/telephony verification.
- Run `python3 tests/test-builder.py`. The lemonades patch reconstruction test
  takes the existing known-good checkout: `python3 tests/check-patches.py /path/to/work`.

Use a separate work directory per device. `AXION_WORK` overrides the default
`work/<codename>` when reusing an existing tree. No manifest is silently replaced
on an already initialized checkout, and no source/key resets occur automatically.

The container image contains only host dependencies; profiles/scripts are mounted
from the builder repo. Updating this feature therefore does not require rebuilding
or republishing the image.
