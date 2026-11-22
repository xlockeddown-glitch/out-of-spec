"""Tiny voxel model builder with .glb and .vox writers (numpy only).

Coordinates are Godot-style voxel indices: x right, y up, z toward the back
(the model's front faces -Z). Voxel (x, y, z) fills the unit cube
[x, x+1] x [y, y+1] x [z, z+1]; one unit = one voxel, and each ModelSlot's
model_scale turns that into meters.

Parts become separate mesh nodes in the .glb. A part named emit_* is a glowing
part (docs/art/voxel_models.md); the game makes it glow by that name.
"""
from __future__ import annotations

import json
import math
import struct
from pathlib import Path

import numpy as np

GLASS_ALPHA = 0.25

# Face directions: normal and the 4 corner offsets (counter-clockwise seen from outside).
_FACES = [
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
    ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
    ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
]


def _srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


class Model:
    def __init__(self, name: str, offset: tuple[float, float, float] = (0.0, 0.0, 0.0)):
        self.name = name
        self.offset = offset  # added to every vertex (center-origin models use -0.5)
        self.voxels: dict[tuple[int, int, int], tuple[str, str]] = {}  # pos -> (part, hex)
        self.glass_parts: set[str] = set()

    # --- building -------------------------------------------------------
    def put(self, part: str, x: int, y: int, z: int, color: str) -> None:
        self.voxels[(int(x), int(y), int(z))] = (part, color.upper())

    def clear(self, x: int, y: int, z: int) -> None:
        self.voxels.pop((int(x), int(y), int(z)), None)

    def box(self, part: str, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, color: str) -> None:
        """Fill the inclusive box x0..x1, y0..y1, z0..z1."""
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    self.put(part, x, y, z, color)

    def clear_box(self, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> None:
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.clear(x, y, z)

    def disc_y(self, part: str, cx: float, cz: float, r: float, y: int, color: str, hollow: float = -1.0) -> None:
        """Horizontal disc (or ring if hollow >= 0) centered on voxel-space point (cx, cz)."""
        for x in range(math.floor(cx - r) - 1, math.ceil(cx + r) + 1):
            for z in range(math.floor(cz - r) - 1, math.ceil(cz + r) + 1):
                d2 = (x + 0.5 - cx) ** 2 + (z + 0.5 - cz) ** 2
                if d2 <= r * r and (hollow < 0 or d2 > hollow * hollow):
                    self.put(part, x, y, z, color)

    def disc_x(self, part: str, x0: int, x1: int, cy: float, cz: float, r: float, color: str) -> None:
        """Disc in the YZ plane (a wheel), extruded over x0..x1."""
        for y in range(math.floor(cy - r) - 1, math.ceil(cy + r) + 1):
            for z in range(math.floor(cz - r) - 1, math.ceil(cz + r) + 1):
                if (y + 0.5 - cy) ** 2 + (z + 0.5 - cz) ** 2 <= r * r:
                    for x in range(x0, x1 + 1):
                        self.put(part, x, y, z, color)

    def line(self, part: str, a: tuple[float, float, float], b: tuple[float, float, float], color: str, thick: int = 1) -> None:
        steps = int(max(abs(b[i] - a[i]) for i in range(3)) * 2) + 1
        for s in range(steps + 1):
            t = s / steps
            p = [a[i] + (b[i] - a[i]) * t for i in range(3)]
            for dx in range(thick):
                for dz in range(thick):
                    self.put(part, math.floor(p[0]) + dx, math.floor(p[1]), math.floor(p[2]) + dz, color)

    def border_lit(self, color: str) -> int:
        """Give lit (emit_*) voxels a 1-voxel border in `color`, where space allows.

        Recolors the visible, non-lit, non-glass voxels in each lit voxel's
        26-neighborhood; it never adds or removes voxels, so silhouettes are
        unchanged. A lit voxel with no solid neighbors (a free-standing beacon)
        gets no border. Returns the number of voxels whose color changed
        (border voxels that already had `color` are not counted).

        Limits: exposure is not directional, so a 1-voxel wall behind a lit
        voxel shows the border on its far side too; an `emit_*` neighbor counts
        as solid, so a voxel whose only open face touches a hideable lit part
        (e.g. `emit_fiber`) is not bordered. The pass has no notion of separate
        objects: a prop or character voxel beside a lit voxel is recolored too.
        """
        def lit(pos: tuple[int, int, int]) -> bool:
            v = self.voxels.get(pos)
            return v is not None and v[0].startswith("emit_")

        def exposed(pos: tuple[int, int, int]) -> bool:
            x, y, z = pos
            for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                v = self.voxels.get((x + d[0], y + d[1], z + d[2]))
                if v is None or v[0] in self.glass_parts:
                    return True
            return False

        targets: set[tuple[int, int, int]] = set()
        for (x, y, z), (part, _) in self.voxels.items():
            if not part.startswith("emit_"):
                continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        n = (x + dx, y + dy, z + dz)
                        v = self.voxels.get(n)
                        if v is None or lit(n) or v[0] in self.glass_parts:
                            continue
                        if exposed(n):
                            targets.add(n)
        changed = 0
        for n in targets:
            part, old = self.voxels[n]
            if old.upper() != color.upper():
                changed += 1
            self.voxels[n] = (part, color.upper())
        return changed

    # --- stats ----------------------------------------------------------
    def bounds(self) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
        arr = np.array(list(self.voxels.keys()))
        return tuple(arr.min(0)), tuple(arr.max(0))

    def size(self) -> tuple[int, int, int]:
        lo, hi = self.bounds()
        return tuple(int(hi[i] - lo[i] + 1) for i in range(3))

    def colors(self) -> list[str]:
        return sorted({c for _, c in self.voxels.values()})

    # --- .glb -----------------------------------------------------------
    def write_glb(self, path: Path) -> None:
        occupied = self.voxels
        # part -> color -> lists
        geo: dict[str, dict[str, tuple[list, list, list]]] = {}
        for (x, y, z), (part, color) in occupied.items():
            for normal, corners in _FACES:
                n = (x + normal[0], y + normal[1], z + normal[2])
                neighbor = occupied.get(n)
                if neighbor is not None:
                    # Hide the face only behind a neighbor that is always there and opaque:
                    # emit_* parts can be hidden by the game, and glass is see-through.
                    n_part = neighbor[0]
                    if n_part == part or (not n_part.startswith("emit_")
                                          and n_part not in self.glass_parts):
                        continue
                pos, nor, idx = geo.setdefault(part, {}).setdefault(color, ([], [], []))
                base = len(pos)
                for c in corners:
                    pos.append((x + c[0] + self.offset[0], y + c[1] + self.offset[1], z + c[2] + self.offset[2]))
                    nor.append(normal)
                idx.extend([base, base + 1, base + 2, base, base + 2, base + 3])

        gltf: dict = {
            "asset": {"version": "2.0", "generator": "out-of-spec voxgen"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"name": self.name, "children": []}],
            "meshes": [], "materials": [], "accessors": [], "bufferViews": [], "buffers": [],
        }
        blob = bytearray()
        material_index: dict[tuple[str, bool, bool], int] = {}

        def add_view(data: bytes, target: int) -> int:
            while len(blob) % 4:
                blob.append(0)
            gltf["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
            blob.extend(data)
            return len(gltf["bufferViews"]) - 1

        def material(color: str, emit: bool, glass: bool) -> int:
            key = (color, emit, glass)
            if key in material_index:
                return material_index[key]
            r, g, b = (v / 255.0 for v in hex_rgb(color))
            lin = [_srgb_to_linear(r), _srgb_to_linear(g), _srgb_to_linear(b)]
            mat: dict = {
                "name": ("emit_" if emit else "") + color.lstrip("#"),
                "pbrMetallicRoughness": {"baseColorFactor": lin + [GLASS_ALPHA if glass else 1.0],
                                         "metallicFactor": 0.0, "roughnessFactor": 0.1 if glass else 0.85},
            }
            if glass:
                mat["alphaMode"] = "BLEND"
                mat["doubleSided"] = True
            if emit:
                mat["emissiveFactor"] = lin
            gltf["materials"].append(mat)
            material_index[key] = len(gltf["materials"]) - 1
            return material_index[key]

        for part in sorted(geo):
            prims = []
            for color, (pos, nor, idx) in sorted(geo[part].items()):
                p = np.array(pos, dtype=np.float32)
                nrm = np.array(nor, dtype=np.float32)
                ind = np.array(idx, dtype=np.uint32)
                pv = add_view(p.tobytes(), 34962)
                gltf["accessors"].append({"bufferView": pv, "componentType": 5126, "count": len(p), "type": "VEC3",
                                          "min": p.min(0).tolist(), "max": p.max(0).tolist()})
                pa = len(gltf["accessors"]) - 1
                nv = add_view(nrm.tobytes(), 34962)
                gltf["accessors"].append({"bufferView": nv, "componentType": 5126, "count": len(nrm), "type": "VEC3"})
                na = len(gltf["accessors"]) - 1
                iv = add_view(ind.tobytes(), 34963)
                gltf["accessors"].append({"bufferView": iv, "componentType": 5125, "count": len(ind), "type": "SCALAR"})
                ia = len(gltf["accessors"]) - 1
                prims.append({"attributes": {"POSITION": pa, "NORMAL": na}, "indices": ia,
                              "material": material(color, part.startswith("emit_"), part in self.glass_parts)})
            gltf["meshes"].append({"name": part, "primitives": prims})
            gltf["nodes"].append({"name": part, "mesh": len(gltf["meshes"]) - 1})
            gltf["nodes"][0]["children"].append(len(gltf["nodes"]) - 1)

        while len(blob) % 4:
            blob.append(0)
        gltf["buffers"].append({"byteLength": len(blob)})
        js = json.dumps(gltf, separators=(",", ":")).encode()
        js += b" " * ((4 - len(js) % 4) % 4)
        out = bytearray()
        out += struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
        out += struct.pack("<II", len(js), 0x4E4F534A) + js
        out += struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
        path.write_bytes(bytes(out))

    # --- .vox (MagicaVoxel 150, single model) ----------------------------
    def write_vox(self, path: Path) -> None:
        """MagicaVoxel axes: x = -x (keeps handedness), y = z (front = low y), z = y (up)."""
        colors = self.colors()
        if len(colors) > 255:
            raise ValueError("more than 255 colors")
        index = {c: i + 1 for i, c in enumerate(colors)}
        lo, hi = self.bounds()
        pts = []
        for (x, y, z), (_, c) in self.voxels.items():
            vx, vy, vz = hi[0] - x, z - lo[2], y - lo[1]
            pts.append((vx, vy, vz, index[c]))
        sx, sy, sz = hi[0] - lo[0] + 1, hi[2] - lo[2] + 1, hi[1] - lo[1] + 1
        if max(sx, sy, sz) > 256:
            raise ValueError("model larger than 256 voxels")

        def chunk(cid: bytes, content: bytes, children: bytes = b"") -> bytes:
            return cid + struct.pack("<II", len(content), len(children)) + content + children

        size = chunk(b"SIZE", struct.pack("<III", sx, sy, sz))
        xyzi = chunk(b"XYZI", struct.pack("<I", len(pts)) + b"".join(struct.pack("<BBBB", *p) for p in pts))
        pal = bytearray()
        for i in range(256):
            if i < len(colors):
                pal += bytes(hex_rgb(colors[i])) + b"\xff"
            else:
                pal += b"\x00\x00\x00\xff"
        rgba = chunk(b"RGBA", bytes(pal))
        main = chunk(b"MAIN", b"", size + xyzi + rgba)
        path.write_bytes(b"VOX " + struct.pack("<I", 150) + main)
