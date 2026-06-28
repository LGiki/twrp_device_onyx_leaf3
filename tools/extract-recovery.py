#!/usr/bin/env python3
"""Extract only recovery.img with cyxx/extract_android_ota_payload."""

import os
import sys


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "usage: extract-recovery.py <extractor-dir> <payload.bin> <recovery.img>",
            file=sys.stderr,
        )
        return 2

    extractor_dir, payload_path, output_path = map(os.path.abspath, sys.argv[1:])
    sys.path.insert(0, extractor_dir)

    from extract_android_ota_payload import Payload, PayloadError, parse_payload

    with open(payload_path, "rb") as payload_file:
        payload = Payload(payload_file)
        payload.Init()

        recovery = next(
            (part for part in payload.manifest.partitions if part.partition_name == "recovery"),
            None,
        )
        if recovery is None:
            raise PayloadError("OTA payload does not contain a recovery partition")

        with open(output_path, "wb") as output_file:
            parse_payload(payload, recovery, output_file)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
