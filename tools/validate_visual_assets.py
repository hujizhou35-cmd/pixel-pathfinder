from __future__ import annotations

import csv
import hashlib
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "equipment_visuals"
CATALOG = ASSETS / "manifests" / "Source_Truth_Catalog_175.csv"
OUT = ROOT / "audit" / "Visual_Asset_Validation.csv"
SLOT_DIRS = {
    "weapon": "Weapons",
    "armor": "Armor",
    "helmet": "Helmets",
    "pants": "Pants",
    "boots": "Boots",
    "accessory": "Accessories",
}
ELEMENT_DIRS = {key: key.capitalize() for key in ("metal", "wood", "water", "fire", "earth")}


def alpha_composite(base: Image.Image, overlay: Image.Image) -> Image.Image:
    out = base.convert("RGBA")
    out.alpha_composite(overlay.convert("RGBA"))
    return out


def sha_image(image: Image.Image) -> str:
    return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def inspect_png(path: Path, expected_size: tuple[int, int]) -> tuple[bool, str]:
    if not path.is_file():
        return False, "missing"
    try:
        with Image.open(path) as image:
            rgba = image.convert("RGBA")
            if rgba.size != expected_size:
                return False, f"size={rgba.size}"
            alpha = rgba.getchannel("A")
            extrema = alpha.getextrema()
            if extrema == (0, 0):
                return False, "fully_transparent"
            if any(value not in (0, 255) for value in set(alpha.get_flattened_data())):
                return False, "non_binary_alpha"
    except Exception as exc:  # pragma: no cover - error is recorded for release QA
        return False, f"load_error={exc}"
    return True, "PASS"


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, str]] = []
    failures = 0
    with CATALOG.open("r", encoding="utf-8-sig", newline="") as handle:
        catalog = list(csv.DictReader(handle))

    if len(catalog) != 175:
        rows.append({"check": "catalog_count", "path": str(CATALOG), "status": "FAIL", "detail": str(len(catalog))})
        failures += 1
    else:
        rows.append({"check": "catalog_count", "path": str(CATALOG), "status": "PASS", "detail": "175"})

    seen_bases: set[str] = set()
    seen_pairs: set[tuple[str, str]] = set()
    for entry in catalog:
        slot = entry["slot"]
        slug = entry["base_slug"]
        element = entry["element"]
        pair = (slug, element)
        if pair in seen_pairs:
            rows.append({"check": "unique_pair", "path": f"{slug}/{element}", "status": "FAIL", "detail": "duplicate"})
            failures += 1
            continue
        seen_pairs.add(pair)

        base_icon = ASSETS / "icons" / "base" / SLOT_DIRS[slot] / f"{slug}_base_20x20.png"
        base_layer = ASSETS / "layers" / "base" / SLOT_DIRS[slot] / f"{slug}_base_40x208.png"
        particle_icon = ASSETS / "icons" / "particles" / ELEMENT_DIRS[element] / f"{element}_{slug}_particles_20x20.png"
        particle_layer = ASSETS / "layers" / "particles" / ELEMENT_DIRS[element] / f"{element}_{slug}_particles_40x208.png"
        final_icon = ASSETS / "icons" / "final" / ELEMENT_DIRS[element] / f"{element}_{slug}_final_20x20.png"

        paths = [
            ("particle_icon", particle_icon, (20, 20)),
            ("particle_layer", particle_layer, (40, 208)),
            ("final_icon", final_icon, (20, 20)),
        ]
        if slug not in seen_bases:
            seen_bases.add(slug)
            paths.extend([
                ("base_icon", base_icon, (20, 20)),
                ("base_layer", base_layer, (40, 208)),
            ])
        for check, path, size in paths:
            ok, detail = inspect_png(path, size)
            rows.append({"check": check, "path": path.relative_to(ROOT).as_posix(), "status": "PASS" if ok else "FAIL", "detail": detail})
            failures += int(not ok)

        if base_icon.is_file() and particle_icon.is_file() and final_icon.is_file():
            with Image.open(base_icon) as base, Image.open(particle_icon) as particle, Image.open(final_icon) as final:
                expected = alpha_composite(base, particle)
                ok = sha_image(expected) == sha_image(final)
            rows.append({
                "check": "final_icon_composition",
                "path": final_icon.relative_to(ROOT).as_posix(),
                "status": "PASS" if ok else "FAIL",
                "detail": "base+particle@0,0",
            })
            failures += int(not ok)

    rows.append({"check": "base_family_count", "path": "", "status": "PASS" if len(seen_bases) == 35 else "FAIL", "detail": str(len(seen_bases))})
    failures += int(len(seen_bases) != 35)
    rows.append({"check": "family_element_pair_count", "path": "", "status": "PASS" if len(seen_pairs) == 175 else "FAIL", "detail": str(len(seen_pairs))})
    failures += int(len(seen_pairs) != 175)

    for slug in ("leather_cap", "iron_helmet", "battle_helmet", "knight_helmet", "dragon_head_helmet"):
        for kind in ("allowed_hair_mask", "forbidden_hair_mask", "helmet_coverage_mask", "visible_hair"):
            path = ASSETS / "masks" / "helmets" / f"{slug}_{kind}_40x208.png"
            ok, detail = inspect_png(path, (40, 208))
            # FULL_HIDE allowed/visible-hair layers are intentionally fully transparent.
            if kind in {"allowed_hair_mask", "visible_hair"} and slug in {"knight_helmet", "dragon_head_helmet"} and path.is_file():
                with Image.open(path) as image:
                    ok = image.convert("RGBA").size == (40, 208)
                    detail = "PASS_FULL_HIDE"
            rows.append({"check": f"helmet_{kind}", "path": path.relative_to(ROOT).as_posix(), "status": "PASS" if ok else "FAIL", "detail": detail})
            failures += int(not ok)

    with OUT.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=("check", "path", "status", "detail"))
        writer.writeheader()
        writer.writerows(rows)
    print(f"visual asset validation: {'PASS' if failures == 0 else 'FAIL'} ({failures} failures)")
    print(OUT)
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
