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
# Answer A: small lit details (eyes, LEDs, small lamps) get a 1-voxel #1D222B
# border. Ryan's cutoff: emit_* parts of at most 9 voxels. Today's lit parts are
# 1-9 or 22+ voxels, so any value from 9 to 21 borders the same parts.
BORDER_MAX_PART_VOXELS = 9
# Models the border pass skips. The FM-3 case is 6 x 4 x 3 voxels: the pass would paint both
# meter voxels and most of the shell around its 2-voxel screen, and Gemini already set the
# screen on dark foam (S).
BORDER_SKIP = {"fm3_field_meter_case"}


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
    # keep the lit-part border off Bram and the red tool beside the torque wrench
    m.border_protect |= {("bram", None), ("props", REDTOOL)}
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
    """After Neon's concept sheet. 18 x 21 x 18 voxels at 0.2 m. Square hull with
    chamfered slate corner struts, a scorched lower band, a stepped pyramid nose with
    a teal beacon, a +Z hatch with a glowing amber outline, and four splayed legs."""
    m = Model("drop_pod")
    ORANGE, ORANGE2, STRUT, SCORCH, HANDLE = "#E85D25", "#C94E1E", "#4F5D73", "#2A211C", "#3A4150"
    m.box("hull", -5, 4, 3, 12, -5, 4, ORANGE)
    for x, z in ((-5, -5), (-5, 4), (4, -5), (4, 4)):      # chamfer the hull corners
        m.clear_box(x, x, 3, 12, z, z)
    for y in range(3, 6):                                    # scorched lower band
        for x in range(-5, 5):
            for z in range(-5, 5):
                if (x, y, z) in m.voxels and (x in (-5, 4) or z in (-5, 4) or x in (-4, 3) and z in (-4, 3)):
                    m.put("hull", x, y, z, SCORCH if (x + z + y) % 3 else "#3A2A20")
    m.box("hull", -4, 3, 2, 2, -4, 3, SCORCH)               # heat-shield base
    for x, z in ((-6, -6), (-6, 4), (4, -6), (4, 4)):        # slate corner struts with caps
        m.box("hull", x, x + 1, 3, 13, z, z + 1, STRUT)
    for i, half in enumerate((4.5, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0)):  # stepped pyramid nose
        lo, hi = math.floor(-half), math.ceil(half) - 1
        m.box("hull", lo, hi, 13 + i, 13 + i, lo, hi, ORANGE if i % 2 == 0 else ORANGE2)
    m.box("emit_beacon", -1, 0, 20, 20, -1, 0, TEAL)
    # hatch on +Z: amber outline, orange door, slate handle
    for x in range(-3, 3):
        m.put("emit_hatch", x, 5, 5, AMBER)
        m.put("emit_hatch", x, 11, 5, AMBER)
    for y in range(5, 12):
        m.put("emit_hatch", -3, y, 5, AMBER)
        m.put("emit_hatch", 2, y, 5, AMBER)
    m.box("hull", -2, 1, 6, 10, 5, 5, ORANGE2)
    m.box("hull", 1, 1, 8, 8, 5, 5, HANDLE)
    # raised side panel on -X
    m.box("hull", -6, -6, 6, 10, -2, 1, ORANGE2)
    # four splayed landing legs: orange upper, slate lower, orange foot pads
    for sx in (-1, 1):
        for sz in (-1, 1):
            # line(thick=2) grows toward +X/+Z, so shift the -X/-Z legs out by one
            ox, oz = (-1 if sx < 0 else 0), (-1 if sz < 0 else 0)
            top = (sx * 4.5 + ox, 7, sz * 4.5 + oz)
            knee = (sx * 6.5 + ox, 3, sz * 6.5 + oz)
            foot = (sx * 7.5, 0, sz * 7.5)
            m.line("hull", top, knee, ORANGE, thick=2)
            m.line("hull", knee, foot, STRUT, thick=2)
            fx, fz = math.floor(foot[0]), math.floor(foot[2])
            m.box("hull", fx - 1, fx + 1, 0, 0, fz - 1, fz + 1, ORANGE)
    return m


