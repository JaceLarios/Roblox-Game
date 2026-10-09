"""Badge scenes: each Roblox badge shows what you do to earn it, built from
the game's own models (the JSON exports in assets/) and props made here.

Run in the background (never touches an open Blender window):
  E:/blender.exe --background --factory-startup --python build_badges.py [-- name name]
Renders scenes/<badge>.png (512 x 512); make_badges.py frames them.
Roblox crops badges to a circle and make_badges.py puts a label over the
bottom quarter, so each scene keeps its subject in the upper middle.
"""
import bpy, bmesh, json, math, random, sys
from pathlib import Path
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parent
OUT = HERE / 'scenes'
OUT.mkdir(exist_ok=True)
ONLY = set(sys.argv[sys.argv.index('--') + 1:]) if '--' in sys.argv else None
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
TAU = math.tau


# ------------------------------------------------------------------ materials
# Colours are linear. The 'Standard' view clips anything over 1, so glows use
# strengths near 1-2 to keep their colour instead of burning to white.
_mats = {}
def mat(key, color, metal=0.0, rough=0.4, emit=0.0, alpha=1.0, emit_color=None):
    if key in _mats: return _mats[key]
    m = bpy.data.materials.new(key); m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if emit:
        p.inputs['Emission Color'].default_value = (*(emit_color or color), 1)
        p.inputs['Emission Strength'].default_value = emit
    if alpha < 1: p.inputs['Alpha'].default_value = alpha
    _mats[key] = m
    return m


def glow(key, color, strength=1.4, alpha=1.0):
    return mat(key, color, 0, .4, emit=strength, alpha=alpha)


def ghost_shader(nt, color=(.4, 1, .72), strength=1.5, base=.12):
    """See-through in the middle, glowing at the edges, the way a Phantom
    car reads in game."""
    lw = nt.nodes.new('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = .45
    mr = nt.nodes.new('ShaderNodeMapRange'); mr.inputs['To Min'].default_value = base
    nt.links.new(lw.outputs['Facing'], mr.inputs['Value'])
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (*color, 1); em.inputs['Strength'].default_value = strength
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(mr.outputs['Result'], mix.inputs['Fac'])
    nt.links.new(tr.outputs[0], mix.inputs[1]); nt.links.new(em.outputs[0], mix.inputs[2])
    return mix.outputs[0]


def ghost_mat(key='ghost', **kw):
    if key in _mats: return _mats[key]
    m = bpy.data.materials.new(key); m.use_nodes = True
    nt = m.node_tree
    nt.links.new(ghost_shader(nt, **kw), nt.nodes['Material Output'].inputs['Surface'])
    _mats[key] = m
    return m


def split_mat(src, direction, cut):
    """`src` on one side of a plane, ghost on the other: a car mid-change."""
    key = f'{src.name} split'
    if key in _mats: return _mats[key]
    m = src.copy(); m.name = key
    nt = m.node_tree
    out = nt.nodes['Material Output']; p = nt.nodes['Principled BSDF']
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    dot = nt.nodes.new('ShaderNodeVectorMath'); dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = direction
    gt = nt.nodes.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = cut
    nt.links.new(geo.outputs['Position'], dot.inputs[0]); nt.links.new(dot.outputs['Value'], gt.inputs[0])
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(gt.outputs[0], mix.inputs['Fac'])
    nt.links.new(p.outputs[0], mix.inputs[1]); nt.links.new(ghost_shader(nt), mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs['Surface'])
    _mats[key] = m
    return m


def image_mat(key, path, emit=.35):
    if key in _mats: return _mats[key]
    m = bpy.data.materials.new(key); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes['Principled BSDF']; p.inputs['Roughness'].default_value = .5
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(str(ASSETS / path))
    nt.links.new(tex.outputs['Color'], p.inputs['Base Color'])
    nt.links.new(tex.outputs['Color'], p.inputs['Emission Color'])
    p.inputs['Emission Strength'].default_value = emit
    _mats[key] = (m, tuple(tex.image.size))
    return _mats[key]


# ------------------------------------------------------------------ geometry
def mesh_obj(name, verts, faces, material, smooth=False):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o)
    me.materials.append(material)
    if smooth:
        for f in me.polygons: f.use_smooth = True
    return o


