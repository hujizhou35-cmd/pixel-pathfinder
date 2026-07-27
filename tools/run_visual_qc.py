from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
SCREENSHOTS = ROOT / "test" / "shots_equipment_runtime"
EXPECTED_SCREENSHOTS = [
    "00_neutral_hero_runtime.png",
    "01_all_icons_175_runtime_1x.png",
    "02_all_icons_175_runtime_4x.png",
    "03_weapons_10x4frames_runtime.png",
    "04_armor_5x4frames_runtime.png",
    "05_helmets_5x4frames_runtime.png",
    "06_helmets_silhouette_runtime.png",
    "07_helmet_hair_leak_debug.png",
    "08_pants_5x4frames_runtime.png",
    "09_boots_5x4frames_runtime.png",
    "10_accessories_5x4frames_runtime.png",
    "11_full_sets_runtime.png",
    "12_elements_runtime.png",
    "13_rarity_visual_invariance.png",
    "14_inventory_actual_ui.png",
    "15_codex_actual_ui.png",
    "16_combat_actual_runtime.png",
]


def main() -> int:
    failures = 0
    for script in ("validate_visual_assets.py", "compare_protected_files.py"):
        result = subprocess.run([sys.executable, str(TOOLS / script)], cwd=ROOT, check=False)
        failures += int(result.returncode != 0)
    missing = [name for name in EXPECTED_SCREENSHOTS if not (SCREENSHOTS / name).is_file()]
    if missing:
        failures += 1
        print("missing Godot runtime screenshots:")
        for name in missing:
            print(f"  - {name}")
    else:
        print("runtime screenshot set: PASS (17/17)")
    if (ROOT / "build" / "PixelPathfinder.exe").is_file():
        result = subprocess.run([sys.executable, str(TOOLS / "validate_export.py")], cwd=ROOT, check=False)
        failures += int(result.returncode != 0)
    print(f"visual QC: {'PASS' if failures == 0 else 'FAIL'}")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
