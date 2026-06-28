# Generated stock files

This directory is intentionally source-only. Run `./prepare-stock.sh` after
cloning the device tree into a TWRP source checkout. The script downloads the
pinned ONYX Page OTA and generates:

- `kernel`
- `dtb/leaf3.dtb`
- `recovery_dtbo.img`
- `libion.so`

The e-ink waveform is generated separately at
`recovery/root/waveform/eink_waveform.wbf`.

These stock-derived files are ignored by Git and must not be committed.
