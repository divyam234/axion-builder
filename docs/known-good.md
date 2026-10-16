# Known-good build record

Original build completed **2026-10-16 10:48:38 UTC**, `exit=0`.
The final resumed run took 2:24:49. This is **not** total clean-build time;
previous runs compiled substantial parts of the tree before their failures.

- Product: `lineage_lemonades`, variant `userdebug`, full GMS.
- Axion version: `2.9-NOESIS`, Android 16.
- ROM: `axion-2.9-NOESIS-20261016-OFFICIAL-GMS-lemonades.zip`
- Size: `2328903614` bytes.
- SHA-256: `ce9d00bedf145e64f6fdd6c338e179bcc1239f9eedaf07ac7b7132f90029ac10`
- No ROM or keys are uploaded in this repository.

The pinned source snapshot has **1194 projects**: 1191 repo-managed projects
plus the three manually fetched OnePlus/camera vendor repositories. It records
Git HEADs, not uncommitted patches; `patches/series.json` supplies those changes.
Local signing material is deliberately not represented in the manifest.

## Toolchain/runtime

- ika: `6a04063fdf107bf0c2b51f950291a9703b3a8070`.
- Clang: `clang-r584948b`, LLVM release `22`.
- Go/CMake/Clang pin family: `mirror-goog-llvm-r596125-release`.
- Rust: `1.88.0`, native GNU host compiler plus musl standard-library support.
- Temurin JDK 21 and JDK 8 supplied using ika's Adoptium endpoints.
- `THINLTO_USE_MLGO=false`; ARM64 payload lacks the requested MLGO advisor.
- Rootless Podman `keep-id`, nofile `524288`, six compile jobs.
- NixOS ARM64 host, 12 vCPUs, 24 GiB RAM, 32 GiB swap, 4 KiB pages.

## Verification of this repository

- 25 ordered patches (16 ika entries + 9 custom entries) reconstruct 345 affected
  file paths from the checked-out repositories' HEADs.
- A second application recognizes the already-applied patches (idempotence).
- The one Trusty dirgroup reference written by ika provisioning is normalized
  out of the source-layer comparison; provisioning supplies it at runtime.
- Bash syntax and ShellCheck checked for the reorganized builder scripts.
- The reorganized runner has not performed an entirely new from-zero ROM build.
- No on-device testing is claimed. Build success does not prove camera operation,
  radio functionality, upgrade compatibility, certification, or flash safety.
