"""Shared Blender helpers: scene reset, materials, primitive builders with world-scale UVs,
hull lofts and glTF export. Blender 4.2+/5.x, run headless.

Conventions (decisions.md): 1 unit = 1 m, Z up, ship bow / front faces -Y (= Godot +Z),
pivot = centre of the waterline / base on the ground.
"""
import math
import os
import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "assets", "textures")

_MATS = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


def _principled(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def _set_input(node, names, value):
    for n in names:
        if n in node.inputs:
            node.inputs[n].default_value = value
            return


def image(name):
    path = os.path.join(TEX, name)
    for img in bpy.data.images:
        if img.filepath and os.path.abspath(bpy.path.abspath(img.filepath)) == os.path.abspath(path):
            return img
    return bpy.data.images.load(path)


def mat(name, tex=None, color=(1, 1, 1, 1), rough=0.6, metal=0.0, emit=None, emit_tex=None,
        emit_strength=1.0, alpha_tex=False):
    """Principled material; `tex` multiplies by `color` (glTF baseColorFactor)."""
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = _principled(m)
    _set_input(p, ["Roughness"], rough)
    _set_input(p, ["Metallic"], metal)
    if len(color) == 3:
        color = (*color, 1)
    if tex:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = image(tex)
        if color != (1, 1, 1, 1):
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            nt.links.new(t.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = color
            nt.links.new(mix.outputs[2], p.inputs["Base Color"])
        else:
            nt.links.new(t.outputs["Color"], p.inputs["Base Color"])
        if alpha_tex:
            rnd = nt.nodes.new("ShaderNodeMath")
            rnd.operation = "ROUND"
            nt.links.new(t.outputs["Alpha"], rnd.inputs[0])
            nt.links.new(rnd.outputs[0], p.inputs["Alpha"])
            try:
                m.surface_render_method = "DITHERED"
            except Exception:
                pass
    else:
        p.inputs["Base Color"].default_value = color
    if emit_tex:
        e = nt.nodes.new("ShaderNodeTexImage")
        e.image = image(emit_tex)
        nt.links.new(e.outputs["Color"], p.inputs["Emission Color"])
        _set_input(p, ["Emission Strength"], emit_strength)
    elif emit:
        p.inputs["Emission Color"].default_value = (*emit[:3], 1)
        _set_input(p, ["Emission Strength"], emit_strength)
    _MATS[name] = m
    return m


# ------------------------------------------------------------------ objects
def link(obj, parent=None):
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def empty(name, loc=(0, 0, 0), parent=None, rot_z=0.0):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.3
    link(e, parent)
    e.location = loc
    e.rotation_euler = (0, 0, rot_z)
    return e


def mesh_obj(name, bm, mats, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    link(ob, parent)
    ob.location = loc
    return ob


def box_uv(bm, scale=1.0, offset=(0, 0, 0)):
    """World-scale planar UVs per face by dominant normal axis (texel density identical everywhere)."""
    uv = bm.loops.layers.uv.verify()
    ox, oy, oz = offset
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            co = l.vert.co
            x, y, z = co.x + ox, co.y + oy, co.z + oz
            if ax == 2:
                u, v = x, y
            elif ax == 0:
                u, v = y, z
            else:
                u, v = x, z
            l[uv].uv = (u / scale, v / scale)


def bm_box(bm, sx, sy, sz, center=(0, 0, 0), bottom=True, taper=1.0, mat_index=0):
    """Box with its base at center.z (bottom=True). taper < 1 shrinks the top face."""
    cx, cy, cz = center
    z0 = cz if bottom else cz - sz / 2
    z1 = z0 + sz
    hx, hy = sx / 2, sy / 2
    tx, ty = hx * taper, hy * taper
    vs = [bm.verts.new(v) for v in [
        (cx - hx, cy - hy, z0), (cx + hx, cy - hy, z0), (cx + hx, cy + hy, z0), (cx - hx, cy + hy, z0),
        (cx - tx, cy - ty, z1), (cx + tx, cy - ty, z1), (cx + tx, cy + ty, z1), (cx - tx, cy + ty, z1)]]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    out = []
    for f in faces:
        face = bm.faces.new([vs[i] for i in f])
        face.material_index = mat_index
        out.append(face)
    return out


def bm_cyl(bm, r, h, center=(0, 0, 0), segs=16, r_top=None, axis="Z", mat_index=0, caps=True, sx=1.0, sy=1.0):
    """Cylinder/cone; base at center (for axis Z). axis Y/X: base at center, extends along +axis."""
    r_top = r if r_top is None else r_top
    cx, cy, cz = center
    bot, top = [], []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        c, s = math.cos(a), math.sin(a)
        if axis == "Z":
            bot.append(bm.verts.new((cx + c * r * sx, cy + s * r * sy, cz)))
            top.append(bm.verts.new((cx + c * r_top * sx, cy + s * r_top * sy, cz + h)))
        elif axis == "Y":
            bot.append(bm.verts.new((cx + c * r, cy, cz + s * r)))
            top.append(bm.verts.new((cx + c * r_top, cy + h, cz + s * r_top)))
        else:
            bot.append(bm.verts.new((cx, cy + c * r, cz + s * r)))
            top.append(bm.verts.new((cx + h, cy + c * r_top, cz + s * r_top)))
    faces = []
    for i in range(segs):
        j = (i + 1) % segs
        f = bm.faces.new([bot[i], bot[j], top[j], top[i]])
        f.material_index = mat_index
        faces.append(f)
    if caps:
        f1 = bm.faces.new(list(reversed(bot)))
        f2 = bm.faces.new(top)
        f1.material_index = f2.material_index = mat_index
        faces += [f1, f2]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def bm_sphere(bm, r, center=(0, 0, 0), segs=12, rings=6, mat_index=0, sz=1.0, hemi=False):
    cx, cy, cz = center
    verts = []
    top_ring = rings // 2 if hemi else 0
    rows = []
    for i in range(top_ring, rings + 1):
        th = math.pi * i / rings
        row = []
        for j in range(segs):
            ph = 2 * math.pi * j / segs
            row.append(bm.verts.new((cx + r * math.sin(th) * math.cos(ph), cy + r * math.sin(th) * math.sin(ph), cz + r * sz * math.cos(th))))
        rows.append(row)
    rows.reverse()  # from top to bottom after reverse? keep consistent orientation via recalc
    faces = []
    for a, b in zip(rows[:-1], rows[1:]):
        for j in range(segs):
            k = (j + 1) % segs
            try:
                f = bm.faces.new([a[j], a[k], b[k], b[j]])
                f.material_index = mat_index
                faces.append(f)
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=[v for r_ in rows for v in r_], dist=1e-5)
    faces = [f for f in faces if f.is_valid]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def transform_faces(bm, faces, matrix):
    verts = list({v for f in faces for v in f.verts})
    bmesh.ops.transform(bm, matrix=matrix, verts=verts)


def bevel_obj(ob, width=0.04, segments=2, angle=40):
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = True
    return mod


def weighted_normals(ob):
    try:
        ob.modifiers.new("wn", "WEIGHTED_NORMAL").keep_sharp = True
    except Exception:
        pass


def shade_flat_smooth(ob, angle=35):
    """Smooth by angle so chunky shapes keep crisp edges."""
    try:
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
        ob.select_set(False)
    except Exception:
        for p in ob.data.polygons:
            p.use_smooth = False


# ------------------------------------------------------------------ export
def select_tree(root):
    bpy.ops.object.select_all(action="DESELECT")
    stack = [root]
    while stack:
        o = stack.pop()
        o.select_set(True)
        stack.extend(o.children)


def export_gltf(root, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    select_tree(root)
    bpy.context.view_layer.objects.active = root
    rel_tex = os.path.relpath(TEX, os.path.dirname(path)).replace("\\", "/")
    kw = dict(filepath=path, export_format="GLTF_SEPARATE", use_selection=True, export_apply=True,
              export_texture_dir=rel_tex, export_yup=True, export_extras=True,
              export_import_convert_lighting_mode="RAW", export_animations=True)
    try:
        bpy.ops.export_scene.gltf(**kw)
    except TypeError as e:
        print("export kw fallback:", e)
        kw.pop("export_import_convert_lighting_mode", None)
        bpy.ops.export_scene.gltf(**kw)
    print("exported", path)


def box_uv_faces(bm, faces, scale=1.0):
    """box_uv for a subset of faces."""
    uv = bm.loops.layers.uv.verify()
    for f in faces:
        if not f.is_valid:
            continue
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            co = l.vert.co
            if ax == 2:
                u, v = co.x, co.y
            elif ax == 0:
                u, v = co.y, co.z
            else:
                u, v = co.x, co.z
            l[uv].uv = (u / scale, v / scale)