def box(name, loc, size, material, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel:
        b = o.modifiers.new('bevel', 'BEVEL'); b.width = bevel; b.segments = 3
    return o


def cyl(name, loc, r, depth, material, rot=(0, 0, 0), verts=32, r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.data.materials.append(material)
    for f in o.data.polygons: f.use_smooth = len(f.vertices) == 4
    return o


def sphere(name, loc, r, material, seg=24, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc, scale=scale)
    o = bpy.context.object; o.name = name; o.data.materials.append(material)
    for f in o.data.polygons: f.use_smooth = True
    return o


def torus(name, loc, major, minor, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=loc, rotation=rot, major_radius=major, minor_radius=minor, major_segments=64, minor_segments=12)
    o = bpy.context.object; o.name = name; o.data.materials.append(material)
    for f in o.data.polygons: f.use_smooth = True
    return o


def tube(name, points, r, material):
    c = bpy.data.curves.new(name, 'CURVE'); c.dimensions = '3D'; c.bevel_depth = r; c.bevel_resolution = 4
    sp = c.splines.new('POLY'); sp.points.add(len(points) - 1)
    for p, co in zip(sp.points, points): p.co = (*co, 1)
    o = bpy.data.objects.new(name, c); scene.collection.objects.link(o)
    c.materials.append(material)
    return o


def flat(name, outline, material, depth=.2, loc=(0, 0, 0), rot=(math.pi / 2, 0, 0)):
    """A 2D outline (x, y) extruded `depth`; by default standing up, facing -Y."""
    c = bpy.data.curves.new(name, 'CURVE'); c.dimensions = '2D'; c.fill_mode = 'BOTH'
    c.extrude = depth / 2; c.bevel_depth = min(.04, depth / 4)
    sp = c.splines.new('POLY'); sp.points.add(len(outline) - 1); sp.use_cyclic_u = True
    for p, (x, y) in zip(sp.points, outline): p.co = (x, y, 0, 1)
    o = bpy.data.objects.new(name, c); o.location = loc; o.rotation_euler = rot
    scene.collection.objects.link(o); c.materials.append(material)
    return o


def lathe(name, profile, material, at=(0, 0, 0), seg=64):
    """Spins a (radius, height) profile round Z: cups, podiums."""
    n = len(profile); verts = []; faces = []
    for s in range(seg):
        a = s * TAU / seg
        verts += [(at[0] + math.cos(a) * r, at[1] + math.sin(a) * r, at[2] + z) for r, z in profile]
    for s in range(seg):
        t = (s + 1) % seg
        faces += [(s * n + i, t * n + i, t * n + i + 1, s * n + i + 1) for i in range(n - 1)]
    o = mesh_obj(name, verts, faces, material, smooth=True)
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data); bm.free()
    return o


def star_outline(r, points=5, inner=.45):
    return [(math.cos(math.pi / 2 + i * math.pi / points) * (r if i % 2 == 0 else r * inner),
             math.sin(math.pi / 2 + i * math.pi / points) * (r if i % 2 == 0 else r * inner)) for i in range(points * 2)]


def sparkle(loc, r, material):
    """A four-pointed twinkle; render() turns every one to face the camera."""
    pts = [(math.cos(i * TAU / 8) * (r if i % 2 == 0 else r * .2), 0, math.sin(i * TAU / 8) * (r if i % 2 == 0 else r * .2)) for i in range(8)]
    o = mesh_obj('sparkle', [(0, 0, 0)] + pts, [(0, 1 + i, 1 + (i + 1) % 8) for i in range(8)], material)
    o.location = loc
    return o


def sparkles(n, lo, hi, rmin, rmax, material, seed):
    rnd = random.Random(seed)
    for _ in range(n):
        sparkle(tuple(rnd.uniform(lo[i], hi[i]) for i in range(3)), rnd.uniform(rmin, rmax), material)


FONTS = {}
def font(name):
    if name not in FONTS:
        found = sorted((Path.home() / 'AppData/Local/Roblox/Versions').glob(f'*/content/fonts/{name}'))
        FONTS[name] = bpy.data.fonts.load(str(found[-1])) if found else None
    return FONTS[name]


def text3d(name, body, loc, size, material, extrude=.12, rot=(math.pi / 2, 0, 0), face='LuckiestGuy-Regular.ttf'):
    c = bpy.data.curves.new(name, 'FONT'); c.body = body; c.size = size; c.extrude = extrude
    c.bevel_depth = extrude * .3; c.align_x = 'CENTER'; c.align_y = 'CENTER'
    if font(face): c.font = font(face)
    o = bpy.data.objects.new(name, c); o.location = loc; o.rotation_euler = rot
    scene.collection.objects.link(o); c.materials.append(material)
    return o


# ------------------------------------------------------------------ game models
# Per-material JSON parts in Roblox space (Y up, front +Z). Blender here is
# Z up with the front on -Y, as in the other builders: (x, y, z) -> (x, -z, y).
def model_material(m):
    col = tuple(m['color']); kind = m.get('kind'); finish = m.get('finish')
    lit = m.get('glow', 0) or 0
    if kind == 'neon' or finish == 'Light':
        return glow(f'm{col}neon', col, max(lit, 1.2))
    if kind == 'mist':
        return glow(f'm{col}mist', col, 1.4, alpha=.45)
    if kind == 'ghost':
        return mat(f'm{col}ghost', col, 0, .3, emit=.7, alpha=m.get('alpha', .6))
    if kind == 'glass' or finish == 'Glass':
        return mat(f'm{col}glass', col, .2, .05, alpha=.55 if kind == 'glass' else 1)
    metal = m.get('metal', .3)
    rough = .25 if finish == 'Brushed' else .35 if finish in ('Enamel', None) else .6
    return mat(f'm{col}{metal}{rough}', col, metal, rough, emit=lit * .5)


def load_model(path, paint=None):
    """`paint(material_json, default_material)` may swap a part's material."""
    d = json.loads((ASSETS / path).read_text())
    objs = []
    for g in d['parts']:
        if 'vertices' not in g: continue
        base = model_material(g['material'])
        m = paint(g['material'], base) if paint else base
        o = mesh_obj(g['name'], [(x, -z, y) for x, y, z in g['vertices']], [tuple(t) for t in g['triangles']], m, smooth=True)
        o.data.normals_split_custom_set_from_vertices([(x, -z, y) for x, y, z in g['normals']])
        objs.append(o)
    return objs


def bounds(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return (Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)]))


def place(objs, at=(0, 0, 0), scale=1.0, turn=0.0, length=None):
    """Scale (or fit its longest ground side to `length`), spin round Z, and
    sit its bottom centre on `at`."""
    lo, hi = bounds(objs)
    if length: scale = length / max(hi.x - lo.x, hi.y - lo.y)
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(turn, 4, 'Z') @ Matrix.Scale(scale, 4) @ Matrix.Translation(-centre)
    for o in objs: o.matrix_world = m @ o.matrix_world
    bpy.context.view_layer.update()
    return objs


