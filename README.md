# TWRP device tree for ONYX BOOX Leaf3 / Page

Unofficial TWRP device tree for the ONYX BOOX Leaf3 (China), using recovery
boot-chain components from the closely related BOOX Page global firmware.

This is a diagnostic TWRP 11 tree. The OTA-derived build must be tested on
hardware before it is described as working or distributed as a release image.

## Device

- SoC: Qualcomm Bengal (Snapdragon 662), arm64
- Stock OS: Android 11
- Kernel: 4.19.157
- Display: 1264x1680 e-ink
- Touch: Cypress `cyttsp5_mt`
- Storage: A/B device with dedicated recovery partitions and dynamic system
  partitions
- Encryption: F2FS with Android 11 file and metadata encryption

## Stock files

No ONYX firmware or proprietary binaries are committed to this repository.
`prepare-stock.sh` downloads the pinned Page OTA, verifies it, decrypts it,
extracts `recovery.img`, and generates the required files locally.

Pinned firmware:

- URL: `http://firmware-us-volc.boox.com/73efa5396d8ff9f53fd34a7e282b8053/update.upx`
- OTA SHA-256: `0be5912e1bc73a8177abe03623f0d1140c01184c49a2f7d7012b43573f6e148c`
- Recovery fingerprint: `Onyx/Page/Page:11/2023-11-22_09-59_3.5_946657f755/43508:user/dev-keys`
- Security patch: `2023-06-05`

The download uses HTTP because that is the firmware URL supplied by ONYX. The
script refuses to process it unless the complete file matches the pinned
SHA-256 checksum.

Verified extracted inputs are also retained under `stock-backup/page-3.5` as
an emergency backup. They are not used by the build; builds continue to obtain
all stock inputs through `prepare-stock.sh`.

The preparation workflow uses pinned revisions of:

- [Hagb/decryptBooxUpdateUpx](https://github.com/Hagb/decryptBooxUpdateUpx)
- [cyxx/extract_android_ota_payload](https://github.com/cyxx/extract_android_ota_payload)

The latter repository is archived, so its verified commit is deliberately
pinned rather than tracking its branch.

## Prerequisites

Use an x86-64 Linux build host with the normal Android/TWRP build dependencies.
Stock preparation additionally requires:

- Git, curl, unzip, gzip, cpio, bzip2, and xz
- Python 3 with the `venv` module
- At least 6 GiB of temporary free disk space

On Ubuntu 22.04, the extra preparation packages can be installed with:

```sh
sudo apt install curl git python3 python3-venv unzip cpio bzip2 xz-utils
```

## Build

Initialize and sync TWRP 11:

```sh
mkdir -p ~/android/twrp-11
cd ~/android/twrp-11
repo init --depth=1 \
    -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git \
    -b twrp-11
repo sync -c --no-clone-bundle --no-tags -j4
```

Clone this tree at its expected Android path:

```sh
git clone -b twrp-11 \
    https://github.com/LGiki/twrp_device_onyx_leaf3.git \
    device/onyx/leaf3
```

Prepare the ignored stock files and apply the required TWRP source patches:

```sh
device/onyx/leaf3/prepare-stock.sh
device/onyx/leaf3/apply-patches.sh
```

Build the recovery image:

```sh
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_leaf3-eng
mka recoveryimage
```

The result is written to:

```text
out/target/product/leaf3/recovery.img
```

## GitHub Actions build

The `Build TWRP` workflow performs the complete build on a GitHub-hosted
Ubuntu 22.04 runner. It is intentionally manual so source sync and the 1.6 GiB
firmware download do not run on every commit.

After pushing this repository to GitHub:

1. Open **Actions**.
2. Select **Build TWRP**.
3. Choose **Run workflow** on the `twrp-11` branch.
4. Download the `twrp-leaf3-<run number>` artifact after the job succeeds.

The workflow caches only the checksum-pinned encrypted OTA. It initializes a
fresh TWRP source tree, prepares stock files, applies the patches, builds the
image, verifies its embedded stock components and ramdisk resources, and
uploads `recovery.img` with its SHA-256 file. It never accesses or flashes a
physical device.

The patch set was verified against these `twrp-11` project revisions:

- `bootable/recovery`: `8bd48201c3ed825a0acecc0e6dcf125449ab1ec2`
- `hardware/interfaces`: `1ee53cfa566471153661b2715ade8a9a5d525776`

If `repo sync` replaces or conflicts with patched files, restore those two
projects to clean source revisions and run `apply-patches.sh` again.

## Status and safety

Do not flash an untested image. This device has real `recovery_a` and
`recovery_b` partitions; never substitute a `boot` partition flash. Preserve a
verified stock recovery backup and confirm slot semantics before writing any
partition.

The current Page-OTA-derived build still requires Leaf3 hardware validation
of:

- Boot and ADB
- E-ink display refresh and touch input
- Logical and removable storage
- File and metadata decryption
- Backup and restore

## License

Repository-authored source and TWRP patches are provided under GPL-3.0-or-later.
Downloaded firmware and third-party tools retain their respective licenses.