def aud1t() -> Model:
    """After Neon's concept sheet. 5 x 5 x 5 voxels at 0.2 m, center origin. Rounded
    white shell, a dark visor band with ONE amber cross-shaped eye, teal lift ring."""
    m = Model("aud1t", offset=(-0.5, -0.5, -0.5))
    WHITE, WHITE2 = "#F0F4F8", "#D8DEE6"
    m.box("shell", -2, 2, -1, 2, -2, 2, WHITE)
    for x in (-2, 2):
        for z in (-2, 2):
            m.clear(x, 2, z)
            m.clear(x, -1, z)
    m.box("shell", -1, 1, 2, 2, -1, 1, WHITE2)                # top bevel
    m.box("shell", -2, 2, -1, 1, 2, 2, SHADOW)                # visor band across the front
    m.clear(-2, -1, 2)                                        # keep the rounded bottom corners
    m.clear(2, -1, 2)
    for x, y in ((1, 0), (0, 0), (2, 0), (1, 1), (1, -1)):    # the one eye, off-center like the sheet
        m.put("emit_eye", x, y, 2, AMBER)
    m.box("shell", -1, 1, -2, -2, -1, 1, WHITE2)
    for x, z in ((-1, -1), (0, -1), (1, -1), (-1, 1), (0, 1), (1, 1), (-1, 0), (1, 0)):
        m.put("emit_lift_ring", x, -2, z, TEAL)
    m.clear(0, -2, 0)
    m.put("shell", 0, -2, 0, SHADOW)
    return m


