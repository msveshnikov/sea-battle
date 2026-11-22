"""Task 2: the fleet. Four warship classes + airstrike plane + torpedo, all procedural.

    blender -b --factory-startup -P blender/scripts/build_ships.py -- [--only battleship,cruiser] [--no-render]

Output: assets/ships/<name>.gltf (+.bin, textures shared in assets/textures), renders/ships/<name>.png
Node names the game relies on:
  <ship>            root empty, pivot = centre of the waterline, bow faces -Y (Godot +Z)
  <ship>_hull       all static parts (multi-material)
  TURRET_<k>        main turrets, pivot on the turret axis; rest yaw baked into the node rotation
  GUN_<k>           barrels of that turret, pivot on the trunnion (elevation about local X)
  MUZZLE_<k>        empty at the barrel tips (muzzle flash / shell spawn)
  SEARCHLIGHT_<n>   empties where the game puts spot lights at night
  FUNNEL_<n>        empties at funnel tops (smoke)
  PROP              plane propeller (spins about local Y in Blender = Godot -Z axis)
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import lib_geo as G  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = None
if "--only" in ARGS:
    ONLY = set(ARGS[ARGS.index("--only") + 1].split(","))
RENDER = "--no-render" not in ARGS

OUT = os.path.join(G.ROOT, "assets", "ships")
REN = os.path.join(G.ROOT, "renders", "ships")


# ------------------------------------------------------------------ materials
def mats():
    return {
        "hull": G.mat("hull", "hull.png", rough=0.55),
        "deck": G.mat("deck", "deck.png", (0.78, 0.72, 0.68, 1), rough=0.8),
        "steel": G.mat("steel", "steel.png", (0.25, 0.27, 0.29, 1), rough=0.5, metal=0.2),
        "dark": G.mat("steel_dark", "steel.png", (0.13, 0.135, 0.15, 1), rough=0.45, metal=0.3),
        "orange": G.mat("orange", "steel.png", (1.0, 0.36, 0.04, 1), rough=0.5),
        "black": G.mat("black", None, (0.03, 0.03, 0.035, 1), rough=0.8),
        "white": G.mat("white", "steel.png", (0.95, 0.94, 0.9, 1), rough=0.6),
        "windows": G.mat("windows", "windows.png", rough=0.15, emit_tex="windows_emit.png", emit_strength=1.0),
        "lamp": G.mat("lamp", None, (1, 0.95, 0.8, 1), rough=0.2, emit=(1, 0.9, 0.7), emit_strength=2.0),
        "flag": G.mat("flag", "flag.png", rough=0.8),
    }


MATS_ORDER = ["hull", "deck", "steel", "dark", "orange", "black", "white", "windows", "lamp", "flag"]


def mi(name):
    return MATS_ORDER.index(name)


# ------------------------------------------------------------------ hull loft
def hull_profile(t, L, B, H, D, bow_rise, kind):
    if kind == "boat":
        b = B / 2 * (1 - (1 - min(t / 0.5, 1)) ** 2.0) ** 0.7
    else:
        b = B / 2 * (1 - (1 - min(t / 0.36, 1)) ** 2.2) ** 0.75
        if t > 0.8:
            b *= 1 - 0.3 * ((t - 0.8) / 0.2) ** 2
    b = max(b, 0.004)
    h = H + bow_rise * max(0.0, 1 - t / 0.35) ** 2
    if kind == "boat":
        d = D * (0.35 + 0.65 * min(1.0, t / 0.4))
        d *= 1 - 0.1 * max(0.0, (t - 0.7) / 0.3)
    else:
        d = D * min(1.0, 0.25 + t / 0.14)
        d *= 1 - 0.35 * max(0.0, (t - 0.82) / 0.18)
    return b, h, d


def build_hull(bm, L, B, H, D, bow_rise=0.35, kind="warship", n=44):
    """Hull sides + transom (material hull) and deck (material deck). Returns deck edge sampler."""
    uv = bm.loops.layers.uv.verify()
    rings, deck_pts = [], []
    for i in range(n + 1):
        t = i / n
        t = t ** 0.85 if t < 0.5 else t  # denser near the bow
        y = -L / 2 + t * L
        b, h, d = hull_profile(t, L, B, H, D, bow_rise, kind)
        half = [(b, h), (b * 0.995, h * 0.45), (b * 0.98, 0.2), (b * 0.955, -0.12 * d)]
        for k in range(1, 6):
            a = math.radians(18 * k)
            x = b * 0.955 * math.cos(a) ** (0.55 if kind == "boat" else 0.7)
            z = -0.12 * d - 0.88 * d * math.sin(a)
            half.append((x, z))
        ring_xz = half + [(-x, z) for (x, z) in reversed(half[:-1])]
        rings.append([bm.verts.new((x, y, z)) for (x, z) in ring_xz])
        deck_pts.append((y, b, h))
    side_faces = []
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for j in range(len(r0) - 1):
            f = bm.faces.new([r0[j], r0[j + 1], r1[j + 1], r1[j]])
            f.material_index = mi("hull")
            side_faces.append(f)
    tr = bm.faces.new(list(rings[-1]))
    tr.material_index = mi("hull")
    side_faces.append(tr)
    deck_faces = []
    for r0, r1 in zip(rings[:-1], rings[1:]):
        f = bm.faces.new([r0[0], r1[0], r1[-1], r0[-1]])
        f.material_index = mi("deck")
        deck_faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=side_faces + deck_faces)
    # make sure the deck faces up and sides face out
    for f in deck_faces:
        if f.normal.z < 0:
            f.normal_flip()
    for f in side_faces:
        for l in f.loops:
            co = l.vert.co
            l[uv].uv = (co.y / 8.0, (co.z + 2.0) / 4.0)
    for f in deck_faces:
        for l in f.loops:
            co = l.vert.co
            l[uv].uv = (co.y / 4.0, co.x / 4.0)
    bmesh.ops.remove_doubles(bm, verts=rings[0], dist=0.012)

    def deck_at(y):
        """(half beam, deck height) at a y position."""
        best = min(deck_pts, key=lambda p: abs(p[0] - y))
        return best[1], best[2]
    return deck_pts, deck_at


def railing(bm, deck_pts, t0=0.04, t1=0.985, height=0.26, inset=0.05, step=0.55):
    pts = [p for p in deck_pts if p[1] > 0.12]
    n = len(deck_pts)
    pts = deck_pts[int(t0 * n):int(t1 * n) + 1]
    for side in (-1, 1):
        last = None
        for (y, b, h) in pts:
            x = side * (b - inset)
            if last is None or abs(y - last[0]) >= step:
                G.bm_cyl(bm, 0.018, height, (x, y, h), segs=4, mat_index=mi("dark"), caps=False)
                last = (y, x, h)
        # top rail as connected thin quads between successive points
        prev = None
        for (y, b, h) in pts:
            x = side * (b - inset)
            p = Vector((x, y, h + height))
            if prev is not None:
                a, c = prev, p
                v = [bm.verts.new(a + Vector((0, 0, -0.02))), bm.verts.new(c + Vector((0, 0, -0.02))),
                     bm.verts.new(c + Vector((0, 0, 0.02))), bm.verts.new(a + Vector((0, 0, 0.02)))]
                f = bm.faces.new(v)
                f.material_index = mi("dark")
            prev = p


# ------------------------------------------------------------------ parts
def deckhouse(bm, sx, sy, sz, y, z, x=0.0, mat="steel", windows=False, taper=1.0, orange_panels=False):
    """Superstructure block; optional window band on the front and sides."""
    faces = G.bm_box(bm, sx, sy, sz, (x, y, z), taper=taper, mat_index=mi(mat))
    G.box_uv_faces(bm, faces, 2.0)
    if windows:
        wz0 = z + sz * 0.45
        wh = min(0.28, sz * 0.38)
        window_band(bm, x, y, sx * (taper + (1 - taper) * 0.4), sy * (taper + (1 - taper) * 0.4), wz0, wh)
    if orange_panels:
        for side in (-1, 1):
            pf = G.bm_box(bm, 0.03, sy * 0.3, sz * 0.35, (x + side * (sx / 2 + 0.01), y + sy * 0.15, z + sz * 0.15), mat_index=mi("orange"))
            G.box_uv_faces(bm, pf, 2.0)
    return z + sz


def window_band(bm, x, y, sx, sy, z0, wh):
    uv = bm.loops.layers.uv.verify()
    hx, hy = sx / 2 + 0.012, sy / 2 + 0.012
    # front (-Y), port and starboard sides
    quads = [
        [(x - hx, y - hy, z0), (x + hx, y - hy, z0), (x + hx, y - hy, z0 + wh), (x - hx, y - hy, z0 + wh)],
        [(x + hx, y - hy, z0), (x + hx, y + hy, z0), (x + hx, y + hy, z0 + wh), (x + hx, y - hy, z0 + wh)],
        [(x - hx, y + hy, z0), (x - hx, y - hy, z0), (x - hx, y - hy, z0 + wh), (x - hx, y + hy, z0 + wh)],
    ]
    for q in quads:
        vs = [bm.verts.new(p) for p in q]
        f = bm.faces.new(vs)
        f.material_index = mi("windows")
        length = (Vector(q[1]) - Vector(q[0])).length
        us = [0, length / 4.0, length / 4.0, 0]
        for l, u, v in zip(f.loops, us, [0, 0, 1, 1]):
            l[uv].uv = (u, v)


def funnel(bm, y, z, r, h, rake=0.18, idx=0, ship=None, parent=None):
    segs = 18
    sy = 1.35
    body = G.bm_cyl(bm, r, h, (0, y, z), segs=segs, r_top=r * 0.96, mat_index=mi("dark"), sy=sy, caps=False)
    band = G.bm_cyl(bm, r * 1.025, h * 0.22, (0, y, z + h * 0.58), segs=segs, r_top=r * 1.0, mat_index=mi("orange"), sy=sy, caps=False)
    cap = G.bm_cyl(bm, r * 1.04, h * 0.08, (0, y, z + h * 0.92), segs=segs, mat_index=mi("black"), sy=sy)
    G.box_uv_faces(bm, body + band + cap, 2.0)
    # rake: lean aft (+Y) proportional to height above the base
    for f in body + band + cap:
        for v in f.verts:
            if not v.tag:
                v.co.y += (v.co.z - z) * rake
                v.tag = True
    for f in body + band + cap:
        for v in f.verts:
            v.tag = False
    if ship is not None:
        G.empty("FUNNEL_%d" % idx, (0, y + h * rake, z + h), parent)


def tripod_mast(bm, y, z, h, spread=0.35, yard=1.4, radar=True):
    top = Vector((0, y, z + h))
    feet = [Vector((0, y - spread, z)), Vector((-spread * 0.9, y + spread * 0.6, z)), Vector((spread * 0.9, y + spread * 0.6, z))]
    for f in feet:
        strut(bm, f, top, 0.035)
    strut(bm, top, top + Vector((0, 0, h * 0.35)), 0.025)
    # yard arm and a little platform
    strut(bm, top + Vector((-yard / 2, 0, h * 0.2)), top + Vector((yard / 2, 0, h * 0.2)), 0.02)
    pf = G.bm_box(bm, 0.45, 0.45, 0.08, (0, y, z + h * 0.92), mat_index=mi("dark"))
    G.box_uv_faces(bm, pf, 2.0)
    if radar:
        rf = G.bm_box(bm, 0.7, 0.08, 0.22, (0, y, z + h * 1.22), mat_index=mi("dark"))
        G.box_uv_faces(bm, rf, 2.0)


def lattice_mast(bm, y, z, h, w=0.55):
    legs = [(-w / 2, -w / 2), (w / 2, -w / 2), (w / 2, w / 2), (-w / 2, w / 2)]
    top_s = 0.25
    tops = [Vector((x * top_s * 2, y + yy * top_s * 2, z + h)) for x, yy in legs]
    bots = [Vector((x, y + yy, z)) for x, yy in legs]
    for a, b in zip(bots, tops):
        strut(bm, a, b, 0.03)
    levels = 5
    for k in range(levels):
        t0, t1 = k / levels, (k + 1) / levels
        p0 = [a.lerp(b, t0) for a, b in zip(bots, tops)]
        p1 = [a.lerp(b, t1) for a, b in zip(bots, tops)]
        for i in range(4):
            strut(bm, p0[i], p1[(i + 1) % 4], 0.012)
            strut(bm, p1[i], p1[(i + 1) % 4], 0.012)
    top = Vector((0, y, z + h))
    strut(bm, top, top + Vector((0, 0, h * 0.4)), 0.025)
    strut(bm, top + Vector((-0.6, 0, h * 0.25)), top + Vector((0.6, 0, h * 0.25)), 0.02)
    rf = G.bm_box(bm, 0.6, 0.08, 0.2, (0, y, z + h + 0.05), mat_index=mi("dark"))
    G.box_uv_faces(bm, rf, 2.0)


def strut(bm, a, b, r, segs=5, mat="dark"):
    d = b - a
    length = d.length
    if length < 1e-4:
        return
    faces = G.bm_cyl(bm, r, length, (0, 0, 0), segs=segs, mat_index=mi(mat), caps=False)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    G.transform_faces(bm, faces, Matrix.Translation(a) @ rot)


def lifebuoy(bm, x, y, z, side):
    f = G.bm_cyl(bm, 0.11, 0.035, (x, y, z), segs=10, axis="X", mat_index=mi("orange"))
    if side < 0:
        G.transform_faces(bm, f, Matrix.Translation((-0.035, 0, 0)))


def lifeboat(bm, x, y, z, length=0.9):
    f = G.bm_sphere(bm, 0.5, (0, 0, 0), segs=10, rings=6, mat_index=mi("white"))
    G.transform_faces(bm, f, Matrix.Translation((x, y, z)) @ Matrix.Diagonal((0.32, length, 0.3, 1)))
    G.box_uv_faces(bm, f, 2.0)


def vent(bm, x, y, z, r=0.09, h=0.25):
    f = G.bm_cyl(bm, r, h, (x, y, z), segs=8, mat_index=mi("steel"))
    G.box_uv_faces(bm, f, 2.0)


def aa_mount(bm, x, y, z):
    f = G.bm_cyl(bm, 0.16, 0.12, (x, y, z), segs=8, mat_index=mi("steel"))
    G.box_uv_faces(bm, f, 2.0)
    for dx in (-0.05, 0.05):
        G.bm_cyl(bm, 0.018, 0.45, (x + dx, y, z + 0.18), segs=4, axis="Y", mat_index=mi("dark"))
    sh = G.bm_box(bm, 0.36, 0.05, 0.16, (x, y - 0.14, z + 0.1), mat_index=mi("steel"))
    G.box_uv_faces(bm, sh, 2.0)


def searchlight(bm, x, y, z, idx, parent):
    f = G.bm_cyl(bm, 0.09, 0.16, (x, y + 0.08, z), segs=10, axis="Y", mat_index=mi("dark"))
    G.bm_cyl(bm, 0.075, 0.01, (x, y + 0.075, z), segs=10, axis="Y", mat_index=mi("lamp"))
    G.empty("SEARCHLIGHT_%d" % idx, (x, y, z), parent)


def secondary_gun(bm, x, y, z, facing_x):
    f = G.bm_cyl(bm, 0.2, 0.14, (x, y, z), segs=10, mat_index=mi("steel"))
    G.box_uv_faces(bm, f, 2.0)
    hf = G.bm_box(bm, 0.36, 0.42, 0.2, (x, y, z + 0.1), taper=0.85, mat_index=mi("steel"))
    G.box_uv_faces(bm, hf, 2.0)
    # barrel points outboard (+X on starboard, -X on port)
    G.bm_cyl(bm, 0.035, facing_x * 0.5, (x + facing_x * 0.1, y, z + 0.2), segs=6, axis="X", mat_index=mi("dark"))


def main_turret(root, ship, key, y, z, s=1.0, barrels=2, facing=0.0, barrel_len=1.6, x=0.0):
    """TURRET_<key> (yaw) with GUN_<key> (pitch) and MUZZLE_<key>."""
    M = mats()
    bm = bmesh.new()
    G.bm_cyl(bm, 0.5 * s, 0.2 * s, (0, 0, -0.08 * s), segs=20, mat_index=0)
    # housing: sloped front and sides, flat roof
    w, l, hgt = 1.18 * s, 1.5 * s, 0.52 * s
    y0, y1 = -0.62 * s, 0.88 * s
    z0 = 0.08 * s
    pts = [(-w / 2, y0, z0), (w / 2, y0, z0), (w / 2, y1, z0), (-w / 2, y1, z0),
           (-w * 0.4, y0 + 0.3 * s, z0 + hgt), (w * 0.4, y0 + 0.3 * s, z0 + hgt), (w * 0.44, y1 - 0.05 * s, z0 + hgt), (-w * 0.44, y1 - 0.05 * s, z0 + hgt)]
    vs = [bm.verts.new(p) for p in pts]
    hf = []
    for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        hf.append(bm.faces.new([vs[i] for i in f]))
    # rangefinder ears at the back
    ear = G.bm_box(bm, w * 1.25, 0.16 * s, 0.14 * s, (0, y1 - 0.35 * s, z0 + hgt * 0.55))
    roof_vent = G.bm_box(bm, 0.25 * s, 0.3 * s, 0.08 * s, (0.2 * s, y1 - 0.35 * s, z0 + hgt))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    G.box_uv(bm, 2.0)
    tur = G.mesh_obj("TURRET_" + key, bm, [M["steel"]], parent=root)
    tur.location = (x, y, z)
    tur.rotation_euler = (0, 0, facing)
    G.bevel_obj(tur, 0.035 * s, 2, 30)
    # guns
    bm = bmesh.new()
    mant = G.bm_box(bm, w * 0.62, 0.22 * s, 0.26 * s, (0, -0.02 * s, -0.13 * s), mat_index=0)
    spacing = 0.32 * s if barrels == 2 else 0.28 * s
    offs = [0.0] if barrels == 1 else ([-spacing / 2, spacing / 2] if barrels == 2 else [-spacing, 0, spacing])
    for ox in offs:
        G.bm_cyl(bm, 0.085 * s, -barrel_len * s, (ox, 0, 0), segs=10, r_top=0.065 * s, axis="Y", mat_index=1)
        G.bm_cyl(bm, 0.082 * s, -0.12 * s, (ox, -barrel_len * s + 0.02, 0), segs=10, axis="Y", mat_index=1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    G.box_uv(bm, 2.0)
    gun = G.mesh_obj("GUN_" + key, bm, [M["steel"], M["dark"]], parent=tur, smooth=True)
    gun.location = (0, y0 + 0.12 * s, z0 + hgt * 0.45)
    G.empty("MUZZLE_" + key, (0, -barrel_len * s - 0.1, 0), gun)
    return tur


# ------------------------------------------------------------------ ships
def new_ship(name):
    root = G.empty(name, (0, 0, 0))
    bm = bmesh.new()
    return root, bm


def finish_hull(root, name, bm):
    M = mats()
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if f.material_index not in (mi("deck"), mi("hull"), mi("windows"))])
    ob = G.mesh_obj(name + "_hull", bm, [M[k] for k in MATS_ORDER], parent=root)
    G.shade_flat_smooth(ob, 32)
    return ob


def battleship():
    name = "battleship"
    L, B, H, D = 15.2, 2.9, 1.15, 0.95
    root, bm = new_ship(name)
    deck_pts, deck_at = build_hull(bm, L, B, H, D, bow_rise=0.42)
    railing(bm, deck_pts)
    z = H
    # breakwater / forecastle details
    for y in (-6.3, -6.0):
        vent(bm, 0.3, y, deck_at(y)[1], 0.06, 0.15)
    # bridge tower (stepped)
    by = -1.1
    zt = deckhouse(bm, 2.1, 2.5, 0.62, by + 0.4, z, orange_panels=True)
    zt = deckhouse(bm, 1.75, 2.0, 0.6, by + 0.2, zt, windows=True)
    zt = deckhouse(bm, 1.35, 1.45, 0.55, by, zt, windows=True)
    zt = deckhouse(bm, 1.0, 1.05, 0.5, by - 0.05, zt, windows=True, taper=0.92)
    zt = deckhouse(bm, 0.62, 0.7, 0.32, by, zt, mat="dark")
    rf = G.bm_box(bm, 1.5, 0.14, 0.14, (0, by + 0.1, zt - 0.2), mat_index=mi("dark"))
    G.box_uv_faces(bm, rf, 2)
    tripod_mast(bm, by + 0.25, zt, 1.6, spread=0.3)
    # wings with searchlights and AA
    for side in (-1, 1):
        wing = G.bm_box(bm, 0.5, 0.6, 0.06, (side * 1.05, by - 0.1, z + 1.75), mat_index=mi("steel"))
        G.box_uv_faces(bm, wing, 2)
        searchlight(bm, side * 1.15, by - 0.25, z + 1.86, 0 if side < 0 else 1, root)
    # funnels
    funnel(bm, 1.15, z + 0.55, 0.42, 2.0, idx=0, ship=name, parent=root)
    funnel(bm, 2.5, z + 0.55, 0.42, 1.85, idx=1, ship=name, parent=root)
    deckhouse(bm, 1.7, 2.9, 0.55, 1.75, z, orange_panels=True)
    # aft superstructure + mainmast
    zt2 = deckhouse(bm, 1.45, 1.35, 0.6, 3.35, z)
    zt2 = deckhouse(bm, 0.9, 0.9, 0.42, 3.35, zt2, windows=True)
    tripod_mast(bm, 3.3, zt2, 1.3, spread=0.25, radar=False)
    # secondary battery + AA + boats
    for side in (-1, 1):
        for y in (-0.4, 0.6, 1.6, 2.6):
            secondary_gun(bm, side * 1.05, y, z, side)
        for y in (0.2, 2.0):
            aa_mount(bm, side * 0.72, y, z + 0.55)
        lifeboat(bm, side * 0.68, 1.15 + 0.6, z + 0.62)
        lifebuoy(bm, side * (1.05 + 0.02), by + 0.6, z + 0.3, side)
        lifebuoy(bm, side * (0.725 + 0.02), 3.35, z + 0.3, side)
    finish_hull(root, name, bm)
    main_turret(root, name, "A", -4.75, deck_at(-4.75)[1], s=1.05)
    bar = bmesh.new()
    G.bm_cyl(bar, 0.6, 0.38, (0, -3.05, z), segs=20)
    G.box_uv(bar, 2.0)
    G.mesh_obj(name + "_barbette", bar, [mats()["steel"]], parent=root)
    main_turret(root, name, "B", -3.05, z + 0.38, s=1.05)
    main_turret(root, name, "C", 5.0, z, s=1.05, facing=math.pi)
    return root


def cruiser():
    name = "cruiser"
    L, B, H, D = 11.3, 2.35, 1.0, 0.8
    root, bm = new_ship(name)
    deck_pts, deck_at = build_hull(bm, L, B, H, D, bow_rise=0.36)
    railing(bm, deck_pts)
    z = H
    by = -1.35
    zt = deckhouse(bm, 1.6, 1.8, 0.55, by + 0.2, z, orange_panels=True)
    zt = deckhouse(bm, 1.3, 1.35, 0.5, by, zt, windows=True)
    zt = deckhouse(bm, 0.95, 0.9, 0.45, by - 0.05, zt, windows=True, taper=0.92)
    zt = deckhouse(bm, 0.55, 0.55, 0.26, by, zt, mat="dark")
    lattice_mast(bm, by + 0.7, z + 0.55, 2.3, w=0.55)
    for side in (-1, 1):
        searchlight(bm, side * 0.7, by - 0.35, z + 1.25, 0 if side < 0 else 1, root)
        lifebuoy(bm, side * (0.8 + 0.02), by + 0.4, z + 0.28, side)
        aa_mount(bm, side * 0.75, 1.3, z + 0.5)
        lifeboat(bm, side * 0.62, 0.55, z + 0.58, 0.8)
        secondary_gun(bm, side * 0.85, 2.3, z, side)
    funnel(bm, -0.05, z + 0.45, 0.36, 1.6, idx=0, ship=name, parent=root)
    funnel(bm, 1.05, z + 0.45, 0.36, 1.5, idx=1, ship=name, parent=root)
    deckhouse(bm, 1.3, 2.3, 0.45, 0.5, z, orange_panels=True)
    zt2 = deckhouse(bm, 1.05, 1.0, 0.5, 2.1, z, windows=True)
    strut(bm, Vector((0, 2.2, zt2)), Vector((0, 2.35, zt2 + 1.4)), 0.03)
    finish_hull(root, name, bm)
    main_turret(root, name, "A", -3.3, deck_at(-3.3)[1], s=0.88)
    main_turret(root, name, "C", 3.55, z, s=0.88, facing=math.pi)
    return root


def destroyer():
    name = "destroyer"
    L, B, H, D = 7.5, 1.85, 0.85, 0.65
    root, bm = new_ship(name)
    deck_pts, deck_at = build_hull(bm, L, B, H, D, bow_rise=0.3)
    railing(bm, deck_pts)
    z = H
    by = -1.0
    zt = deckhouse(bm, 1.25, 1.2, 0.5, by + 0.1, z, orange_panels=True)
    zt = deckhouse(bm, 1.0, 0.85, 0.45, by, zt, windows=True, taper=0.94)
    zt = deckhouse(bm, 0.55, 0.45, 0.2, by, zt, mat="dark")
    lattice_mast(bm, by + 0.45, z + 0.5, 1.7, w=0.45)
    for side in (-1, 1):
        searchlight(bm, side * 0.55, by - 0.25, z + 0.98, 0 if side < 0 else 1, root)
        lifebuoy(bm, side * (0.625 + 0.02), by + 0.2, z + 0.25, side)
    funnel(bm, 0.25, z + 0.3, 0.32, 1.35, idx=0, ship=name, parent=root)
    deckhouse(bm, 0.95, 1.2, 0.3, 0.35, z)
    # triple torpedo tubes
    tt = G.bm_cyl(bm, 0.25, 0.1, (0, 1.45, z), segs=12, mat_index=mi("steel"))
    G.box_uv_faces(bm, tt, 2)
    for ox in (-0.17, 0, 0.17):
        tb = G.bm_cyl(bm, 0.075, 1.05, (ox, 0.95, z + 0.2), segs=8, axis="Y", mat_index=mi("steel"))
        G.box_uv_faces(bm, tb, 2)
    aa_mount(bm, 0, 2.35, z + 0.0)
    deckhouse(bm, 0.6, 0.5, 0.3, 2.85, z)
    finish_hull(root, name, bm)
    main_turret(root, name, "A", -2.3, deck_at(-2.3)[1], s=0.72, barrels=2, barrel_len=1.45)
    return root


def patrol():
    name = "patrol"
    L, B, H, D = 3.5, 1.45, 0.6, 0.38
    root, bm = new_ship(name)
    deck_pts, deck_at = build_hull(bm, L, B, H, D, bow_rise=0.16, kind="boat", n=24)
    railing(bm, deck_pts, t0=0.12, height=0.18, step=0.4)
    z = H
    # cabin with windscreen
    zt = deckhouse(bm, 0.9, 0.95, 0.42, -0.2, z, windows=True, taper=0.9, orange_panels=True)
    G.box_uv_faces(bm, G.bm_box(bm, 0.5, 0.45, 0.1, (0, -0.15, zt), mat_index=mi("dark")), 2)
    lattice_mast(bm, 0.0, zt + 0.08, 0.75, w=0.22)
    searchlight(bm, 0.0, -0.45, zt + 0.12, 0, root)
    for side in (-1, 1):
        tb = G.bm_cyl(bm, 0.085, 1.2, (side * 0.46, 0.15, z + 0.1), segs=10, axis="Y", mat_index=mi("steel"))
        G.box_uv_faces(bm, tb, 2)
        lifebuoy(bm, side * (0.42 + 0.02), -0.05, z + 0.2, side)
    finish_hull(root, name, bm)
    main_turret(root, name, "A", -1.05, deck_at(-1.05)[1], s=0.42, barrels=2, barrel_len=1.3)
    return root


def plane():
    """Airstrike plane, nose toward -Y, pivot at the centre of mass, PROP spins about Y."""
    name = "plane"
    M = mats()
    root = G.empty(name)
    bm = bmesh.new()
    # fuselage loft
    secs = [(-1.6, 0.22), (-1.4, 0.3), (-0.8, 0.34), (0.0, 0.32), (0.9, 0.22), (1.7, 0.08)]
    rings = []
    for y, r in secs:
        ring = []
        for i in range(12):
            a = 2 * math.pi * i / 12
            ring.append(bm.verts.new((math.cos(a) * r, y, math.sin(a) * r * 1.1)))
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(12):
            j = (i + 1) % 12
            bm.faces.new([a[i], a[j], b[j], b[i]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    for f in bm.faces:
        f.material_index = 0
    # wings, tail
    w = G.bm_box(bm, 4.2, 0.85, 0.1, (0, -0.35, -0.12), taper=1.0)
    th = G.bm_box(bm, 1.6, 0.45, 0.06, (0, 1.45, 0.05))
    tv = G.bm_box(bm, 0.06, 0.55, 0.6, (0, 1.45, 0.05), taper=0.6)
    for f in w + th + tv:
        f.material_index = 0
    # wing tips orange
    for side in (-1, 1):
        tip = G.bm_box(bm, 0.4, 0.86, 0.11, (side * 1.9, -0.35, -0.125))
        for f in tip:
            f.material_index = 2
    # canopy
    can = G.bm_sphere(bm, 0.28, (0, -0.5, 0.25), segs=10, rings=6, hemi=True)
    G.transform_faces(bm, can, Matrix.Translation((0, -0.5, 0.25)) @ Matrix.Diagonal((0.8, 2.0, 0.9, 1)) @ Matrix.Translation((0, 0.5, -0.25)))
    for f in can:
        f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    G.box_uv(bm, 2.0)
    body = G.mesh_obj(name + "_body", bm, [M["steel"], M["windows"], M["orange"]], parent=root, smooth=True)
    G.shade_flat_smooth(body, 40)
    bm = bmesh.new()
    G.bm_cyl(bm, 0.1, -0.2, (0, 0, 0), segs=8, axis="Y")
    for k in range(3):
        bl = G.bm_box(bm, 0.12, 0.03, 0.75, (0, -0.15, 0))
        G.transform_faces(bm, bl, Matrix.Rotation(k * 2 * math.pi / 3, 4, "Y"))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    G.box_uv(bm, 2.0)
    G.mesh_obj("PROP", bm, [M["dark"]], parent=root, loc=(0, -1.62, 0))
    return root


def torpedo():
    name = "torpedo"
    M = mats()
    root = G.empty(name)
    bm = bmesh.new()
    G.bm_cyl(bm, 0.1, 1.3, (0, -0.65, 0), segs=10, axis="Y")
    nose = G.bm_sphere(bm, 0.1, (0, -0.65, 0), segs=10, rings=6)
    G.box_uv(bm, 1.0)
    G.mesh_obj(name + "_body", bm, [M["dark"]], parent=root, smooth=True)
    return root


def shell():
    root = G.empty("shell")
    bm = bmesh.new()
    G.bm_cyl(bm, 0.09, 0.4, (0, -0.2, 0), segs=8, axis="Y")
    G.bm_sphere(bm, 0.09, (0, -0.2, 0), segs=8, rings=5)
    G.box_uv(bm, 1.0)
    G.mesh_obj("shell_body", bm, [mats()["orange"]], parent=root, smooth=True)
    return root


BUILDERS = {"battleship": battleship, "cruiser": cruiser, "destroyer": destroyer, "patrol": patrol,
            "plane": plane, "torpedo": torpedo, "shell": shell}


# ------------------------------------------------------------------ render
def preview(root, path, dist=None, water=True):
    import lib_render as R
    R.render_object(root, path, dist=dist, water=water)


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(REN, exist_ok=True)
    for name, fn in BUILDERS.items():
        if ONLY and name not in ONLY:
            continue
        G.reset()
        root = fn()
        G.export_gltf(root, os.path.join(OUT, name + ".gltf"))
        if RENDER:
            preview(root, os.path.join(REN, name + ".png"), water=name not in ("plane", "torpedo", "shell"))
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(G.ROOT, "blender", name + ".blend"))
    print("DONE")


if __name__ == "__main__":
    main()
