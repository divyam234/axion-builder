#!/usr/bin/env bash
set -eo pipefail
cd /srv/axion
DEVICE=${DEVICE:-lemonades}
VARIANT=${VARIANT:-userdebug}
GMS=${GMS:-gms}
ACTION=${1:?action required}
if [[ -f .axion-builder-device && $(cat .axion-builder-device) != "$DEVICE" ]]; then
  echo 'This work directory belongs to a different device. Use a separate AXION_WORK.' >&2
  exit 1
fi
case "$ACTION" in
  sync|patches|configure|build) printf '%s\n' "$DEVICE" > .axion-builder-device ;;
esac
case "$ACTION" in
  sync)
    if [[ ! -d .repo ]]; then
      : "${GIT_AUTHOR_NAME:=axion-builder}"
      : "${GIT_AUTHOR_EMAIL:=builder@localhost}"
      git config --global user.name "$GIT_AUTHOR_NAME"
      git config --global user.email "$GIT_AUTHOR_EMAIL"
      manifest=manifests/common.xml
      if [[ -f "/builder/manifests/devices/$DEVICE.xml" ]]; then
        manifest="manifests/devices/$DEVICE.xml"
      fi
      repo init -u https://github.com/divyam234/axion-builder.git -b main \
        -m "$manifest" --git-lfs --no-clone-bundle </dev/null
    else
      echo 'Using existing repo manifest; not replacing local manifests or revisions.'
    fi
    if [[ -f /device-manifest.xml ]]; then
      /usr/bin/python3 /builder/scripts/install-device-manifest.py /device-manifest.xml .repo/local_manifests/axion-builder-device.xml
    fi
    repo sync -c -j6 --no-clone-bundle --no-tags </dev/null
    ;;
  patches)
    exec /usr/bin/python3 /builder/scripts/apply-patches.py /srv/axion --device "$DEVICE"
    ;;
  provision)
    source /builder/scripts/arm64-env.sh
    configure_arm64_host_build
    export_active_llvm_env
    echo 'ARM64 provisioning complete'
    ;;
  configure|build)
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
    selection="$DEVICE:$VARIANT:$GMS"
    if [[ ! -f .axion-builder-last-target || $(cat .axion-builder-last-target) != "$selection" ]]; then
      echo 'New device/variant/GMS selection: forcing graph generation.'
      SKIP_GLOBS=0
    fi
    skipGlobs "${SKIP_GLOBS:-0}"
    # envsetup's setup_keys generates keys only if the keys directory is absent.
    test -s "$ANDROID_KEY_PATH/keys.mk" || exit 1
    test -s "$ANDROID_KEY_PATH/releasekey.pk8" || exit 1
    axion "$DEVICE" "$VARIANT" "$GMS"
    if [[ "$TARGET_PRODUCT" != "lineage_$DEVICE" || "$TARGET_BUILD_VARIANT" != "$VARIANT" ]]; then
      echo 'Axion could not configure the target. Check device/vendor dependencies; supply DEVICE_MANIFEST and sync if needed.' >&2
      exit 1
    fi
    if [[ "$GMS" == va ]]; then
      [[ "$WITH_GMS" == false ]] || exit 1
    else
      [[ "$WITH_GMS" == true && "$TARGET_GAPPS_VARIANT" == "$GMS" ]] || exit 1
    fi
    [[ "$ACTION" != configure ]] || exit 0
    ccache -M 50G || exit $?
    ax -br -j"${BUILD_JOBS:-6}"
    result=$?
    if [[ $result == 0 ]]; then printf '%s\n' "$selection" > .axion-builder-last-target; fi
    exit "$result"
    ;;
  status)
    tail -n 15 out/error.log 2>/dev/null || true
    find "out/target/product/$DEVICE" -maxdepth 1 -name '*.zip' -printf '%f %s bytes\n' 2>/dev/null || true
    echo 'Do not count .ninja_log rows as progress: it includes repeated outputs and prior runs.'
    ;;
  *) echo 'Unknown action' >&2; exit 2 ;;
esac
