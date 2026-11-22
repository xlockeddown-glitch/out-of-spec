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
    """After Neon's concept sheet. 16 (20 wide) x 19 x 25 voxels at 0.1 m. Front = -Z.
    Big rear wheels, small front wheels, mustard lower panels, chrome grille,
    amber headlights, roof dish (uplink, at the Rover/Antenna marker) and a cyan
    roof beacon. Wide variant: full-length tracks and amber roof lights.
    """
    m = Model("tractor_wide" if wide else "tractor")
    HULL, PANEL, GRILLE, CHROME = "#C85A2A", "#C9962E", "#2A2F38", "#8C96A6"
    GLASS, TIRE, DISH = "#4A7A82", "#101216", "#E2E8F0"
    m.glass_parts.add("glass")

    def wheel(x0: int, x1: int, cy: float, cz: float, r: float, outer: int) -> None:
        m.disc_x("wheels", x0, x1, cy, cz, r, TIRE)
        for a in range(0, 360, 30):  # tread lugs
            y = cy + (r - 0.5) * math.sin(math.radians(a))
            z = cz + (r - 0.5) * math.cos(math.radians(a))
            m.put("wheels", outer, math.floor(y), math.floor(z), GRILLE)
        m.disc_x("wheels", outer, outer, cy, cz, r * 0.45, CHROME)

    def track(x0: int, x1: int, outer: int) -> None:
        for z in range(-11, 12):
            for y in range(0, 8):
                end = z in (-11, 11) and y in (0, 7)
                if not end:
                    for x in range(x0, x1 + 1):
                        m.put("wheels", x, y, z, TIRE)
        for z in range(-11, 12, 2):  # lugs on the ground run
            for x in range(x0, x1 + 1):
                m.put("wheels", x, 0, z, GRILLE)
        m.disc_x("wheels", outer, outer, 4.0, 8.0, 2.6, CHROME)   # drive sprocket
        m.disc_x("wheels", outer, outer, 4.0, -8.0, 2.0, CHROME)  # idler
        m.disc_x("wheels", outer, outer, 2.5, 0.0, 1.4, CHROME)   # road wheel
        m.box("body", x0, x1, 8, 8, -10, 10, HULL)                # fender

    if wide:
        track(-10, -6, -10)
        track(5, 9, 9)
    else:
        wheel(-8, -6, 6.0, 6.0, 6.0, -8)     # big rear wheels, 1.2 m
        wheel(5, 7, 6.0, 6.0, 6.0, 7)
        wheel(-7, -6, 3.5, -8.0, 3.5, -7)    # small front wheels, 0.7 m
        wheel(5, 6, 3.5, -8.0, 3.5, 6)
        m.box("body", -8, -6, 12, 12, 1, 11, HULL)  # rear fenders
        m.box("body", 5, 7, 12, 12, 1, 11, HULL)

    # chassis and axles
    m.box("body", -4, 3, 3, 4, -11, 11, SHADOW)
    if not wide:
        m.box("body", -5, 4, 3, 3, -8, -8, SHADOW)  # front axle
    # hood with mustard lower panels, chrome-slatted grille, amber headlights
    m.box("body", -3, 2, 5, 9, -12, -3, HULL)
    m.box("body", -3, -3, 5, 6, -12, -3, PANEL)
    m.box("body", 2, 2, 5, 6, -12, -3, PANEL)
    m.box("body", -2, 1, 5, 8, -12, -12, GRILLE)
    for y in (5, 7):
        m.box("body", -2, 1, y, y, -12, -12, CHROME)
    m.put("emit_headlights", -3, 8, -12, AMBER)
    m.put("emit_headlights", 2, 8, -12, AMBER)
    m.box("body", 1, 1, 10, 13, -6, -6, SHADOW)  # exhaust stack
    # cab: mustard-skirted base, posts, glass, overhanging roof
    m.box("body", -5, 4, 5, 8, -2, 7, HULL)
    m.box("body", -5, -5, 5, 6, -2, 7, PANEL)
    m.box("body", 4, 4, 5, 6, -2, 7, PANEL)
    for x in (-5, 4):
        for z in (-2, 7):
            m.box("body", x, x, 9, 13, z, z, SHADOW)
    m.box("glass", -4, 3, 9, 13, -2, -2, GLASS)
    m.box("glass", -4, 3, 9, 13, 7, 7, GLASS)
    m.box("glass", -5, -5, 9, 13, -1, 6, GLASS)
    m.box("glass", 4, 4, 9, 13, -1, 6, GLASS)
    m.box("body", -6, 5, 14, 14, -3, 8, HULL)
    if wide:
        m.put("emit_roof_lights", -6, 14, -3, AMBER)
        m.put("emit_roof_lights", 5, 14, -3, AMBER)
    # cyan roof beacon (front) and the uplink dish (rear), Rover/Antenna at its center
    m.box("emit_beacon", -1, 0, 15, 15, -2, -1, TEAL)
    m.box("body", 2, 2, 15, 16, 4, 4, SHADOW)  # dish post
    n = (-0.25, 1.0, -0.55)
    ln = math.sqrt(sum(v * v for v in n))
    n = tuple(v / ln for v in n)
    c = (2.5, 17.5, 4.5)
    for x in range(-1, 6):
        for y in range(15, 21):
            for z in range(1, 8):
                pnt = (x + 0.5 - c[0], y + 0.5 - c[1], z + 0.5 - c[2])
                d = sum(pnt[i] * n[i] for i in range(3))
                r2 = sum(v * v for v in pnt) - d * d
                if abs(d - 0.08 * r2) <= 0.5 and r2 <= 2.6 ** 2:
                    m.put("body", x, y, z, DISH)
    m.line("body", c, (c[0] + n[0] * 1.5, c[1] + n[1] * 1.5, c[2] + n[2] * 1.5), SHADOW)
    # rear hitch
    m.box("body", -1, 0, 3, 4, 12, 12, CHROME)
    return m


