#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="${ANDROID_ROOT:-$(cd "$DEVICE_DIR/../../.." && pwd)}"
CACHE_DIR="${BOOX_PAGE_354_STOCK_CACHE:-$DEVICE_DIR/.cache/page-3.5.4-stock}"
TOOLS_DIR="$CACHE_DIR/tools"
VENV_DIR="$CACHE_DIR/venv"

FIRMWARE_URL="http://firmware-us.boox.com/e275d1c30d46c00585188fb00127acde/update.upx"
UPX_SHA256="f982b3639a2d4df64cf13616b197d1bb0cc894cda48bba449320f18aec8dd493"
ZIP_SHA256="ca5fd7dd5b85bfdcc25970cb21fdde478bb25e434986009ebd2d5b3a42c1f696"
RECOVERY_SHA256="2bc82de127913c1fad7b5c3f1efaa282ee1354315375094245e62061a58ede37"

DECRYPT_REPO="https://github.com/Hagb/decryptBooxUpdateUpx.git"
DECRYPT_REVISION="ddcabf6ce27f1acff51a2506b597d506e5f1a928"
PAYLOAD_REPO="https://github.com/cyxx/extract_android_ota_payload.git"
PAYLOAD_REVISION="6952cd8095573b14cae24198fe923347a13790df"

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

verify_sha256() {
    local file="$1" expected="$2" actual
    actual="$(sha256_file "$file")"
    if [[ "$actual" != "$expected" ]]; then
        echo "SHA-256 mismatch for $file" >&2
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        exit 1
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

clone_pinned() {
    local url="$1" revision="$2" destination="$3"
    if [[ ! -d "$destination/.git" ]]; then
        git clone --filter=blob:none --no-checkout "$url" "$destination"
    fi
    if ! git -C "$destination" cat-file -e "$revision^{commit}" 2>/dev/null; then
        git -C "$destination" fetch --depth=1 origin "$revision"
    fi
    git -C "$destination" checkout --detach --force "$revision"
}

for command in curl git python3 unzip gzip cpio awk; do
    require_command "$command"
done

UNPACK_BOOTIMG="$ANDROID_ROOT/system/tools/mkbootimg/unpack_bootimg.py"
[[ -f "$UNPACK_BOOTIMG" ]] || {
    echo "Cannot find $UNPACK_BOOTIMG" >&2
    echo "Clone this repository to device/onyx/leaf3 inside a synced TWRP tree." >&2
    exit 1
}

mkdir -p "$CACHE_DIR" "$TOOLS_DIR"

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/python" -m pip install --disable-pip-version-check \
    -r "$DEVICE_DIR/requirements-stock.txt"

clone_pinned "$DECRYPT_REPO" "$DECRYPT_REVISION" "$TOOLS_DIR/decryptBooxUpdateUpx"
clone_pinned "$PAYLOAD_REPO" "$PAYLOAD_REVISION" "$TOOLS_DIR/extract_android_ota_payload"

UPX_FILE="$CACHE_DIR/update.upx"
if [[ ! -f "$UPX_FILE" ]]; then
    curl --fail --location --retry 3 --continue-at - \
        --output "$UPX_FILE.part" "$FIRMWARE_URL"
    mv "$UPX_FILE.part" "$UPX_FILE"
fi
verify_sha256 "$UPX_FILE" "$UPX_SHA256"

WORK_DIR="$(mktemp -d "$CACHE_DIR/work.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
ZIP_FILE="$WORK_DIR/update.zip"
PAYLOAD_FILE="$WORK_DIR/payload.bin"
RECOVERY_FILE="$WORK_DIR/recovery.img"
UNPACK_DIR="$WORK_DIR/recovery-unpacked"
RAMDISK_DIR="$WORK_DIR/ramdisk"

"$VENV_DIR/bin/python" "$TOOLS_DIR/decryptBooxUpdateUpx/DeBooxUpx.py" \
    Page "$UPX_FILE" "$ZIP_FILE"
verify_sha256 "$ZIP_FILE" "$ZIP_SHA256"

unzip -p "$ZIP_FILE" payload.bin > "$PAYLOAD_FILE"
"$VENV_DIR/bin/python" "$DEVICE_DIR/tools/extract-recovery.py" \
    "$TOOLS_DIR/extract_android_ota_payload" "$PAYLOAD_FILE" "$RECOVERY_FILE"
verify_sha256 "$RECOVERY_FILE" "$RECOVERY_SHA256"

mkdir -p "$UNPACK_DIR" "$RAMDISK_DIR"
python3 "$UNPACK_BOOTIMG" --boot_img "$RECOVERY_FILE" --out "$UNPACK_DIR" >/dev/null
(
    cd "$RAMDISK_DIR"
    gzip -dc "$UNPACK_DIR/ramdisk" | cpio -idm \
        system/lib64/libion.so waveform/eink_waveform.wbf 2>/dev/null
)

verify_sha256 "$UNPACK_DIR/kernel" \
    "2a021fcf41685fdc424931c7760c172cc44e81f35472daf0efd23a40f898c4e7"
verify_sha256 "$UNPACK_DIR/dtb" \
    "535de563a6382a0ed3e335d7d66e17701f90f92f96aee765b059f97f73f17913"
verify_sha256 "$UNPACK_DIR/recovery_dtbo" \
    "d257f1d88e74c0cc472d023a956f98cda0b53e1a7c0d3e94d36c8498f1d99ee9"
verify_sha256 "$RAMDISK_DIR/system/lib64/libion.so" \
    "6e1aa91baa92c90fb10d500ff3855e630174cb59039373707b7b29cc7fc67069"
verify_sha256 "$RAMDISK_DIR/waveform/eink_waveform.wbf" \
    "aa5d965d5c0f279ca1c4819bd4a621d37769b63284985b10d3903db828ebf38f"

mkdir -p "$DEVICE_DIR/prebuilt/dtb" "$DEVICE_DIR/recovery/root/waveform"
install -m 0644 "$UNPACK_DIR/kernel" "$DEVICE_DIR/prebuilt/kernel"
install -m 0644 "$UNPACK_DIR/dtb" "$DEVICE_DIR/prebuilt/dtb/leaf3.dtb"
install -m 0644 "$UNPACK_DIR/recovery_dtbo" "$DEVICE_DIR/prebuilt/recovery_dtbo.img"
install -m 0644 "$RAMDISK_DIR/system/lib64/libion.so" "$DEVICE_DIR/prebuilt/libion.so"
install -m 0644 "$RAMDISK_DIR/waveform/eink_waveform.wbf" \
    "$DEVICE_DIR/recovery/root/waveform/eink_waveform.wbf"

echo "Stock Page build inputs prepared successfully"
