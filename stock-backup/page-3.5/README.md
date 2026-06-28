# Page 3.5 stock input backup

These files were extracted from the pinned ONYX Page 3.5 OTA documented in
the repository README. They are retained only as a backup in case the vendor
firmware URL becomes unavailable.

The build does not consume files from this directory. GitHub Actions still
runs `prepare-stock.sh`, which downloads, verifies, decrypts, and extracts the
stock OTA before every uncached build.

`SHA256SUMS` records the expected digest of each archived file.