def rig(car_path, addon_path=None, length=4.5, paint=None, width=.6, along=.15, at=(0, 0, 0), turn=0.0):
    """A car (facing -Y) with an addon resting on it, then moved into place."""
    car = place(load_model(car_path, paint), length=length)
    parts = list(car)
    if addon_path:
        # find the roof before the addon exists, or the ray lands on the addon
        lo, hi = bounds(car)
        y = (lo.y + hi.y) / 2 + (hi.y - lo.y) * along
        deps = bpy.context.evaluated_depsgraph_get()
        hit, loc, *_ = scene.ray_cast(deps, Vector(((lo.x + hi.x) / 2, y, hi.z + 5)), Vector((0, 0, -1)))
        addon = load_model(addon_path)
        alo, ahi = bounds(addon)
        place(addon, ((lo.x + hi.x) / 2, y, (loc.z if hit else hi.z) - .05), scale=(hi.x - lo.x) * width / (ahi.x - alo.x))
        parts += addon
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(turn, 4, 'Z')
    for o in parts: o.matrix_world = m @ o.matrix_world
    bpy.context.view_layer.update()
    return parts


def as_ghost(m, base):
    return ghost_mat()


# ------------------------------------------------------------------ stage
def camera(loc, target, lens=50):
    d = bpy.data.cameras.new('cam'); d.lens = lens
    cam = bpy.data.objects.new('cam', d); scene.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    return cam


def light(loc, target, power, size=4, color=(1, 1, 1)):
    d = bpy.data.lights.new('l', 'AREA'); d.energy = power; d.size = size; d.color = color
    o = bpy.data.objects.new('l', d); scene.collection.objects.link(o)
    o.location = loc; o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return o


def point(loc, power, color=(1, 1, 1), r=.3):
    d = bpy.data.lights.new('p', 'POINT'); d.energy = power; d.color = color; d.shadow_soft_size = r
    o = bpy.data.objects.new('p', d); scene.collection.objects.link(o); o.location = loc
    return o


def sky(top, bottom, strength=1.0, lo=.35, hi=.8):
    w = bpy.data.worlds.new('sky'); scene.world = w; w.use_nodes = True
    nt = w.node_tree; bg = nt.nodes['Background']
    tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = lo; ramp.color_ramp.elements[0].color = (*bottom, 1)
    ramp.color_ramp.elements[1].position = hi; ramp.color_ramp.elements[1].color = (*top, 1)
    nt.links.new(tc.outputs['Window'], sep.inputs[0])
    nt.links.new(sep.outputs['Y'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = strength


def floor(material, z=0, size=200):
    return box('floor', (0, 0, z - .05), (size, size, .1), material)


def rays(at, n, length, material, spread=.09, y=0.0):
    """A sunburst behind something: flat wedges in the XZ plane."""
    verts, faces = [], []
    for i in range(n):
        a = i * TAU / n
        k = len(verts)
        verts += [(at[0], y, at[2]),
                  (at[0] + math.cos(a - spread) * length, y, at[2] + math.sin(a - spread) * length),
                  (at[0] + math.cos(a + spread) * length, y, at[2] + math.sin(a + spread) * length)]
        faces.append((k, k + 1, k + 2))
    return mesh_obj('rays', verts, faces, material)


def reset():
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.curves): bpy.data.curves.remove(c)
    for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)
    for l in list(bpy.data.lights): bpy.data.lights.remove(l)
    for c in list(bpy.data.cameras): bpy.data.cameras.remove(c)


def render(name, samples=128):
    cam = scene.camera
    for o in scene.objects:
        if o.name.startswith('sparkle'):
            o.rotation_euler = (cam.location - o.location).to_track_quat('-Y', 'Z').to_euler()
    scene.render.engine = 'CYCLES'; scene.cycles.samples = samples; scene.cycles.use_denoising = True
    scene.cycles.transparent_max_bounces = 32
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        for kind in ['OPTIX', 'CUDA']:
            try:
                prefs.compute_device_type = kind; prefs.get_devices()
                if any(dv.type == kind for dv in prefs.devices): break
            except TypeError:
                pass
        for dv in prefs.devices: dv.use = True
        scene.cycles.device = 'GPU'
    except Exception:
        scene.cycles.device = 'CPU'
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.render.filepath = str(OUT / f'{name}.png')
    bpy.ops.render.render(write_still=True)
    print('RENDERED', name, flush=True)


# ------------------------------------------------------------------ props
def props():
    """Shared materials, rebuilt after each reset."""
    global BLACK, RUBBER, BELT, YELLOW, GOLD, GOLD_GLOW, MINT, WHITE, CYAN, VIOLET, RED_EYE
    BLACK = mat('box black', (.012, .013, .016), .2, .35)
    RUBBER = mat('rubber', (.02, .02, .025), 0, .8)
    BELT = mat('belt', (.05, .055, .06), .1, .7)
    YELLOW = mat('hazard yellow', (1, .55, .0), .1, .4)
    GOLD = mat('gold', (1, .6, .12), .85, .28, emit=.2, emit_color=(1, .55, .1))
    GOLD_GLOW = glow('gold glow', (1, .7, .15), 1.6)
    MINT = glow('mint glow', (.3, 1, .6), 1.5)
    WHITE = glow('white glow', (1, 1, .95), 4)
    CYAN = glow('cyan glow', (.25, .85, 1), 1.8)
    VIOLET = glow('violet glow', (.55, .2, 1), 1.5)
    RED_EYE = glow('red eye', (1, .12, .04), 2.5)


