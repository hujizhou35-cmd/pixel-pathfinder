#!/usr/bin/env python3
"""Deterministically prepare pixel-perfect equipment visual assets.

This script deliberately works at native 1x resolution.  It uses only hard
integer coordinates, nearest-neighbour scaling for the audit sheet, and
binary alpha (0/255).  Re-running it produces the same PNG pixel content.
"""

from __future__ import annotations

import csv
import hashlib
from collections import deque
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "equipment_visuals"
HERO = ASSETS / "hero"
ICON_BASE = ASSETS / "icons" / "base" / "Helmets"
ICON_PARTICLES = ASSETS / "icons" / "particles"
ICON_FINAL = ASSETS / "icons" / "final"
LAYER_BASE = ASSETS / "layers" / "base"
HELMET_LAYERS = LAYER_BASE / "Helmets"
BOOT_LAYERS = LAYER_BASE / "Boots"
WEAPON_LAYERS = LAYER_BASE / "Weapons"
MASKS = ASSETS / "masks" / "helmets"
AUDIT = ROOT / "audit"
DESIGN_REFS = AUDIT / "design_references"

FRAME_W = 40
FRAME_H = 52
SHEET_SIZE = (40, 208)
ICON_SIZE = (20, 20)
HEAD_ANCHORS = ((20, 11), (20, 10), (21, 12), (18, 13))

HELMETS = (
    "leather_cap",
    "iron_helmet",
    "battle_helmet",
    "knight_helmet",
    "dragon_head_helmet",
)
HAIR_MODES = {
    "leather_cap": "CAP_PARTIAL",
    "iron_helmet": "CUSTOM_MASK",
    "battle_helmet": "OPEN_HELM_PARTIAL",
    "knight_helmet": "FULL_HIDE",
    "dragon_head_helmet": "FULL_HIDE",
}
ELEMENTS = ("Earth", "Fire", "Metal", "Water", "Wood")

OUTLINE = (20, 24, 40, 255)
PALETTES = {
    "leather_cap": {
        "outline": (29, 20, 25, 255),
        "shadow": (75, 42, 30, 255),
        "mid": (132, 75, 43, 255),
        "light": (185, 112, 61, 255),
        "highlight": (224, 157, 88, 255),
    },
    "iron_helmet": {
        "outline": (21, 25, 36, 255),
        "shadow": (67, 78, 92, 255),
        "mid": (119, 135, 153, 255),
        "light": (177, 194, 207, 255),
        "highlight": (231, 239, 242, 255),
    },
    "battle_helmet": {
        "outline": (21, 24, 36, 255),
        "shadow": (64, 74, 94, 255),
        "mid": (112, 130, 153, 255),
        "light": (171, 188, 207, 255),
        "highlight": (225, 234, 241, 255),
    },
    "knight_helmet": {
        "outline": (15, 21, 33, 255),
        "shadow": (55, 68, 84, 255),
        "mid": (97, 115, 136, 255),
        "light": (158, 176, 195, 255),
        "highlight": (225, 234, 241, 255),
    },
    "dragon_head_helmet": {
        "outline": (17, 34, 29, 255),
        "shadow": (31, 73, 57, 255),
        "mid": (51, 119, 88, 255),
        "light": (91, 166, 123, 255),
        "highlight": (154, 210, 157, 255),
        "accent": (223, 177, 90, 255),
        "accent_light": (244, 211, 132, 255),
    },
}

