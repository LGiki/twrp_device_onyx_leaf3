#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="${ANDROID_ROOT:-$(cd "$DEVICE_DIR/../../.." && pwd)}"
RECOVERY_DIR="$ANDROID_ROOT/bootable/recovery"
INTERFACES_DIR="$ANDROID_ROOT/hardware/interfaces"

RECOVERY_REVISION="8bd48201c3ed825a0acecc0e6dcf125449ab1ec2"
INTERFACES_REVISION="1ee53cfa566471153661b2715ade8a9a5d525776"

RECOVERY_PATCHES=(
    "$DEVICE_DIR/patches/bootable-recovery/0002-minuitwrp-onyx-epdc-atomic.patch"
    "$DEVICE_DIR/patches/bootable-recovery/0003-minuitwrp-onyx-ebc-refresh.patch"
    "$DEVICE_DIR/patches/bootable-recovery/0004-leaf3-start-stock-crypto-hals.patch"
    "$DEVICE_DIR/patches/bootable-recovery/0006-fscrypt-ignore-system-key-directory-fsync.patch"
    "$DEVICE_DIR/patches/bootable-recovery/0009-fscrypt-policy-key-status.patch"
    "$DEVICE_DIR/patches/bootable-recovery/0008-fscrypt-skip-unavailable-per-boot-key.patch"
)
INTERFACES_PATCHES=(
    "$DEVICE_DIR/patches/hardware-interfaces/0005-keymaster-use-hidl-context-manager.patch"
)

require_project() {
    local path="$1"
    git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || {
        echo "Missing Android source project: $path" >&2
        exit 1
    }
}

warn_revision() {
    local path="$1" expected="$2" actual
    actual="$(git -C "$path" rev-parse HEAD)"
    if [[ "$actual" != "$expected" ]]; then
        echo "Warning: patches were verified at $expected, current revision is $actual" >&2
    fi
}

recovery_is_patched() {
    grep -qF 'ONYX_EBC_SEND_UPDATE' "$RECOVERY_DIR/minuitwrp/graphics_drm.cpp" &&
        grep -qF 'ctl.start", "leaf3-keymaster' "$RECOVERY_DIR/partitionmanager.cpp" &&
        grep -qF 'fscrypt init failed: encryption options' "$RECOVERY_DIR/crypto/fscrypt/FsCrypt.cpp" &&
        grep -qF 'per-boot key unavailable; continuing' "$RECOVERY_DIR/crypto/fscrypt/FsCrypt.cpp" &&
        grep -qF 'fscrypt key status: status=' "$RECOVERY_DIR/crypto/fscrypt/KeyUtil.cpp"
}

interfaces_are_patched() {
    grep -qF 'defaultServiceManager1_2()' \
        "$INTERFACES_DIR/keymaster/4.1/support/Keymaster.cpp"
}

apply_series() {
    local project="$1"
    shift
    local patch
    for patch in "$@"; do
        git -C "$project" apply --recount --check "$patch" || {
            echo "Patch series is incompatible or partially applied: $patch" >&2
            echo "Restore the project to a clean twrp-11 checkout and retry." >&2
            exit 1
        }
        git -C "$project" apply --recount "$patch"
    done
}

require_project "$RECOVERY_DIR"
require_project "$INTERFACES_DIR"
warn_revision "$RECOVERY_DIR" "$RECOVERY_REVISION"
warn_revision "$INTERFACES_DIR" "$INTERFACES_REVISION"

if recovery_is_patched; then
    echo "bootable/recovery patches are already applied"
else
    apply_series "$RECOVERY_DIR" "${RECOVERY_PATCHES[@]}"
    recovery_is_patched || {
        echo "bootable/recovery patch verification failed" >&2
        exit 1
    }
fi

if interfaces_are_patched; then
    echo "hardware/interfaces patches are already applied"
else
    apply_series "$INTERFACES_DIR" "${INTERFACES_PATCHES[@]}"
    interfaces_are_patched || {
        echo "hardware/interfaces patch verification failed" >&2
        exit 1
    }
fi

echo "Leaf3 TWRP patches applied successfully"