def black_box(at=(0, 4, 0), w=7.5, h=5.5, d=4.5, light_mat=None, open_flaps=0.0):
    """The yard's black box: cars come out of its mouth on the belt."""
    x, y, z = at
    box('black box', (x, y, z + h / 2), (w, d, h), BLACK, bevel=.12)
    for s in range(7):
        fx = x - 2.1 + s * .7
        tilt = open_flaps * (1 - abs(s - 3) / 4)
        box('flap', (fx, y - d / 2 - .05 - tilt * 1.2, z + 1.6 + tilt * .4), (.62, .06, 2.7), RUBBER, rot=(-tilt, 0, 0))
    box('mouth light', (x, y - d / 2 - .08, z + 3.25), (5.2, .1, .22), light_mat or glow('exit green', (.1, 1, .3), 1.8))
    for s in range(-4, 5):
        if abs(s) > 1:
            box('hazard', (x + s * .8, y - d / 2 - .03, z + .3), (.36, .04, .6), YELLOW, rot=(0, .6, 0))


def belt(y0=2, y1=-14, width=5, z=0):
    box('belt', (0, (y0 + y1) / 2, z + .2), (width, abs(y0 - y1), .4), BELT)
    for side in (-1, 1):
        box('belt rail', (side * (width / 2 + .15), (y0 + y1) / 2, z + .3), (.3, abs(y0 - y1), .6), YELLOW)
    slat = mat('slat', (.12, .12, .13), .2, .6)
    for i in range(int(abs(y0 - y1) / 1.2)):
        box('belt slat', (0, y0 - .6 - i * 1.2, z + .41), (width - .2, .08, .02), slat)


def junk_pile(at, n=10, spread=2.5, seed=1):
    rnd = random.Random(seed)
    cols = [(.33, .12, .04), (.08, .09, .1), (.25, .27, .3), (.5, .22, .06), (.1, .2, .4)]
    for _ in range(n):
        c = cols[rnd.randrange(len(cols))]
        p = (at[0] + rnd.uniform(-spread, spread), at[1] + rnd.uniform(-spread, spread), at[2] + rnd.uniform(0, 1.5))
        s = (rnd.uniform(.6, 1.8), rnd.uniform(.6, 1.8), rnd.uniform(.4, 1.2))
        box('junk', p, s, mat(f'junk{c}', c, .5, .7), rot=(rnd.uniform(-.4, .4), rnd.uniform(-.4, .4), rnd.uniform(0, TAU)), bevel=.05)
    for _ in range(3):
        torus('tyre', (at[0] + rnd.uniform(-spread, spread), at[1] + rnd.uniform(-spread, spread), at[2] + .3), .55, .25, RUBBER, rot=(rnd.uniform(0, .5), 0, 0))


def lightning(a, b, material, kinks=8, jitter=.45, r=.07, seed=3):
    rnd = random.Random(seed)
    a, b = Vector(a), Vector(b)
    pts = [a] + [a.lerp(b, i / kinks) + Vector([rnd.uniform(-jitter, jitter) for _ in range(3)]) for i in range(1, kinks)] + [b]
    tube('bolt', [tuple(p) for p in pts], r, material)
    tube('bolt halo', [tuple(p) for p in pts], r * 3, glow('bolt halo', (.3, .8, 1), .8, alpha=.2))


def coin(loc, rot, r=.5):
    c = cyl('coin', loc, r, r * .25, GOLD, rot=rot, verts=32)
    cyl('coin face', loc, r * .68, r * .28, mat('coin face', (1, .78, .28), .7, .25, emit=.25), rot=rot, verts=32)
    return c


def checkers(center, cols, rows, cell, plane='XY', depth=.04):
    """Real black and white squares (a texture smears at an angle)."""
    white = mat('flag white', (.9, .9, .9), 0, .5); black = mat('flag black', (.015, .015, .02), 0, .5)
    for i in range(cols):
        for j in range(rows):
            u = (i - (cols - 1) / 2) * cell; v = (j - (rows - 1) / 2) * cell
            loc = (center[0] + u, center[1] + v, center[2]) if plane == 'XY' else (center[0] + u, center[1], center[2] + v)
            size = (cell, cell, depth) if plane == 'XY' else (cell, depth, cell)
            box('check', loc, size, white if (i + j) % 2 else black)


def monster(at=(0, 6, 0), s=0.32):
    """The Race Wars scrap beast (RaceMonster's build), facing the camera (-Y).
    Laid out in its own studs: x right, y up, z forward."""
    x0, y0, z0 = at
    def P(x, y, z): return (x0 + x * s, y0 - z * s, z0 + y * s)
    hide = mat('monster', (.04, .036, .045), .5, .5)
    rust = mat('rust', (.36, .13, .04), .4, .75)
    bone = mat('bone', (.9, .86, .74), 0, .45)
    box('body', P(0, 13, -2), (22 * s, 16 * s, 17 * s), hide, rot=(math.radians(-10), 0, 0), bevel=.25)
    box('back plate', P(0, 20.5, -4), (17 * s, 10 * s, 5 * s), rust, rot=(math.radians(-20), 0, 0), bevel=.12)
    for i in (-1, 0, 1):
        cyl('spike', P(i * 5.5, 26.5 - abs(i), -5), 1.4 * s, 8 * s, rust, rot=(math.radians(-15), math.radians(i * 22), 0), verts=6, r2=0)
    box('head', P(0, 20, 7), (17 * s, 9 * s, 10 * s), hide, bevel=.15)
    box('brow', P(0, 24.2, 11.5), (17 * s, 1.6 * s, 2 * s), rust, rot=(math.radians(8), 0, 0))
    box('jaw', P(0, 12.5, 8.5), (16 * s, 3.5 * s, 10 * s), hide, rot=(math.radians(18), 0, 0), bevel=.1)
    box('mouth', P(0, 16.5, 10), (14 * s, 5 * s, 6 * s), glow('maw', (.55, .03, .02), 1.2))
    for i in range(6):
        xx = -6.2 + i * 2.5
        cyl('tooth', P(xx, 17.5, 12.6), .75 * s, 3 * s, bone, rot=(math.pi, 0, 0), verts=6, r2=0)
        cyl('tooth', P(xx + 1.2, 14.6, 13.6), .7 * s, 2.6 * s, bone, verts=6, r2=0)
    for side in (-1, 1):
        box('eye', P(side * 4.6, 22.4, 12.2), (3.6 * s, 1.6 * s, 1 * s), RED_EYE)
        sphere('eye halo', P(side * 4.6, 22.4, 12.6), 2.2 * s, glow('eye halo', (1, .1, .03), 1.2, alpha=.3), 12)
        box('arm', P(side * 13.5, 14, 4), (6 * s, 6 * s, 15 * s), hide, rot=(math.radians(35), math.radians(side * -12), 0), bevel=.12)
        for c in (-1, 0, 1):
            cyl('claw', P(side * 13.5 + c * 2, 19.5, 11.5), .7 * s, 6 * s, bone, rot=(math.radians(20), math.radians(c * 15), 0), verts=6, r2=0)
        box('leg', P(side * 7, 4, -2), (7 * s, 8 * s, 9 * s), hide, bevel=.12)
    point(P(0, 16, 22), 900, (1, .25, .1), .8)


