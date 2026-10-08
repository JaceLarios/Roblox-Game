"""Phantom addons: the 15 ghost addons sold for bolts at the Phantom Garage.

Run in the background (it never touches an open Blender scene):
  E:/blender.exe --background --factory-startup --python build_phantoms.py

Builds each addon from parts, normalizes it to its shelf's size, exports the
same per-material JSON as assets/new-addons (Blender Z-up -> Roblox Y-up, front
along -Y in Blender = +Z in Roblox), writes manifest.json, saves
Phantom-Addons.blend and renders a preview per addon. Concepts:
https://claude.ai/artifact/6pWuFngQZNMWdvbTRiz7TA
"""
import bpy, bmesh, math, json, random, re, sys
from pathlib import Path
from mathutils import Vector
from collections import defaultdict

OUT = Path(__file__).resolve().parent
ONLY = None  # set from the command line: -- "Name" "Name" to build a few
RENDER = True
if '--' in sys.argv:
    args = sys.argv[sys.argv.index('--') + 1:]
    RENDER = '--norender' not in args
    ONLY = set(a for a in args if not a.startswith('--')) or None
random.seed(1031)
bpy.ops.wm.read_factory_settings(use_empty=True)

M = {}; META = {}; MODELS = {}; current = None
TAU = math.tau


def material(name, col, metal=0, rough=.35, glow=0, alpha=1, kind='plastic'):
    m = bpy.data.materials.new(name); m.diffuse_color = (*col, alpha); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*col, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    p.inputs['Alpha'].default_value = alpha
    if glow:
        p.inputs['Emission Color'].default_value = (*col, 1)
        p.inputs['Emission Strength'].default_value = glow * .45
    M[name] = m
    META[name] = {'color': col, 'metal': metal, 'glow': glow, 'alpha': alpha, 'kind': kind}


# The ghost palette: ectoplasm mint, wisp blue and violet over black iron,
# bone and gold, so these read as a different family from every other addon.
for args in [
    ('Iron', (.06, .065, .08), .7, .4, 0, 1, 'metal'),
    ('Chrome', (.60, .68, .75), .92, .2, 0, 1, 'metal'),
    ('Gold', (.95, .60, .08), .8, .25, 0, 1, 'metal'),
    ('Bone', (.86, .80, .62), 0, .55, 0, 1, 'plastic'),
    ('Violet', (.28, .06, .62), .45, .3, 0, 1, 'enamel'),
    ('DeepViolet', (.10, .03, .22), .4, .35, 0, 1, 'enamel'),
    ('Rubber', (.012, .015, .02), 0, .7, 0, 1, 'plastic'),
    ('Wood', (.22, .10, .04), 0, .7, 0, 1, 'wood'),
    ('DarkWood', (.10, .045, .02), 0, .7, 0, 1, 'wood'),
    ('Stone', (.30, .31, .34), 0, .8, 0, 1, 'slate'),
    ('Red', (.65, .02, .03), .3, .35, 0, 1, 'enamel'),
    ('Ecto', (.12, 1.0, .42), 0, .3, 3, 1, 'neon'),
    ('EctoMist', (.35, 1.0, .70), 0, .3, 1.5, .5, 'mist'),
    ('Wisp', (.20, .60, 1.0), 0, .3, 3, 1, 'neon'),
    ('WispMist', (.40, .75, 1.0), 0, .3, 1.5, .5, 'mist'),
    ('VioletGlow', (.60, .20, 1.0), 0, .3, 3, 1, 'neon'),
    ('VioletMist', (.70, .40, 1.0), 0, .3, 1.5, .5, 'mist'),
    ('Ghost', (.82, 1.0, .93), 0, .3, .5, .6, 'ghost'),
    ('GhostSail', (.75, 1.0, .90), 0, .4, .4, .45, 'ghost'),
    ('Lace', (.95, .95, 1.0), 0, .6, 0, .55, 'ghost'),
    ('Glass', (.55, .85, 1.0), .05, .1, 0, .25, 'glass'),
]:
    material(*args)


def add(o, name, mat):
    o.name = name; o.data.materials.append(M[mat]); MODELS[current].append(o)
    for c in list(o.users_collection): c.objects.unlink(o)
    bpy.data.collections[current].objects.link(o)
    return o


def model(name):
    global current
    current = name; MODELS[name] = []
    c = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c)


def box(name, p, size, mat='Iron', bevel=.03, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p); o = add(bpy.context.object, name, mat); o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot: o.rotation_euler = rot
    if bevel:
        mod = o.modifiers.new('Edge radii', 'BEVEL'); mod.width = bevel; mod.segments = 2
        o.modifiers.new('Panel normals', 'WEIGHTED_NORMAL')
    return o


def cylinder(name, a, b, r, mat='Iron', r2=None, n=24):
    a, b = Vector(a), Vector(b); d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r if r2 is None else r2, depth=d.length, location=(a + b) / 2)
    o = add(bpy.context.object, name, mat); o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    for f in o.data.polygons: f.use_smooth = len(f.vertices) == 4
    return o


def sphere(name, p, r, mat='Iron', scale=(1, 1, 1), seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=p)
    o = add(bpy.context.object, name, mat); o.scale = scale
    for f in o.data.polygons: f.use_smooth = True
    return o


def torus(name, p, major, minor, mat='Iron', axis=(0, 0, 1), seg=32, minor_seg=8):
    bpy.ops.mesh.primitive_torus_add(major_segments=seg, minor_segments=minor_seg, location=p, major_radius=major, minor_radius=minor)
    o = add(bpy.context.object, name, mat); o.rotation_euler = Vector(axis).to_track_quat('Z', 'Y').to_euler()
    for f in o.data.polygons: f.use_smooth = True
    return o


def pipe(name, points, r, mat='Chrome', resolution=2):
    curve = bpy.data.curves.new(name, 'CURVE'); curve.dimensions = '3D'; curve.resolution_u = 6
    curve.bevel_depth = r; curve.bevel_resolution = resolution; curve.use_fill_caps = True
    sp = curve.splines.new('BEZIER'); sp.bezier_points.add(len(points) - 1)
    for p, co in zip(sp.bezier_points, points):
        p.co = co; p.handle_left_type = 'AUTO'; p.handle_right_type = 'AUTO'
    o = bpy.data.objects.new(name, curve); bpy.context.collection.objects.link(o); add(o, name, mat)
    return o


