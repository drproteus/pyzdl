#!/usr/bin/env python3
"""Trim trailing garbage that macholib/py2app appends to Mach-O files.

py2app (via macholib) rewrites dylib install names so they resolve inside the
``.app`` bundle. When doing so it can append unreferenced trailing bytes and
leave the original ``LC_CODE_SIGNATURE`` stale. This confuses ``codesign``:

* ``codesign --remove-signature`` fails with "internal error in Code Signing
  subsystem", and
* ``codesign --force --sign ...`` fails with "main executable failed strict
  validation".

Truncating each Mach-O slice to the end of its last segment
(``max(fileoff + filesize)``) drops the orphaned trailing bytes and makes the
file structurally consistent again, after which ``codesign --remove-signature``
works normally.

Usage:
    repair_macho.py <path> [path ...]

Each path may be a Mach-O file or a directory walked recursively. Thin
(arm64-only) binaries are repaired in place; fat (universal2) binaries are left
untouched.
"""

import os
import struct
import sys

LC_SEGMENT = 0x1
LC_SEGMENT_64 = 0x19

MH_MAGIC = 0xFEEDFACE
MH_CIGAM = 0xCEFAEDFE
MH_MAGIC_64 = 0xFEEDFACF
MH_CIGAM_64 = 0xCFFAEDFE
FAT_MAGIC = 0xCAFEBABE
FAT_CIGAM = 0xBEBAFECA
FAT_MAGIC_64 = 0xCAFEBABF
FAT_CIGAM_64 = 0xBFBAFECA


def _endian(magic):
    return ">" if magic in (MH_MAGIC, MH_MAGIC_64) else "<"


def trim_thin(data, endian, is64):
    """Return data truncated to the last segment's end, or None if already fine."""
    header_size = 32 if is64 else 28
    if len(data) < header_size:
        return None
    ncmds = struct.unpack_from(endian + "I", data, 16)[0]
    off = header_size
    max_extent = 0
    for _ in range(ncmds):
        if off + 8 > len(data):
            return None
        cmd, cmdsize = struct.unpack_from(endian + "II", data, off)
        if cmd == LC_SEGMENT_64:
            fileoff = struct.unpack_from(endian + "Q", data, off + 40)[0]
            filesize = struct.unpack_from(endian + "Q", data, off + 48)[0]
            max_extent = max(max_extent, fileoff + filesize)
        elif cmd == LC_SEGMENT:
            fileoff = struct.unpack_from(endian + "I", data, off + 32)[0]
            filesize = struct.unpack_from(endian + "I", data, off + 36)[0]
            max_extent = max(max_extent, fileoff + filesize)
        off += cmdsize

    if 0 < max_extent < len(data):
        return data[:max_extent]
    return None


def process_file(path):
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return False

    if len(data) < 4:
        return False

    magic = struct.unpack(">I", data[:4])[0]
    if magic in (MH_MAGIC, MH_CIGAM, MH_MAGIC_64, MH_CIGAM_64):
        endian = _endian(magic)
        is64 = magic in (MH_MAGIC_64, MH_CIGAM_64)
        out = trim_thin(data, endian, is64)
        if out is None:
            return False
        with open(path, "wb") as f:
            f.write(out)
        return True

    # Fat (universal2) binaries are left alone.
    return False


def main(paths):
    changed = 0
    for p in paths:
        files = []
        if os.path.isdir(p):
            for root, _dirs, names in os.walk(p):
                for name in names:
                    files.append(os.path.join(root, name))
        elif os.path.isfile(p):
            files.append(p)
        for fn in files:
            if process_file(fn):
                changed += 1
                print("trimmed", fn)
    print("trimmed %d file(s)" % changed)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1:])