# Inclusive x spans keyed by y relative to the frozen per-frame head centre.
# Every family starts from a different silhouette, not a palette swap.
HELMET_ROWS = {
    "leather_cap": {
        -8: [(-3, 3)],
        -7: [(-5, 4)],
        -6: [(-6, 5)],
        -5: [(-7, 6)],
        -4: [(-7, 7)],
        -3: [(-8, 7)],
        -2: [(-8, 8)],
        -1: [(-9, 7)],
        0: [(-10, 7)],
    },
    "iron_helmet": {
        -8: [(-3, 3)],
        -7: [(-5, 5)],
        -6: [(-6, 6)],
        -5: [(-7, 7)],
        -4: [(-7, 7)],
        -3: [(-8, 8)],
        -2: [(-8, 8)],
        -1: [(-9, 9)],
        0: [(-9, -7), (7, 9)],
        1: [(-8, -7), (7, 8)],
        2: [(-8, -8), (8, 8)],
    },
    "battle_helmet": {
        -10: [(-1, 1)],
        -9: [(-2, 2)],
        -8: [(-5, 5)],
        -7: [(-7, 7)],
        -6: [(-8, 8)],
        -5: [(-8, 8)],
        -4: [(-9, 9)],
        -3: [(-9, 9)],
        -2: [(-9, -2), (2, 9)],
        -1: [(-9, -4), (4, 9)],
        0: [(-9, -7), (7, 9)],
        1: [(-8, -7), (7, 8)],
        2: [(-8, -8), (8, 8)],
    },
    "knight_helmet": {
        -10: [(-1, 1)],
        -9: [(-2, 2)],
        -8: [(-4, 4)],
        -7: [(-6, 6)],
        -6: [(-7, 7)],
        -5: [(-8, 8)],
        -4: [(-8, 8)],
        -3: [(-9, 9)],
        -2: [(-9, 9)],
        -1: [(-9, 9)],
        0: [(-9, 9)],
        1: [(-8, 8)],
        2: [(-8, 8)],
        3: [(-8, -4), (4, 8)],
        4: [(-8, -5), (5, 8)],
        5: [(-7, -5), (5, 7)],
    },
    "dragon_head_helmet": {
        -11: [(-9, -9), (9, 9)],
        -10: [(-9, -8), (8, 9)],
        -9: [(-8, -7), (-2, 2), (7, 8)],
        -8: [(-7, -6), (-4, 4), (6, 7)],
        -7: [(-6, 6)],
        -6: [(-8, 8)],
        -5: [(-9, 9)],
        -4: [(-9, 9)],
        -3: [(-9, 9)],
        -2: [(-9, -2), (2, 9)],
        -1: [(-9, -5), (-1, 1), (5, 9)],
        0: [(-9, -7), (-2, 2), (7, 9)],
        1: [(-8, -7), (-2, 2), (7, 8)],
        2: [(-8, -8), (-1, 1), (8, 8)],
    },
}

# Narrow horizontal eye slit for the vertical knight face plate.
HELMET_CUTOUTS = {
    "knight_helmet": {
        -1: [(-5, -1), (1, 5)],
        0: [(-4, -1), (1, 4)],
    }
}

BOOT_PALETTES = {
    "straw_sandals": ((45, 34, 29, 255), (139, 94, 48, 255), (213, 170, 87, 255)),
    "leather_boots": ((36, 28, 30, 255), (91, 53, 35, 255), (158, 96, 54, 255)),
    "iron_toe_boots": ((28, 31, 40, 255), (86, 96, 110, 255), (176, 188, 197, 255)),
    "wind_boots": ((24, 35, 44, 255), (51, 112, 125, 255), (119, 201, 199, 255)),
    "dragon_walk_boots": ((27, 36, 31, 255), (55, 109, 69, 255), (141, 184, 90, 255)),
}


def rgba_mask(mask: Image.Image, color=(255, 255, 255, 255)) -> Image.Image:
    """Return an RGBA image whose binary alpha is *mask*."""
    out = Image.new("RGBA", mask.size, color)
    out.putalpha(mask.point(lambda value: 255 if value else 0))
    return out


def alpha(image: Image.Image) -> Image.Image:
    return image.getchannel("A").point(lambda value: 255 if value else 0)


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    image.save(path, "PNG", optimize=False, compress_level=9)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pixel_sha(image: Image.Image) -> str:
    return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def binary_alpha(image: Image.Image) -> bool:
    return set(image.convert("RGBA").getchannel("A").get_flattened_data()).issubset({0, 255})


