"""Renders the 3D store art (transparent PNGs) into assets/store/.

Run (≈2 minutes on Apple Silicon):
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tool/store_art/render_store_art.py

Every object is built from primitives here, so tweak shapes/colours below and
re-run. Style: glossy "toy" materials, warm key light + cool rim, soft shadow
catcher, slightly high camera - matches the candy UI of the game.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

OUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "assets", "store"))
SIZE = 512
SAMPLES = 96

# Optional: render only some items, e.g. `-- coins_small gift`.
ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


# ---------------------------------------------------------------- scene setup

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception:
        pass
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"

    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.62, 0.66, 0.78, 1)
    bg.inputs["Strength"].default_value = 0.35
    return scene


def light(name, kind, loc, energy, color=(1, 1, 1), size=3.0, shadow=True):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.use_shadow = shadow
    data.color = color
    if kind == "AREA":
        data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    direction = Vector((0, 0, 0.6)) - Vector(loc)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return obj


def camera(distance=7.0, height=3.4, lens=50, target=(0, 0, 0.75)):
    data = bpy.data.cameras.new("Cam")
    data.lens = lens
    cam = bpy.data.objects.new("Cam", data)
    bpy.context.collection.objects.link(cam)
    cam.location = (distance * 0.42, -distance, height)
    direction = Vector(target) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def studio():
    light("Key", "AREA", (4, -4, 6), 800, (1.0, 0.93, 0.82), 2.5)
    light("Fill", "AREA", (-5, -2, 3), 220, (0.82, 0.88, 1.0), 5, shadow=False)
    light("Rim", "AREA", (-1.5, 5, 4), 650, (0.85, 0.9, 1.0), 3, shadow=False)
    # Shadow catcher: only the contact shadow survives the transparent film.
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.is_shadow_catcher = True


# ---------------------------------------------------------------- materials

def mat(name, color, metallic=0.0, rough=0.35, coat=0.0, emission=None,
        strength=0.0, transmission=0.0, ior=1.45, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    p.inputs["Coat Weight"].default_value = coat
    p.inputs["Transmission Weight"].default_value = transmission
    p.inputs["IOR"].default_value = ior
    p.inputs["Alpha"].default_value = alpha
    if emission:
        p.inputs["Emission Color"].default_value = (*emission, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


GOLD = lambda: mat("Gold", (1.0, 0.62, 0.08), metallic=1.0, rough=0.2)
GOLD_DARK = lambda: mat("GoldDark", (0.8, 0.38, 0.03), metallic=1.0, rough=0.28)
WOOD = lambda: mat("Wood", (0.2, 0.045, 0.015), rough=0.5, coat=0.25)
GLASS = lambda: mat("Glass", (1.0, 0.86, 0.45), rough=0.06, transmission=1.0,
                    ior=1.25)
GLOW = lambda s=18: mat("Glow", (1.0, 0.62, 0.05), emission=(1.0, 0.55, 0.04),
                        strength=s)
METAL = lambda: mat("Metal", (0.78, 0.8, 0.86), metallic=1.0, rough=0.28)


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def smooth(obj, bevel=0.0, segments=4, subsurf=0):
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    if subsurf:
        mod = obj.modifiers.new("Sub", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


# ---------------------------------------------------------------- props

def coin(loc, rot=(0, 0, 0), radius=0.62, depth=0.16, material=None):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=64, radius=radius, depth=depth, location=loc, rotation=rot)
    body = smooth(bpy.context.active_object, bevel=0.035, segments=3)
    assign(body, material or GOLD())
    # Raised star on the face.
    verts, faces = [], []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = radius * (0.52 if i % 2 == 0 else 0.22)
        verts.append((r * math.cos(a), r * math.sin(a), 0))
    faces.append(list(range(10)))
    mesh = bpy.data.meshes.new("Star")
    mesh.from_pydata(verts, [], faces)
    star = bpy.data.objects.new("Star", mesh)
    bpy.context.collection.objects.link(star)
    sol = star.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = 0.05
    star.modifiers.new("Bevel", "BEVEL").width = 0.012
    star.parent = body
    star.location = (0, 0, depth / 2 + 0.005)
    assign(star, GOLD_DARK())
    # Rim ring.
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radius * 0.86, minor_radius=0.025,
        location=(0, 0, depth / 2))
    ring = bpy.context.active_object
    ring.parent = body
    ring.location = (0, 0, depth / 2)
    assign(smooth(ring), GOLD_DARK())
    return body


def coin_stack(base, count, jitter=0.04, seed=1):
    rnd = random.Random(seed)
    for i in range(count):
        coin((base[0] + rnd.uniform(-jitter, jitter),
              base[1] + rnd.uniform(-jitter, jitter),
              base[2] + 0.08 + i * 0.165),
             rot=(0, 0, rnd.uniform(0, math.pi)))


def bulb(loc, scale=1.0, tilt=0.0, glow=7):
    x, y, z = loc
    group = bpy.data.objects.new("Bulb", None)
    bpy.context.collection.objects.link(group)
    group.location = loc
    group.rotation_euler = (0, tilt, 0)
    group.scale = (scale, scale, scale)

    def child(obj):
        obj.parent = group
        return obj

    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=64, ring_count=32, radius=0.7, location=(0, 0, 1.25))
    glass = child(smooth(bpy.context.active_object))
    glass.scale = (1, 1, 1.08)
    assign(glass, GLASS())
    # Neck of the glass.
    bpy.ops.mesh.primitive_cone_add(
        vertices=64, radius1=0.36, radius2=0.5, depth=0.45,
        location=(0, 0, 0.62))
    assign(child(smooth(bpy.context.active_object)), GLASS())
    # Glowing core (reads as a lit filament through the glass).
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.3, location=(0, 0, 1.2))
    assign(child(smooth(bpy.context.active_object)), GLOW(glow))
    # Screw base: stacked rings.
    for i in range(4):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.3, minor_radius=0.075, location=(0, 0, 0.36 - i * 0.1))
        assign(child(smooth(bpy.context.active_object)), METAL())
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.3, depth=0.38, location=(0, 0, 0.22))
    assign(child(smooth(bpy.context.active_object)), METAL())
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(0, 0, 0.02))
    assign(child(smooth(bpy.context.active_object)),
           mat("Tip", (0.15, 0.15, 0.18), metallic=1, rough=0.3))
    # Point light so the glow actually lights the scene around it.
    data = bpy.data.lights.new("BulbLight", "POINT")
    data.energy = 45 * glow / 7
    data.color = (1.0, 0.7, 0.3)
    # Light from inside props must not darken the transparent shadow catcher.
    data.use_shadow = False
    lamp = bpy.data.objects.new("BulbLight", data)
    bpy.context.collection.objects.link(lamp)
    lamp.parent = group
    lamp.location = (0, 0, 1.25)
    return group


def chest(loc=(0, 0, 0), open_angle=-1.05, inner_glow=True, gold_pile=False):
    x, y, z = loc
    w, d, h = 2.2, 1.45, 1.05
    bpy.ops.mesh.primitive_cube_add(location=(x, y, z + h / 2))
    box = bpy.context.active_object
    box.scale = (w / 2, d / 2, h / 2)
    bpy.ops.object.transform_apply(scale=True)
    assign(smooth(box, bevel=0.08, segments=4), WOOD())
    # Gold bands + corners.
    for bx in (-w * 0.32, w * 0.32):
        bpy.ops.mesh.primitive_cube_add(location=(x + bx, y, z + h / 2))
        band = bpy.context.active_object
        band.scale = (0.09, d / 2 + 0.03, h / 2 + 0.02)
        bpy.ops.object.transform_apply(scale=True)
        assign(smooth(band, bevel=0.03), GOLD())
    # Lock plate.
    bpy.ops.mesh.primitive_cube_add(location=(x, y - d / 2 - 0.04, z + h - 0.18))
    lock = bpy.context.active_object
    lock.scale = (0.2, 0.05, 0.24)
    bpy.ops.object.transform_apply(scale=True)
    assign(smooth(lock, bevel=0.04), GOLD())
    # Lid: half cylinder hinged at the back edge.
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=48, radius=d / 2, depth=w, location=(0, 0, 0),
        rotation=(0, math.pi / 2, 0))
    lid = bpy.context.active_object
    # The cylinder is rotated 90° about Y, so world-down is local +X:
    # flatten that half to get a dome-shaped lid.
    for v in lid.data.vertices:
        if v.co.x > 0:
            v.co.x = 0
    hinge = bpy.data.objects.new("Hinge", None)
    bpy.context.collection.objects.link(hinge)
    hinge.location = (x, y + d / 2, z + h)
    lid.parent = hinge
    lid.location = (0, -d / 2, 0)
    hinge.rotation_euler = (open_angle, 0, 0)
    assign(smooth(lid, bevel=0.06), WOOD())
    for bx in (-w * 0.32, w * 0.32):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=48, radius=d / 2 + 0.03, depth=0.18,
            rotation=(0, math.pi / 2, 0))
        band = bpy.context.active_object
        for v in band.data.vertices:
            if v.co.x > 0:
                v.co.x = 0
        band.parent = hinge
        band.location = (bx, -d / 2, 0)
        assign(smooth(band, bevel=0.02), GOLD())
    if inner_glow:
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, z + h - 0.02))
        glow = bpy.context.active_object
        glow.scale = (w / 2 - 0.12, d / 2 - 0.12, 1)
        assign(glow, GLOW(6))
        data = bpy.data.lights.new("ChestGlow", "POINT")
        data.energy = 120
        data.color = (1.0, 0.72, 0.3)
        data.use_shadow = False
        lamp = bpy.data.objects.new("ChestGlow", data)
        bpy.context.collection.objects.link(lamp)
        lamp.location = (x, y, z + h + 0.5)
    if gold_pile:
        rnd = random.Random(7)
        for i in range(16):
            a = rnd.uniform(0, math.tau)
            r = rnd.uniform(0, 0.75)
            coin((x + math.cos(a) * r * 1.2, y + math.sin(a) * r * 0.6,
                  z + h + 0.05 + rnd.uniform(0, 0.25)),
                 rot=(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), 0),
                 radius=0.34, depth=0.09)
    return box


def gift(loc=(0, 0, 0)):
    x, y, z = loc
    s = 1.5
    bpy.ops.mesh.primitive_cube_add(location=(x, y, z + s / 2))
    box = bpy.context.active_object
    box.scale = (s / 2, s / 2, s / 2)
    bpy.ops.object.transform_apply(scale=True)
    assign(smooth(box, bevel=0.07), mat("Box", (0.3, 0.06, 0.85), rough=0.3,
                                         coat=0.8))
    bpy.ops.mesh.primitive_cube_add(location=(x, y, z + s + 0.08))
    lid = bpy.context.active_object
    lid.scale = (s / 2 + 0.07, s / 2 + 0.07, 0.15)
    bpy.ops.object.transform_apply(scale=True)
    assign(smooth(lid, bevel=0.06), mat("Lid", (0.4, 0.1, 0.95), rough=0.3,
                                         coat=0.8))
    ribbon = mat("Ribbon", (1.0, 0.78, 0.2), metallic=0.6, rough=0.25)
    for sx, sy in ((0.13, s / 2 + 0.09), (s / 2 + 0.09, 0.13)):
        bpy.ops.mesh.primitive_cube_add(location=(x, y, z + (s + 0.25) / 2))
        band = bpy.context.active_object
        band.scale = (sx, sy, (s + 0.27) / 2)
        bpy.ops.object.transform_apply(scale=True)
        assign(smooth(band, bevel=0.02), ribbon)
    for side in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.32, minor_radius=0.1,
            location=(x + side * 0.3, y, z + s + 0.42),
            rotation=(math.pi / 2, side * 0.6, 0))
        loop = bpy.context.active_object
        loop.scale = (1, 1.4, 1)
        assign(smooth(loop), ribbon)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16,
                                         location=(x, y, z + s + 0.28))
    assign(smooth(bpy.context.active_object), ribbon)
    return box


def sparkle(loc, size=0.18):
    verts = []
    for i in range(8):
        a = i * math.pi / 4
        r = size if i % 2 == 0 else size * 0.22
        verts.append((r * math.cos(a), 0, r * math.sin(a)))
    mesh = bpy.data.meshes.new("Sparkle")
    mesh.from_pydata(verts, [], [list(range(8))])
    obj = bpy.data.objects.new("Sparkle", mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.visible_shadow = False
    assign(obj, mat("Spark", (1, 1, 1), emission=(1.0, 0.95, 0.7), strength=12))
    return obj


# ---------------------------------------------------------------- items

def item_bulb_single():
    bulb((0, 0, 0), scale=1.15, tilt=0.18)
    sparkle((1.1, -0.4, 2.3), 0.22)
    sparkle((-1.0, 0.2, 1.7), 0.14)
    camera(distance=6.6, height=3.0, target=(0, 0, 1.25))


def item_bulb_trio():
    bulb((-0.95, 0.35, 0), scale=0.9, tilt=-0.3)
    bulb((0.95, 0.35, 0), scale=0.9, tilt=0.3)
    bulb((0, -0.35, 0), scale=1.08, tilt=0.05)
    sparkle((1.6, -0.6, 2.4), 0.22)
    sparkle((-1.6, -0.2, 2.0), 0.16)
    camera(distance=8.2, height=3.4, target=(0, 0, 1.1))


def item_bulb_chest():
    chest(open_angle=-1.25, inner_glow=True)
    bulb((-0.45, 0.05, 0.75), scale=0.62, tilt=-0.35)
    bulb((0.5, 0.0, 0.8), scale=0.66, tilt=0.3)
    bulb((0.0, 0.15, 0.9), scale=0.72, tilt=0.0)
    sparkle((1.5, -0.5, 2.6), 0.24)
    sparkle((-1.5, -0.3, 2.2), 0.16)
    camera(distance=8.6, height=4.2, target=(0, 0, 1.15))


def item_coins_small():
    coin_stack((0, 0, 0), 4, seed=2)
    coin((0.95, -0.35, 0.62), rot=(1.1, 0.0, 0.5))
    sparkle((0.9, -0.5, 1.7), 0.2)
    camera(distance=5.4, height=3.0, target=(0.2, 0, 0.55))


def item_coins_medium():
    coin_stack((-0.55, 0.2, 0), 6, seed=3)
    coin_stack((0.6, 0.1, 0), 4, seed=4)
    coin_stack((0.05, -0.6, 0), 2, seed=5)
    coin((1.25, -0.6, 0.62), rot=(1.15, 0.0, 0.7))
    sparkle((1.2, -0.7, 1.9), 0.22)
    sparkle((-1.3, 0.0, 1.5), 0.14)
    camera(distance=6.8, height=3.4, target=(0.1, 0, 0.6))


def item_coins_large():
    chest(open_angle=-1.2, inner_glow=True, gold_pile=True)
    coin_stack((1.65, -0.8, 0), 3, seed=6)
    coin((-1.6, -0.9, 0.62), rot=(1.2, 0, -0.6))
    sparkle((1.4, -0.5, 2.6), 0.24)
    sparkle((-1.5, -0.4, 2.2), 0.17)
    camera(distance=8.8, height=4.4, target=(0, 0, 1.0))


def item_gift():
    gift()
    sparkle((1.2, -0.5, 2.2), 0.22)
    sparkle((-1.1, -0.2, 1.8), 0.15)
    camera(distance=6.6, height=3.6, target=(0, 0, 0.95))


ITEMS = {
    "hint_1": item_bulb_single,
    "hint_5": item_bulb_trio,
    "hint_12": item_bulb_chest,
    "coins_small": item_coins_small,
    "coins_medium": item_coins_medium,
    "coins_large": item_coins_large,
    "gift": item_gift,
}


def autocrop(path, pad=0.06):
    """Crops the render to the object (ignoring the faint shadow), squares it
    and scales back to SIZE, so every item fills its card the same way."""
    import numpy as np
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    mask = px[:, :, 3] > 0.35
    rows = np.where(mask.any(axis=1))[0]
    cols = np.where(mask.any(axis=0))[0]
    if len(rows) == 0:
        return
    y0, y1, x0, x1 = rows[0], rows[-1], cols[0], cols[-1]
    side = int(max(y1 - y0, x1 - x0) * (1 + pad * 2))
    cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
    out = np.zeros((side, side, 4), dtype=np.float32)
    sy0, sx0 = cy - side // 2, cx - side // 2
    for yy in range(side):
        src_y = sy0 + yy
        if 0 <= src_y < h:
            xs0, xs1 = max(sx0, 0), min(sx0 + side, w)
            out[yy, xs0 - sx0:xs1 - sx0] = px[src_y, xs0:xs1]
    cropped = bpy.data.images.new("crop", side, side, alpha=True)
    cropped.pixels = out.ravel()
    cropped.scale(SIZE, SIZE)
    cropped.filepath_raw = path
    cropped.file_format = "PNG"
    cropped.save()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in ITEMS.items():
        if ONLY and name not in ONLY:
            continue
        scene = reset()
        studio()
        build()
        scene.render.filepath = os.path.join(OUT_DIR, f"{name}.png")
        scene.render.resolution_x = SIZE * 2
        scene.render.resolution_y = SIZE * 2
        bpy.ops.render.render(write_still=True)
        autocrop(scene.render.filepath)
        print(f"rendered {name}")


main()