# -------------------------------------------------------------- terrarium
def terrarium() -> Model:
    """After Neon's concept sheet. 14 x 15 x 10 voxels at 0.1 m; origin on the bench.
    Glass tank with slate posts, amber dome heat lamp on a bracket, half-log hide,
    round water dish, pebbles. Hygrometer pod front-right (LED is game-driven).
    """
    m = Model("terrarium")
    FRAME, GLASS, SUB, SUB2, BARK, BARK2 = SHADOW, "#A3D5E0", "#3B2314", "#5A3A22", "#634E3A", "#8A6A4A"
    PEBBLE, BOWL, WATER, POD = "#6B5A4A", "#8C96A6", "#2E5A6B", "#D4D9DE"
    m.glass_parts.add("glass")
    m.box("frame", -7, 6, 0, 0, -5, 4, FRAME)
    m.box("substrate", -6, 5, 1, 2, -4, 3, SUB)  # top at 0.3 m, where the spider stands
    for x, z in ((-5, 1), (-2, -1), (1, 2), (3, -3), (4, 0), (-1, 3), (2, -2)):
        m.put("substrate", x, 2, z, SUB2)
    for x, z in ((2, 3), (5, -4), (-6, 3)):
        m.put("decor", x, 3, z, PEBBLE)
    # half-log hide, back-left, hollow so it reads as a tunnel
    cy, cz, r_out, r_in = 3.0, -2.5, 2.4, 1.3
    for x in range(-6, -1):
        for y in range(3, 6):
            for z in range(-5, 0):
                d2 = (y + 0.5 - cy) ** 2 + (z + 0.5 - cz) ** 2
                if r_in * r_in < d2 <= r_out * r_out:
                    m.put("decor", x, y, z, BARK2 if x in (-6, -2) else BARK)
    # water dish, front-left
    m.disc_y("decor", -3.5, 2.0, 1.6, 3, BOWL, hollow=0.8)
    m.disc_y("decor", -3.5, 2.0, 0.9, 3, WATER)
    # glass panes, slate corner posts and top frame
    m.box("glass", -6, 5, 1, 10, -5, -5, GLASS)
    m.box("glass", -6, 5, 1, 10, 4, 4, GLASS)
    m.box("glass", -7, -7, 1, 10, -4, 3, GLASS)
    m.box("glass", 6, 6, 1, 10, -4, 3, GLASS)
    for x in (-7, 6):
        for z in (-5, 4):
            m.box("frame", x, x, 1, 11, z, z, FRAME)
    m.box("frame", -7, 6, 11, 11, -5, -5, FRAME)
    m.box("frame", -7, 6, 11, 11, 4, 4, FRAME)
    m.box("frame", -7, -7, 11, 11, -5, 4, FRAME)
    m.box("frame", 6, 6, 11, 11, -5, 4, FRAME)
    # hygrometer pod clipped to the front-right glass; LED socket (game-driven LED)
    m.box("frame", 4, 5, 5, 7, 4, 4, POD)
    m.put("frame", 5, 6, 4, SHADOW)
    # heat lamp: bracket from the rear-right post, glowing amber dome over the center
    m.box("lamp", 6, 6, 12, 14, -5, -5, FRAME)
    m.line("lamp", (6, 14, -5), (0, 14, -1), FRAME)
    for y, r in ((12, 2.6), (13, 2.0)):
        m.disc_y("emit_heat_lamp", -0.0, 0.0, r, y, AMBER)
    m.box("lamp", -1, 0, 14, 14, -1, 0, FRAME)  # socket
    return m


