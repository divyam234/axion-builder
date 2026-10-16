#!/usr/bin/env bash
# shellcheck disable=SC2034
# Source only. ika engine globals pinned to the verified build; no main engine execution.
workspace=/srv/axion
ika_root=/srv/ika-upstream
ika_work_root=/srv/axion
host_nofile_limit=${NOFILE_LIMIT:-524288}
arm64_go_prebuilt_git_url="${ARM64_GO_PREBUILT_GIT_URL:-https://android.googlesource.com/platform/prebuilts/go/linux-arm64}"
arm64_go_prebuilt_git_ref="${ARM64_GO_PREBUILT_GIT_REF:-mirror-goog-llvm-r596125-release}"
arm64_rust_prebuilt_dir="${ARM64_RUST_PREBUILT_DIR:-}"
arm64_rust_prebuilt_archive="${ARM64_RUST_PREBUILT_ARCHIVE:-}"
arm64_rust_prebuilt_git_url="${ARM64_RUST_PREBUILT_GIT_URL:-}"
arm64_rust_prebuilt_git_ref="${ARM64_RUST_PREBUILT_GIT_REF:-}"
arm64_rust_upstream_base_url="${ARM64_RUST_UPSTREAM_BASE_URL:-https://static.rust-lang.org/dist}"
clang_prebuilt_git_ref="${CLANG_PREBUILT_GIT_REF:-mirror-goog-llvm-r596125-release}"
clang_prebuilt_version="${CLANG_PREBUILT_VERSION:-clang-r584948b}"
linux_arm64_clang_prebuilt_git_url="${ARM64_CLANG_PREBUILT_GIT_URL:-https://android.googlesource.com/platform/prebuilts/clang/host/linux-arm64}"
linux_arm64_clang_prebuilt_git_ref="${ARM64_CLANG_PREBUILT_GIT_REF:-$clang_prebuilt_git_ref}"
linux_arm64_clang_prebuilt_version="${ARM64_CLANG_PREBUILT_VERSION:-$clang_prebuilt_version}"
linux_x86_clang_prebuilt_git_url="${X86_CLANG_PREBUILT_GIT_URL:-https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86}"
linux_x86_clang_prebuilt_git_ref="${X86_CLANG_PREBUILT_GIT_REF:-$clang_prebuilt_git_ref}"
linux_x86_clang_prebuilt_version="${X86_CLANG_PREBUILT_VERSION:-$clang_prebuilt_version}"
arm64_clang_tools_prebuilt_dir="${ARM64_CLANG_TOOLS_PREBUILT_DIR:-}"
arm64_clang_tools_prebuilt_archive="${ARM64_CLANG_TOOLS_PREBUILT_ARCHIVE:-}"
arm64_clang_tools_prebuilt_git_url="${ARM64_CLANG_TOOLS_PREBUILT_GIT_URL:-https://android.googlesource.com/platform/prebuilts/clang-tools}"
arm64_clang_tools_prebuilt_git_ref="${ARM64_CLANG_TOOLS_PREBUILT_GIT_REF:-mirror-goog-main-prebuilts}"
arm64_cmake_prebuilt_git_url="${ARM64_CMAKE_PREBUILT_GIT_URL:-https://android.googlesource.com/platform/prebuilts/cmake/linux-arm64}"
arm64_cmake_prebuilt_git_ref="${ARM64_CMAKE_PREBUILT_GIT_REF:-mirror-goog-llvm-r596125-release}"
arm64_jdk21_prebuilt_url="${ARM64_JDK21_PREBUILT_URL:-https://api.adoptium.net/v3/binary/latest/21/ga/linux/aarch64/jdk/hotspot/normal/eclipse}"
arm64_jdk8_prebuilt_url="${ARM64_JDK8_PREBUILT_URL:-https://api.adoptium.net/v3/binary/latest/8/ga/linux/aarch64/jdk/hotspot/normal/eclipse}"
arm64_thinlto_use_mlgo="${ARM64_THINLTO_USE_MLGO:-false}"
arm64_android_java_home="${ARM64_ANDROID_JAVA_HOME:-}"
linux_arm64_llvm_prebuilts_version=""
linux_arm64_llvm_release_version=""
linux_x86_llvm_prebuilts_version=""
linux_x86_llvm_release_version=""

log() { printf '[arm64] %s\n' "$*" >&2; }
die() { printf '[arm64] error: %s\n' "$*" >&2; exit 1; }
[[ -r "$ika_root/lineageos/scripts/lib/prebuilts.sh" ]] || die 'Run ./axion-builder provision first'
source "$ika_root/lineageos/scripts/lib/common.sh"
source "$ika_root/lineageos/scripts/lib/host_env.sh"
source "$ika_root/lineageos/scripts/lib/prebuilts.sh"
source "$ika_root/lineageos/scripts/lib/build_exec.sh"
