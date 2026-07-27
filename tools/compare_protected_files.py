from __future__ import annotations

import csv
import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REGISTER = ROOT / "audit" / "Protected_File_Register.csv"
OUT = ROOT / "audit" / "Protected_File_Diff_Audit.csv"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> int:
    with REGISTER.open("r", encoding="utf-8-sig", newline="") as handle:
        baseline = list(csv.DictReader(handle))
    output: list[dict[str, str]] = []
    failures = 0
    for entry in baseline:
        rel = entry["Relative_Path"]
        path = ROOT / Path(rel)
        expected = entry["SHA256"].upper()
        if not path.is_file():
            actual = ""
            status = "MISSING"
        else:
            actual = sha256(path)
            status = "UNCHANGED" if actual == expected else "CHANGED"
        failures += int(status != "UNCHANGED")
        output.append({
            "Relative_Path": rel,
            "Baseline_SHA256": expected,
            "Current_SHA256": actual,
            "Status": status,
            "Explanation": "" if status == "UNCHANGED" else "Protected logic file must not change.",
        })
    with OUT.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=output[0].keys())
        writer.writeheader()
        writer.writerows(output)
    print(f"protected file audit: {'PASS' if failures == 0 else 'FAIL'} ({failures} differences)")
    print(OUT)
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