def curlyhair() -> Model:
    """Tliltocatl albopilosus, 7 x 3 x 7 voxels at 0.1 m, center origin. Dark brown
    body with curly gold speckle; 8 legs, gold at the tips."""
    m = Model("curlyhair", offset=(-0.5, -0.5, -0.5))
    BODY, GOLD = "#261710", "#D4A359"
    m.box("spider", -1, 1, 0, 1, 1, 3, BODY)    # abdomen (rear, +Z)
    for x, y, z in ((-1, 1, 2), (1, 1, 1), (0, 1, 3), (1, 0, 3), (-1, 0, 1), (0, 1, 1)):
        m.put("spider", x, y, z, GOLD)           # curly gold speckle
    m.box("spider", -1, 1, 0, 0, -2, 0, BODY)   # prosoma
    m.put("spider", 0, 1, -1, BODY)
    m.box("spider", -1, 0, 0, 0, -3, -3, BODY)  # chelicerae
    for side in (-1, 1):
        for hip_z, tip_z in ((-2, -3), (-1, -1), (0, 1), (0, 3)):
            m.put("spider", side * 2, 1, hip_z, BODY)       # raised knee
            m.put("spider", side * 2, 0, (hip_z + tip_z) // 2, BODY)
            m.put("spider", side * 3, 0, tip_z, BODY)
            m.put("spider", side * 3, -1, tip_z, GOLD)      # gold-tipped foot
    return m


# -------------------------------------------------------------- Bram's bay
def bram_bay() -> Model:
    """After Neon's concept sheet. 25 x 18 x 20 voxels at 0.2 m; open side faces +Z;
    the slab is sunk so its top is flush with the ground (the rover drives in).
    Timber posts, lean-to corrugated roof over the back half (the front stays open
    so the game camera sees in), pegboard tool wall, tire stacks, barrels,
    workbench monitor, two hanging amber lamps, and Bram with a pipe wrench.
    """
    m = Model("bram_bay", offset=(0.0, -1.0, -2.5))
    SLAB, POST, PEG, WOOD = "#8A857A", "#5A3A2A", "#8B6A3F", "#6B4A2A"
    RUST, ROOF2, ROOF3, TOOL, REDTOOL = "#8A4A2A", "#6B4A3A", "#8C8C8C", "#8C96A6", "#B0392B"
    NAVY, SKIN, HAIR, LENS = "#2B3C65", "#D99B78", "#6B3F1F", "#2A3A40"
    m.box("floor", -12, 11, 0, 0, -10, 9, SLAB)
    for x, z in ((-6, -2), (-5, -3), (3, 5), (4, 5), (-2, 6), (0, -6), (6, 2)):
        m.put("floor", x, 0, z, SHADOW)  # oil stains
    # timber posts: tall at the back, shorter at the front (lean-to)
    for x in (-12, 11):
        m.box("frame", x, x, 1, 16, -10, -10, POST)
        m.box("frame", x, x, 1, 13, 9, 9, POST)
        m.box("frame", x, x, 1, 14, -1, -1, POST)
    m.box("frame", -12, 11, 13, 13, 9, 9, POST)   # front beam
    for x in (-12, 11):
        m.line("frame", (x, 16, -10), (x, 13, 9), POST)  # side rafters
    # corrugated roof over the back half, sloping toward the front
    panels = ((RUST, "#6E3A22"), (ROOF2, "#553A2E"), (ROOF3, "#707070"), (RUST, "#6E3A22"), (ROOF2, "#553A2E"))
    for z in range(-10, 0):
        y = math.floor(16 - (z + 10) * 3 / 19)  # sits on the rafters
        for x in range(-12, 12):
            light, dark = panels[((x + 12) // 5) % len(panels)]
            m.put("roof", x, y + 1, z, light if x % 2 else dark)
    # back wall: lower planks and the pegboard with tools
    m.box("frame", -11, 10, 1, 5, -10, -10, WOOD)
    m.box("frame", -9, -1, 6, 10, -10, -10, PEG)
    for x, color in ((-8, TOOL), (-7, REDTOOL), (-4, TOOL), (-3, REDTOOL), (-2, TOOL)):
        m.box("props", x, x, 7, 9, -9, -9, color)
    # the broken digital torque wrench: always red, out of calibration
    m.box("props", -6, -6, 6, 10, -9, -9, TOOL)
    m.box("emit_torque_wrench", -6, -6, 9, 10, -9, -9, RED)
    # workbench with the diagnostic monitor (cyan screen)
    m.box("props", 2, 8, 1, 3, -9, -7, WOOD)
    m.box("props", 2, 8, 4, 4, -9, -7, SHADOW)
    m.box("props", 5, 7, 5, 7, -9, -9, SHADOW)
    m.box("emit_scope", 5, 6, 5, 6, -8, -8, TEAL)
    # tire stacks (rings) back-left and front-left
    for cx, cz, levels in ((-8.5, -6.5, 4), (-9.0, 4.5, 2), (-5.5, -7.5, 2)):
        for level in range(levels):
            m.disc_y("props", cx, cz, 1.9, 1 + level, SHADOW, hollow=0.8)
    # rusty oil barrels with a grey band
    for bx0, bz0 in ((-10, 0), (8, 5), (9, 2)):
        for y in range(1, 6):
            m.disc_y("props", bx0 + 0.5, bz0 + 0.5, 1.2, y, TOOL if y == 3 else RUST)
    # two hanging amber lamps
    for lx in (-6, 3):
        m.box("props", lx, lx, 12, 16, -4, -4, SHADOW)
        m.box("emit_work_lamp", lx - 1, lx, 11, 11, -5, -4, AMBER)
    # Bram (chibi): boots, navy coveralls, big head, messy hair, goggles up
    bx, bz = 9, -7
    for x in (bx - 1, bx + 1):
        m.box("bram", x, x, 1, 1, bz, bz + 1, SHADOW)
        m.box("bram", x, x, 2, 2, bz, bz + 1, NAVY)
    m.box("bram", bx - 1, bx + 1, 3, 5, bz, bz + 1, NAVY)
    m.box("bram", bx - 1, bx + 1, 3, 3, bz, bz + 1, WOOD)  # tool belt
    m.box("bram", bx - 2, bx - 2, 4, 5, bz, bz + 1, NAVY)
    m.box("bram", bx + 2, bx + 2, 4, 5, bz, bz + 1, NAVY)
    m.put("bram", bx - 2, 3, bz + 1, SKIN)
    m.put("bram", bx + 2, 3, bz + 1, SKIN)
    m.box("bram", bx - 1, bx + 1, 6, 8, bz - 1, bz + 1, SKIN)
    m.box("bram", bx - 1, bx + 1, 9, 9, bz - 1, bz + 1, HAIR)
    for x, z in ((bx - 1, bz - 1), (bx + 1, bz), (bx, bz + 1)):
        m.put("bram", x, 10, z, HAIR)
    m.box("bram", bx - 1, bx + 1, 8, 8, bz + 1, bz + 1, LENS)  # goggles on the forehead
    # pipe wrench held across the body
    m.line("bram", (bx - 2, 3, bz + 2), (bx + 2, 5, bz + 2), REDTOOL)
    m.box("bram", bx + 2, bx + 3, 5, 6, bz + 2, bz + 2, TOOL)
    return m


# ---------------------------------------------------------------- fissure
def ore_fissure() -> Model:
    """After Neon's concept sheet. 8 x 7 x 8 voxels at 0.2 m. Cracked terracotta
    flush with the ground (two layers sunk), a dark jagged fissure, and clusters of
    tall pointed cyan crystals growing out of the crack."""
    m = Model("ore_fissure")
    CLAY, CLAY2, CRACK, QUARTZ = "#A8422B", "#8E3522", "#5E2214", "#1F7A70"
    m.box("rock", -4, 3, -2, -1, -4, 3, CLAY)
    for x, z in ((-3, -2), (-2, -2), (2, -3), (2, 1), (3, 1), (-3, 2), (-2, 3), (0, 3)):
        m.put("rock", x, -1, z, CRACK)  # hairline surface cracks
    for x, z in ((-4, 0), (3, -1), (-1, -4), (1, 3)):
        m.put("rock", x, -1, z, CLAY2)
    # the fissure: a jagged diagonal with a short branch, open down to the quartz
    path = [(-3, 3), (-2, 2), (-2, 1), (-1, 1), (-1, 0), (0, 0), (0, -1), (1, -1), (1, -2), (2, -3)]
    for i, (x, z) in enumerate(path + [(1, 1), (2, 2)]):
        m.put("rock", x, -1, z, QUARTZ if i % 3 == 1 else SHADOW)  # quartz glints in the crack
        m.put("rock", x, -2, z, QUARTZ)

    def crystal(x: int, z: int, h: int, lean: tuple[int, int]) -> None:
        for y in range(0, h):
            dx, dz = int(lean[0] * y / 3), int(lean[1] * y / 3)
            m.put("emit_crystals", x + dx, y, z + dz, TEAL)
            if y < h - 2:  # thicker shaft, single-voxel point
                m.put("emit_crystals", x + dx + (1 if lean[0] >= 0 else -1), y, z + dz, TEAL)
    crystal(-1, 0, 5, (0, 0))      # main cluster in the crack
    crystal(0, -1, 4, (1, -1))
    crystal(-2, 1, 3, (-1, 1))
    crystal(1, -2, 3, (1, 0))
    crystal(2, 2, 2, (0, 1))       # branch shard
    crystal(-3, 3, 2, (-1, 0))
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
    beacon light at (0, 17.25, 0) m.
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
        y1 = min(y0 + bay, top)
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
                if abs(d - 0.06 * r2) <= 0.5 and r2 <= 3.2 ** 2:
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
    m.line("emit_fiber", (hi + 1, 29, hi), (hi + 1, 30, hi + 1), TEAL)
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