def build_helmet_mask(slug: str, center_x: int, center_y: int) -> Image.Image:
    mask = Image.new("L", (FRAME_W, FRAME_H), 0)
    pixels = mask.load()
    for dy, spans in HELMET_ROWS[slug].items():
        y = center_y + dy
        if not 0 <= y < FRAME_H:
            continue
        for left, right in spans:
            for x in range(center_x + left, center_x + right + 1):
                if 0 <= x < FRAME_W:
                    pixels[x, y] = 255
    for dy, spans in HELMET_CUTOUTS.get(slug, {}).items():
        y = center_y + dy
        for left, right in spans:
            for x in range(center_x + left, center_x + right + 1):
                if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
                    pixels[x, y] = 0
    return mask


def colorize_helmet(slug: str, mask: Image.Image, center_x: int, center_y: int) -> Image.Image:
    palette = PALETTES[slug]
    eroded = mask.filter(ImageFilter.MinFilter(3))
    border = ImageChops.subtract(mask, eroded)
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    dst = out.load()
    mask_px = mask.load()
    border_px = border.load()
    for y in range(mask.height):
        for x in range(mask.width):
            if not mask_px[x, y]:
                continue
            if border_px[x, y]:
                color = palette["outline"]
            elif x <= center_x - 2 and y <= center_y - 3:
                color = palette["highlight"]
            elif x <= center_x and y <= center_y:
                color = palette["light"]
            elif x >= center_x + 3 or y >= center_y:
                color = palette["shadow"]
            else:
                color = palette["mid"]
            dst[x, y] = color

    # Deliberate family marks remain inside the hard silhouette.
    if slug in {"iron_helmet", "battle_helmet", "knight_helmet"}:
        for dy in range(-7, -1):
            x = center_x
            y = center_y + dy
            if 0 <= y < FRAME_H and mask_px[x, y] and not border_px[x, y]:
                dst[x, y] = palette["light"]
    if slug == "leather_cap":
        y = center_y - 2
        for x in range(center_x - 6, center_x + 4):
            if mask_px[x, y] and not border_px[x, y]:
                dst[x, y] = palette["light"] if x < center_x else palette["mid"]
    if slug == "dragon_head_helmet":
        for y in range(FRAME_H):
            for x in range(FRAME_W):
                if not mask_px[x, y]:
                    continue
                dy = y - center_y
                dx = x - center_x
                # The horns are only two native pixels thick.  Preserve the
                # outside dark pixel and colour the inward pixel so they read
                # at 1x instead of disappearing into the outline.
                horn_inward_pixel = (
                    (dy == -10 and abs(dx) == 8)
                    or (dy == -9 and abs(dx) == 7)
                    or (dy == -8 and abs(dx) == 6)
                )
                if horn_inward_pixel:
                    dst[x, y] = palette["accent_light"] if x < center_x else palette["accent"]
        # Two restrained golden eye pixels under the dragon brow.
        for dx in (-5, 5):
            x = center_x + dx
            y = center_y - 1
            if mask_px[x, y]:
                dst[x, y] = palette["accent_light"]
    return out


def build_helmet_layer(slug: str) -> Image.Image:
    sheet = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    for frame_index, (center_x, center_y) in enumerate(HEAD_ANCHORS):
        frame_mask = build_helmet_mask(slug, center_x, center_y)
        frame = colorize_helmet(slug, frame_mask, center_x, center_y)
        sheet.alpha_composite(frame, (0, frame_index * FRAME_H))
    return sheet


