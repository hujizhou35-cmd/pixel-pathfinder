from __future__ import annotations

import csv
import hashlib
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "build" / "PixelPathfinder.exe"
OUT = ROOT / "audit" / "Export_Validation.csv"
OLD_SHA256 = "6B5363F9419F6D09D6C84395304E0E1E3F61114ECDAF85905A40E277481B79DD"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def check_pe_x64(path: Path) -> bool:
    with path.open("rb") as handle:
        if handle.read(2) != b"MZ":
            return False
        handle.seek(0x3C)
        pe_offset = struct.unpack("<I", handle.read(4))[0]
        handle.seek(pe_offset)
        return handle.read(4) == b"PE\0\0" and struct.unpack("<H", handle.read(2))[0] == 0x8664


def has_embedded_pck_marker(path: Path) -> bool:
    with path.open("rb") as handle:
        handle.seek(max(0, path.stat().st_size - 4096))
        return b"GDPC" in handle.read()


def main() -> int:
    checks: list[tuple[str, bool, str]] = []
    exists = EXE.is_file()
    checks.append(("exe_exists", exists, str(EXE)))
    if exists:
        digest = sha256(EXE)
        checks.extend([
            ("exe_size", EXE.stat().st_size > 10 * 1024 * 1024, str(EXE.stat().st_size)),
            ("pe_x86_64", check_pe_x64(EXE), "PE machine 0x8664"),
            ("new_hash", digest != OLD_SHA256, digest),
            ("embedded_pck_marker", has_embedded_pck_marker(EXE), "GDPC in appended footer"),
        ])
    sidecars = list((ROOT / "build").glob("*.pck")) if (ROOT / "build").is_dir() else []
    checks.append(("no_sidecar_pck", len(sidecars) == 0, ",".join(path.name for path in sidecars)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(("Check", "Status", "Detail"))
        for name, ok, detail in checks:
            writer.writerow((name, "PASS" if ok else "FAIL", detail))
    failures = sum(not ok for _, ok, _ in checks)
    print(f"export validation: {'PASS' if failures == 0 else 'FAIL'} ({failures} failures)")
    print(OUT)
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
