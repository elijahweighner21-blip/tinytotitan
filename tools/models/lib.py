"""
Shared helpers for the model scripts (run with Blender's Python module):

    .tools/blender-venv/bin/python tools/models/build.py [names...]

Conventions, so the game can place every model the same way:
  * units: the model's height is 1 (the game scales it to the creature/prop)
  * Blender +Z is Roblox +Y (up); the model faces Blender -Y, which the FBX
    export turns into Roblox -Z (a Model's LookVector)
  * every object is named after its ROLE ("Body", "Stripe", "Wing"...). One
    mesh per role, coloured in game from the manifest (colour + material), so
    no textures are needed and colours stay tweakable in code
"""

import json
import math
import os

import bpy  # must come first: it provides bmesh/mathutils
import bmesh  # noqa: I001
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "build", "models")
os.makedirs(OUT, exist_ok=True)

# Roblox material names the manifest may use.
MATERIALS = {"SmoothPlastic", "Plastic", "Glass", "Metal", "Fabric", "Neon", "Wood", "Rubber", "Leather", "Foil"}


# A part coloured by the enemy (its config Color) instead of a fixed colour:
# pass one of these as `color`. Previews use PREVIEW_TINT.
TINTS = {"Tint": 0.0, "TintDark": -0.4, "TintLight": 0.35}
PREVIEW_TINT = [(200, 80, 60)]


def tint_rgb(mode):
    base = PREVIEW_TINT[0]
    k = TINTS[mode]
    target = 255 if k > 0 else 0
    return tuple(round(c + (target - c) * abs(k)) for c in base)


def reset(preview_tint=(200, 80, 60)):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PREVIEW_TINT[0] = preview_tint


def _material(color, material):
    key = f"{material}_{color[0]}_{color[1]}_{color[2]}"
    mat = bpy.data.materials.get(key)
    if mat:
        return mat
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgb = [pow(c / 255, 2.2) for c in color]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = {"Metal": 0.3, "Glass": 0.05, "Neon": 0.5, "Foil": 0.2}.get(material, 0.55)
    bsdf.inputs["Metallic"].default_value = 1.0 if material in ("Metal", "Foil") else 0.0
    if material == "Glass":
        bsdf.inputs["Alpha"].default_value = 0.7
    if material == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat


def _finish(obj, role, color, material, smooth=True, subdiv=0):
    assert material in MATERIALS, material
    obj["role"] = role
    if isinstance(color, str):
        obj["tint"] = color
        color = tint_rgb(color)
    obj["color"] = list(color)
    obj["material"] = material
    obj.data.materials.clear()
    obj.data.materials.append(_material(color, material))
    if subdiv:
        mod = obj.modifiers.new("Subdiv", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def _place(obj, location, rotation, scale):
    obj.location = Vector(location)
    obj.rotation_euler = rotation or (0, 0, 0)
    obj.scale = Vector(scale)


def ellipsoid(role, center, radii, color, material="SmoothPlastic", rotation=None, segments=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=max(8, segments // 2), radius=1)
    obj = bpy.context.object
    _place(obj, center, rotation, radii)
    return _finish(obj, role, color, material)


def rounded_box(role, center, size, color, material="SmoothPlastic", bevel=0.15, rotation=None, segments=3):
    """A box with rounded edges; `bevel` is a fraction of the smallest side."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.scale = Vector(size)
    bpy.ops.object.transform_apply(scale=True)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = min(size) * bevel
    mod.segments = segments
    mod.limit_method = "NONE"
    obj.location = Vector(center)
    obj.rotation_euler = rotation or (0, 0, 0)
    _finish(obj, role, color, material)
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.modifiers.new("Normals", "WEIGHTED_NORMAL") if hasattr(bpy.types, "WeightedNormalModifier") else None
    return obj


def tube(role, points, radii, color, material="SmoothPlastic", sides=10):
    """A tapered tube through `points` (list of xyz) with a radius per point:
    legs, antennae, stems, handles."""
    bm = bmesh.new()
    rings = []
    pts = [Vector(p) for p in points]
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
        a = d.cross(up).normalized()
        b = d.cross(a).normalized()
        ring = []
        for s in range(sides):
            t = s / sides * math.tau
            ring.append(bm.verts.new(p + (a * math.cos(t) + b * math.sin(t)) * radii[i]))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for s in range(sides):
            bm.faces.new((r0[s], r0[(s + 1) % sides], r1[(s + 1) % sides], r1[s]))
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        bm.faces.new(list(reversed(ring)) if flip else ring)
    bm.normal_update()
    mesh = bpy.data.meshes.new(role)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(role, mesh)
    bpy.context.collection.objects.link(obj)
    _finish(obj, role, color, material)
    return obj


def cylinder(role, center, radius, depth, color, material="SmoothPlastic", rotation=None, sides=24, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth)
    obj = bpy.context.object
    obj.location = Vector(center)
    obj.rotation_euler = rotation or (0, 0, 0)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    _finish(obj, role, color, material)
    mod = obj.modifiers.new("Auto", "EDGE_SPLIT") if not bevel else None
    if mod:
        mod.split_angle = math.radians(40)
    return obj


def loft(role, sections, color, material="SmoothPlastic", sides=24, power=2.6):
    """A smooth body through cross-sections along Blender X. Each section is
    (x, y_centre, z_bottom, half_width, height): a rounded-rectangle-ish
    (superellipse) ring whose bottom sits at z_bottom. Ends are capped."""
    bm = bmesh.new()
    rings = []
    for x, yc, zb, hw, h in sections:
        ring = []
        for k in range(sides):
            t = k / sides * math.tau
            c, sn = math.cos(t), math.sin(t)
            # Superellipse: flatter sides, rounded corners.
            ex = math.copysign(abs(c) ** (2 / power), c)
            ez = math.copysign(abs(sn) ** (2 / power), sn)
            ring.append(bm.verts.new((x, yc + ex * hw, zb + h / 2 + ez * h / 2)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((r0[k], r1[k], r1[(k + 1) % sides], r0[(k + 1) % sides]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(role)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(role, mesh)
    bpy.context.collection.objects.link(obj)
    return _finish(obj, role, color, material, subdiv=1)


def cone(role, base, tip, radius, color, material="SmoothPlastic", sides=12):
    """A pointed cone from `base` to `tip` (horns, crystals, spikes)."""
    return tube(role, [base, tip], [radius, radius * 0.02], color, material, sides=sides)


def wing(role, root, tip_dir, length, width, color, material="Glass"):
    """A thin leaf-shaped wing membrane starting at `root`."""
    bm = bmesh.new()
    n = 12
    top, bottom = [], []
    d = Vector(tip_dir).normalized()
    side = d.cross(Vector((0, 0, 1))).normalized()
    for i in range(n + 1):
        t = i / n
        w = math.sin(math.pi * min(1, t * 1.15)) * width * (1 - 0.25 * t)
        p = Vector(root) + d * (t * length)
        top.append(bm.verts.new(p + side * w * 0.6 + Vector((0, 0, 0.004))))
        bottom.append(bm.verts.new(p - side * w * 0.4 + Vector((0, 0, 0.004))))
    for i in range(n):
        bm.faces.new((top[i], top[i + 1], bottom[i + 1], bottom[i]))
    mesh = bpy.data.meshes.new(role)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(role, mesh)
    bpy.context.collection.objects.link(obj)
    sol = obj.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.008
    return _finish(obj, role, color, material)


def mirror_x(obj):
    """Duplicate an object mirrored across X (left/right pairs)."""
    dup = obj.copy()
    dup.data = obj.data.copy()
    bpy.context.collection.objects.link(dup)
    dup.location.x = -obj.location.x
    dup.rotation_euler = (obj.rotation_euler.x, -obj.rotation_euler.y, -obj.rotation_euler.z)
    dup.scale = obj.scale.copy()
    if obj.type == "MESH" and obj.location.x == 0:
        dup.scale.x = -dup.scale.x
    for k in ("role", "color", "material", "tint"):
        if k in obj:
            dup[k] = obj[k]
    return dup


def mirror_mesh_x(obj):
    """Mirror geometry built in world space (tubes, wings) across X."""
    mod = obj.modifiers.new("MirrorX", "MIRROR")
    mod.use_axis[0] = True
    return obj


def _apply_and_join():
    """Apply modifiers, then join objects into one mesh per role."""
    by_role = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        if obj.scale.x * obj.scale.y * obj.scale.z < 0:
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.flip_normals()
            bpy.ops.object.mode_set(mode="OBJECT")
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        by_role.setdefault(obj["role"], []).append(obj)
    joined = {}
    for role, objs in by_role.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = role
        obj.data.name = role
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        joined[role] = obj
    return joined


def _triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _normalize(objs):
    """Scale so the whole model is 1 tall with its base at Z=0 and centred."""
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    size = hi - lo
    s = 1 / size.z
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for o in objs:
        o.data.transform(Matrix.Translation(-centre))
        o.data.transform(Matrix.Scale(s, 4))
    return size * s


def _preview(path, size):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.62, 0.68, 0.78, 1)
    bg.inputs["Strength"].default_value = 0.9
    # Floor to catch the shadow.
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.object
    floor.data.materials.append(_material((215, 212, 205), "SmoothPlastic"))
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.context.collection.objects.link(sun)
    reach = max(size.x, size.y, size.z)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    bpy.context.collection.objects.link(cam)
    target = Vector((0, 0, size.z * 0.45))
    cam.location = target + Vector((1.35, -2.0, 0.95)).normalized() * reach * 1.55
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export(name, preview=True, collision=None):
    """Join per role, normalise, export FBX + manifest (+ preview PNG)."""
    joined = _apply_and_join()
    size = _normalize(list(joined.values()))
    parts = {}
    total = 0
    for role, obj in joined.items():
        tris = _triangles(obj)
        total += tris
        # Bounding-box centre/extent of the role in Roblox axes (x right, y up, z back), used in
        # game to orient the imported model whatever axes the importer chose.
        xs = [v.co.x for v in obj.data.vertices]
        ys = [v.co.y for v in obj.data.vertices]
        zs = [v.co.z for v in obj.data.vertices]
        centre = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2))
        extent = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
        parts[role] = {
            "Color": [int(c) for c in obj["color"]],
            "Material": obj["material"],
            "Triangles": tris,
            "Center": [round(centre.x, 4), round(centre.z, 4), round(centre.y, 4)],
            "Extent": [round(extent.x, 4), round(extent.z, 4), round(extent.y, 4)],
        }
        if "tint" in obj:
            parts[role]["Tint"] = obj["tint"]
        assert tris <= 20000, f"{name}.{role}: {tris} triangles (Roblox limit 20000)"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in joined.values():
        obj.select_set(True)
    fbx = os.path.join(OUT, f"{name}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        apply_unit_scale=True,
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
    )
    manifest = {
        "Name": name,
        "Size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)],
        "Triangles": total,
        "Parts": parts,
    }
    if collision:
        manifest["Collision"] = collision
    with open(os.path.join(OUT, f"{name}.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    if preview:
        _preview(os.path.join(OUT, f"{name}.png"), size)
    print(f"{name}: {total} triangles, {len(parts)} parts")
    return manifest
