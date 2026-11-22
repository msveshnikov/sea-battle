"""Task 1 + 3: archipelago arena (islands, rocks, palms, lighthouse, pier), props (buoys, markers)
and the arena layout JSON the game builds the level from.

    blender -b --factory-startup -P blender/scripts/build_env.py -- [--no-render]

Output:
  assets/env/arena.gltf            all static scenery (islands with palms, lighthouse, pier, rocks)
  assets/env/buoy.gltf             grid corner buoy (LIGHT_ lamp empty on top)
  assets/env/marker_miss.gltf      small white buoy with a pennant (miss)
  assets/env/marker_hit.gltf       red flare float (hit on a not-yet-sunk ship)
  assets/levels/arena_layout.json  grids, islands (for the water shallows), corner buoys, cameras, moods
Coordinates in the JSON are Godot's (X right, Y up, Z toward the player's side): gx = bx, gz = -by.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import lib_geo as G  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = "--no-render" not in ARGS
OUT = os.path.join(G.ROOT, "assets", "env")
LEVELS = os.path.join(G.ROOT, "assets", "levels")
REN = os.path.join(G.ROOT, "renders", "env")

CELL = 4.0
GRID_N = 10
PLAYER_GRID = (0.0, 28.0)   # Godot x, z of the grid centre
ENEMY_GRID = (0.0, -28.0)


def M():
    return {
        "sand": G.mat("sand", "sand.png", rough=0.9),
        "grass": G.mat("grass", "grass.png", rough=0.9),
        "rock": G.mat("rock", "rock.png", rough=0.85),
        "bark": G.mat("bark", "bark.png", rough=0.9),
        "leaf": G.mat("palm_leaf", "palm_leaf.png", rough=0.7, alpha_tex=True),
        "plaster": G.mat("plaster", "plaster.png", rough=0.8),
        "red": G.mat("red_paint", "plaster.png", (0.78, 0.13, 0.1, 1), rough=0.6),
        "roof": G.mat("roof", "roof.png", rough=0.8),
        "wood": G.mat("wood", "wood.png", rough=0.85),
        "dark": G.mat("steel_dark", "steel.png", (0.13, 0.135, 0.15, 1), rough=0.45, metal=0.3),
        "lamp": G.mat("lamp", None, (1, 0.95, 0.8, 1), rough=0.2, emit=(1, 0.9, 0.7), emit_strength=2.0),
        "windows": G.mat("windows", "windows.png", rough=0.15, emit_tex="windows_emit.png", emit_strength=1.0),
        "white": G.mat("white", "steel.png", (0.95, 0.94, 0.9, 1), rough=0.6),
        "orange": G.mat("orange", "steel.png", (1.0, 0.36, 0.04, 1), rough=0.5),
        "flare": G.mat("flare", None, (1, 0.2, 0.1, 1), rough=0.4, emit=(1, 0.15, 0.05), emit_strength=3.0),
        "green_paint": G.mat("green_paint", "steel.png", (0.1, 0.55, 0.25, 1), rough=0.5),
    }


def bl(gx, gz, y=0.0):
    """Godot (x, z) -> Blender location."""
    return (gx, -gz, y)


# ------------------------------------------------------------------ island
def island(name, R, H, seed, parent):
    """Irregular island: beach ring, rocky cliffs, grassy top, underwater skirt to -4 m."""
    mats = M()
    order = ["sand", "grass", "rock"]
    bm = bmesh.new()
    rng = random.Random(seed)
    off = Vector((rng.random() * 100, rng.random() * 100, rng.random() * 100))
    rings, segs = 22, 56
    rows = []
    center = bm.verts.new((0, 0, H))
    for i in range(1, rings + 1):
        rn = (i / rings) ** 0.9 * 1.45
        row = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            d = Vector((math.cos(a), math.sin(a), 0))
            coast = 1 + 0.28 * noise.noise(d * 1.4 + off) + 0.12 * noise.noise(d * 3.5 + off)
            r = rn / coast  # normalised radius relative to this direction's coastline
            p = d * rn * R
            n1 = noise.noise(p * 0.12 + off)
            n2 = noise.noise(p * 0.35 + off * 2)
            cliff = 0.6 + 0.1 * noise.noise(d * 2.2 + off * 3)
            hill = H * (0.78 + 0.32 * noise.noise(p * 0.07 + off) + 0.12 * n1)
            if r < cliff:
                z = hill * (1.0 - (r / cliff) ** 2 * 0.22) + 0.5 * n2
            elif r < 0.86:
                t = (r - cliff) / (0.86 - cliff)
                top = hill * 0.78
                z = top * (1 - t) ** 1.3 + 0.9 * t + 0.6 * n2 * (1 - t)  # cliffs down to the beach shelf
            elif r < 1.0:
                t = (r - 0.86) / 0.14
                z = 0.9 * (1 - t) + 0.05 + 0.1 * n2
            else:
                t = min(1.0, (r - 1.0) / 0.35)
                z = 0.05 - 4.0 * t ** 0.8
            row.append(bm.verts.new((p.x, p.y, z)))
        rows.append(row)
    for j in range(segs):
        bm.faces.new([center, rows[0][j], rows[0][(j + 1) % segs]])
    for a, b in zip(rows[:-1], rows[1:]):
        for j in range(segs):
            k = (j + 1) % segs
            bm.faces.new([a[j], b[j], b[k], a[k]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    for f in bm.faces:
        c = f.calc_center_median()
        if c.z < 1.4:
            f.material_index = 0
        elif f.normal.z < 0.8:
            f.material_index = 2
        else:
            f.material_index = 1
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            co = l.vert.co
            if f.material_index == 2:
                ang = math.atan2(co.y, co.x)
                l[uv].uv = (ang * R / 6.0, co.z / 6.0)
            else:
                l[uv].uv = (co.x / 6.0, co.y / 6.0)
    ob = G.mesh_obj(name, bm, [mats[k] for k in order], parent=parent, smooth=True)
    return ob


def surface_z(ob, x, y):
    """Height of the island mesh at local x, y (ray cast from above)."""
    hit, loc, nrm, idx = ob.ray_cast(Vector((x, y, 50)), Vector((0, 0, -1)))
    return (loc.z, nrm) if hit else (None, None)


def rock(name, size, seed, parent, loc, squash=0.7):
    mats = M()
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=size)
    off = Vector((seed * 1.7, seed * 3.1, seed * 0.3))
    for v in bm.verts:
        n = noise.noise(v.co * (1.2 / size) + off)
        v.co *= 1 + 0.32 * n
        v.co.z *= squash
        # chunky: flatten the top facets a bit
        if v.co.z > size * 0.45:
            v.co.z = size * 0.45 + (v.co.z - size * 0.45) * 0.4
    G.box_uv(bm, 4.0)
    ob = G.mesh_obj(name, bm, [mats["rock"]], parent=parent)
    ob.location = loc
    ob.rotation_euler = (0, 0, seed * 1.3)
    return ob


_PALM_MESHES = {}


def palm_mesh(variant):
    if variant in _PALM_MESHES:
        return _PALM_MESHES[variant]
    mats = M()
    rng = random.Random(100 + variant)
    bm = bmesh.new()
    height = 5.5 + variant * 1.1
    lean = 0.18 + 0.1 * variant
    segs_n = 9
    prev = None
    uv = bm.loops.layers.uv.verify()
    pts = []
    for i in range(segs_n + 1):
        t = i / segs_n
        x = lean * height * t ** 1.8
        z = height * t
        pts.append(Vector((x, 0, z)))
    rings = []
    for i, p in enumerate(pts):
        r = 0.24 * (1 - 0.35 * i / segs_n)
        ring = []
        for k in range(8):
            a = 2 * math.pi * k / 8
            ring.append(bm.verts.new(p + Vector((math.cos(a) * r, math.sin(a) * r, 0))))
        rings.append(ring)
    for i, (a, b) in enumerate(zip(rings[:-1], rings[1:])):
        for k in range(8):
            kk = (k + 1) % 8
            f = bm.faces.new([a[k], a[kk], b[kk], b[k]])
            f.material_index = 0
            for l, (u, v) in zip(f.loops, [(k / 8, i / 3), ((k + 1) / 8, i / 3), ((k + 1) / 8, (i + 1) / 3), (k / 8, (i + 1) / 3)]):
                l[uv].uv = (u, v)
    top = pts[-1]
    # fronds: drooping strips, texture tip at V=1 (row 0 of the image is the tip)
    n_fronds = 9
    for fi in range(n_fronds):
        a = 2 * math.pi * fi / n_fronds + rng.random() * 0.3
        length = 3.0 + rng.random() * 0.8
        width = 0.75
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        rise = 0.6 + rng.random() * 0.5
        segs = 6
        left, right = [], []
        for s in range(segs + 1):
            t = s / segs
            c = top + d * length * t + Vector((0, 0, rise * t - 2.2 * t * t))
            w = width * (0.3 + 0.7 * math.sin(math.pi * min(1, t * 1.1)))
            # slight V fold
            left.append(bm.verts.new(c - side * w / 2 + Vector((0, 0, -0.12 * w))))
            right.append(bm.verts.new(c + side * w / 2 + Vector((0, 0, -0.12 * w))))
        for s in range(segs):
            f = bm.faces.new([left[s], right[s], right[s + 1], left[s + 1]])
            f.material_index = 1
            v0, v1 = 1 - s / segs, 1 - (s + 1) / segs
            for l, (u, v) in zip(f.loops, [(0, v0), (1, v0), (1, v1), (0, v1)]):
                l[uv].uv = (u, 1 - v)
    # coconuts
    for k in range(3):
        a = k * 2.1
        f = G.bm_sphere(bm, 0.16, (0, 0, 0), segs=8, rings=5, mat_index=2)
        G.transform_faces(bm, f, Matrix.Translation(top + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, -0.25))))
    me = bpy.data.meshes.new("palm_%d" % variant)
    bm.to_mesh(me)
    bm.free()
    for m in (mats["bark"], mats["leaf"], mats["bark"]):
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    _PALM_MESHES[variant] = me
    return me


def palm(name, variant, parent, loc, rot):
    ob = bpy.data.objects.new(name, palm_mesh(variant))
    G.link(ob, parent)
    ob.location = loc
    ob.rotation_euler = (0, 0, rot)
    s = 0.85 + (hash(name) % 30) / 100
    ob.scale = (s, s, s)
    return ob


def lighthouse(parent, loc, rot=0.0):
    mats = M()
    root = G.empty("lighthouse", loc, parent, rot)
    bm = bmesh.new()
    order = ["plaster", "red", "dark", "lamp", "roof", "windows", "wood"]
    idx = {k: i for i, k in enumerate(order)}
    G.bm_cyl(bm, 2.2, 0.8, (0, 0, -0.2), segs=20, mat_index=idx["plaster"])  # plinth
    h = 11.0
    bands = [(0.0, 0.25, "plaster"), (0.25, 0.42, "red"), (0.42, 0.62, "plaster"), (0.62, 0.8, "red"), (0.8, 1.0, "plaster")]
    r0, r1 = 1.55, 1.05
    for a, b, m in bands:
        G.bm_cyl(bm, r0 + (r1 - r0) * a, h * (b - a), (0, 0, 0.6 + h * a), segs=20, r_top=r0 + (r1 - r0) * b, mat_index=idx[m], caps=False)
    zt = 0.6 + h
    G.bm_cyl(bm, 1.55, 0.18, (0, 0, zt), segs=20, mat_index=idx["dark"])  # gallery
    for k in range(16):
        a = 2 * math.pi * k / 16
        G.bm_cyl(bm, 0.03, 0.55, (math.cos(a) * 1.45, math.sin(a) * 1.45, zt + 0.18), segs=4, mat_index=idx["dark"], caps=False)
    G.bm_cyl(bm, 1.48, 0.06, (0, 0, zt + 0.7), segs=20, mat_index=idx["dark"], caps=False)
    G.bm_cyl(bm, 0.85, 1.3, (0, 0, zt + 0.18), segs=12, mat_index=idx["lamp"])  # lantern
    for k in range(6):
        a = 2 * math.pi * k / 6
        G.bm_cyl(bm, 0.04, 1.3, (math.cos(a) * 0.87, math.sin(a) * 0.87, zt + 0.18), segs=4, mat_index=idx["dark"], caps=False)
    G.bm_cyl(bm, 1.0, 0.9, (0, 0, zt + 1.48), segs=12, r_top=0.08, mat_index=idx["red"])  # dome
    # small windows up the tower
    G.box_uv(bm, 3.0)
    ob = G.mesh_obj("lighthouse_tower", bm, [mats[k] for k in order], parent=root, smooth=True)
    G.shade_flat_smooth(ob, 40)
    G.empty("LIGHT_beacon", (0, 0, zt + 0.8), root)
    # keeper's house
    bm = bmesh.new()
    G.box_uv_faces(bm, G.bm_box(bm, 5.0, 3.6, 2.6, (3.8, 1.8, 0), mat_index=0), 3.0)
    # gable roof
    hx, hy, z0, z1 = 2.8, 2.05, 2.6, 4.3
    cx, cy = 3.8, 1.8
    vs = [bm.verts.new(v) for v in [(cx - hx, cy - hy, z0), (cx + hx, cy - hy, z0), (cx + hx, cy, z1), (cx - hx, cy, z1),
                                    (cx - hx, cy + hy, z0), (cx + hx, cy + hy, z0)]]
    for f, m in [((0, 1, 2, 3), 4), ((3, 2, 5, 4), 4), ((0, 3, 4), 0), ((1, 5, 2), 0), ((0, 4, 5, 1), 0)]:
        face = bm.faces.new([vs[i] for i in f])
        face.material_index = m
    uvl = bm.loops.layers.uv.verify()
    G.box_uv(bm, 3.0)
    # windows and door on the -Y side
    for wx in (2.3, 5.3):
        q = [(wx - 0.45, cy - 1.82, 1.0), (wx + 0.45, cy - 1.82, 1.0), (wx + 0.45, cy - 1.82, 1.9), (wx - 0.45, cy - 1.82, 1.9)]
        f = bm.faces.new([bm.verts.new(p) for p in q])
        f.material_index = idx["windows"]
        for l, uvv in zip(f.loops, [(0, 0), (0.25, 0), (0.25, 1), (0, 1)]):
            l[uvl].uv = uvv
    q = [(3.4, cy - 1.82, 0.0), (4.2, cy - 1.82, 0.0), (4.2, cy - 1.82, 2.0), (3.4, cy - 1.82, 2.0)]
    f = bm.faces.new([bm.verts.new(p) for p in q])
    f.material_index = idx["wood"]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    G.mesh_obj("keeper_house", bm, [mats[k] for k in order], parent=root)
    return root


def pier(parent, loc, rot, length=12):
    mats = M()
    bm = bmesh.new()
    G.box_uv_faces(bm, G.bm_box(bm, 2.4, length, 0.2, (0, -length / 2, 1.0), mat_index=0), 2.0)
    for y in range(0, int(length) + 1, 2):
        for x in (-1.0, 1.0):
            G.box_uv_faces(bm, G.bm_cyl(bm, 0.14, 4.0, (x, -y, -2.8), segs=6, mat_index=0), 2.0)
    for k in range(3):
        G.box_uv_faces(bm, G.bm_box(bm, 0.6, 0.5, 0.5, (0.5 - k * 0.5, -length + 1.0 + k * 0.7, 1.2), mat_index=0), 1.0)
    root = G.mesh_obj("pier", bm, [mats["wood"]], parent=parent)
    root.location = loc
    root.rotation_euler = (0, 0, rot)
    return root


# ------------------------------------------------------------------ small props
def buoy():
    mats = M()
    root = G.empty("buoy")
    bm = bmesh.new()
    order = ["orange", "dark", "lamp", "white"]
    G.bm_cyl(bm, 0.75, 0.9, (0, 0, -0.5), segs=16, r_top=0.55, mat_index=0)
    G.bm_cyl(bm, 0.78, 0.18, (0, 0, -0.1), segs=16, mat_index=3)
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        G.bm_cyl(bm, 0.05, 1.5, (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.4), segs=4, r_top=0.03, mat_index=1, caps=False)
    G.bm_cyl(bm, 0.12, 0.3, (0, 0, 1.75), segs=10, mat_index=2)
    G.bm_cyl(bm, 0.45, 0.06, (0, 0, 1.0), segs=12, mat_index=1)
    G.box_uv(bm, 2.0)
    G.mesh_obj("buoy_body", bm, [mats[k] for k in order], parent=root, smooth=True)
    G.empty("LIGHT_buoy", (0, 0, 1.95), root)
    return root


def marker_miss():
    mats = M()
    root = G.empty("marker_miss")
    bm = bmesh.new()
    G.bm_sphere(bm, 0.42, (0, 0, 0), segs=12, rings=6, mat_index=0, sz=0.6)
    G.bm_cyl(bm, 0.03, 1.4, (0, 0, 0), segs=4, mat_index=1)
    flag = G.bm_box(bm, 0.02, 0.55, 0.36, (0, 0.28, 1.0), mat_index=2)
    G.box_uv(bm, 1.0)
    G.mesh_obj("marker_miss_body", bm, [mats["white"], mats["dark"], mats["green_paint"]], parent=root, smooth=True)
    return root


def marker_hit():
    mats = M()
    root = G.empty("marker_hit")
    bm = bmesh.new()
    G.bm_cyl(bm, 0.4, 0.35, (0, 0, -0.15), segs=12, r_top=0.3, mat_index=1)
    G.bm_cyl(bm, 0.12, 0.55, (0, 0, 0.2), segs=8, mat_index=0)
    G.box_uv(bm, 1.0)
    G.mesh_obj("marker_hit_body", bm, [mats["flare"], mats["dark"]], parent=root, smooth=True)
    G.empty("FX_flare", (0, 0, 0.8), root)
    return root


# ------------------------------------------------------------------ arena
ISLANDS = [
    # name, godot x, z, radius, height, seed, palms, extras
    ("isle_lighthouse", -46, -14, 13, 7.0, 3, 10, "lighthouse"),
    ("isle_east", 47, 6, 11, 5.5, 5, 9, None),
    ("isle_west_s", -40, 34, 7, 3.5, 8, 4, None),
    ("isle_far_n", 4, -80, 18, 11.0, 11, 12, None),
    ("isle_far_nw", -62, -62, 12, 8.0, 13, 6, None),
    ("isle_far_ne", 66, -58, 14, 9.0, 17, 7, None),
    ("isle_south_e", 52, 54, 9, 5.0, 19, 6, None),
    ("isle_south_w", -58, 66, 10, 6.0, 23, 5, None),
    ("isle_far_s", 8, 92, 15, 9.0, 29, 8, None),
]
ROCKS = [(-26, -2, 2.2), (-28, 0.5, 1.4), (27, -50, 2.6), (24, -54, 1.6), (-27, 52, 2.0), (28, 4, 1.8),
         (30, 1, 1.2), (-31, -46, 2.4), (36, 26, 2.0), (-35, 10, 1.6), (18, -66, 2.8), (-14, 70, 2.2)]


def arena():
    mats = M()
    root = G.empty("arena")
    data_islands = []
    for (name, gx, gz, R, H, seed, n_palms, extra) in ISLANDS:
        grp = G.empty(name + "_grp", bl(gx, gz), root)
        ob = island(name, R, H, seed, grp)
        bpy.context.view_layer.update()
        rng = random.Random(seed)
        placed = 0
        tries = 0
        while placed < n_palms and tries < 400:
            tries += 1
            a = rng.random() * 2 * math.pi
            rr = rng.uniform(0.15, 0.92) * R
            x, y = math.cos(a) * rr, math.sin(a) * rr
            z, nrm = surface_z(ob, x, y)
            if z is None or z < 0.5 or nrm.z < 0.82:
                continue
            if extra == "lighthouse" and Vector((x - 2, y + 2, 0)).length < 7:
                continue
            palm("%s_palm_%d" % (name, placed), placed % 3, grp, (x, y, z - 0.2), rng.random() * 6.28)
            placed += 1
        for k in range(int(8 + R * 0.6)):
            a = rng.random() * 2 * math.pi
            rr = rng.uniform(0.55, 1.08) * R
            x, y = math.cos(a) * rr, math.sin(a) * rr
            z, _ = surface_z(ob, x, y)
            size = rng.uniform(1.2, 2.2 + R * 0.12)
            rock("%s_rock_%d" % (name, k), size, seed * 10 + k, grp, (x, y, (z or 0) - size * 0.35), squash=rng.uniform(0.6, 1.0))
        if extra == "lighthouse":
            z, _ = surface_z(ob, 2, -2)
            lighthouse(grp, (2, -2, (z or 4) - 0.3), 0.6)
            pier(grp, (R * 0.55, -R * 0.55, 0), math.radians(-60) - math.pi / 2, 12)
        data_islands.append({"name": name, "x": gx, "z": gz, "r": R * 0.92})
    for k, (gx, gz, s) in enumerate(ROCKS):
        rock("sea_rock_%d" % k, s, 900 + k, root, bl(gx, gz, -0.4))
        data_islands.append({"name": "sea_rock_%d" % k, "x": gx, "z": gz, "r": s * 1.1})
    return root, data_islands


def layout(data_islands):
    half = CELL * GRID_N / 2
    corners = []
    for (cx, cz) in (PLAYER_GRID, ENEMY_GRID):
        for sx in (-1, 1):
            for sz in (-1, 1):
                corners.append([cx + sx * (half + 1.6), cz + sz * (half + 1.6)])
    d = {
        "cell": CELL,
        "grid_n": GRID_N,
        "grids": {"player": {"x": PLAYER_GRID[0], "z": PLAYER_GRID[1]}, "enemy": {"x": ENEMY_GRID[0], "z": ENEMY_GRID[1]}},
        "scenery": "res://assets/env/arena.gltf",
        "buoys": corners,
        "islands": data_islands,
        "beacon": {"x": -46 + 2, "y": 0, "z": -14 + 2},
        "cameras": {"title": {"pos": [-30, 9, 70], "target": [0, 4, 26]}, "placement": {"pos": [0, 50, 57], "target": [0, 0, 30]}, "attack": {"pos": [0, 44, 14], "target": [0, 0, -30]}, "defense": {"pos": [0, 36, -14], "target": [0, 0, 25]}, "overview": {"pos": [64, 52, 8], "target": [0, 0, 0]}},
        "moods": {
            "day": {"sun_dir": [-0.45, -0.75, -0.48], "sun_color": [1.0, 0.95, 0.85], "sun_energy": 1.3,
                    "sky_top": [0.18, 0.42, 0.78], "sky_horizon": [0.72, 0.86, 0.95], "ambient": 0.42,
                    "water_deep": [0.02, 0.2, 0.3], "water_shallow": [0.1, 0.75, 0.72], "fog": 0.0012, "lights": False},
            "sunset": {"sun_dir": [0.75, -0.28, 0.6], "sun_color": [1.0, 0.8, 0.62], "sun_energy": 1.2, "sky_top": [0.22, 0.3, 0.6], "sky_horizon": [0.98, 0.66, 0.5], "ambient": 0.5, "water_deep": [0.02, 0.12, 0.22], "water_shallow": [0.12, 0.5, 0.55], "fog": 0.0018, "lights": True},
            "night": {"sun_dir": [-0.3, -0.65, 0.7], "sun_color": [0.68, 0.78, 1.0], "sun_energy": 0.9, "sky_top": [0.02, 0.04, 0.11], "sky_horizon": [0.1, 0.16, 0.32], "ambient": 0.7, "water_deep": [0.02, 0.08, 0.15], "water_shallow": [0.05, 0.26, 0.32], "fog": 0.0025, "lights": True},
        },
    }
    os.makedirs(LEVELS, exist_ok=True)
    with open(os.path.join(LEVELS, "arena_layout.json"), "w") as f:
        json.dump(d, f, indent=1)
    print("layout written")


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(REN, exist_ok=True)
    for fn in (buoy, marker_miss, marker_hit):
        G.reset()
        root = fn()
        G.export_gltf(root, os.path.join(OUT, root.name + ".gltf"))
    G.reset()
    root, data_islands = arena()
    G.export_gltf(root, os.path.join(OUT, "arena.gltf"))
    layout(data_islands)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(G.ROOT, "blender", "arena.blend"))
    if RENDER:
        import lib_render as R
        scene = bpy.context.scene
        R.setup(scene, (1280, 720))
        R.water_plane(scene, 600)
        # Godot camera "attack" pos (0,46,30) target (0,0,-24) -> Blender (x, -z, y)
        R.render_cam(os.path.join(REN, "arena_attack.png"), (0, -30, 46), (0, 24, 0), lens=24)
        R.render_cam(os.path.join(REN, "arena_overview.png"), (70, 0, 60), (0, 0, 0), lens=22)
        R.render_cam(os.path.join(REN, "isle_lighthouse.png"), (-20, 0, 14), (-46, 14, 4), lens=30)
    print("DONE")


if __name__ == "__main__":
    main()
