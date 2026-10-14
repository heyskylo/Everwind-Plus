#!/usr/bin/env python3
"""Extract a single file from an ISO9660 image, using only the stdlib.

Tiny Core's kernel and initramfs live inside the ISO, but the CI runners are
macOS (no isoinfo) and the fetch script must work on Linux too, so we parse the
ISO directly instead of shelling out to platform-specific tools.

Usage: iso-extract.py <image.iso> <path-in-iso> <output-file>
Example: iso-extract.py TinyCore-11.0.iso /boot/vmlinuz vmlinuz
"""
import struct
import sys

SECTOR = 2048


def normalize(name: bytes) -> str:
    text = name.decode("ascii", "replace")
    if ";" in text:
        text = text.split(";", 1)[0]
    return text.upper().rstrip(".")


def parse_record(rec: bytes):
    extent_lba = struct.unpack_from("<I", rec, 2)[0]
    size = struct.unpack_from("<I", rec, 10)[0]
    flags = rec[25]
    name_len = rec[32]
    name = rec[33:33 + name_len]
    return extent_lba, size, flags, name


def iter_records(handle, lba: int, size: int):
    """Yield directory records, honouring the "records don't cross sectors" rule."""
    handle.seek(lba * SECTOR)
    data = handle.read(size)
    offset = 0
    while offset < len(data):
        rec_len = data[offset]
        if rec_len == 0:
            offset = ((offset // SECTOR) + 1) * SECTOR
            continue
        yield data[offset:offset + rec_len]
        offset += rec_len


def find(handle, lba: int, size: int, parts):
    target = parts[0]
    for rec in iter_records(handle, lba, size):
        r_lba, r_size, _flags, name = parse_record(rec)
        name = normalize(name)
        if name in ("\x00", "\x01"):  # "." and ".."
            continue
        if name == target:
            if len(parts) == 1:
                return r_lba, r_size
            return find(handle, r_lba, r_size, parts[1:])
    raise SystemExit(f"iso-extract: {target} not found")


def main() -> int:
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    image, path, output = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(image, "rb") as handle:
        handle.seek(16 * SECTOR)
        pvd = handle.read(SECTOR)
        if pvd[0] != 1 or pvd[1:6] != b"CD001":
            raise SystemExit("iso-extract: not an ISO9660 image")

        root_lba, root_size, _, _ = parse_record(pvd[156:156 + 34])
        parts = [p.upper().rstrip(".") for p in path.strip("/").split("/") if p]
        lba, size = find(handle, root_lba, root_size, parts)

        handle.seek(lba * SECTOR)
        remaining = size
        with open(output, "wb") as out:
            while remaining > 0:
                chunk = handle.read(min(remaining, 1 << 20))
                if not chunk:
                    break
                out.write(chunk)
                remaining -= len(chunk)

    print(f"iso-extract: {path} -> {output} ({size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
