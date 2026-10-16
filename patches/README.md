# Patch provenance

`series.json` lists the **common** patches. Then
`devices/<codename>/series.json`, if present, adds only that device's patches.
Each patch is applied in its named project; `.` denotes Android's source root.
Conflicts stop without resetting anything. An unknown profile gets only the
common set, not the lemonades fixes.

## ika (16 entries)

All selected from DesktopECHO/ika commit
`6a04063fdf107bf0c2b51f950291a9703b3a8070`, including its `bison.patch` for
one-true-awk, libpcap and iproute2. Those Bison changes are **not original fixes**.
`vendor-lineage-kernel-tools.patch` contains only the `BoardConfigKernel.mk`
section of ika's `vendor-lineage-arm64-host-tools.patch`: Axion's bootanimation
script did not need the remaining mogrify fallback.

These are the ARM64-host/Clang/Rust/musl/Trusty pieces, not ika's desktop UI,
graphics, camera or Cuttlefish feature patch set.

## Custom (9 files: 5 common + 4 lemonades-only)

| Patch | Why |
|---|---|
| 0001 | Kernel-header cleaner selects ARM64 libclang + matching bindings, works with stripped sandbox env, tolerates LLVM 22 null cursors |
| 0002 | cpuinfo fixed-width strings trigger a new Clang 22 warning; scope suppression to the module |
| 0003 | Device kernel config selects native host libc sysroot |
| 0004 | Kernel host tools must not include/link x86 prebuilt headers or libcrypto |
| 0005 | repo manifest needs system Python `_ssl`, absent in ARM64 build-tools Python |
| 0006 | atest flag-list generator uses source packaging/system Python for the same `_ssl` limitation |
| 0007 | Remove duplicate WaveformEffect from hardware/oplus; framework already supplies it |
| 0008 | Remove six `prefer: true` declarations that cause source/prebuilt partition conflicts |
| 0009 | Camera mirror ships onepluscamera.mk; provide camera-vendor.mk entry point |

0007/0008/0009 are device/platform integration adaptations, not generic ARM64
toolchain requirements. Keeping the source class or preferring a prebuilt can
affect runtime selection: build success does **not** establish camera correctness.
0003 is also scoped to lemonades because it edits its shared sm8250 device tree.
These four live under `devices/lemonades/`; the other five remain in `custom/`.

Custom patches are exported from the actual successful tree. Patch 0004 is
relative to the already-applied ika kernel-tools changes, so the two sets do not
duplicate those hunks. No proprietary `.so`, APK or JAR is in these patches.
