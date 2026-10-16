#!/usr/bin/env bash
set -eo pipefail
cd /srv/axion
case "${1:?action required}" in
  sync)
    if [[ ! -d .repo ]]; then
      : "${GIT_AUTHOR_NAME:=axion-builder}"
      : "${GIT_AUTHOR_EMAIL:=builder@localhost}"
      git config --global user.name "$GIT_AUTHOR_NAME"
      git config --global user.email "$GIT_AUTHOR_EMAIL"
      repo init -u https://github.com/divyam234/axion-builder.git -b main \
        -m manifests/known-good.xml --git-lfs --no-clone-bundle </dev/null
    else
      echo 'Using existing repo manifest; not replacing local manifests or revisions.'
    fi
    repo sync -c -j6 --no-clone-bundle --no-tags </dev/null
    ;;
  patches)
    exec /usr/bin/python3 /builder/scripts/apply-patches.py /srv/axion
    ;;
  provision)
    source /builder/scripts/arm64-env.sh
    configure_arm64_host_build
    export_active_llvm_env
    echo 'ARM64 provisioning complete'
    ;;
  build)
    # Repeat runtime exports in EVERY build shell; provisioning alone is not enough.
    source /builder/scripts/arm64-env.sh
    configure_arm64_host_build
    export_active_llvm_env
    export THINLTO_USE_MLGO=false
    export ANDROID_KEY_PATH="$PWD/vendor/lineage-priv/keys"
    export ANDROID_BUILD_TOP="$PWD"
    # Axion's shell helpers use intentional SIGPIPE pipelines (e.g. head).
    # Do not impose errexit/pipefail inside them; check required outcomes below.
    set +eu
    set +o pipefail
    source build/envsetup.sh
    skipGlobs "${SKIP_GLOBS:-0}"
    # envsetup's setup_keys generates keys only if the keys directory is absent.
    test -s "$ANDROID_KEY_PATH/keys.mk" || exit 1
    test -s "$ANDROID_KEY_PATH/releasekey.pk8" || exit 1
    axion lemonades userdebug gms
    [[ "$TARGET_PRODUCT" == lineage_lemonades && "$TARGET_BUILD_VARIANT" == userdebug && "$WITH_GMS" == true ]] || exit 1
    ccache -M 50G || exit $?
    ax -br -j"${BUILD_JOBS:-6}"
    ;;
  status)
    tail -n 15 out/error.log 2>/dev/null || true
    find out/target/product/lemonades -maxdepth 1 -name '*.zip' -printf '%f %s bytes\n' 2>/dev/null || true
    echo 'Do not count .ninja_log rows as progress: it includes repeated outputs and prior runs.'
    ;;
  *) echo 'Unknown action' >&2; exit 2 ;;
esac
