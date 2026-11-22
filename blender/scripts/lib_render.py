"""Preview renders: three-quarter camera, warm sun, teal water plane, EEVEE."""
import math
import bpy
from mathutils import Vector


def _engine(scene):
    for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = e
            return e
        except TypeError:
            continue


def bounds(root):
    pts = []
    stack = [root]
    bpy.context.view_layer.update()
    while stack:
        o = stack.pop()
        stack.extend(o.children)
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    if not pts:
        return Vector((0, 0, 0)), 2.0
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return (lo + hi) / 2, (hi - lo).length / 2


def setup(scene, res=(960, 540)):
    _engine(scene)
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.55, 0.72, 0.9, 1)
    bg.inputs[1].default_value = 0.9
    scene.world = world
    sun_d = bpy.data.lights.new("sun", "SUN")
    sun_d.energy = 4.0
    sun_d.color = (1.0, 0.93, 0.82)
    sun_d.angle = math.radians(3)
    sun = bpy.data.objects.new("sun", sun_d)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))


def water_plane(scene, size=200):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    p = bpy.context.active_object
    p.name = "preview_water"
    m = bpy.data.materials.new("preview_water")
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.02, 0.22, 0.27, 1)
    b.inputs["Roughness"].default_value = 0.08
    p.data.materials.append(m)
    return p


def render_object(root, path, dist=None, water=True, yaw=-35, pitch=28):
    scene = bpy.context.scene
    setup(scene)
    if water:
        water_plane(scene)
    c, r = bounds(root)
    d = dist or r * 3.3
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 50
    cam = bpy.data.objects.new("cam", cam_d)
    scene.collection.objects.link(cam)
    yaw_r, pitch_r = math.radians(yaw), math.radians(pitch)
    off = Vector((math.sin(yaw_r) * math.cos(pitch_r), -math.cos(yaw_r) * math.cos(pitch_r), math.sin(pitch_r))) * d
    cam.location = c + off
    direction = c - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("render", path)


def render_cam(path, loc, target, lens=35, res=(1280, 720)):
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = res
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = lens
    cam_d.clip_end = 2000
    cam = bpy.data.objects.new("cam", cam_d)
    scene.collection.objects.link(cam)
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("render", path)
