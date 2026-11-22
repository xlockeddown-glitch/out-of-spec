"""Builds the Week 4 voxel models from docs/art/voxel_models.md.

    python tools/voxgen/build_models.py

Writes assets/voxels/<name>.glb (loaded by the game's ModelSlots) and
assets/voxels/source/<name>.vox (open in MagicaVoxel to refine by hand).
These are first passes built from the spec, not final art.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from voxlib import Model  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "voxels"

# Semantic palette (docs/art/voxel_models.md)
TEAL, AMBER, RED, SHADOW = "#38E1C6", "#F5A623", "#FF5A5F", "#1D222B"


# ---------------------------------------------------------------- tractor
def tractor(wide: bool) -> Model:
    """16 x 22 x 25 voxels (W x H x D) at 0.1 m; body 14 high, whip to 2.2 m. Front = -Z."""
    m = Model("tractor_wide" if wide else "tractor")
    HULL, STEEL, GLASS, SAT, TIRE = "#C85A2A", "#4D5663", "#4A7A82", "#E2E8F0", "#101216"
    m.glass_parts.add("glass")

    def wheel(cx_lo: int, cx_hi: int, cz: float, r: float, hub_x: int) -> None:
        m.disc_x("wheels", cx_lo, cx_hi, r, cz, r, TIRE)
        # tread lugs on the rim
        for a in range(0, 360, 30):
            y = r + (r - 0.5) * math.sin(math.radians(a))
            z = cz + (r - 0.5) * math.cos(math.radians(a))
            m.put("wheels", hub_x, math.floor(y), math.floor(z), SHADOW)
        m.disc_x("wheels", hub_x, hub_x, r, cz, 1.6, STEEL)

    # front wheels: 9 voxels across (0.9 m), at z = -0.8 m
    wheel(-8, -6, -7.5, 4.5, -8)
    wheel(5, 7, -7.5, 4.5, 7)
    if wide:
        # Bram's track units on the rear: 5 voxels wide, sprocket and mud scraper
        for x_lo, x_hi, outer in ((-10, -6, -10), (5, 9, 9)):
            for z in range(3, 13):
                for y in range(0, 8):
                    corner = (z in (3, 12)) and (y in (0, 7))
                    if not corner:
                        for x in range(x_lo, x_hi + 1):
                            m.put("wheels", x, y, z, TIRE)
            for z in range(3, 13, 2):
                for x in range(x_lo, x_hi + 1):
                    m.put("wheels", x, 7, z, STEEL)
                    m.put("wheels", x, 0, z, STEEL)
            m.disc_x("wheels", outer, outer, 4.0, 7.5, 2.2, STEEL)
            m.box("body", x_lo, x_hi, 8, 8, 4, 11, SHADOW)
    else:
        wheel(-8, -6, 8.5, 4.5, -8)
        wheel(5, 7, 8.5, 4.5, 7)

    # chassis rails and axles
    m.box("body", -5, 4, 3, 4, -11, 11, SHADOW)
    m.box("body", -8, 7, 4, 4, -8, -7, SHADOW)
    m.box("body", -8, 7, 4, 4, 8, 9, SHADOW)
    # engine hood and grille (front)
    m.box("body", -4, 3, 5, 8, -12, -3, HULL)
    m.box("body", -3, 2, 5, 7, -12, -12, STEEL)
    for x in (-3, -1, 1):
        m.box("body", x, x, 5, 7, -12, -12, SHADOW)
    m.box("body", -1, 0, 9, 10, -6, -5, SHADOW)  # exhaust stack
    m.put("emit_headlights", -4, 7, -12, AMBER)
    m.put("emit_headlights", 3, 7, -12, AMBER)
    # cab: posts, glass, roof
    m.box("body", -5, 4, 5, 7, -2, 6, HULL)
    for x in (-5, 4):
        for z in (-2, 6):
            m.box("body", x, x, 8, 12, z, z, SHADOW)
    m.box("glass", -4, 3, 8, 12, -2, -2, GLASS)
    m.box("glass", -4, 3, 8, 12, 6, 6, GLASS)
    m.box("glass", -5, -5, 8, 12, -1, 5, GLASS)
    m.box("glass", 4, 4, 8, 12, -1, 5, GLASS)
    m.box("body", -5, 4, 13, 13, -2, 6, HULL)
    # sat-phone unit clamped to the roof, with a dark socket for the future readout
    m.box("body", -2, 1, 14, 15, 0, 4, SAT)
    m.box("body", -1, 0, 15, 15, -1, -1, SHADOW)
    m.box("body", 2, 2, 14, 14, 2, 6, SHADOW)  # coiled cable to the whip
    # rear bed and hitch
    m.box("body", -4, 3, 5, 7, 7, 10, HULL)
    m.box("body", -3, 2, 7, 7, 8, 9, SHADOW)
    m.box("body", -1, 0, 3, 4, 11, 11, STEEL)
    # whip antenna at (0.4, 2.2, 0.8) m, matching Rover/Antenna
    m.box("body", 4, 4, 8, 20, 8, 8, STEEL)
    m.put("emit_antenna", 4, 21, 8, TEAL)
    return m


# -------------------------------------------------------------- terrarium
def terrarium() -> Model:
    """14 x 14 x 10 voxels at 0.1 m. Origin on the bench top."""
    m = Model("terrarium")
    FRAME, GLASS, SUB, BARK, BRASS, POD = SHADOW, "#A3D5E0", "#3B2314", "#634E3A", "#9E7D3B", "#D4D9DE"
    m.glass_parts.add("glass")
    m.box("frame", -7, 6, 0, 0, -5, 4, FRAME)
    m.box("substrate", -6, 5, 1, 2, -4, 3, SUB)
    m.box("substrate", -6, -2, 3, 3, -4, -2, SUB)  # rises to the rear-left
    m.box("substrate", -6, -4, 4, 4, -4, -3, SUB)
    # cork bark slab tilted into the back corner
    for i in range(4):
        m.box("decor", -6 + i, -5 + i, 4 + (3 - i) // 2, 5 + (3 - i) // 2, -4, -4, BARK)
    m.box("decor", 2, 4, 3, 3, -3, -2, "#4D5663")  # water dish
    m.box("decor", 3, 3, 3, 3, -3, -2, "#2E5A6B")
    # glass panes and corner posts
    m.box("glass", -6, 5, 1, 8, -5, -5, GLASS)
    m.box("glass", -6, 5, 1, 8, 4, 4, GLASS)
    m.box("glass", -7, -7, 1, 8, -4, 3, GLASS)
    m.box("glass", 6, 6, 1, 8, -4, 3, GLASS)
    for x in (-7, 6):
        for z in (-5, 4):
            m.box("frame", x, x, 1, 9, z, z, FRAME)
    # mesh lid: frame rim with alternating grid
    m.box("frame", -7, 6, 9, 9, -5, -5, FRAME)
    m.box("frame", -7, 6, 9, 9, 4, 4, FRAME)
    m.box("frame", -7, -7, 9, 9, -5, 4, FRAME)
    m.box("frame", 6, 6, 9, 9, -5, 4, FRAME)
    for x in range(-6, 6, 2):
        m.box("frame", x, x, 9, 9, -4, 3, "#333C4D")
    # hygrometer pod clipped to the front-right glass; LED socket (game-driven LED)
    m.box("frame", 4, 5, 5, 7, 4, 4, POD)
    m.put("frame", 5, 6, 4, SHADOW)
    # heat lamp: arm from the rear-right post, brass hood over the center
    m.box("lamp", 6, 6, 10, 13, -5, -5, FRAME)
    m.line("lamp", (6, 13, -5), (1, 13, -1), FRAME)
    m.box("lamp", -1, 0, 12, 13, -1, 0, BRASS)
    m.box("lamp", -2, 1, 11, 11, -2, 1, BRASS)
    m.box("emit_heat_lamp", -1, 0, 11, 11, -1, 0, AMBER)
    return m


def curlyhair() -> Model:
    """Tliltocatl albopilosus, 7 x 3 x 7 voxels at 0.1 m, center origin."""
    m = Model("curlyhair", offset=(-0.5, -0.5, -0.5))
    BODY, GOLD = "#261710", "#D4A359"
    m.box("spider", -1, 1, 0, 1, 1, 3, BODY)  # abdomen (rear, +Z)
    for x, z in ((-1, 2), (1, 1), (0, 3), (1, 3), (-1, 1)):
        m.put("spider", x, 1, z, GOLD)  # curly gold speckle
    m.box("spider", -1, 1, 0, 0, -2, 0, BODY)  # prosoma
    m.put("spider", 0, 1, -1, BODY)
    m.box("spider", -1, 1, 0, 0, -3, -3, BODY)  # chelicerae
    m.put("spider", 0, 0, -3, GOLD)
    for side in (-1, 1):
        for i, z in enumerate((-3, -2, 0, 2)):
            knee_x = side * 2
            m.put("spider", knee_x, 0, z if i else -2, BODY)
            m.put("spider", side * 3, -1, z, GOLD)  # gold-tipped leg ends
            m.put("spider", side * 2, -1, z, BODY)
    return m


# -------------------------------------------------------------- Bram's bay
def bram_bay() -> Model:
    """24 x 16 x 20 voxels at 0.2 m. Open side faces +Z."""
    m = Model("bram_bay", offset=(0.0, 0.0, -2.5))
    CONC, RUST, OVER, SKIN, TOOL, BEARD = "#3D4654", "#7A3E26", "#2B4C65", "#D99B78", "#8C9BAE", "#5E5855"
    m.box("floor", -12, 11, 0, 0, -10, 9, CONC)
    for x, z in ((-6, -2), (-5, -3), (3, 5), (4, 5), (-2, 6)):
        m.put("floor", x, 0, z, SHADOW)  # grease stains
    # I-beam frame
    for x in (-12, 11):
        for z in (-10, 9):
            m.box("frame", x, x, 1, 15, z, z, RUST)
    m.box("frame", -12, 11, 15, 15, -10, -10, RUST)
    m.box("frame", -12, 11, 15, 15, 9, 9, RUST)
    m.box("frame", -12, -12, 15, 15, -10, 9, RUST)
    m.box("frame", 11, 11, 15, 15, -10, 9, RUST)
    m.box("frame", -12, 11, 15, 15, -1, -1, RUST)
    # back wall with pegboard and tools
    m.box("frame", -11, 10, 1, 14, -10, -10, CONC)
    m.box("frame", -9, -1, 5, 11, -10, -10, RUST)
    for x in (-8, -6, -3):
        m.box("props", x, x, 7, 10, -9, -9, TOOL)
    # the broken digital torque wrench: always red, out of calibration
    m.box("props", -5, -5, 6, 10, -9, -9, TOOL)
    m.box("emit_torque_wrench", -5, -5, 9, 10, -9, -9, RED)
    # workbench and diagnostic scope
    m.box("props", 1, 7, 1, 3, -9, -7, CONC)
    m.box("props", 1, 7, 4, 4, -9, -7, SHADOW)
    m.box("props", 2, 4, 5, 6, -9, -8, TOOL)
    m.box("emit_scope", 2, 3, 5, 6, -7, -7, TEAL)
    # tire stack
    for level in range(3):
        y = 1 + level * 2
        m.disc_y("props", -7.5, -5.5, 2.6, y, SHADOW, hollow=1.0)
        m.disc_y("props", -7.5, -5.5, 2.6, y + 1, SHADOW, hollow=1.0)
    # overhead lamp on the middle beam
    m.box("props", -1, 0, 13, 14, -1, -1, SHADOW)
    m.box("props", -2, 1, 12, 12, -3, 0, CONC)
    m.box("emit_work_lamp", -1, 0, 11, 11, -2, -1, AMBER)
    # Bram, ~1.8 m tall, at the greybox spot (1.8, 0, -1.4) m
    bx, bz = 9, -7
    m.box("bram", bx - 1, bx - 1, 1, 1, bz, bz + 1, SHADOW)
    m.box("bram", bx + 1, bx + 1, 1, 1, bz, bz + 1, SHADOW)
    m.box("bram", bx - 1, bx - 1, 2, 3, bz, bz + 1, OVER)
    m.box("bram", bx + 1, bx + 1, 2, 3, bz, bz + 1, OVER)
    m.box("bram", bx - 1, bx + 1, 4, 6, bz, bz + 1, OVER)
    m.box("bram", bx - 2, bx - 2, 5, 6, bz, bz + 1, SKIN)
    m.box("bram", bx + 2, bx + 2, 5, 7, bz, bz + 1, SKIN)
    m.box("bram", bx - 1, bx + 1, 7, 8, bz, bz + 1, SKIN)
    m.box("bram", bx - 1, bx + 1, 7, 7, bz + 2, bz + 2, BEARD)
    m.box("bram", bx - 1, bx + 1, 9, 9, bz, bz + 1, BEARD)
    m.box("bram", bx - 1, bx + 1, 8, 8, bz + 2, bz + 2, TOOL)  # goggles
    # sledgehammer raised over a bent suspension arm in a floor vise
    m.line("bram", (bx + 2, 8, bz), (bx + 3, 11, bz), RUST)
    m.box("bram", bx + 3, bx + 4, 11, 12, bz - 1, bz, TOOL)
    m.box("props", bx + 2, bx + 3, 1, 3, bz + 3, bz + 4, CONC)
    m.line("props", (bx + 1, 4, bz + 3), (bx + 4, 3, bz + 4), TOOL)
    return m


# ---------------------------------------------------------------- fissure
def ore_fissure() -> Model:
    """8 x 6 x 8 voxels at 0.2 m; bottom two layers sit below ground."""
    m = Model("ore_fissure")
    CLAY, CRUST, QUARTZ = "#A8422B", "#6E2617", "#1F7A70"
    for y in (-2, -1):
        m.disc_y("rock", -0.0, 0.0, 4.0, y, CLAY)
    for x, z in ((-3, 1), (2, -3), (3, 2), (-2, -3), (1, 3)):
        m.put("rock", x, -1, z, CRUST)
    for i in range(-3, 3):
        m.put("rock", i, -1, -i - 1, SHADOW)  # diagonal fissure line
        m.put("rock", i, -1, -i, SHADOW)
    spires = [(-1, -1, 2, 3), (-3, -3, 1, 1), (1, -3, 1, 2), (1, 2, 1, 1), (-3, 1, 1, 1)]
    for x, z, w, h in spires:
        m.box("rock", x, x + w - 1, -1, -1, z, z + w - 1, QUARTZ)
        m.box("emit_crystals", x, x + w - 1, 0, h - 1, z, z + w - 1, TEAL)
    m.put("emit_crystals", -1, 3, 0, TEAL)  # main spire tip
    return m


# ------------------------------------------------------- drop-pod, AUD-1T
def drop_pod() -> Model:
    """12 x 16 x 12 voxels at 0.2 m. Hatch faces +Z."""
    m = Model("drop_pod")
    ORANGE, STRUT = "#E85D25", "#4F5D73"
    for x, z in ((-5, -5), (3, -5), (-5, 3), (3, 3)):
        m.box("hull", x, x + 1, 0, 0, z, z + 1, SHADOW)
        m.box("hull", x, x + 1, 1, 3, z, z + 1, STRUT)
    for y in (2, 3):
        m.disc_y("hull", 0, 0, 5.0, y, SHADOW)  # heat shield skirt
    for y in range(4, 12):
        m.disc_y("hull", 0, 0, 5.9, y, STRUT if y in (4, 11) else ORANGE)
    for y, r in ((12, 5.0), (13, 4.0), (14, 2.8)):
        m.disc_y("hull", 0, 0, r, y, ORANGE)
    m.box("hull", -1, 0, 14, 14, -1, 0, STRUT)
    m.box("emit_beacon", -1, 0, 15, 15, -1, 0, TEAL)
    # hatch on +Z with a glowing amber seam
    m.box("hull", -2, 1, 5, 9, 5, 5, STRUT)
    for x in range(-3, 3):
        m.put("emit_hatch", x, 4, 6, AMBER)
        m.put("emit_hatch", x, 10, 6, AMBER)
    for y in range(4, 11):
        m.put("emit_hatch", -3, y, 6, AMBER)
        m.put("emit_hatch", 2, y, 6, AMBER)
    return m


def aud1t() -> Model:
    """4 x 5 x 4 voxels at 0.2 m, center origin. One amber eye on +Z."""
    m = Model("aud1t", offset=(0.0, -0.5, 0.0))
    WHITE = "#F0F4F8"
    m.box("shell", -2, 1, -1, 1, -2, 1, WHITE)
    for x in (-2, 1):
        for z in (-2, 1):
            m.clear(x, 1, z)
    m.box("shell", -1, 0, 2, 2, -1, 0, WHITE)
    m.box("shell", -2, 1, 0, 0, 1, 1, SHADOW)  # visor band around the eye
    m.box("emit_eye", -1, 0, 0, 0, 1, 1, AMBER)
    m.box("shell", -1, 0, -2, -2, -1, 0, SHADOW)
    for x, z in ((-2, -1), (1, -1), (-1, -2), (0, 1)):
        m.put("emit_lift_ring", x, -2, z, TEAL)
    return m


# ---------------------------------------------------------------- relay
def relay_mast() -> Model:
    """After Neon's concept sheet: square lattice tower on a concrete plinth, side-
    mounted dish near the top, beacon cap, caged spool bay low on the tower and a
    cyan fiber run (emit_fiber, shown only once a spool is installed). 0.5 m voxels.
    Matches the scene: SpoolBay at (2.0, 3, 0) m, Dish at (2.0, 15.5, 2.0) m,
    beacon light at (0, 17, 0) m.
    """
    m = Model("relay_mast")
    LATTICE, PLINTH, DISH, FLANGE = "#526075", "#5C6067", "#E1E8F0", "#C48F2B"
    lo, hi, top, bay = -3, 2, 30, 6  # leg columns, tower top, brace panel height
    # plinth
    m.box("mast", lo - 2, hi + 2, 0, 0, lo - 2, hi + 2, PLINTH)
    m.box("mast", lo - 1, hi + 1, 1, 1, lo - 1, hi + 1, PLINTH)
    # four legs, rings, and one zigzag diagonal per panel (Warren truss look)
    for x in (lo, hi):
        for z in (lo, hi):
            m.box("mast", x, x, 2, top, z, z, LATTICE)
    for y in range(2, top + 1, bay):
        for a, b in ((lo, lo), (hi, hi)):
            m.box("mast", lo, hi, y, y, a, b, LATTICE)
            m.box("mast", a, b, y, y, lo, hi, LATTICE)
    for i, y0 in enumerate(range(2, top, bay)):
        y1 = y0 + bay
        flip = i % 2 == 1
        for zf in (lo, hi):
            m.line("mast", (hi if flip else lo, y0, zf), (lo if flip else hi, y1, zf), LATTICE)
        for xf in (lo, hi):
            m.line("mast", (xf, y0, hi if flip else lo), (xf, y1, lo if flip else hi), LATTICE)
    # cap and beacon stub
    m.box("mast", lo, hi, top + 1, top + 1, lo, hi, SHADOW)
    m.box("mast", -1, 0, top + 2, top + 3, -1, 0, LATTICE)
    # side-mounted dish facing the farm (+X +Z, tipped up), on the Dish marker
    n = (1.0, 0.45, 1.0)
    ln = math.sqrt(sum(v * v for v in n))
    n = tuple(v / ln for v in n)
    c = (4.0, 31.0, 4.0)
    m.line("mast", (hi, 29, hi), (hi + 1, 30, hi + 1), LATTICE)  # mount arm
    for x in range(0, 9):
        for y in range(26, 37):
            for z in range(0, 9):
                p = (x + 0.5 - c[0], y + 0.5 - c[1], z + 0.5 - c[2])
                d = sum(p[i] * n[i] for i in range(3))
                r2 = sum(v * v for v in p) - d * d
                if abs(d + 0.06 * r2) <= 0.5 and r2 <= 3.2 ** 2:
                    m.put("mast", x, y, z, DISH)
    m.line("mast", c, (c[0] + n[0] * 2.5, c[1] + n[1] * 2.5, c[2] + n[2] * 2.5), SHADOW)  # feed horn
    # spool bay cage on +X, low on the tower; the game's spool sits in the pocket
    for x in (3, 5):
        for z in (-2, 1):
            m.box("mast", x, x, 4, 8, z, z, LATTICE)
    m.box("mast", 3, 5, 4, 4, -2, 1, SHADOW)   # floor
    m.box("mast", 3, 5, 8, 8, -2, 1, LATTICE)  # roof
    m.box("mast", 3, 5, 5, 7, -2, -2, SHADOW)  # back panel
    for y in (5, 7):  # gold-anodized flange guides either side of the pocket
        m.put("mast", 5, y, -1, FLANGE)
        m.put("mast", 5, y, 0, FLANGE)
    m.clear_box(3, 4, 5, 7, -1, 0)
    m.put("emit_bay_lamp", 4, 7, -2, AMBER)
    # fiber run from the bay up beside the +X+Z leg to the dish (shown once a spool is in)
    m.box("emit_fiber", hi + 1, hi + 1, 9, 29, hi, hi, TEAL)
    m.line("emit_fiber", (hi + 1, 29, hi), (hi + 2, 30, hi + 1), TEAL)
    # beacon last so nothing overwrites it: 17 m, where the beacon light sits
    m.box("emit_beacon", -1, 0, 34, 34, -1, 0, TEAL)
    return m


MODELS = [
    (lambda: tractor(False), 0.1), (lambda: tractor(True), 0.1),
    (terrarium, 0.1), (curlyhair, 0.1), (bram_bay, 0.2), (ore_fissure, 0.2),
    (drop_pod, 0.2), (aud1t, 0.2), (relay_mast, 0.5),
]


def main() -> None:
    (OUT / "source").mkdir(parents=True, exist_ok=True)
    for build, voxel_m in MODELS:
        m = build()
        m.write_glb(OUT / f"{m.name}.glb")
        m.write_vox(OUT / "source" / f"{m.name}.vox")
        w, h, d = m.size()
        print(f"{m.name:13} {w:3} x {h:3} x {d:3} voxels = "
              f"{w * voxel_m:.1f} m x {h * voxel_m:.1f} m x {d * voxel_m:.1f} m, "
              f"{len(m.voxels):5} voxels, {len(m.colors()):2} colors")


if __name__ == "__main__":
    main()