def card(name, image, at, size=(2.6, 3.5), rot=(0, 0, 0), frame=(.12, .75, .95), lit=.6):
    """An Index card: the item's render in a coloured frame over a name plate."""
    w, h = size
    holder = bpy.data.objects.new(name, None); scene.collection.objects.link(holder)
    holder.location = at; holder.rotation_euler = rot
    box(name + ' frame', (0, 0, 0), (w, .14, h), glow(f'frame{frame}{lit}', frame, lit), bevel=.12).parent = holder
    box(name + ' inner', (0, -.075, h * .08), (w - .28, .02, h * .68), mat('card inner', (.05, .06, .09), 0, .6)).parent = holder
    m, (iw, ih) = image_mat(f'pic {image}', image)
    pw, ph = w - .4, h * .64
    span = (pw / ph) / (iw / ih)
    lo, hi = .5 - span / 2, .5 + span / 2
    me = bpy.data.meshes.new(name + ' pic')
    me.from_pydata([(-pw / 2, -.09, -ph / 2 + h * .08), (pw / 2, -.09, -ph / 2 + h * .08), (pw / 2, -.09, ph / 2 + h * .08), (-pw / 2, -.09, ph / 2 + h * .08)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new()
    for li, coord in enumerate([(lo, 0), (hi, 0), (hi, 1), (lo, 1)]): uv.data[li].uv = coord
    pic = bpy.data.objects.new(name + ' pic', me); scene.collection.objects.link(pic); me.materials.append(m)
    pic.parent = holder
    box(name + ' plate', (0, -.08, -h * .37), (w - .5, .02, h * .13), mat('plate', (1, .93, .75), 0, .5), bevel=.03).parent = holder
    return holder


# ------------------------------------------------------------------ the badges
BASE = 'warp-drive-batch/base-inputs/'
SCENES = {}
def badge(fn):
    SCENES[fn.__name__] = fn
    return fn


@badge
def welcome():
    """Join the game: your first car rolls out of the black box."""
    sky((.25, .6, 1), (.75, .88, 1))
    floor(mat('yard dirt', (.42, .33, .22), 0, .95))
    for i in range(-6, 7):
        box('fence', (i * 2.2, 14, 2), (2.1, .15, 4), mat('fence', (.35, .37, .4), .7, .5))
        box('fence post', (i * 2.2 + 1.1, 13.9, 2.1), (.18, .18, 4.3), mat('post', (.2, .2, .22), .6, .5))
    black_box((0, 5.5, 0))
    belt(3.3, -16)
    rig(BASE + 'Rusted_Sedan.json', length=4.2, at=(0, -1.0, .4))
    junk_pile((-7, 3, 0), 14, 2.2, seed=2)
    junk_pile((7.5, 4, 0), 14, 2.2, seed=4)
    light((6, -10, 12), (0, 0, 1), 2600, 10)
    light((-8, -6, 6), (0, 0, 1), 900, 8, (.8, .9, 1))
    camera((7, -12, 5.6), (0, 1.6, 1.0), 40)
    render('welcome')


@badge
def firstFusion():
    """Fuse a car with an addon on your Fusion Pad."""
    sky((.03, .05, .14), (.08, .12, .26))
    floor(mat('garage floor', (.1, .11, .14), .2, .5))
    box('fusion pad', (0, 0, .2), (10, 7, .4), mat('pad orange', (1, .32, .02), 0, .35, emit=.55, emit_color=(1, .3, 0)), bevel=.1)
    box('pad rim', (0, 0, .1), (10.6, 7.6, .2), mat('pad rim', (.06, .06, .07), .6, .4), bevel=.1)
    text3d('pad text', 'FUSION PAD', (0, -2.6, .42), .75, mat('pad text', (1, .85, .5), 0, .4, emit=.6), extrude=.02, rot=(0, 0, 0))
    rig(BASE + 'Muscle_Car.json', length=3.6, at=(-2.9, .5, .4), turn=-math.pi / 2 + .45)
    rig('new-addons/Twin_Turbo.json', length=1.9, at=(3.1, .6, .4), turn=math.pi / 2 - .5)
    core = Vector((.15, .3, 1.7))
    sphere('core', core, .32, WHITE)
    sphere('core halo', core, .8, glow('core halo', (1, .55, .15), 1.2, alpha=.35))
    for k, tilt in enumerate((0, 1.0, -1.0)):
        torus('swirl', core, 1.15 + k * .12, .035, CYAN, rot=(math.pi / 2 + tilt * .5, tilt * .4, 0))
    lightning(core, (-1.7, .6, 1.3), CYAN, seed=3)
    lightning(core, (2.3, .7, 1.2), CYAN, seed=9)
    lightning(core, (-1.5, .2, 2.1), CYAN, seed=12, r=.045)
    lightning(core, (2.0, .4, 2.1), CYAN, seed=15, r=.045)
    sparkles(14, (-3.5, -1, 2.2), (3.5, 1.5, 4.6), .12, .3, GOLD_GLOW, seed=5)
    light((0, -7, 9), (0, 0, 1), 1300, 8)
    light((-6, 4, 5), (0, 0, 1), 500, 6, (.6, .8, 1))
    camera((2.2, -10.5, 6.2), (0, .3, 1.0), 40)
    render('firstFusion')


@badge
def firstGhost():
    """Put a Phantom on a car: it turns into a ghost, front to back."""
    sky((.03, .02, .1), (.2, .09, .36))
    floor(mat('night ground', (.05, .04, .09), 0, .9))
    sphere('moon', (-5.5, 16, 8.5), 1.9, glow('moon', (1, .97, .85), 2.5))
    turn = math.pi / 2 - .45
    ahead = Vector((math.sin(turn), -math.cos(turn), 0))
    cut = .3
    rig(BASE + 'Muscle_Car.json', 'phantom-addons/Ghost_Chauffeur.json', length=5.2, width=.42, along=.05,
        paint=lambda m, base: split_mat(base, ahead, cut), turn=turn)
    # the change sweeping back along the car
    hoop = torus('wave', tuple(ahead * cut + Vector((0, 0, .85))), 1, .05, glow('wave', (.35, 1, .7), 2.0), rot=(math.pi / 2, 0, turn))
    hoop.scale = (1.55, 1.15, 1)
    sheet = cyl('wave sheet', tuple(ahead * cut + Vector((0, 0, .85))), 1, .02, glow('wave sheet', (.35, 1, .7), .6, alpha=.12), rot=(math.pi / 2, 0, turn), verts=48)
    sheet.scale = (1.55, 1.15, 1)
    rnd = random.Random(4)
    for _ in range(16):
        d = rnd.uniform(-.4, 2.8)
        p = ahead * (cut + d) + Vector((rnd.uniform(-1.6, 1.6) * ahead.y, rnd.uniform(-1.6, 1.6) * -ahead.x, rnd.uniform(.4, 3.2)))
        sphere('wisp', p, rnd.uniform(.06, .12), MINT, 10)
    for _ in range(4):
        sphere('mist', (rnd.uniform(-4, 4), rnd.uniform(-1, 4), .15), rnd.uniform(1.6, 2.4), glow('mist', (.35, .9, .7), .4, alpha=.05), 16, scale=(1, 1, .25))
    sparkles(8, (-3, -1, 2.5), (3.5, 2, 4.5), .12, .26, MINT, seed=8)
    light((3, -7, 7), (0, 0, 1), 900, 8, (.75, .8, 1))
    light((-4, 6, 4), (0, 0, 1), 500, 6, (.5, 1, .8))
    camera((1.2, -10.2, 4.3), (0, 0, 1.45), 40)
    render('firstGhost')


@badge
def secretCar():
    """A Secret car: it comes out of the black box in a blaze of gold."""
    sky((.02, .02, .05), (.08, .06, .12))
    floor(mat('dark floor', (.04, .04, .05), .2, .6))
    black_box((0, 4.5, 0), light_mat=GOLD_GLOW, open_flaps=.85)
    belt(2.3, -12)
    box('mouth glow', (0, 2.25, 1.65), (4.4, .05, 2.9), glow('mouth glow', (1, .62, .15), 2.2))
    rays((0, 0, 3.2), 22, 14, glow('beam', (1, .7, .25), .8, alpha=.22), y=7.5)
    shadow = mat('silhouette', (.004, .004, .006), .3, .45)
    rig('remaining-fusions/Afterburner_GT.json', length=4.8, paint=lambda m, base: shadow, at=(0, -.6, .4), turn=-.25)
    text3d('question', '?', (0, 2.2, 7.6), 3.8, GOLD, extrude=.35)
    sparkles(12, (-4.2, -1, 1), (4.2, 2.5, 9), .14, .32, GOLD_GLOW, seed=11)
    light((0, -8, 3), (0, 0, 1), 250, 6, (1, .85, .5))
    light((0, 6, 7), (0, -2, 1), 1800, 4, (1, .75, .35))
    light((-4, -6, 9), (0, 2, 7), 600, 4, (1, .9, .7))
    camera((3.8, -13, 4.6), (0, 1.5, 3.0), 38)
    render('secretCar')


@badge
def firstRebirth():
    """Rebirth: coins go, the car stays, and the multiplier goes up."""
    sky((.18, .07, .42), (.45, .22, .75))
    floor(mat('purple floor', (.13, .07, .22), .1, .6))
    cyl('pad', (0, 0, .15), 3.4, .3, mat('rebirth pad', (.6, .3, 1), 0, .35, emit=.7))
    rig(BASE + 'Muscle_Car.json', length=4.4, at=(0, 0, .3), turn=.4)
    # two arrows chasing each other round a circle behind the car
    cz, r0, r1 = 2.6, 3.3, 4.0
    for k in range(2):
        a0 = k * math.pi + .35; a1 = a0 + math.pi - .75
        steps = 24
        ring = [(math.cos(a0 + (a1 - a0) * i / steps) * r1, math.sin(a0 + (a1 - a0) * i / steps) * r1) for i in range(steps + 1)]
        ring += [(math.cos(a0 + (a1 - a0) * i / steps) * r0, math.sin(a0 + (a1 - a0) * i / steps) * r0) for i in range(steps, -1, -1)]
        flat('arrow', ring, VIOLET, .3, (0, 2.2, cz))
        tip = a1 + .42; mid = (r0 + r1) / 2
        head = [(math.cos(a1) * (r0 - .5), math.sin(a1) * (r0 - .5)), (math.cos(a1) * (r1 + .5), math.sin(a1) * (r1 + .5)),
                (math.cos(tip) * mid, math.sin(tip) * mid)]
        flat('arrowhead', head, VIOLET, .3, (0, 2.2, cz))
    rnd = random.Random(6)
    for i in range(8):
        a = rnd.uniform(0, TAU)
        coin((math.cos(a) * rnd.uniform(2.2, 4.2), rnd.uniform(-1, 1), cz + math.sin(a) * rnd.uniform(2.2, 3.4) + .4),
             (rnd.uniform(0, math.pi), rnd.uniform(0, math.pi), 0), .38)
    sparkles(10, (-4, -1, 1.5), (4, 1, 6.5), .1, .25, glow('lilac', (.85, .6, 1), 1.6), seed=7)
    light((3, -8, 8), (0, 0, 1), 1500, 8)
    light((-5, -2, 4), (0, 0, 1), 600, 5, (.8, .6, 1))
    camera((0, -12.5, 3.6), (0, 0, 2.3), 40)
    render('firstRebirth')


@badge
def maxRebirth():
    """The last Rebirth: x4 for good, breaking through the ceiling."""
    sky((.05, .04, .18), (.22, .12, .38))
    floor(mat('stage', (.08, .06, .12), .3, .4))
    rays((0, 0, 3.6), 20, 14, glow('gold ray', (1, .72, .25), .9, alpha=.3), y=3)
    lathe('podium', [(0, 0), (3.4, 0), (3.4, .45), (3.1, .6), (0, .6)], GOLD)
    cyl('podium top', (0, 0, .62), 2.9, .06, glow('podium glow', (1, .75, .3), 1.4))
    parts = rig('warp-drive-batch/Starcrusher.json', length=4.4, at=(0, 0, .65), turn=.45,
                paint=lambda m, base: GOLD_GLOW if (m.get('glow') or 0) > 0 else GOLD)
    lo, hi = bounds(parts)
    cz = hi.z + .15
    lathe('crown band', [(1.0, 0), (1.1, 0), (1.1, .55), (1.0, .55)], GOLD, at=(0, 0, cz))
    for i in range(5):
        a = i * TAU / 5 + .3
        cyl('crown point', (math.cos(a) * 1.02, math.sin(a) * 1.02, cz + 1.0), .3, .95, GOLD, verts=4, r2=0)
        sphere('jewel', (math.cos(a) * 1.12, math.sin(a) * 1.12, cz + .28), .14, mat('ruby', (1, .08, .18), .2, .1, emit=.8), 12)
    text3d('x4', 'x4', (0, 2.6, cz + 3.0), 2.0, GOLD, extrude=.25)
    # ceiling slabs flying apart above it
    rnd = random.Random(3)
    slab = mat('ceiling', (.3, .26, .4), .1, .6)
    for i in range(9):
        a = i * TAU / 9 + rnd.uniform(-.2, .2)
        box('ceiling shard', (math.cos(a) * rnd.uniform(3.4, 5.2), rnd.uniform(-.5, 2), 9.6 + math.sin(a) * 1.2),
            (rnd.uniform(.8, 1.6), rnd.uniform(.6, 1.2), .3), slab, rot=(rnd.uniform(-.8, .8), rnd.uniform(-.8, .8), rnd.uniform(0, TAU)))
    sparkles(16, (-5, -1, 1), (5, 2, 9.5), .12, .32, GOLD_GLOW, seed=13)
    light((4, -7, 9), (0, 0, 2), 1800, 8)
    light((-5, -4, 4), (0, 0, 2), 800, 6, (1, .85, .6))
    camera((0, -16, 4.6), (0, 0, 3.3), 40)
    render('maxRebirth')


@badge
def raceFinish():
    """Finish a Race Wars race, with the scrap beast right behind you."""
    sky((.95, .42, .2), (1, .78, .45), lo=.3, hi=.75)
    floor(mat('track', (.13, .12, .14), .1, .7))
    for side in (-1, 1):
        box('kerb', (side * 5.3, 0, .1), (.7, 40, .2), mat('kerb', (.9, .15, .1), .1, .5))
    checkers((0, -1.6, .03), 12, 2, .8)
    for side in (-1, 1):
        box('arch post', (side * 5.1, -1.6, 4.6), (.55, .55, 9.2), mat('post red', (.85, .1, .08), .2, .4), bevel=.08)
    checkers((0, -1.6, 9.4), 14, 2, .72, plane='XZ', depth=.2)
    monster((0, 8.5, 0), s=.36)
    rig('remaining-fusions/Afterburner_GT.json', length=4.6, at=(.4, -1.9, .02), turn=.12)
    rnd = random.Random(2)
    speed = glow('speed', (1, 1, 1), 1.2, alpha=.5)
    for _ in range(12):
        box('speed line', (rnd.uniform(-3.5, 4), rnd.uniform(1, 5), rnd.uniform(.4, 2.6)), (.05, rnd.uniform(2, 4), .05), speed)
    light((5, -8, 9), (0, 0, 1), 2200, 8, (1, .9, .8))
    light((-4, 2, 10), (0, 8, 5), 600, 5, (1, .5, .3))
    camera((3.0, -15.5, 3.6), (0, 2, 3.7), 36)
    render('raceFinish')


CARDS = [('remaining-fusions/Scrapyard_God-front.png', (.95, .62, .1)), ('remaining-fusions/Hover_Hulk-front.png', (.6, .25, 1)),
         ('remaining-fusions/Afterburner_GT-front.png', (1, .2, .15)), ('remaining-fusions/Sky_Marshal-front.png', (.15, .55, 1)),
         ('remaining-fusions/Riot_Rig-front.png', (.25, .85, .3)), ('remaining-fusions/Junk_Mashup-front.png', (.6, .25, 1)),
         ('remaining-fusions/Blown_Charger-front.png', (.15, .55, 1)), ('remaining-fusions/Mangled_Overlord-front.png', (1, .2, .15)),
         ('phantom-builds/Wisp_Kart.png', (.25, .85, .3))]


@badge
def collector():
    """25 builds found: a hand of Index cards."""
    sky((.04, .25, .6), (.25, .6, .95))
    rays((0, 0, 2.2), 16, 14, glow('blue ray', (.6, .85, 1), .5, alpha=.25), y=3)
    order = [3, 4, 0, 1, 2]
    for slot, i in enumerate(order):
        a = (slot - 2) * .3
        pic, frame = CARDS[i]
        card(f'card{slot}', pic, (math.sin(a) * 4.2, -(2 - abs(slot - 2)) * .05, -1.6 + math.cos(a) * 4.0),
             size=(2.7, 3.7), rot=(0, a, 0), frame=frame, lit=.9 if slot == 2 else .55)
    sparkles(10, (-4.5, -1, .5), (4.5, -.5, 5.5), .12, .3, WHITE, seed=21)
    light((0, -9, 6), (0, 0, 1.8), 1600, 10)
    camera((0, -12, 2.4), (0, 0, 2.2), 40)
    render('collector')


@badge
def masterBuilder():
    """Every fusion build found: the whole Index lit gold, and a trophy."""
    sky((.3, .16, .04), (.7, .45, .18))
    for r in range(3):
        for c in range(5):
            card(f'wall{r}{c}', CARDS[(r * 5 + c) % len(CARDS)][0], ((c - 2) * 2.55, 5, 2.2 + r * 3.45), size=(2.25, 3.05), frame=(1, .62, .12), lit=.5)
    lathe('trophy base', [(0, 0), (1.5, 0), (1.5, .55), (1.25, .7), (.4, .75), (.3, .9), (0, .9)], mat('trophy base', (.08, .05, .03), .4, .35))
    lathe('trophy', [(0, .9), (.32, .9), (.22, 1.4), (.25, 1.9), (.55, 2.2), (1.15, 2.7), (1.45, 3.5), (1.55, 4.3), (1.62, 4.4),
                     (1.5, 4.4), (1.38, 3.6), (1.05, 2.9), (0, 2.75)], GOLD)
    for side in (-1, 1):
        torus('handle', (side * 1.55, 0, 3.55), .55, .13, GOLD, rot=(math.pi / 2, 0, 0))
    flat('star', star_outline(.6), glow('trophy star', (1, .9, .55), 1.3), .14, (0, -1.5, 3.55), rot=(math.pi / 2 - .25, 0, 0))
    sparkles(16, (-5.5, -2, .5), (5.5, 1, 10), .12, .3, GOLD_GLOW, seed=17)
    light((3, -8, 8), (0, 0, 2), 2000, 8)
    light((-6, -3, 4), (0, 0, 2), 700, 6, (1, .85, .6))
    camera((0, -13, 4.6), (0, 1, 3.9), 40)
    render('masterBuilder')


@badge
def ghostCollector():
    """Every Phantom on every car: a parade of ghosts."""
    sky((.03, .02, .1), (.2, .09, .36))
    floor(mat('night ground', (.05, .04, .09), 0, .9))
    sphere('moon', (6, 18, 10.5), 2.2, glow('moon', (1, .97, .85), 2.5))
    lineup = [(BASE + 'Golf_Cart.json', 'phantom-addons/Will_o_Wisp_Lanterns.json', (-4.6, 3.0), .2, .7),
              (BASE + 'Box_Truck.json', 'phantom-addons/Specter_Sails.json', (4.6, 3.4), -.2, .8),
              (BASE + 'Monster_Truck.json', 'phantom-addons/Coffin_Carrier.json', (-2.4, .6), .12, .7),
              (BASE + 'Cop_Cruiser.json', 'phantom-addons/Reaper_Scythes.json', (2.5, .8), -.12, .75),
              (BASE + 'Rusted_Sedan.json', 'phantom-addons/Ghost_Chauffeur.json', (0, -1.8), 0, .5)]
    for carpath, addonpath, (x, y), turn, width in lineup:
        rig(carpath, addonpath, length=3.8, paint=as_ghost, width=width, along=0, at=(x, y, 0), turn=turn)
    rnd = random.Random(9)
    for _ in range(22):
        sphere('wisp', (rnd.uniform(-6, 6), rnd.uniform(-2, 6), rnd.uniform(.5, 6)), rnd.uniform(.05, .11), MINT, 10)
    for _ in range(6):
        sphere('mist', (rnd.uniform(-7, 7), rnd.uniform(-1, 6), .15), rnd.uniform(1.8, 2.8), glow('mist', (.35, .9, .7), .4, alpha=.08), 16, scale=(1, 1, .25))
    light((4, -7, 8), (0, 2, 1), 1000, 8, (.7, .8, 1))
    light((-3, 8, 4), (0, 2, 1), 700, 6, (.5, 1, .8))
    camera((0, -11.5, 4.6), (0, 1.4, 1.0), 38)
    render('ghostCollector')


for name, build in SCENES.items():
    if ONLY and name not in ONLY: continue
    reset(); _mats.clear()
    for m in list(bpy.data.materials): bpy.data.materials.remove(m)
    random.seed(7)
    props()
    build()
print('BADGE_SCENES_DONE', flush=True)