def icon_from_first_frame(layer: Image.Image) -> Image.Image:
    frame = layer.crop((0, 0, FRAME_W, FRAME_H))
    bbox = alpha(frame).getbbox()
    assert bbox is not None
    cropped = frame.crop(bbox)
    assert cropped.width <= 20 and cropped.height <= 20
    icon = Image.new("RGBA", ICON_SIZE, (0, 0, 0, 0))
    icon.alpha_composite(cropped, ((20 - cropped.width) // 2, (20 - cropped.height) // 2))
    return icon


def write_helmet_assets() -> list[Path]:
    written: list[Path] = []
    for slug in HELMETS:
        layer = build_helmet_layer(slug)
        layer_path = HELMET_LAYERS / f"{slug}_base_40x208.png"
        icon_path = ICON_BASE / f"{slug}_base_20x20.png"
        save_png(layer, layer_path)
        save_png(icon_from_first_frame(layer), icon_path)
        written.extend((layer_path, icon_path))
    return written


def write_hair_masks() -> list[Path]:
    hair = Image.open(HERO / "Hero_Neutral_HeadHair_40x208.png").convert("RGBA")
    hair_alpha = alpha(hair)
    written: list[Path] = []
    for slug in HELMETS:
        helmet = Image.open(HELMET_LAYERS / f"{slug}_base_40x208.png").convert("RGBA")
        # Exactly one native pixel of coverage expansion.
        coverage = alpha(helmet).filter(ImageFilter.MaxFilter(3))
        if HAIR_MODES[slug] == "FULL_HIDE":
            forbidden = hair_alpha.copy()
            allowed = Image.new("L", SHEET_SIZE, 0)
        else:
            forbidden = ImageChops.multiply(hair_alpha, coverage)
            allowed = ImageChops.subtract(hair_alpha, forbidden)
        visible = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
        visible.paste(hair, (0, 0), allowed)

        outputs = {
            "allowed_hair_mask": rgba_mask(allowed),
            "forbidden_hair_mask": rgba_mask(forbidden),
            "helmet_coverage_mask": rgba_mask(coverage),
            "visible_hair": visible,
        }
        for suffix, image in outputs.items():
            path = MASKS / f"{slug}_{suffix}_40x208.png"
            save_png(image, path)
            written.append(path)
    return written


def boot_footprint(body_frame: Image.Image) -> Image.Image:
    """Extract the frozen default boot footprint, including its 1px outline."""
    seed = Image.new("L", body_frame.size, 0)
    seed_px = seed.load()
    body_px = body_frame.load()
    default_boot_colors = {(103, 70, 39), (157, 108, 55)}
    for y in range(40, FRAME_H):
        for x in range(FRAME_W):
            if body_px[x, y][3] and body_px[x, y][:3] in default_boot_colors:
                seed_px[x, y] = 255
    expanded = seed.filter(ImageFilter.MaxFilter(3))
    return ImageChops.multiply(expanded, alpha(body_frame))


def colorize_boot(mask: Image.Image, palette: tuple, family_index: int) -> Image.Image:
    dark, mid, light = palette
    eroded = mask.filter(ImageFilter.MinFilter(3))
    border = ImageChops.subtract(mask, eroded)
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    dst = out.load()
    mask_px = mask.load()
    border_px = border.load()
    for y in range(mask.height):
        for x in range(mask.width):
            if not mask_px[x, y]:
                continue
            if border_px[x, y]:
                dst[x, y] = dark
            elif (x + y + family_index) % 5 == 0:
                dst[x, y] = light
            else:
                dst[x, y] = mid
    return out


def write_boot_layers() -> list[Path]:
    body = Image.open(HERO / "Hero_Neutral_Body_40x208.png").convert("RGBA")
    written: list[Path] = []
    for family_index, (slug, palette) in enumerate(BOOT_PALETTES.items()):
        sheet = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
        for frame_index in range(4):
            frame = body.crop((0, frame_index * FRAME_H, FRAME_W, (frame_index + 1) * FRAME_H))
            footprint = boot_footprint(frame)
            boot = colorize_boot(footprint, palette, family_index)
            sheet.alpha_composite(boot, (0, frame_index * FRAME_H))
        path = BOOT_LAYERS / f"{slug}_base_40x208.png"
        save_png(sheet, path)
        written.append(path)
    return written


def shorten_sword(long_sword: Image.Image) -> Image.Image:
    """Keep the original hilt/grip but shorten the metal blade in every frame."""
    brown = (126, 82, 43)
    result = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    for frame_index in range(4):
        frame = long_sword.crop((0, frame_index * FRAME_H, FRAME_W, (frame_index + 1) * FRAME_H))
        source = frame.load()
        handle = [
            (x, y)
            for y in range(FRAME_H)
            for x in range(FRAME_W)
            if source[x, y][3] and source[x, y][:3] == brown
        ]
        assert handle, f"long sword frame {frame_index} has no hilt pixels"
        keep = Image.new("L", (FRAME_W, FRAME_H), 0)
        keep_px = keep.load()
        original_alpha = alpha(frame)
        original_px = original_alpha.load()
        for y in range(FRAME_H):
            for x in range(FRAME_W):
                if not original_px[x, y]:
                    continue
                if source[x, y][:3] == brown:
                    keep_px[x, y] = 255
                    continue
                distance_sq = min((x - hx) ** 2 + (y - hy) ** 2 for hx, hy in handle)
                if distance_sq <= 92:  # about 9.6 native pixels from the fixed hilt
                    keep_px[x, y] = 255

        short_frame = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        short_frame.paste(frame, (0, 0), keep)
        # Any newly exposed metal cut becomes a hard dark tip outline.
        short_px = short_frame.load()
        for y in range(FRAME_H):
            for x in range(FRAME_W):
                if not keep_px[x, y] or source[x, y][:3] == brown:
                    continue
                newly_exposed = False
                for ny in range(max(0, y - 1), min(FRAME_H, y + 2)):
                    for nx in range(max(0, x - 1), min(FRAME_W, x + 2)):
                        if original_px[nx, ny] and not keep_px[nx, ny]:
                            newly_exposed = True
                if newly_exposed:
                    short_px[x, y] = OUTLINE
        result.alpha_composite(short_frame, (0, frame_index * FRAME_H))
    return result


def write_short_sword() -> list[Path]:
    long_path = WEAPON_LAYERS / "long_sword_base_40x208.png"
    short_path = WEAPON_LAYERS / "short_sword_base_40x208.png"
    long_sword = Image.open(long_path).convert("RGBA")
    save_png(shorten_sword(long_sword), short_path)
    return [short_path]


def write_final_helmet_icons() -> list[Path]:
    written: list[Path] = []
    for element in ELEMENTS:
        element_slug = element.lower()
        for slug in HELMETS:
            base = Image.open(ICON_BASE / f"{slug}_base_20x20.png").convert("RGBA")
            particles = Image.open(
                ICON_PARTICLES / element / f"{element_slug}_{slug}_particles_20x20.png"
            ).convert("RGBA")
            final = Image.alpha_composite(base, particles)
            path = ICON_FINAL / element / f"{element_slug}_{slug}_final_20x20.png"
            save_png(final, path)
            written.append(path)
    return written


def write_contact_sheet() -> Path:
    """Two rows: coloured redesigns and unlabelled black silhouettes, both 4x."""
    cell = 88
    sheet = Image.new("RGBA", (cell * 5, cell * 2), (26, 31, 44, 255))
    for column, slug in enumerate(HELMETS):
        icon = Image.open(ICON_BASE / f"{slug}_base_20x20.png").convert("RGBA")
        color_4x = icon.resize((80, 80), Image.Resampling.NEAREST)
        sheet.alpha_composite(color_4x, (column * cell + 4, 4))

        silhouette = Image.new("RGBA", ICON_SIZE, (0, 0, 0, 0))
        silhouette.putalpha(alpha(icon))
        black_4x = silhouette.resize((80, 80), Image.Resampling.NEAREST)
        x0 = column * cell
        sheet.paste((218, 222, 226, 255), (x0, cell, x0 + cell, cell * 2))
        sheet.alpha_composite(black_4x, (x0 + 4, cell + 4))
    path = DESIGN_REFS / "helmet_pixel_redesign_contact_sheet.png"
    save_png(sheet, path)
    return path


def connected_components(mask: Image.Image) -> list[set[tuple[int, int]]]:
    pixels = mask.load()
    remaining = {
        (x, y)
        for y in range(mask.height)
        for x in range(mask.width)
        if pixels[x, y]
    }
    components: list[set[tuple[int, int]]] = []
    while remaining:
        start = next(iter(remaining))
        component = {start}
        queue = deque([start])
        remaining.remove(start)
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    component.add(neighbor)
                    queue.append(neighbor)
        components.append(component)
    return components


def horizontal_runs(mask: Image.Image, y: int) -> list[tuple[int, int]]:
    pixels = mask.load()
    runs = []
    start = None
    for x in range(mask.width + 1):
        opaque = x < mask.width and bool(pixels[x, y])
        if opaque and start is None:
            start = x
        elif not opaque and start is not None:
            runs.append((start, x - 1))
            start = None
    return runs


def validate(generated_pngs: Iterable[Path]) -> list[str]:
    results: list[str] = []
    generated_pngs = list(generated_pngs)
    for path in generated_pngs:
        image = Image.open(path)
        assert image.mode == "RGBA", f"{path}: expected RGBA, got {image.mode}"
        assert binary_alpha(image), f"{path}: semi-transparent pixel found"
    results.append(f"RGBA_BINARY_ALPHA_OK:{len(generated_pngs)}")

    icon_silhouettes = set()
    layer_silhouettes = set()
    for slug in HELMETS:
        icon = Image.open(ICON_BASE / f"{slug}_base_20x20.png").convert("RGBA")
        layer = Image.open(HELMET_LAYERS / f"{slug}_base_40x208.png").convert("RGBA")
        assert icon.size == ICON_SIZE
        assert layer.size == SHEET_SIZE
        icon_silhouettes.add(hashlib.sha256(alpha(icon).tobytes()).hexdigest())
        layer_silhouettes.add(hashlib.sha256(alpha(layer).tobytes()).hexdigest())
        for frame_index in range(4):
            frame_alpha = alpha(
                layer.crop((0, frame_index * FRAME_H, FRAME_W, (frame_index + 1) * FRAME_H))
            )
            assert frame_alpha.getbbox() is not None, f"{slug}: empty frame {frame_index}"
    assert len(icon_silhouettes) == len(HELMETS), "helmet icon silhouettes are not unique"
    assert len(layer_silhouettes) == len(HELMETS), "helmet layer silhouettes are not unique"
    results.append("HELMET_DIMENSIONS_FRAMES_UNIQUE_OK:5")

    for slug in HELMETS:
        allowed = Image.open(MASKS / f"{slug}_allowed_hair_mask_40x208.png").convert("RGBA")
        forbidden = Image.open(MASKS / f"{slug}_forbidden_hair_mask_40x208.png").convert("RGBA")
        coverage = Image.open(MASKS / f"{slug}_helmet_coverage_mask_40x208.png").convert("RGBA")
        visible = Image.open(MASKS / f"{slug}_visible_hair_40x208.png").convert("RGBA")
        for image in (allowed, forbidden, coverage, visible):
            assert image.size == SHEET_SIZE
        leak = ImageChops.multiply(alpha(visible), alpha(forbidden))
        assert leak.getbbox() is None, f"{slug}: visible hair leaks into forbidden region"
        if HAIR_MODES[slug] == "FULL_HIDE":
            assert alpha(allowed).getbbox() is None, f"{slug}: FULL_HIDE allowed mask must be empty"
            assert alpha(visible).getbbox() is None, f"{slug}: FULL_HIDE visible hair must be transparent"
    results.append("HAIR_MASKS_4_TYPES_LEAK_ZERO_OK:5")

    for slug in BOOT_PALETTES:
        sheet = Image.open(BOOT_LAYERS / f"{slug}_base_40x208.png").convert("RGBA")
        assert sheet.size == SHEET_SIZE
        for frame_index in range(4):
            frame_mask = alpha(
                sheet.crop((0, frame_index * FRAME_H, FRAME_W, (frame_index + 1) * FRAME_H))
            )
            components = connected_components(frame_mask)
            assert len(components) == 2, (
                f"{slug}: frame {frame_index} must have two separated feet, got {len(components)}"
            )
            for y in range(FRAME_H):
                runs = horizontal_runs(frame_mask, y)
                assert len(runs) <= 2, f"{slug}: frame {frame_index} row {y} has stray runs"
                if len(runs) == 1:
                    assert runs[0][1] - runs[0][0] < 9, (
                        f"{slug}: frame {frame_index} row {y} forms a horizontal base"
                    )
    results.append("BOOTS_TWO_COMPONENTS_NO_HORIZONTAL_BASE_OK:5x4")

    long_path = WEAPON_LAYERS / "long_sword_base_40x208.png"
    short_path = WEAPON_LAYERS / "short_sword_base_40x208.png"
    assert sha256(long_path) != sha256(short_path), "short and long sword SHA256 are identical"
    long_sword = Image.open(long_path).convert("RGBA")
    short_sword = Image.open(short_path).convert("RGBA")
    for frame_index in range(4):
        long_count = sum(
            1
            for value in alpha(
                long_sword.crop((0, frame_index * FRAME_H, FRAME_W, (frame_index + 1) * FRAME_H))
            ).get_flattened_data()
            if value
        )
        short_count = sum(
            1
            for value in alpha(
                short_sword.crop((0, frame_index * FRAME_H, FRAME_W, (frame_index + 1) * FRAME_H))
            ).get_flattened_data()
            if value
        )
        assert 0 < short_count < long_count, f"short sword frame {frame_index} is not shorter"
    results.append("SHORT_LONG_DISTINCT_AND_SHORTER_OK:4")

    for element in ELEMENTS:
        for slug in HELMETS:
            final = Image.open(
                ICON_FINAL / element / f"{element.lower()}_{slug}_final_20x20.png"
            ).convert("RGBA")
            assert final.size == ICON_SIZE
            assert alpha(final).getbbox() is not None
    results.append("HELMET_FINAL_BASE_PLUS_PARTICLE_OK:25")
    return results


def write_report(paths: Iterable[Path], assertions: Iterable[str]) -> Path:
    report_path = AUDIT / "Asset_Preparation_Report.csv"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(
            (
                "record_type",
                "asset_path_or_assertion",
                "kind",
                "width",
                "height",
                "mode",
                "binary_alpha",
                "sha256",
                "status",
            )
        )
        for path in sorted(set(paths), key=lambda item: item.as_posix().lower()):
            image = Image.open(path)
            writer.writerow(
                (
                    "ASSET",
                    path.relative_to(ROOT).as_posix(),
                    path.parent.name,
                    image.width,
                    image.height,
                    image.mode,
                    str(binary_alpha(image)).upper(),
                    sha256(path),
                    "PASS",
                )
            )
        for assertion in assertions:
            writer.writerow(("ASSERTION", assertion, "", "", "", "", "", "", "PASS"))
    return report_path


def main() -> None:
    generated: list[Path] = []
    generated.extend(write_helmet_assets())
    generated.extend(write_hair_masks())
    generated.extend(write_boot_layers())
    generated.extend(write_short_sword())
    generated.extend(write_final_helmet_icons())
    generated.append(write_contact_sheet())
    assertions = validate(generated)
    report = write_report(generated, assertions)
    print(f"Generated {len(generated)} deterministic PNG assets.")
    print(f"Report: {report.relative_to(ROOT).as_posix()}")
    for result in assertions:
        print(f"PASS {result}")


if __name__ == "__main__":
    main()