# ------------------------------------------------------------- dome room
def dome_room() -> Model:
    """After Neon's dome-interior sheet. The habitat room shell at 0.2 m: arched,
    ribbed vault (14 m wide, 5.6 m peak, 10 m deep, open at the front toward the
    camera), back wall with a round airlock and a cyan ring, a door panel with teal
    LEDs, and three amber pendant lamps. Origin = room origin (floor top at 0)."""
    m = Model("dome_room")
    FLOOR, SHELL, RIB, BACK, DOOR = "#6B7078", "#4A5262", "#3A4150", "#3F4756", "#2F3540"
    a_in, b_in = 34.5, 27.0
    m.box("floor", -35, 34, -1, -1, -20, 29, FLOOR)
    for z in range(-20, 30, 5):
        m.box("floor", -35, 34, -1, -1, z, z, "#62676F")      # floor seams
    for z in range(-20, 30):
        rib = z % 10 == 0 or z == 29
        a_o, b_o = (36.5, 29.0) if rib else (35.5, 28.0)
        a_i, b_i = (33.5, 26.0) if rib else (a_in, b_in)
        for x in range(-37, 37):
            for y in range(0, 30):
                px, py = x + 0.5, y + 0.5
                outer = px * px / (a_o * a_o) + py * py / (b_o * b_o) <= 1.0
                inner = px * px / (a_i * a_i) + py * py / (b_i * b_i) <= 1.0
                if outer and not inner:
                    m.put("shell", x, y, z, RIB if rib else SHELL)
    # back wall filling the arch, with vertical panel seams
    for x in range(-35, 35):
        for y in range(0, 28):
            if (x + 0.5) ** 2 / a_in ** 2 + (y + 0.5) ** 2 / b_in ** 2 <= 1.0:
                m.put("shell", x, y, -20, RIB if x % 7 == 0 else BACK)
    # round airlock at (0, 1.4, -3.84) m: stepped frame, door, cyan ring, seam
    cy = 7.0
    for x in range(-10, 10):
        for y in range(0, 17):
            d = ((x + 0.5) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5
            if d <= 8.6:
                if d > 7.6:
                    m.put("shell", x, y, -19, RIB)
                elif d > 6.6:
                    m.put("emit_airlock_ring", x, y, -19, TEAL)
                else:
                    m.put("shell", x, y, -19, DOOR)
    for y, x in ((1, 0), (2, 0), (3, -1), (4, -1), (5, 0), (6, 0), (7, -1), (8, -1), (9, 0), (10, 0), (11, -1), (12, -1)):
        m.put("shell", x, y, -18, SHADOW)                     # jagged door seam
    m.box("shell", 11, 12, 8, 10, -19, -19, SHADOW)           # door control panel
    m.put("emit_panel", 12, 9, -18, TEAL)
    m.put("emit_panel", 12, 8, -18, TEAL)
    # three amber pendant lamps hung from the vault
    for lx, lz in ((-15, 0), (0, -5), (15, 0)):
        top = math.floor(b_in * math.sqrt(max(0.0, 1 - ((lx + 0.5) / a_in) ** 2)))
        m.box("lamps", lx, lx, 21, top, lz, lz, SHADOW)
        m.disc_y("lamps", lx + 0.5, lz + 0.5, 1.2, 20, "#8C96A6")
        m.disc_y("emit_lamps", lx + 0.5, lz + 0.5, 2.2, 19, AMBER)
        m.disc_y("emit_lamps", lx + 0.5, lz + 0.5, 1.6, 18, AMBER)
    # (voxel centers land at x = -2.9, 0.1 and 3.1 m: 0.1 m off the bench centers, on purpose)
    return m


def dome_bench() -> Model:
    """3.6 m x 1.0 m x 1.6 m work table at 0.1 m (matches the LeftBench greybox): worn
    steel top, slate legs and a lower shelf. Origin on the floor at the table center."""
    m = Model("dome_bench")
    TOP, LEG, SHELF = "#9AA0A8", "#4F5D73", "#3A4150"
    m.box("bench", -18, 17, 9, 9, -8, 7, TOP)
    m.box("bench", -18, 17, 8, 8, -8, -8, LEG)
    m.box("bench", -18, 17, 8, 8, 7, 7, LEG)
    for x in (-17, 15):
        for z in (-7, 5):
            m.box("bench", x, x + 1, 0, 8, z, z + 1, LEG)
    m.box("bench", -17, 16, 3, 3, -7, 6, SHELF)
    m.box("bench", -14, -9, 4, 5, -6, -2, "#5A5F68")  # a crate on the shelf
    return m


def cal_station() -> Model:
    """The calibration bench kit at 0.1 m, after Neon's dome sheet. Origin on the
    bench top at the station center: a reference standard with a cyan screen, a clamp
    stand holding the hygrometer under test (LED socket only), an encoder test jig,
    a clipboard and a handheld meter with a teal readout."""
    m = Model("cal_station")
    CASE, STEEL, SLATE, WOOD, PAPER = "#D4D9DE", "#8C96A6", "#4F5D73", "#8B6A3F", "#E2E8F0"
    # reference standard (CRT-style case) facing +Z
    m.box("kit", -7, -3, 0, 5, -4, 0, CASE)
    m.box("kit", -7, -3, 1, 5, 0, 0, SHADOW)
    m.box("emit_screen", -6, -4, 2, 4, 1, 1, TEAL)
    m.box("kit", -7, -3, 0, 0, 1, 1, SHADOW)
    # clamp stand with the hygrometer under test
    m.box("kit", -1, 1, 0, 0, -3, -1, SHADOW)
    m.box("kit", 0, 0, 1, 7, -2, -2, STEEL)
    m.box("kit", 0, 3, 7, 7, -2, -2, STEEL)
    m.box("kit", 3, 3, 6, 6, -2, -2, STEEL)
    m.box("kit", 3, 4, 3, 5, -2, -1, CASE)
    m.put("kit", 4, 4, -1, SHADOW)                     # LED socket (state is game-driven)
    # steering-encoder test jig with a dial
    m.box("kit", 2, 5, 0, 1, 0, 2, SLATE)
    m.disc_y("kit", 3.5, 1.5, 1.0, 2, STEEL)
    # clipboard with a calibration sticker
    m.box("kit", -2, 1, 0, 0, 1, 3, WOOD)
    m.box("kit", -2, 0, 1, 1, 1, 3, PAPER)
    m.put("kit", 0, 1, 1, "#C9962E")
    # handheld meter with a teal readout
    m.box("kit", -7, -4, 0, 0, 2, 3, SLATE)
    m.box("emit_meter", -6, -5, 1, 1, 2, 2, TEAL)
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
    m.hidden_parts.add("emit_fiber")  # hidden until a spool is slotted: no border
    m.border_protect.add(("mast", FLANGE))  # keep all four gold flange guides gold
    return m


# ---------------------------------------------------------------- boulders
# Concepts from Gemini (2026-11-21) as layer grids (sheets/boulder_a.txt .. boulder_d.txt),
# built voxel for voxel by boulder_sheet. Plateau palette from the ore fissure; each
# fills its greybox box collider. Z=0 sits on the ground.
PLATEAU = ("#A8422B", "#8E3522", "#6E2617", "#5E2214")  # clay, clay 2, rust crust, crack


def boulder_sheet(name: str, sheet: str) -> Model:
    """Built voxel for voxel from a layer-grid concept sheet in tools/voxgen/sheets/.
    Sheet axes are MagicaVoxel's: "Z=n" headers are layers bottom up, each layer has
    one row per Y (first row = highest Y, the back) and one character per X. Cells:
    1-4 = PLATEAU colors, S = SHADOW, . = empty. Layer Z=0 sits on the ground; origin
    is the footprint center. MagicaVoxel (x, y, z) maps to Godot (x, z, -y)."""
    import re
    colors = dict(zip("1234", PLATEAU)) | {"S": SHADOW}
    layers: dict[int, list[str]] = {}
    current = -1
    for line in (Path(__file__).parent / "sheets" / sheet).read_text(encoding="utf-8").splitlines():
        header = re.match(r"Z=(\d+)", line)
        if header:
            current = int(header.group(1))
            layers[current] = []
        elif current >= 0 and re.fullmatch(r"[.1234S]+", line):
            layers[current].append(line)
    w = len(layers[0][0])
    d = len(layers[0])
    m = Model(name, offset=(-w / 2.0, 0.0, -d / 2.0))
    for y, rows in layers.items():
        assert len(rows) == d and all(len(r) == w for r in rows), f"{sheet}: Z={y} is not {w} x {d}"
        for z, row in enumerate(rows):
            for x, cell in enumerate(row):
                if cell != ".":
                    m.put("rock", x, y, z, colors[cell])
    return m


# ---------------------------------------------------------------- soil tiles
# GridMap items for FarmGrid.Tile (0 = untilled, 1 = tilled), built into
# assets/voxels/soil_tiles.tres by tools/voxgen/build_soil_library.gd. 19 x 2 x 19
# voxels at 0.1 m = 1.9 m x 0.2 m x 1.9 m in a 2 m x 0.2 m x 2 m cell, centered on
# the cell (voxel rows -1 and 0). Gemini's layer grids give no hex values; the colors
# are sampled off its concept images.
def token_sheet(sheet: str) -> dict[int, list[list[str]]]:
    """Reads a token layer grid from tools/voxgen/sheets/: "Z = n" headers are layers
    bottom up; each "Y=NN  t t t ..." row lists one token per X (".." = empty), first
    row = highest Y. "Z = a..b" repeats one grid on layers a to b. Anything after "<-"
    is a comment. Returns {z: rows}."""
    import re
    layers: dict[int, list[list[str]]] = {}
    current: list[list[str]] | None = None
    for line in (Path(__file__).parent / "sheets" / sheet).read_text(encoding="utf-8").splitlines():
        header = re.match(r"Z\s*=\s*(\d+)(?:\.\.(\d+))?", line)
        row = re.match(r"Y=\d+\s+(.*)", line)
        if header:
            first = int(header.group(1))
            current = []
            for z in range(first, int(header.group(2) or first) + 1):
                layers[z] = current
        elif row and current is not None:
            current.append(row.group(1).split("<-")[0].split())
    w, d = len(layers[0][0]), len(layers[0])
    for z, rows in layers.items():
        assert len(rows) == d and all(len(r) == w for r in rows), f"{sheet}: Z={z} is not {w} x {d}"
    return layers


def soil_sheet(tilled: bool) -> Model:
    """Built voxel for voxel from Gemini's layer grids (sheets/soil_tilled.txt,
    sheets/soil_untilled.txt). Sheet Z=0 is voxel row -1, Z=1 is row 0; the first
    sheet row (Y=18) is the back (-z). Tilled furrows are the empty cells of Z=1."""
    name = "soil_tilled" if tilled else "soil_untilled"
    colors = {"U1": "#78563B", "U2": "#A98463", "U3": "#563D26",   # base, light, dark speckle
              "T1": "#442E21", "T2": "#2A1D15", "T3": "#2D1E14"}   # ridge, wet base/furrow, speckle
    m = Model(name, offset=(-9.5, 0.0, -9.5))
    for layer, rows in token_sheet(f"{name}.txt").items():
        for z, row in enumerate(rows):
            for x, cell in enumerate(row):
                if cell != "..":
                    m.put("soil", x, layer - 1, z, colors[cell])
    return m


# ---------------------------------------------------------------- tarantula exuvia
def tarantula_exuvia() -> Model:
    """The Curlyhair's shed skin, built voxel for voxel from Gemini's 7 x 7 x 3 layer grid
    (sheets/tarantula_exuvia.txt). 0.1 m voxels like curlyhair, origin at the footprint
    center on the ground. Turned 180 degrees from the sheet so its front faces -z, as
    curlyhair's does. E1 husk cream, E2 gold tips/speckle (sampled off the concept),
    S = the hollow interior in shadow."""
    colors = {"E1": "#E8D4A8", "E2": "#C6944E", "S": SHADOW}
    m = Model("tarantula_exuvia", offset=(-3.5, 0.0, -3.5))
    for layer, rows in token_sheet("tarantula_exuvia.txt").items():
        for row_i, row in enumerate(rows):          # row 0 = rear (+Y)
            for x, cell in enumerate(row):
                if cell != "..":
                    m.put("husk", 6 - x, layer, 6 - row_i, colors[cell])
    return m


# ---------------------------------------------------------------- field props
# Gemini's field calibration & survey props pack (2026-11-21; the jig's Z = 2 and the tripod's
# Z = 1..13 are Gemini Neon's corrected grids from the same day): 0.1 m voxels, origin at the
# footprint center on the ground, palettes as given in the spec. Like the exuvia, each is
# turned 180 degrees from the sheet so its front (sheet Y=0, -Y) faces -z.
FIELD_PROPS = {
    "soil_moisture_probe": {"P1": "#3A3F47", "P2": "#8A94A0", "P3": "#D9534F", "P4": "#E8ECEF"},
    "steering_encoder_jig": {"J1": "#2B303A", "J2": "#5C6B73", "J3": "#E0A96D", "J4": "#7BB661"},
    "field_survey_tripod": {"T1": "#C47D2B", "T2": "#4A4E57", "T3": "#D1D5DB", "T4": "#3B82F6"},
}


# Gemini's Plateau Sun-Pod crop growth stages (2026-11-21): crop_stage_0..3, 0.1 m voxels,
# origin at the footprint center on the ground, palette as given in its generator script.
# Built and turned like the field props. FarmGrid shows them on planted cells.
CROP_SUNPOD = {"T1": "#3D2919", "G3": "#2E4F22", "G1": "#4C7A34", "G2": "#6FA34B",
               "C1": "#D9A13B", "C2": "#F2C96B", "S": SHADOW}

# Ryan's Pack 3 (2026-11-22): 0.1 m voxels, origin at the footprint center on the ground,
# palettes as given in his generator script (S there is already SHADOW). Built and turned
# like the field props. The farm shows the wilted crop on planted cells; the tarantula is in the
# dome and the junction in the farm.
PACK3 = {
    "crop_stage_wilted": ({"T1": "#3D2919", "W1": "#7A6838", "W2": "#544728", "W3": "#9E8B4F",
                           "S": SHADOW}, "crop"),
    "live_tarantula": ({"B1": "#2B1D16", "B2": "#473124", "E2": "#D4A359", "S": SHADOW}, "spider"),
    "irrigation_junction": ({"M1": "#4A607A", "M2": "#6C7A89", "M3": "#2E3844", "B1": "#D9A13B",
                             "S": SHADOW}, "prop"),
}


# Ryan's Plateau Clutter pack (2026-11-22): 0.2 m voxels (like the boulders), origin at the
# footprint center on the ground, palettes as given in his generator script (S is SHADOW; the
# cobbles' P1..P4 and the stump's dust P1 are the boulders' PLATEAU colors). Built and turned
# like the field props. Two of each are scattered in the farm.
CLUTTER = {
    "mesa_scrub_bush": {"B1": "#5A3E2B", "B2": "#3D2919", "F1": "#6D7A4C", "F2": "#8A9663",
                        "F3": "#4E5936", "S": SHADOW},
    "scatter_pebbles_cluster": {"P1": PLATEAU[0], "P2": PLATEAU[1], "P3": PLATEAU[2],
                                "P4": PLATEAU[3], "S": SHADOW},
    "mesa_dry_stump": {"P1": PLATEAU[0], "W1": "#8C7A65", "W2": "#6B5B4A", "W3": "#A89782",
                       "S": SHADOW},
}

# Ryan's Farm Logistics pack (2026-11-22, 0.1 m voxels): a water cistern, a harvest crate and a
# shipping pallet. Colors are his generator's own (the cistern reuses the irrigation junction's
# steel and brass; the crate's pods are the sun-pod C1/C2). Built and turned like the field props.
# All three are placed in the farm: the cistern beside the junction, the crate and pallet at
# the plot's front edge.
LOGISTICS = {
    "water_cistern": {"M1": "#4A607A", "M2": "#6C7A89", "M3": "#2E3844", "B1": "#D9A13B",
                      "S": SHADOW},
    "harvest_crate": {"O1": "#E85D25", "O2": "#B54414", "M3": "#2E3844",
                      "C1": CROP_SUNPOD["C1"], "C2": CROP_SUNPOD["C2"], "S": SHADOW},
    "shipping_pallet": {"W1": "#8C6742", "W2": "#6B4D30", "M3": "#2E3844", "S": SHADOW},
}

# Ryan's Dry Gulch & Plateau Rim terrain pack (2026-11-22, 0.2 m voxels): 10 x 10 tiles for a
# 2.0 m grid cell. One palette for all three: P1..P4 are the boulders' PLATEAU colors, D1 his
# dust. Built and turned like the field props (origin at the cell center), part "rock" like the
# boulders. The gulch is placed (six tiles in a row behind the farm plot), and the rim (a 20 m
# run with a corner at each end) stands behind the gulch.
GULCH_RIM_COLORS = {"P1": PLATEAU[0], "P2": PLATEAU[1], "P3": PLATEAU[2], "P4": PLATEAU[3],
                    "D1": "#C26B4A", "S": SHADOW}
GULCH_RIM = ("dry_gulch_straight", "plateau_rim_straight", "plateau_rim_corner")

# Ryan's Metrology Lab Bench & Multimeters pack (2026-11-22): an ESD calibration bench (0.1 m
# voxels) and two meters at 0.025 m voxels, a new class for bench
# instruments and hand-held kit. Colors are his
# generator's own (the bench reuses the cistern's steel and brass; S is SHADOW; no glow, blank
# screens). Built and turned like the field props. The bench and the field meter stand in the
# dome; the reference meter is on the chamber cart's lid.
METROLOGY_LAB = {
    "lab_calibration_bench": ({"M1": "#4A607A", "M2": "#6C7A89", "M3": "#2E3844", "E1": "#3A4E5C",
                               "B1": "#D9A13B", "S": SHADOW}, 0.1),
    "ref_meter_ls85": ({"C1": "#D4DAE0", "C2": "#8D99AE", "F1": "#2E3844", "K1": "#6C7A89",
                        "Y1": "#E5B53B", "S": SHADOW}, 0.025),
    "field_meter_fm3": ({"Y1": "#E5B53B", "Y2": "#B88B22", "F1": "#2E3844", "K1": "#6C7A89",
                         "S": SHADOW}, 0.025),
}

# Ryan's Environmental Chamber pack (2026-11-22, 0.1 m voxels): an environmental chamber
# on a rolling cart. Colors are his generator's own (C1/C2 the reference meter's case,
# F1 the meters' front panel, B1/S the bench's; no glow, a blank recessed screen). Built and turned like the field props.
# It stands in the dome, right of the calibration bench.
ENV_CHAMBER = {"C1": "#D4DAE0", "C2": "#8D99AE", "M1": "#3B5978", "F1": "#2E3844", "B1": "#D9A13B",
               "S": SHADOW}

# Ryan's Environmental Standards pack (2026-11-22, 0.025 m voxels, desktop scale for the
# calibration bench): a dry-well temperature calibrator and a chilled-mirror hygrometer. Colors
# are his generator's own and all match ones above (C1/C2/F1/K1/Y1 the reference meter's, M1 the
# chamber's, B1 the bench's brass; no glow, blank recessed screens). Built and turned like the
# field props. The hygrometer is on the dome's calibration bench; the dry well is on its back-right corner.
ENV_STANDARDS = {
    "dry_well_calibrator": {"C1": "#D4DAE0", "C2": "#8D99AE", "F1": "#2E3844", "K1": "#6C7A89",
                            "Y1": "#E5B53B", "S": SHADOW},
    "chilled_mirror_hygrometer": {"C1": "#D4DAE0", "C2": "#8D99AE", "M1": "#3B5978",
                                  "F1": "#2E3844", "B1": "#D9A13B", "S": SHADOW},
}

# The Gemini art loop's batch (2026-11-22, 0.1 m voxels, Ryan: "All five"): two more live
# tarantulas sized like the Curlyhair, the PX-1 rotary table, the MD-2P humidity generator and
# the FM-3 in its carry case. Palettes are as Gemini gave them, with two exceptions.
# The Brazilian black is lightened (see its entry). The case's meter: Gemini made it orange
# (O1 #E85D25), but the game's FM-3 is Ryan's yellow (field_meter_fm3 Y1), so O1 takes that
# yellow; and Gemini lit its screen teal (G1), but Ryan dropped the glow ("Drop", 2026-11-22),
# so G1 is the blank screen of his metrology pack (F1 #2E3844).
# Built and turned like the field props; each glowing token is its own emit_* part.
# All five are placed: the two tarantulas in small tanks of their own and the MD-2P in the
# dome, the FM-3 case on the dome's calibration bench, and the PX-1 on the field cal pad.
ART_LOOP = {
    "mexican_redknee": ({"B1": "#2E2B30", "B2": "#473F3E", "C1": "#D8B794", "K1": "#D44E1C",
                         "K2": "#9A3A1E", "S": SHADOW}, "spider", {}),
    # Lightened for Ryan ("Lighten", 2026-11-22): Gemini's near-black read as a hole in the
    # tank, so the body is slate and the sheen a lighter steel blue.
    "brazilian_black": ({"K1": "#4A5468", "K2": "#363E4C", "S1": "#7C90AE", "S2": "#AABCD4",
                         "EY": "#D8E2F0"}, "spider", {}),
    "px1_rotary_table": ({"M1": "#4A607A", "M2": "#6C7A89", "M3": "#2E3844", "P1": "#B8C4CE",
                          "B1": "#D9A13B", "GT": TEAL, "S": SHADOW}, "prop",
                         {"GT": "emit_display"}),
    "md2p_humidity_generator": ({"C1": "#6C7A89", "C2": "#4A607A", "M3": "#2E3844",
                                 "M4": "#9AA5B1", "B1": "#E0A96D", "W1": "#4A7A82",
                                 "N1": "#C85A2A", "G1": TEAL, "G2": AMBER, "S": SHADOW}, "prop",
                                {"G1": "emit_display", "G2": "emit_standby_led"}),
    "fm3_field_meter_case": ({"M1": "#4A607A", "M2": "#6C7A89", "M3": "#2E3844", "B1": "#D9A13B",
                              "O1": "#E5B53B", "C1": "#8A94A0", "P1": "#D1D5DB", "G1": "#2E3844",
                              "S": SHADOW}, "prop", {}),
}

# Ryan's Mining & Crystal Extraction pack (2026-11-22): a core drill, an ore skip and a seismic
# thumper (0.1 m voxels), and an active and a depleted crystal fissure (0.2 m, like ore_fissure).
# Colors are his generator's own: P1..P4 match the boulders' PLATEAU colors, EC is TEAL and S is
# SHADOW. Built and turned like the field props; the crystals glow (emit_crystals, as in
# ore_fissure) and everything else is unlit. None is placed in a scene yet.
MINING = {
    "portable_core_drill": ({"M1": "#4A607A", "M2": "#6C7A89", "M3": "#2E3844", "B1": "#D9A13B",
                             "O1": "#C84B31", "S": SHADOW}, "prop", {}, 0.1),
    "ore_sorting_skip": ({"M1": "#4A607A", "M2": "#6C7A89", "M3": "#2E3844", "Q1": "#2A8F85",
                          "Q2": "#6EC8BE", "P2": PLATEAU[1], "S": SHADOW}, "prop", {}, 0.1),
    "seismic_thumper": ({"M2": "#6C7A89", "M3": "#2E3844", "Y1": "#E5B53B", "B1": "#D9A13B",
                         "S": SHADOW}, "prop", {}, 0.1),
    "crystal_ore_fissure": ({"P1": PLATEAU[0], "P2": PLATEAU[1], "P3": PLATEAU[2],
                             "P4": PLATEAU[3], "EC": TEAL, "Q1": "#2A8F85", "S": SHADOW},
                            "rock", {"EC": "emit_crystals"}, 0.2),
    "crystal_ore_fissure_depleted": ({"P1": PLATEAU[0], "P2": PLATEAU[1], "P3": PLATEAU[2],
                                      "P4": PLATEAU[3], "A1": "#5C6B73", "S": SHADOW},
                                     "rock", {}, 0.2),
}

# Ryan's Outdoor Infrastructure pack (2026-11-22): a weather mast and a solar skid (0.1 m voxels),
# and a culvert bridge for dry_gulch_straight (0.2 m, like the gulch). Colors are his own; P1 and
# P2 match the boulders' PLATEAU colors and S is SHADOW. Nothing is lit, none is placed yet.
OUTDOOR = {
    "plateau_weather_mast": ({"C1": "#EBF0F5", "C2": "#8D99AE", "M3": "#2E3844", "B1": "#D9A13B",
                              "S": SHADOW}, "prop", {}, 0.1),
    "gulch_culvert_bridge": ({"P2": PLATEAU[1], "D1": "#C26B4A", "M1": "#4A607A", "M3": "#2E3844",
                              "W1": "#8C6742", "S": SHADOW}, "prop", {}, 0.2),
    "solar_array_skid": ({"M3": "#2E3844", "M2": "#6C7A89", "PV": "#243B55", "P1": PLATEAU[0],
                          "B1": "#D9A13B", "S": SHADOW}, "prop", {}, 0.1),
}


def front_to_minus_z(name: str, cells: dict[tuple[int, int, int], str], w: int, d: int,
                     colors: dict[str, str], part: str = "prop",
                     parts: dict[str, str] | None = None) -> Model:
    """cells: {(x, y, z): token} in sheet axes (X right, Y back, Z up). Sheet (x, y, z) goes
    to Godot (w-1-x, z, y), so sheet Y=0 (the front) lands at -z after the offset. `parts`
    puts some tokens in their own part (an emit_* part glows); the rest go in `part`."""
    m = Model(name, offset=(-w / 2.0, 0.0, -d / 2.0))
    for (x, y, z), token in cells.items():
        m.put((parts or {}).get(token, part), w - 1 - x, z, y, colors[token])
    return m


def prop_sheet(name: str, colors: dict[str, str] | None = None, part: str = "prop",
               parts: dict[str, str] | None = None) -> Model:
    """Built voxel for voxel from Gemini's layer grid in sheets/<name>.txt."""
    layers = token_sheet(f"{name}.txt")
    w, d = len(layers[0][0]), len(layers[0])
    cells = {(x, d - 1 - row_i, z): cell
             for z, rows in layers.items() for row_i, row in enumerate(rows)
             for x, cell in enumerate(row) if cell != ".."}
    return front_to_minus_z(name, cells, w, d, colors or FIELD_PROPS[name], part, parts)


MODELS = [
    (lambda: tractor(False), 0.1), (lambda: tractor(True), 0.1),
    (terrarium, 0.1), (curlyhair, 0.1), (bram_bay, 0.2), (ore_fissure, 0.2),
    (drop_pod, 0.2), (aud1t, 0.2), (relay_mast, 0.5),
    (dome_room, 0.2), (dome_bench, 0.1), (cal_station, 0.1),
    # boulders match the greybox boxes: RockA 5 x 4 x 4 m, B 4 x 3.5 x 5 m, C 4 m cube, D 3 m cube
    # Gemini layer grids in sheets/
    (lambda: boulder_sheet("boulder_a", "boulder_a.txt"), 0.2),
    (lambda: boulder_sheet("boulder_b", "boulder_b.txt"), 0.2),
    (lambda: boulder_sheet("boulder_c", "boulder_c.txt"), 0.2),
    (lambda: boulder_sheet("boulder_d", "boulder_d.txt"), 0.2),
    (lambda: soil_sheet(False), 0.1), (lambda: soil_sheet(True), 0.1),
    (tarantula_exuvia, 0.1),
    (lambda: prop_sheet("soil_moisture_probe"), 0.1),
    (lambda: prop_sheet("steering_encoder_jig"), 0.1),
    (lambda: prop_sheet("field_survey_tripod"), 0.1),
    *[((lambda n=n: prop_sheet(f"crop_stage_{n}", CROP_SUNPOD, "crop")), 0.1) for n in range(4)],
    *[((lambda n=n: prop_sheet(n, *PACK3[n])), 0.1) for n in PACK3],
    *[((lambda n=n: prop_sheet(n, CLUTTER[n])), 0.2) for n in CLUTTER],
    *[((lambda n=n: prop_sheet(n, LOGISTICS[n])), 0.1) for n in LOGISTICS],
    *[((lambda n=n: prop_sheet(n, GULCH_RIM_COLORS, "rock")), 0.2) for n in GULCH_RIM],
    *[((lambda n=n: prop_sheet(n, METROLOGY_LAB[n][0])), METROLOGY_LAB[n][1]) for n in METROLOGY_LAB],
    (lambda: prop_sheet("env_chamber_cart", ENV_CHAMBER), 0.1),
    *[((lambda n=n: prop_sheet(n, ENV_STANDARDS[n])), 0.025) for n in ENV_STANDARDS],
    *[((lambda n=n: prop_sheet(n, *ART_LOOP[n])), 0.1) for n in ART_LOOP],
    *[((lambda n=n: prop_sheet(n, *MINING[n][:3])), MINING[n][3]) for n in MINING],
    *[((lambda n=n: prop_sheet(n, *OUTDOOR[n][:3])), OUTDOOR[n][3]) for n in OUTDOOR],
]


def _metres(value: float) -> str:
    """0.025 -> "0.025", 2.0 -> "2"."""
    return f"{value:.3f}".rstrip("0").rstrip(".")


def main() -> None:
    (OUT / "source").mkdir(parents=True, exist_ok=True)
    for build, voxel_m in MODELS:
        m = build()
        bordered = 0 if m.name in BORDER_SKIP else m.border_lit(SHADOW, BORDER_MAX_PART_VOXELS)
        m.write_glb(OUT / f"{m.name}.glb")
        m.write_vox(OUT / "source" / f"{m.name}.vox")
        w, h, d = m.size()
        print(f"{m.name:13} {w:3} x {h:3} x {d:3} voxels = "
              f"{_metres(w * voxel_m)} m x {_metres(h * voxel_m)} m x {_metres(d * voxel_m)} m, "
              f"{len(m.voxels):5} voxels, {len(m.colors()):2} colors, {bordered:3} bordered")


if __name__ == "__main__":
    main()