def mesh(name, verts, faces, mat, smooth=False):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    if smooth:
        for f in me.polygons: f.use_smooth = True
    return add(o, name, mat)


def basis(axis):
    v = Vector(axis).normalized()
    u = v.cross(Vector((0, 0, 1))) if abs(v.z) < .9 else v.cross(Vector((1, 0, 0)))
    u.normalize(); return v, u, v.cross(u)


def lathe(name, center, axis, profile, mat, n=32, hem=None, closed_bottom=False):
    """Revolves (radius, height) pairs round `axis`. A radius of 0 is a pole.
    hem=(height, count) waves the first ring, for a ghost sheet's ragged edge."""
    c = Vector(center); v, u, w = basis(axis)
    verts, faces, rings = [], [], []
    for i, (r, h) in enumerate(profile):
        if r == 0:
            rings.append([len(verts)]); verts.append(tuple(c + v * h)); continue
        ring = []
        for j in range(n):
            t = j * TAU / n; hh = h
            if hem and i == 0: hh += hem[0] * math.sin(hem[1] * t)
            ring.append(len(verts)); verts.append(tuple(c + v * hh + (u * math.cos(t) + w * math.sin(t)) * r))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1: continue
        if len(a) == 1:
            for j in range(n): faces.append((a[0], b[(j + 1) % n], b[j]))
        elif len(b) == 1:
            for j in range(n): faces.append((a[j], a[(j + 1) % n], b[0]))
        else:
            for j in range(n): faces.append((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    if closed_bottom and len(rings[0]) > 1: faces.append(tuple(reversed(rings[0])))
    return mesh(name, verts, faces, mat, smooth=True)


def bolt(p, axis=(0, 0, 1), r=.045, mat='Gold'):
    a = Vector(p); cylinder('Hex fastener', a, a + Vector(axis).normalized() * .04, r, mat, n=6)


def bolts_ring(p, r, axis=(0, 1, 0), count=8, size=.035, mat='Gold'):
    p = Vector(p); v, u, w = basis(axis)
    for j in range(count): bolt(p + r * (u * math.cos(j * TAU / count) + w * math.sin(j * TAU / count)), axis, size, mat)


def flame(name, p, h, r, mat='Ecto', axis=(0, 0, 1)):
    return lathe(name, p, axis, [(0, 0), (r * .8, h * .12), (r, h * .3), (r * .75, h * .55), (r * .35, h * .8), (0, h)], mat, n=16)


def ghost(name, base, height, mat='Ghost', face=(0, -1, 0), hat=False):
    """A little sheet ghost standing on `base`, face toward `face`."""
    b = Vector(base); s = height
    lathe(name, b, (0, 0, 1), [(.30 * s, 0), (.27 * s, .18 * s), (.23 * s, .42 * s), (.22 * s, .60 * s),
                               (.24 * s, .74 * s), (.22 * s, .86 * s), (.13 * s, .96 * s), (0, s)], mat, n=20, hem=(.05 * s, 6))
    f = Vector(face).normalized(); side = f.cross(Vector((0, 0, 1))).normalized()
    for k in [-1, 1]:
        sphere('Ghost eye', b + Vector((0, 0, .74 * s)) + f * .20 * s + side * k * .075 * s, .05 * s, 'Rubber', (1, 1, 1.5), 12)
    sphere('Ghost mouth', b + Vector((0, 0, .58 * s)) + f * .21 * s, .045 * s, 'Rubber', (1, 1, 1.3), 12)


def spokes_ring(center, axis, r0, r1, count, rad, mat):
    c = Vector(center); v, u, w = basis(axis)
    for j in range(count):
        d = u * math.cos(j * TAU / count) + w * math.sin(j * TAU / count)
        cylinder('Spoke', c + d * r0, c + d * r1, rad, mat, n=8)


def footplate(w, l, z=.08, mat='Iron'):
    box('Bolt-on mount plate', (0, 0, z), (w, l, .12), mat, .03)
    for x in [-w / 2 + .1, w / 2 - .1]:
        for y in [-l / 2 + .1, l / 2 - .1]: bolt((x, y, z + .06))


# ---------------------------------------------------------------- WISP
model("Will-o'-Wisp Lanterns")
box('Lantern rail', (0, 0, .08), (2.4, .35, .16), 'Iron')
box('Rail nameplate', (0, -.19, .12), (.55, .04, .12), 'Violet', .015)
for x in [-.18, .18]: bolt((x, -.21, .12), (0, -1, 0), .025)
for x in [-.9, .9]:
    cylinder('Lantern post', (x, 0, .16), (x, 0, 1.9), .06, 'Iron', n=12)
    for z in [.5, 1.4]: torus('Post collar', (x, 0, z), .085, .022, 'Gold', seg=16)
    pipe('Hanging arm', [(x, 0, 1.85), (x, -.25, 2.05), (x, -.46, 1.95)], .035, 'Iron')
    torus('Lantern hook', (x, -.46, 1.87), .05, .015, 'Iron', (1, 0, 0), 12)
    c = Vector((x, -.46, 0))
    cylinder('Lantern roof', c + Vector((0, 0, 1.72)), c + Vector((0, 0, 1.86)), .22, 'Iron', r2=.03, n=4)
    box('Roof plate', c + Vector((0, 0, 1.70)), (.42, .42, .05), 'Iron', .01)
    box('Lantern base', c + Vector((0, 0, 1.16)), (.40, .40, .06), 'Iron', .01)
    cylinder('Base finial', c + Vector((0, 0, 1.13)), c + Vector((0, 0, 1.02)), .05, 'Gold', r2=.008, n=8)
    for dx in [-.18, .18]:
        for dy in [-.18, .18]:
            cylinder('Cage bar', c + Vector((dx, dy, 1.18)), c + Vector((dx, dy, 1.69)), .022, 'Iron', n=8)
    box('Lantern glass', c + Vector((0, 0, 1.43)), (.34, .34, .5), 'Glass', 0)
    cylinder('Wick cup', c + Vector((0, 0, 1.19)), c + Vector((0, 0, 1.24)), .07, 'Gold', n=12)
    flame('Spirit flame', c + Vector((0, 0, 1.23)), .40, .12, 'Ecto')
    sphere('Flame heart', c + Vector((0, 0, 1.34)), .05, 'EctoMist', seg=12)
    for k, (ox, oy, oz) in enumerate([(.32, -.12, 1.95), (-.28, -.2, 2.18), (.12, -.35, 2.4)]):
        p = c + Vector((ox * (1 if x > 0 else -1), oy, oz)); r = .06 - k * .012
        sphere('Drifting wisp', p, r, 'Ecto', seg=12)
        cylinder('Wisp tail', p, p + Vector((0, .05, -.16)), r * .8, 'EctoMist', r2=0, n=10)

model('Phantom Exhaust')
box('Exhaust mount', (0, .62, .12), (1.2, .45, .14), 'Iron')
for x in [-.32, .32]: bolt((x, .62, .2), r=.035)
for x in [-.35, .35]:
    pipe('Bone exhaust', [(x, 1.0, .3), (x, .35, .3), (x, -.55, .40), (x, -.95, .48)], .16, 'Bone')
    torus('Pipe clamp', (x, .62, .3), .16, .028, 'Chrome', (0, 1, 0), 20)
    for i in range(5):
        y = .25 - i * .26; z = .31 + (.25 - y) * .1
        torus('Vertebra ring', (x, y, z), .158, .034, 'Bone', (0, 1, 0), 20)
        cylinder('Spine knob', (x, y, z + .14), (x, y, z + .26), .045, 'Bone', r2=.012, n=8)
    sphere('Skull tip', (x, -1.12, .55), .27, 'Bone', (1, 1.05, .92))
    sphere('Skull jaw', (x, -1.16, .38), .17, 'Bone', (1, 1.1, .7))
    for k in [-1, 1]: sphere('Eye socket', (x + k * .1, -1.34, .62), .075, 'Rubber', (1, .6, 1.1), 12)
    cylinder('Nose hole', (x, -1.38, .53), (x, -1.32, .53), .04, 'Rubber', r2=.0, n=3)
    cylinder('Exhaust mouth', (x, -1.28, .40), (x, -1.38, .40), .09, 'Rubber', n=16)
    for k in [-1.5, -.5, .5, 1.5]: box('Tooth', (x + k * .05, -1.36, .47), (.04, .03, .05), 'Bone', .005)
    for k in range(3):
        y = -1.55 - k * .36; z = .48 + k * .16
        torus('Skull smoke ring', (x, y, z), .12 + .05 * k, .035, 'EctoMist', (0, 1, .15), 20)
    p = Vector((x, -2.55, 1.0))
    sphere('Smoke skull', p, .13, 'EctoMist', (1, .9, .95), 16)
    for k in [-1, 1]: sphere('Smoke skull eye', p + Vector((k * .045, -.11, .02)), .028, 'Rubber', seg=10)

model('Crystal Ball Ornament')
lathe('Claw stand base', (0, 0, 0), (0, 0, 1), [(0, 0), (.55, 0), (.56, .07), (.44, .13), (.26, .22), (.18, .40), (.22, .47), (0, .48)], 'Gold', n=40, closed_bottom=True)
torus('Violet stand band', (0, 0, .10), .5, .03, 'Violet', seg=40)
sphere('Stand gem', (0, -.47, .12), .06, 'VioletGlow', seg=12)
for k in range(4):
    a = k * TAU / 4; ca, sa = math.cos(a), math.sin(a)
    pipe('Gold claw', [(.18 * ca, .18 * sa, .45), (.50 * ca, .50 * sa, .62), (.58 * ca, .58 * sa, .98), (.44 * ca, .44 * sa, 1.30)], .042, 'Gold')
    cylinder('Claw talon', (.44 * ca, .44 * sa, 1.30), (.31 * ca, .31 * sa, 1.40), .045, 'Gold', r2=.004, n=8)
sphere('Crystal ball', (0, 0, 1.0), .48, 'Glass', seg=40)
ghost('Ghost in the ball', (0, 0, .70), .5)
torus('Ball mist swirl', (0, 0, .82), .30, .025, 'VioletMist', (.25, 0, 1), 32)
torus('Ball highlight ring', (0, 0, 1.0), .485, .01, 'VioletGlow', (0, 1, .3), 48)

model('Graveyard Grille')
box('Gate top rail', (0, 0, 1.25), (2.4, .12, .1), 'Iron', .02)
box('Gate bottom rail', (0, 0, .22), (2.4, .12, .1), 'Iron', .02)
for x in [-1.22, 1.22]:
    box('Gate post', (x, 0, .72), (.16, .16, 1.2), 'Iron', .03)
    sphere('Post ball finial', (x, 0, 1.42), .1, 'Gold', seg=16)
pipe('Gate arch', [(-1.05, 0, 1.25), (0, 0, 1.68), (1.05, 0, 1.25)], .045, 'Iron')
torus('Arch medallion', (0, 0, 1.52), .1, .025, 'Gold', (0, 1, 0), 20)
sphere('Medallion gem', (0, -.02, 1.52), .05, 'Ecto', seg=12)
for i in range(11):
    x = -1.0 + i * .2
    cylinder('Gate bar', (x, 0, .27), (x, 0, 1.30), .024, 'Iron', n=8)
    cylinder('Spear tip', (x, 0, 1.30), (x, 0, 1.43), .05, 'Gold', r2=0, n=4)
for x in [-.5, .5]: torus('Scroll curl', (x, 0, .74), .12, .02, 'Iron', (0, 1, 0), 20)
box('Tombstone', (0, -.34, .24), (.72, .18, .46), 'Stone', .03)
cylinder('Tombstone top', (0, -.43, .47), (0, -.25, .47), .36, 'Stone', n=28)
box('Stone cross upright', (0, -.44, .45), (.06, .03, .34), 'Bone', .008)
box('Stone cross bar', (0, -.44, .52), (.22, .03, .06), 'Bone', .008)
for k, (x, z) in enumerate([(-.85, .12), (-.4, .08), (.45, .1), (.9, .13)]):
    sphere('Creeping mist', (x, -.18, z), .2 - k % 2 * .04, 'EctoMist', (1.7, 1, .55), 16)

model('Ecto Tank')
box('Tank tray', (0, 0, .08), (1.3, 1.0, .12), 'Iron')
cylinder('Glass canister', (0, 0, .25), (0, 0, 1.75), .45, 'Glass', n=40)
cylinder('Ectoplasm', (0, 0, .28), (0, 0, 1.30), .42, 'Ecto', n=40)
for z in [.14, 1.72]:
    cylinder('Canister end cap', (0, 0, z), (0, 0, z + .18), .5, 'Iron', n=40)
    bolts_ring((0, 0, z + .09), .5, (0, 0, 1), 10)
sphere('Domed top', (0, 0, 1.9), .3, 'Iron', (1, 1, .5))
for z in [.62, 1.38]: torus('Retaining strap', (0, 0, z), .47, .04, 'Gold', seg=40)
for k in range(9):
    a = random.uniform(0, TAU); r = random.uniform(.05, .3)
    sphere('Rising bubble', (r * math.cos(a), r * math.sin(a), random.uniform(.45, 1.5)), random.uniform(.035, .08), 'EctoMist', seg=10)
cylinder('Gauge body', (0, -.50, 1.82), (0, -.60, 1.82), .16, 'Iron', n=24)
cylinder('Gauge face', (0, -.60, 1.82), (0, -.605, 1.82), .13, 'Bone', n=24)
torus('Gauge rim', (0, -.605, 1.82), .14, .015, 'Chrome', (0, 1, 0), 24)
box('Gauge needle', (.04, -.612, 1.85), (.1, .005, .015), 'Red', 0, rot=(0, -.7, 0))
cylinder('Valve stem', (0, 0, 2.0), (0, 0, 2.12), .035, 'Chrome', n=10)
torus('Valve wheel', (0, 0, 2.12), .14, .022, 'Red', seg=24)
spokes_ring((0, 0, 2.12), (0, 0, 1), .02, .14, 4, .015, 'Red')
pipe('Ecto feed hose', [(.42, 0, 1.86), (.68, .1, 1.6), (.66, .1, .5), (.5, .3, .16)], .05, 'Rubber')
for z in [1.6, .55]: torus('Hose clamp', (.66, .1, z), .065, .014, 'Chrome', (0, 0, 1), 16)
box('Skull warning plate', (0, -.51, .08), (.36, .03, .1), 'Bone', .01)

# ---------------------------------------------------------------- WRAITH
model('Banshee Horn')
box('Horn mount', (0, .95, .1), (.72, .72, .14), 'Iron')
for x in [-.26, .26]:
    for y in [.7, 1.2]: bolt((x, y, .18), r=.035)
pipe('Bone horn', [(0, .95, .2), (0, .72, .58), (0, .2, .98), (0, -.4, 1.16), (0, -.92, 1.2)], .14, 'Bone')
for p in [(0, .55, .78), (0, .05, 1.05), (0, -.5, 1.18)]: torus('Horn band', p, .12, .025, 'Gold', (0, 1, .4), 20)
lathe('Banshee bell', (0, -.9, 1.2), (0, -1, 0), [(.14, 0), (.17, .15), (.25, .30), (.40, .42), (.58, .50), (.66, .52), (.64, .55), (.54, .52)], 'Bone', n=40)
lathe('Bell lip', (0, -.9, 1.2), (0, -1, 0), [(.66, .52), (.70, .53), (.66, .56)], 'Gold', n=40)
cylinder('Wailing face', (0, -1.27, 1.2), (0, -1.30, 1.2), .34, 'Ghost', n=32)
for k in [-1, 1]: sphere('Hollow eye', (k * .13, -1.36, 1.33), .07, 'Rubber', (1, .5, 1.35), 12)
sphere('Screaming mouth', (0, -1.36, 1.06), .1, 'Rubber', (.9, .5, 1.6), 16)
for k in range(2):
    torus('Sound ring', (0, -1.7 - k * .34, 1.2), .48 + .12 * k, .03, 'VioletMist' if k else 'VioletGlow', (0, 1, 0), 40)

model('Poltergeist Spoiler')
box('Spoiler base', (0, 0, .08), (2.4, .5, .12), 'Iron')
for x in [-.75, .75]:
    box('Snapped strut', (x, 0, .3), (.12, .24, .4), 'Iron', .02)
    box('Snapped edge', (x + .03, 0, .53), (.12, .24, .08), 'Iron', .01, rot=(0, .5, 0))
box('Floating wing', (0, 0, 1.06), (2.8, .62, .1), 'Violet', .04, rot=(.12, 0, 0))
box('Gurney flap', (0, .32, 1.13), (2.7, .06, .1), 'DeepViolet', .015, rot=(.12, 0, 0))
box('Underglow strip', (0, 0, .99), (2.6, .05, .03), 'VioletGlow', 0)
for x in [-1.42, 1.42]: box('Wing endplate', (x, 0, 1.02), (.06, .78, .46), 'DeepViolet', .02)
for x, n in [(-.75, 6), (.75, 6), (-.28, 3), (.28, 4)]:
    for i in range(n):
        torus('Broken chain link', (x, 0, .95 - i * .085), .055, .014, 'Chrome', (1, 0, 0) if i % 2 else (0, 1, 0), 14, 6)
for x in [-1.25, 1.25]:
    for k in range(2):
        s = 1 if x > 0 else -1
        pipe('Rattle mark', [(x + s * .2, -.2, .85 + k * .3), (x + s * .3, -.25, .95 + k * .3), (x + s * .2, -.3, 1.05 + k * .3)], .015, 'VioletMist', 1)
for p in [(-.5, -.2, .7), (.1, .15, .6), (.6, -.1, .75)]: sphere('Restless wisp', p, .05, 'VioletGlow', seg=12)

model('Coffin Carrier')
for x in [-.72, .72]:
    box('Roof rack rail', (x, 0, .12), (.1, 2.7, .1), 'Iron', .02)
    for y in [-1.15, 1.15]: cylinder('Rack foot', (x, y, .07), (x, y, 0), .07, 'Rubber', n=12)
for y in [-.9, 0, .9]: box('Rack crossbar', (0, y, .14), (1.6, .1, .08), 'Iron', .02)
outline = [(-.32, 1.25), (.32, 1.25), (.56, .55), (.36, -1.25), (-.36, -1.25), (-.56, .55)]
def prism(name, pts, z0, z1, mat, lift=None, scale=1.0):
    vs = []
    for z in [z0, z1]:
        for x, y in pts:
            zz = z + (lift(x * scale) if lift else 0)
            vs.append((x * scale, y * scale, zz))
    n = len(pts)
    fs = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    o = mesh(name, vs, fs, mat)
    mod = o.modifiers.new('Edge radii', 'BEVEL'); mod.width = .025; mod.segments = 2
    return o
prism('Coffin box', outline, .2, .7, 'Wood')
prism('Coffin dark inside', outline, .69, .71, 'Rubber', scale=.88)
lid = prism('Cracked coffin lid', outline, .72, .84, 'DarkWood', lift=lambda x: (x + .56) * .16)
lid.location.z += .04
for k, y in enumerate([.62, .80]): sphere('Glowing eye', (.42, y, .79), .055, 'Ecto', (1, 1, .7), 12)
box('Lid cross upright', (0, .1, .99), (.1, .9, .04), 'Gold', .01, rot=(0, -.16, 0))
box('Lid cross bar', (0, .4, .99), (.42, .1, .04), 'Gold', .01, rot=(0, -.16, 0))
def coffin_edge(y):
    # Half-width of the coffin at `y`, from its outline's +x side.
    side = [(1.25, .32), (.55, .56), (-1.25, .36)]
    for (y0, x0), (y1, x1) in zip(side, side[1:]):
        if y1 <= y <= y0: return x0 + (x1 - x0) * (y - y0) / (y1 - y0)
    return .36
for y in [-.7, 0, .6]:
    for k in [-1, 1]:
        x = k * (coffin_edge(y) + .035)
        cylinder('Coffin handle', (x, y - .12, .45), (x, y + .12, .45), .03, 'Gold', n=8)
        for dy in [-.12, .12]: box('Handle bracket', (x - k * .02, y + dy, .45), (.05, .04, .06), 'Gold', .005)
for y in [-.55, .75]: box('Tie-down strap', (0, y, .87), (1.2, .08, .04), 'Rubber', .01)

model("Witch's Cauldron")
box('Fire ring base', (0, 0, .05), (1.5, 1.5, .1), 'Iron', .04)
lathe('Iron cauldron', (0, 0, 0), (0, 0, 1), [(0, .28), (.35, .30), (.62, .45), (.74, .68), (.74, .92), (.63, 1.10), (.67, 1.14), (.67, 1.20), (.58, 1.20), (.53, 1.08), (.62, .92), (.62, .68), (.51, .48), (.30, .38), (0, .37)], 'Iron', n=40)
torus('Cauldron rim', (0, 0, 1.17), .63, .06, 'Iron', seg=40)
for k in range(3):
    a = k * TAU / 3; ca, sa = math.cos(a), math.sin(a)
    cylinder('Cauldron leg', (.42 * ca, .42 * sa, .42), (.55 * ca, .55 * sa, .1), .06, 'Iron', r2=.04, n=12)
    sphere('Leg foot', (.56 * ca, .56 * sa, .1), .07, 'Iron', seg=12)
cylinder('Bubbling brew', (0, 0, .96), (0, 0, .99), .58, 'VioletGlow', n=40)
for k in range(11):
    a = random.uniform(0, TAU); r = random.uniform(0, .45)
    sphere('Brew bubble', (r * math.cos(a), r * math.sin(a), 1.0 + random.uniform(0, .5) * (k % 3 == 0)), random.uniform(.05, .12), 'VioletMist' if k % 3 == 0 else 'VioletGlow', seg=12)
cylinder('Stirring stick', (.15, -.1, .75), (.72, .42, 1.85), .045, 'Wood', n=10)
for x in [-.77, .77]: torus('Cauldron handle', (x, 0, .98), .14, .03, 'Iron', (0, 1, 0), 20)
for k in range(5):
    a = k * TAU / 5
    flame('Green fire', (.3 * math.cos(a), .3 * math.sin(a), .1), .3, .09, 'Ecto')

model('Specter Sails')
footplate(.9, .9)
cylinder('Mast', (0, 0, .14), (0, 0, 3.05), .07, 'Wood', n=16)
for z in [.6, 1.6, 2.5]: torus('Mast band', (0, 0, z), .08, .018, 'Iron', seg=16)
cylinder('Top yard', (-1.0, 0, 2.75), (1.0, 0, 2.75), .05, 'Wood', n=12)
cylinder('Boom', (-.9, 0, .9), (.9, 0, .9), .045, 'Wood', n=12)
cols, rows = 14, 12
vs, fs = [], []
for i in range(rows + 1):
    v = i / rows; z = 2.7 - v * 1.75; half = .95 - .1 * v
    for j in range(cols + 1):
        u = j / cols; x = -half + 2 * half * u
        y = .32 * math.sin(math.pi * u) * math.sin(math.pi * min(v * 1.1, 1))
        vs.append((x, y + .02, z - (random.uniform(0, .28) if i == rows else 0)))
holes = {(4, 3), (5, 3), (9, 6), (3, 8), (10, 9), (10, 10), (6, 10)}
for i in range(rows):
    for j in range(cols):
        if (j, i) in holes: continue
        if i == rows - 1 and random.random() < .3: continue
        a = i * (cols + 1) + j; fs.append((a, a + 1, a + cols + 2, a + cols + 1))
mesh('Torn ghost sail', vs, fs, 'GhostSail', smooth=True)
for x in [-1.0, 1.0]: pipe('Rigging line', [(x, 0, 2.75), (x * .45, 0, .14)], .012, 'Rubber', 1)
mesh('Ecto pennant', [(0, 0, 3.05), (0, 0, 2.86), (.32, .05, 2.97), (.6, .02, 2.93)], [(0, 1, 2), (0, 2, 3)], 'Ecto')
sphere('Masthead', (0, 0, 3.08), .07, 'Gold', seg=12)

# ---------------------------------------------------------------- REAPER
model('Wraith Wheels')
cylinder('Axle', (-1.12, 0, .75), (1.12, 0, .75), .07, 'Iron', n=16)
box('Axle housing', (0, 0, .75), (.5, .34, .34), 'Iron', .06)
for x in [-1.0, 1.0]:
    s = 1 if x > 0 else -1
    cylinder('Wheel hub', (x - .16 * s, 0, .75), (x + .16 * s, 0, .75), .22, 'Iron', n=24)
    cylinder('Hub cap', (x + .16 * s, 0, .75), (x + .2 * s, 0, .75), .14, 'Gold', n=24)
    torus('Ghost fire tyre', (x, 0, .75), .62, .11, 'Wisp', (1, 0, 0), 48, 12)
    torus('Inner rim', (x, 0, .75), .49, .035, 'Iron', (1, 0, 0), 40)
    spokes_ring((x, 0, .75), (1, 0, 0), .2, .5, 8, .026, 'Wisp')
    for j in range(12):
        a = j * TAU / 12; d = Vector((0, math.cos(a), math.sin(a)))
        b = Vector((x, 0, .75)) + d * .68
        tip = b + d * .12 + Vector((0, .38, .12))
        cylinder('Ghost fire tongue', b, tip, .085, 'WispMist', r2=0, n=10)

model('Soul Turbo')
for x in [-.6, .6]: box('Turbo foot', (x, 0, .1), (.16, 1.3, .16), 'Iron', .02)
for y in [-.45, .45]: box('Turbo cross brace', (0, y, .12), (1.4, .16, .16), 'Iron', .02)
c = Vector((0, 0, 1.0)); sc = 1.3; verts = []; faces = []
for i in range(49):
    t = i / 48; a = t * TAU * 1.05; R = .18 + .38 * t; rr = .105 + .105 * t
    for j in range(10):
        b = j * TAU / 10
        verts.append(tuple(c + Vector(((R + rr * math.cos(b)) * math.cos(a), rr * math.sin(b), (R + rr * math.cos(b)) * math.sin(a))) * sc))
for i in range(48):
    for j in range(10): k = i * 10 + j; q = i * 10 + (j + 1) % 10; faces.append((k, q, q + 10, k + 10))
mesh('Soul volute', verts, faces, 'DeepViolet', smooth=True)
torus('Intake flange', c + Vector((0, -.30, 0)), .34, .05, 'Gold', (0, 1, 0), 32)
cylinder('Intake throat', c + Vector((0, -.26, 0)), c + Vector((0, -.32, 0)), .33, 'Rubber', n=32)
bolts_ring(c + Vector((0, -.33, 0)), .34, (0, -1, 0), 8)
for k in range(2):
    pts = []
    for i in range(16):
        t = i / 15; a = t * TAU * 1.6 + k * math.pi; r = .32 - .27 * t
        pts.append((r * math.cos(a), -1.15 + .82 * t, 1.0 + r * math.sin(a)))
    pipe('Soul vortex', pts, .022, 'Ecto', 1)
for k in range(5):
    t = k / 5; a = t * TAU * 1.4 + .6; r = .4 - .25 * t
    ghost('Soul being pulled in', (r * math.cos(a), -1.5 + .9 * t, .82 + r * math.sin(a)), .30 - .03 * k, 'Ghost', face=(0, -1, 0))
cylinder('Outlet coupling', c + Vector((.58, .03, .26)), c + Vector((.95, .03, .26)), .2, 'Iron', n=24)
pipe('Outlet elbow', [tuple(c + Vector((.95, .03, .26))), tuple(c + Vector((1.15, .2, .5))), tuple(c + Vector((1.1, .6, .75)))], .15, 'Chrome')
torus('Ecto outlet ring', c + Vector((1.1, .6, .75)), .16, .02, 'Ecto', (0, 1, .5), 24)

model('Hearse Canopy')
for x in [-.92, .92]:
    box('Canopy base rail', (x, 0, .1), (.12, 2.8, .12), 'Iron', .02)
    for y in [-1.32, 1.32]:
        cylinder('Carved post', (x, y, .1), (x, y, 1.45), .065, 'Iron', n=12)
        for z in [.35, .8, 1.25]: torus('Post gilt ring', (x, y, z), .075, .018, 'Gold', seg=14)
box('Canopy roof', (0, 0, 1.52), (2.1, 3.0, .16), 'Iron', .05)
box('Roof crest', (0, 0, 1.66), (1.6, 2.7, .14), 'Iron', .05)
box('Roof cap', (0, 0, 1.78), (1.0, 2.3, .12), 'Iron', .04)
for p, s in [((0, -1.5, 1.44), (2.1, .04, .05)), ((0, 1.5, 1.44), (2.1, .04, .05)), ((-1.05, 0, 1.44), (.04, 3.0, .05)), ((1.05, 0, 1.44), (.04, 3.0, .05))]:
    box('Gilt trim', p, s, 'Gold', .008)
for k in range(15):
    y = -1.4 + k * .2
    for x in [-1.06, 1.06]: sphere('Gilt scallop', (x, y, 1.40), .045, 'Gold', (1, 1, 1.4), 10)
for x in [-.92, .92]:
    for y in [-1.32, 1.32]:
        sphere('Corner finial', (x, y, 1.72), .09, 'Gold', seg=14)
        cylinder('Finial spike', (x, y, 1.78), (x, y, 1.98), .04, 'Gold', r2=0, n=8)
lathe('Funeral urn', (0, 0, 1.84), (0, 0, 1), [(0, 0), (.12, 0), (.08, .05), (.16, .18), (.12, .3), (.06, .33), (.08, .38), (0, .40)], 'Gold', n=24)
def curtain(name, a, b, top, bottom, depth_axis, waves=6):
    a, b = Vector(a), Vector(b); n = Vector(depth_axis); cols, rows = 20, 6; vs, fs = [], []
    for i in range(rows + 1):
        v = i / rows
        for j in range(cols + 1):
            u = j / cols; p = a.lerp(b, u)
            sag = .08 * math.sin(math.pi * u)
            z = top - (top - bottom) * v - (sag + .06 * abs(math.sin(u * waves * math.pi)) if i == rows else 0)
            vs.append(tuple(p + n * (.05 * math.sin(u * waves * TAU)) + Vector((0, 0, z))))
    for i in range(rows):
        for j in range(cols): q = i * (cols + 1) + j; fs.append((q, q + 1, q + cols + 2, q + cols + 1))
    mesh(name, vs, fs, 'Lace', smooth=True)
for x in [-.92, .92]: curtain('Side lace curtain', (x, -1.28, 0), (x, 1.28, 0), 1.42, .78, (1, 0, 0))
for y in [-1.32, 1.32]:
    for x0, x1 in [(-.92, -.5), (.5, .92)]:
        curtain('Tied-back drape', (x0, y, 0), (x1, y, 0), 1.42, .7, (0, 1, 0), 3)
ghost('Face behind the curtain', (.6, .3, .62), .55, 'Ghost', face=(1, 0, 0))

model('Reaper Scythes')
cylinder('Scythe axle', (-1.05, 0, .72), (1.05, 0, .72), .06, 'Iron', n=16)
for x in [-1.0, 1.0]:
    s = 1 if x > 0 else -1
    cylinder('Scythe hub', (x - .15 * s, 0, .72), (x + .15 * s, 0, .72), .3, 'Iron', n=28)
    cylinder('Ecto hub core', (x + .15 * s, 0, .72), (x + .18 * s, 0, .72), .19, 'Ecto', n=24)
    torus('Hub gold rim', (x + .15 * s, 0, .72), .3, .03, 'Gold', (1, 0, 0), 28)
    bolts_ring((x + .13 * s, 0, .72), .2, (s, 0, 0), 6, .03)
    # A curved blade sweeping back and up from the hub, edge lit green.
    spine = []; outer = []; inner = []
    for i in range(25):
        t = i / 24; th = math.radians(95 + 125 * t); r = .32 + .95 * t
        p = Vector((0, r * math.cos(th), r * math.sin(th)))
        nrm = Vector((0, math.cos(th), math.sin(th)))
        wdt = .38 * (1 - t) ** .7 + .015
        outer.append(p + nrm * wdt * .5); inner.append(p - nrm * wdt * .5)
    vs = []
    for dx in [-.025, .025]:
        for q in outer + inner: vs.append((x + .3 * s + dx, q.y, .72 + q.z))
    n = len(outer); fs = []
    for layer in [0, 2 * n]:
        for i in range(n - 1): fs.append((layer + i, layer + i + 1, layer + n + i + 1, layer + n + i))
    for i in range(n - 1):
        fs.append((i, i + 1, 2 * n + i + 1, 2 * n + i)); fs.append((n + i, n + i + 1, 3 * n + i + 1, 3 * n + i))
    mesh('Scythe blade', vs, fs, 'Chrome', smooth=True)
    pipe('Ecto cutting edge', [(x + .3 * s, q.y, .72 + q.z) for q in outer[::3]], .024, 'Ecto', 1)
    cylinder('Blade arm', (x + .14 * s, 0, .72), (x + .3 * s, 0, .72 + .32), .05, 'Iron', n=12)

model('Ghost Chauffeur')
box('Seat frame', (0, .3, .12), (1.2, 1.0, .14), 'Iron', .03)
box('Seat cushion', (0, .3, .32), (1.1, .9, .26), 'Violet', .08)
box('Seat back', (0, .74, .9), (1.1, .18, 1.05), 'Violet', .08)
for x in [-.3, 0, .3]:
    for z in [.65, 1.05]: sphere('Tufted button', (x, .645, z), .035, 'Gold', seg=10)
s = 1.6
lathe('Ghost driver', (0, .25, .42), (0, 0, 1), [(.55, 0), (.48, .3), (.42, .66), (.38, 1.0), (.36, 1.18), (.30, 1.32), (.31, 1.52), (.22, 1.70), (0, 1.80)], 'Ghost', n=28, hem=(.07, 6))
for k in [-1, 1]: sphere('Driver eye', (k * .11, -.04, 1.72), .06, 'Rubber', (1, .5, 1.4), 12)
sphere('Driver smile', (0, -.07, 1.56), .055, 'Rubber', (1.6, .5, .6), 12)
for k in [-1, 1]:
    pipe('Ghostly arm', [(k * .34, .25, 1.55), (k * .36, -.2, 1.3), (k * .2, -.55, 1.18)], .07, 'Ghost')
    sphere('White glove', (k * .2, -.58, 1.18), .085, 'Bone', seg=14)
cylinder('Hat brim', (0, .25, 2.16), (0, .25, 2.2), .33, 'Rubber', n=32)
cylinder('Top hat', (0, .25, 2.2), (0, .25, 2.62), .2, 'Rubber', r2=.22, n=32)
cylinder('Hat band', (0, .25, 2.23), (0, .25, 2.3), .207, 'Red', n=32)
for k in [-1, 1]: cylinder('Bow tie', (0, -.1, 1.38), (k * .14, -.13, 1.38), .02, 'Red', r2=.08, n=10)
sphere('Bow knot', (0, -.11, 1.38), .035, 'Red', seg=10)
torus('Steering wheel', (0, -.68, 1.1), .3, .035, 'Iron', (0, 1, .7), 36)
spokes_ring((0, -.68, 1.1), (0, 1, .7), .04, .3, 3, .02, 'Chrome')
cylinder('Steering column', (0, -.7, 1.08), (0, -1.05, .2), .045, 'Iron', n=12)
box('Column base', (0, -1.05, .14), (.4, .4, .1), 'Iron', .02)
for k in range(4): sphere('Ghostly trail', (random.uniform(-.3, .3), .9 + k * .18, .5 + k * .12), .12 - k * .02, 'EctoMist', seg=12)


# ---------------------------------------------------------------- export
GROUP = {"Will-o'-Wisp Lanterns": 'wisp', 'Phantom Exhaust': 'wisp', 'Crystal Ball Ornament': 'wisp',
         'Graveyard Grille': 'wisp', 'Ecto Tank': 'wisp', 'Banshee Horn': 'wraith', 'Poltergeist Spoiler': 'wraith',
         'Coffin Carrier': 'wraith', "Witch's Cauldron": 'wraith', 'Specter Sails': 'wraith', 'Wraith Wheels': 'reaper',
         'Soul Turbo': 'reaper', 'Hearse Canopy': 'reaper', 'Reaper Scythes': 'reaper', 'Ghost Chauffeur': 'reaper'}
TARGET = {'wisp': 4.6, 'wraith': 4.8, 'reaper': 5.0}  # longest side, studs (Legendary addons are 4.5)


def file_name(name):
    return re.sub(r'[^A-Za-z0-9]+', '_', name).strip('_')


names = [n for n in MODELS if ONLY is None or n in ONLY]
manifest = []
for index, name in enumerate(names):
    objects = MODELS[name]
    for o in objects:
        bpy.context.view_layer.objects.active = o; o.select_set(True)
        if o.type == 'CURVE': bpy.ops.object.convert(target='MESH')
        for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        o.select_set(False)
    objects = MODELS[name] = [o for o in bpy.data.collections[name].objects if o.type == 'MESH']
    # Consistent outward normals on every closed shape.
    for o in objects:
        bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(o.data); bm.free()
    points = [o.matrix_world @ Vector(p) for o in objects for p in o.bound_box]
    lo = Vector([min(p[i] for p in points) for i in range(3)]); hi = Vector([max(p[i] for p in points) for i in range(3)])
    center = (lo + hi) / 2; target = TARGET[GROUP[name]]; factor = target / max(hi - lo)
    for o in objects:
        o.location = (o.location - center) * factor; o.scale *= factor
    bpy.context.view_layer.update()
    groups = defaultdict(lambda: {'vertices': [], 'normals': [], 'triangles': [], 'components': []})
    for o in objects:
        mat = o.data.materials[0].name; g = groups[mat]; g['components'].append(o.name)
        me = o.data; me.calc_loop_triangles(); nm = o.matrix_world.to_3x3().inverted().transposed()
        lookup = {}
        for tri in me.loop_triangles:
            ids = []
            for li in tri.loops:
                v = o.matrix_world @ me.vertices[me.loops[li].vertex_index].co
                n = (nm @ me.corner_normals[li].vector).normalized()
                vp = (round(v.x, 5), round(v.z, 5), round(-v.y, 5)); np_ = (round(n.x, 5), round(n.z, 5), round(-n.y, 5)); key = vp + np_
                if key not in lookup:
                    lookup[key] = len(g['vertices']); g['vertices'].append(vp); g['normals'].append(np_)
                ids.append(lookup[key])
            if len(set(ids)) == 3: g['triangles'].append(ids)
    data = {'name': name, 'rarity': 'spectral', 'group': GROUP[name], 'targetMax': target, 'parts': [], 'authoredComponents': len(objects)}
    for mat, g in groups.items(): data['parts'].append({'name': mat, 'material': META[mat], **g})
    path = OUT / (file_name(name) + '.json'); path.write_text(json.dumps(data, separators=(',', ':')))
    tris = sum(len(g['triangles']) for g in groups.values())
    manifest.append({'name': name, 'file': path.name, 'group': GROUP[name], 'maxDimension': target, 'parts': len(groups), 'components': len(objects), 'triangles': tris})
    print('EXPORTED', name, len(groups), 'parts', tris, 'triangles', flush=True)
    for o in objects: o.location += Vector(((index % 5) * 7.0, (index // 5) * 7.0, 0))
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2))
if ONLY is None:
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'Phantom-Addons.blend'))

if RENDER:
    scene = bpy.context.scene; scene.render.engine = 'CYCLES'; scene.cycles.samples = 48
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        for kind in ['OPTIX', 'CUDA']:
            try:
                prefs.compute_device_type = kind; prefs.get_devices()
                if any(d.type == kind for d in prefs.devices): break
            except TypeError:
                pass
        for d in prefs.devices: d.use = True
        scene.cycles.device = 'GPU'
    except Exception as e:
        print('GPU unavailable, using CPU:', e); scene.cycles.device = 'CPU'
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 640; scene.render.resolution_y = 640; scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new('Night'); scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.035, .03, .065, 1)
    scene.view_settings.view_transform = 'Standard'
    bpy.ops.object.camera_add(); cam = bpy.context.object; scene.camera = cam; cam.data.type = 'ORTHO'
    lights = []
    rig = [((2, -4, 6), 900, 5), ((-4, -1, 3), 600, 4), ((1, 4, 5), 1100, 3)]
    for loc, power, size in rig:
        bpy.ops.object.light_add(type='AREA', location=loc); o = bpy.context.object; o.data.energy = power; o.data.shape = 'DISK'; o.data.size = size; lights.append(o)
    for index, name in enumerate(names):
        for n in MODELS: bpy.data.collections[n].hide_render = n != name
        center = Vector(((index % 5) * 7.0, (index // 5) * 7.0, 0))
        cam.data.ortho_scale = TARGET[GROUP[name]] * 1.32
        cam.location = center + Vector((5.5, -7, 4.5)); cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()
        for o, (loc, power, size) in zip(lights, rig):
            o.location = center + Vector(loc); o.rotation_euler = (center - o.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(OUT / (file_name(name) + '.png')); bpy.ops.render.render(write_still=True)
        print('RENDERED', name, flush=True)
print('PHANTOM_ADDONS_DONE', flush=True)
