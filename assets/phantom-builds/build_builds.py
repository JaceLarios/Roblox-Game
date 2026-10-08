"""Phantom builds: sample Spectral builds, each base car wearing one Phantom addon.

Run in the background (it never touches an open Blender scene):
  E:/blender.exe --background --factory-startup --python build_builds.py
Add `-- --norender` to skip the previews, or `-- "Wisp Kart"` to build a few.

The base car is Codex's exact geometry (assets/warp-drive-batch/base-inputs),
repainted in the haunted livery. Its parts are not exported again: the Studio
importer copies them from the base car already in ItemModels and only uploads
the new parts. The addon is made by build_phantoms.py itself (same code, same
seed), minus its display stand, scaled and mounted on the car. Exports one JSON
per build in the shape of assets/remaining-fusions (wheel ids, pivots and radii,
front along +Z in Roblox), plus manifest.json, Phantom-Builds.blend and a front
and rear preview per build.
"""
import bpy, bmesh, math, json, sys, re, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from collections import defaultdict

OUT = Path(__file__).resolve().parent
ASSETS = OUT.parent
ADDON_DIR = ASSETS / 'phantom-addons'
BASE_DIR = ASSETS / 'warp-drive-batch' / 'base-inputs'
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
RENDER = '--norender' not in args
ONLY = set(a for a in args if not a.startswith('--')) or None

# The addon parts exactly as build_phantoms.py makes them, one collection each.
source = (ADDON_DIR / 'build_phantoms.py').read_text()
saved, sys.argv = sys.argv, sys.argv[:1]
P = {'__file__': str(ADDON_DIR / 'build_phantoms.py'), '__name__': 'build_phantoms'}
exec(compile(source[:source.index('# ---------------------------------------------------------------- export')], 'build_phantoms.py', 'exec'), P)
sys.argv = saved
ADDON_COLLECTIONS = list(P['MODELS'])
TAU = math.tau

# Roblox finish for each addon material (as assets/phantom-addons/import.edit.luau).
FINISH = {'Iron': 'Cast', 'Chrome': 'Brushed', 'Gold': 'Brushed', 'Violet': 'Enamel', 'DeepViolet': 'Enamel',
          'Red': 'Enamel', 'Rubber': 'Rubber'}

# ---------------------------------------------------------------- livery
# The haunted paint job every Spectral build wears: violet enamel body, bone
# and night-black panels, gold calipers, ectoplasm headlights, violet tail
# lights. (name, linear colour, metal, rough, glow, kind, Roblox finish)
for name, col, metal, rough, glow, kind, finish in [
    ('Spectral Violet', (.28, .06, .62), .45, .3, 0, 'enamel', 'Enamel'),
    ('Night', (.014, .009, .026), .3, .4, 0, 'enamel', 'Enamel'),
    ('Bone Paint', (.86, .80, .62), .1, .45, 0, 'enamel', 'Enamel'),
    ('Ecto Paint', (.10, .70, .36), .2, .35, 0, 'enamel', 'Enamel'),
    ('Caliper Gold', (.95, .60, .08), .8, .25, 0, 'metal', 'Brushed'),
    ('Ghost Leather', (.05, .02, .10), 0, .75, 0, 'plastic', 'Rubber'),
    ('Violet Leather', (.16, .05, .30), 0, .7, 0, 'plastic', 'Rubber'),
    ('Ecto Lamp', (.12, 1.0, .42), 0, .3, 3, 'neon', 'Light'),
    ('Violet Lamp', (.60, .20, 1.0), 0, .3, 3, 'neon', 'Light'),
    ('Wisp Lamp', (.20, .60, 1.0), 0, .3, 3, 'neon', 'Light'),
    ('Dark Iron', (.06, .065, .08), .7, .4, 0, 'metal', 'Cast'),
]:
    P['material'](name, col, metal, rough, glow, 1, kind); FINISH[name] = finish

# Base materials by their name in the base car (Iron_Body_0 -> Iron); `wheel`
# entries apply only to the rolling wheel parts. Anything not listed keeps
# its original look (iron, steel, chrome, rubber, gold, glass, titanium).
REPAINT = {'Red': 'Caliper Gold', 'White': 'Bone Paint', 'Cream': 'Bone Paint', 'Black': 'Night',
           'Seat': 'Ghost Leather', 'Upholstery': 'Violet Leather', 'Lamp': 'Ecto Lamp', 'Brake': 'Violet Lamp',
           'BlueLamp': 'Wisp Lamp'}
CAR_REPAINT = {
    'Rusted Sedan': {'Turquoise': 'Spectral Violet', 'Orange': 'Bone Paint', 'wheel Orange': 'Spectral Violet'},
    'Dirt Bike': {'Pink': 'Spectral Violet', 'Orange': 'Ecto Paint'},
    'Golf Cart': {'Green': 'Spectral Violet', 'Blue': 'Spectral Violet', 'Orange': 'Ecto Paint'},
    'Muscle Car': {'Orange': 'Spectral Violet'},
    'Cop Cruiser': {'White': 'Spectral Violet'},
    'Box Truck': {'Blue': 'Spectral Violet', 'Orange': 'Ecto Paint'},
    'Monster Truck': {'Blue': 'Spectral Violet', 'Orange': 'Ecto Paint', 'wheel Orange': 'Dark Iron'},
}


def base_material(car, part):
    kind = part['name'].split('_')[0]
    table = CAR_REPAINT.get(car, {})
    if part.get('wheel') and 'wheel ' + kind in table: return table['wheel ' + kind]
    if kind in table: return table[kind]
    if kind in REPAINT: return REPAINT[kind]
    return None


def original_material(car, part):
    name = 'Original ' + part['name'].split('_')[0]
    if name not in P['M']:
        m = part['material']; finish = m['finish']
        P['material'](name, tuple(m['color']), m.get('metal', .3), .38, m.get('glow', 0), 1,
                      'neon' if finish == 'Light' else 'glass' if finish == 'Glass' else 'enamel')
    return name


# ---------------------------------------------------------------- helpers
def base_name(o):
    return re.sub(r'\.\d+$', '', o.name)


def bake(objects):
    """Curves become meshes and modifiers are applied, for export."""
    for o in list(objects):
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = o; o.select_set(True)
        if o.type == 'CURVE': bpy.ops.object.convert(target='MESH')
        for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        o.select_set(False)


def world_points(objects):
    return [o.matrix_world @ v.co for o in objects for v in o.data.vertices]


def bounds(points):
    lo = Vector([min(p[i] for p in points) for i in range(3)]); hi = Vector([max(p[i] for p in points) for i in range(3)])
    return lo, hi


def center(o):
    lo, hi = bounds(world_points([o])); return (lo + hi) / 2


def tree_of(objects):
    verts, polys = [], []
    for o in objects:
        start = len(verts); verts += world_points([o])
        polys += [[start + i for i in p.vertices] for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


ADDON_OBJECTS = {}


def addon_objects(addon):
    if addon not in ADDON_OBJECTS:
        collection = bpy.data.collections[addon]
        bake(list(collection.objects))
        ADDON_OBJECTS[addon] = [o for o in collection.objects if o.type == 'MESH']
    return ADDON_OBJECTS[addon]


def place(addon, at, scale=1.0, turn=0.0, anchor=None, drop=(), keep=None, nudge=None, copy=False):
    """Mounts an addon's parts on the current build: scaled (one factor or
    x, y, z), turned round Z,
    then moved so the bottom centre of `anchor` (one of its part names, or
    the whole addon) lands on `at`. `drop` leaves parts out by name, `keep`
    filters by part (in the addon's own space), `nudge` moves single parts
    (after the turn)."""
    chosen = [o for o in addon_objects(addon) if base_name(o) not in drop and (keep is None or keep(o))]
    target = bpy.data.collections[P['current']]
    objects = []
    for o in chosen:
        if copy:
            o = o.copy(); o.data = o.data.copy(); target.objects.link(o)
        else:
            for c in list(o.users_collection): c.objects.unlink(o)
            target.objects.link(o)
        objects.append(o)
    sx, sy, sz = scale if isinstance(scale, tuple) else (scale, scale, scale)
    spin = Matrix.Rotation(turn, 4, 'Z') @ Matrix.Diagonal((sx, sy, sz, 1))
    for o in objects: o.matrix_world = spin @ o.matrix_world
    if nudge:
        for o in objects: o.matrix_world = Matrix.Translation(nudge(o)) @ o.matrix_world
    named = [o for o in objects if anchor is None or base_name(o) == anchor]
    lo, hi = bounds(world_points(named))
    move = Vector(at) - Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for o in objects: o.matrix_world = Matrix.Translation(move) @ o.matrix_world
    return objects


def tag_wheel(objects, wheel):
    for o in objects:
        o['WheelId'] = wheel['id']; o['WheelPivot'] = list(wheel['pivot']); o['WheelRadius'] = wheel['radius']


# ---------------------------------------------------------------- base cars
def load_base(car):
    d = json.loads((BASE_DIR / (car.replace(' ', '_') + '.json')).read_text())
    body, wheels = [], {}
    for g in d['parts']:
        repaint = base_material(car, g)
        o = P['mesh'](g['name'], [(x, -z, y) for x, y, z in g['vertices']], [tuple(t) for t in g['triangles']],
                      repaint or original_material(car, g))
        for f in o.data.polygons: f.use_smooth = True
        o.data.normals_split_custom_set_from_vertices([(x, -z, y) for x, y, z in g['normals']])
        o['BasePart'] = g['name']
        if g.get('wheel'):
            w = g['wheel']; pivot = (w['pivot'][0], -w['pivot'][2], w['pivot'][1])
            entry = wheels.setdefault(w['id'], {'id': w['id'], 'pivot': pivot, 'radius': w['radius'], 'parts': []})
            entry['parts'].append(o)
        else:
            body.append(o)
    return d, body, wheels


def wheel_info(wheels):
    out = []
    for w in wheels.values():
        lo, hi = bounds(world_points([o for o in w['parts'] if base_name(o).startswith('Rubber')]))
        flo, fhi = bounds(world_points(w['parts']))
        out.append({**w, 'inner': min(abs(lo.x), abs(hi.x)), 'outer': max(abs(lo.x), abs(hi.x)),
                    'face': max(abs(flo.x), abs(fhi.x)), 'side': 1 if w['pivot'][0] > 0 else -1})
    return out


class Car:
    def __init__(self, car):
        self.data, self.body, wheels = load_base(car)
        self.wheels = wheel_info(wheels)
        self.width, self.height, self.length = self.data['targetSize']
        self.ground = -self.height / 2
        self.tree = tree_of(self.body)

    def cast(self, origin, direction):
        loc = self.tree.ray_cast(Vector(origin), Vector(direction))[0]
        return loc

    def top(self, x, y):
        hit = self.cast((x, y, 50), (0, 0, -1)); return hit.z if hit else None

    def under(self, x, y):
        hit = self.cast((x, y, -50), (0, 0, 1)); return hit.z if hit else None

    def roof(self, x=0, band=.12):
        """The y range (and height) of the highest flat run along the car's middle."""
        samples = [(y / 20, self.top(x, y / 20)) for y in range(int(-self.length * 10), int(self.length * 10) + 1)]
        samples = [(y, z) for y, z in samples if z is not None]
        peak = max(z for _, z in samples)
        ys = [y for y, z in samples if z > peak - band]
        return min(ys), max(ys), peak

    def axles(self):
        ys = sorted(set(round(w['pivot'][1], 3) for w in self.wheels)); return ys[0], ys[-1]


def underglow(car, inset=.30, length=None):
    """Ectoplasm strips under each sill, between the axles."""
    front, rear = car.axles()
    r = max(w['radius'] for w in car.wheels)
    run = length or max(.6, (rear - front) - 2.3 * r)
    mid = (front + rear) / 2
    for side in [-1, 1]:
        x = side * car.width * inset
        z = car.under(x, mid)
        if z is None: continue
        P['box']('Ecto underglow', (x, mid, z - .035), (.06, run, .04), 'Ecto', 0)


# ---------------------------------------------------------------- the builds
def wisp_kart(car):
    # Carriage lanterns on the bonnet, lighting the way, wisps drifting off them.
    y = -car.length * .30
    place("Will-o'-Wisp Lanterns", (0, y, car.top(0, y) - .02), scale=.85, anchor='Lantern rail')
    underglow(car)


def skullsmoke_rider(car):
    # Twin bone exhausts down each side of the back wheel, skulls blowing smoke rings behind.
    rear = max(w['pivot'][1] for w in car.wheels); wheel = [w for w in car.wheels if w['pivot'][1] == rear][0]
    far_ring = lambda o: not (base_name(o) == 'Skull smoke ring' and center(o).y < -2.1)
    spread = lambda o: Vector((.14 * (1 if center(o).x > 0 else -1), 0, 0))
    place('Phantom Exhaust', (0, rear - .62, wheel['pivot'][2] + .02), scale=.8, turn=math.pi, anchor='Bone exhaust',
          drop={'Exhaust mount', 'Hex fastener', 'Smoke skull', 'Smoke skull eye'}, keep=far_ring, nudge=spread)


def coffin_caddy(car):
    # The coffin strapped to the canopy roof on its rack.
    y0, y1, z = car.roof()
    place('Coffin Carrier', (0, (y0 + y1) / 2, z - .01), scale=min(1.1, (y1 - y0 + .4) / 2.7))
    underglow(car)


def banshee_muscle(car):
    # The banshee horn bursts out of the hood like a blower, wailing ahead.
    y = -car.length * .165
    place('Banshee Horn', (0, y, car.top(0, y) - .03), scale=.7, anchor='Horn mount')
    underglow(car)


def graveyard_patrol(car):
    # The cemetery gate is the push bar, tombstone and creeping mist out front.
    lo, hi = bounds(world_points(car.body))
    place('Graveyard Grille', (0, lo.y - .34, car.ground + .02), scale=1.0)
    underglow(car)


def specter_hauler(car):
    # A ghost ship: two torn sails, stretched to the truck's width, on masts
    # along the cargo box roof.
    y0, y1, z = car.roof()
    for k, t in enumerate([.2, .78]):
        place('Specter Sails', (0, y0 + (y1 - y0) * t, z - .01), scale=(1.3, .95, .9), anchor='Bolt-on mount plate', copy=k == 0)
    underglow(car)


def wraith_crusher(car):
    # Every wheel burns with wisp fire: glowing tread band, sidewall ring and
    # spokes that roll with the wheel, flames streaming back that don't.
    for w in car.wheels:
        s = w['side']; c = Vector(w['pivot']); r = w['radius']
        mid = s * (w['inner'] + w['outer']) / 2; face = s * (w['face'] + .01)
        made = P['MODELS'][P['current']]; n0 = len(made)
        P['torus']('Ghost fire tread', (mid, c.y, c.z), r * .99, r * .085, 'Wisp', (1, 0, 0), 36, 6)
        P['torus']('Ghost fire sidewall', (face, c.y, c.z), r * .80, r * .06, 'Wisp', (1, 0, 0), 32, 6)
        P['spokes_ring']((face, c.y, c.z), (1, 0, 0), r * .18, r * .62, 8, r * .035, 'Wisp')
        P['cylinder']('Wraith hub cap', (face - s * .03, c.y, c.z), (face + s * .05, c.y, c.z), r * .17, 'Gold', n=20)
        tag_wheel(made[n0:], w)
        for j, a in enumerate([-30, 5, 40, 75, 110, 145]):
            d = Vector((0, math.cos(math.radians(a)), math.sin(math.radians(a))))
            for k, dx in enumerate([-.18, .18]):
                b = Vector((mid + s * dx, 0, 0)) + Vector((0, c.y, c.z)) + d * r * 1.02
                tip = b + d * r * .14 + Vector((0, r * (.62 + .1 * ((j + k) % 2)), r * .14))
                P['cylinder']('Ghost fire tongue', b, tip, r * .12, 'WispMist', r2=0, n=10)
    underglow(car, inset=.22)


BUILDS = [
    ('Wisp Kart', 'Rusted Sedan', "Will-o'-Wisp Lanterns", wisp_kart),
    ('Skullsmoke Rider', 'Dirt Bike', 'Phantom Exhaust', skullsmoke_rider),
    ('Coffin Caddy', 'Golf Cart', 'Coffin Carrier', coffin_caddy),
    ('Banshee Muscle', 'Muscle Car', 'Banshee Horn', banshee_muscle),
    ('Graveyard Patrol', 'Cop Cruiser', 'Graveyard Grille', graveyard_patrol),
    ('Specter Hauler', 'Box Truck', 'Specter Sails', specter_hauler),
    ('Wraith Crusher', 'Monster Truck', 'Wraith Wheels', wraith_crusher),
]


# ---------------------------------------------------------------- export
def meta(material):
    m = dict(P['META'][material]); finish = FINISH.get(material)
    if finish: m['finish'] = finish
    return m


def to_roblox(v):
    return (round(v.x, 5), round(v.z, 5), round(-v.y, 5))


def file_name(name):
    return re.sub(r'[^A-Za-z0-9]+', '_', name).strip('_')


manifest = []
built = []
for index, (name, base, addon, make) in enumerate(BUILDS):
    if ONLY and name not in ONLY: continue
    P['model'](name)
    car = Car(base)
    make(car)
    collection = bpy.data.collections[name]
    added = [o for o in collection.objects if 'BasePart' not in o]
    bake(added)
    added = [o for o in collection.objects if 'BasePart' not in o and o.type == 'MESH']
    for o in added:
        bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(o.data); bm.free()
    groups = defaultdict(lambda: {'vertices': [], 'normals': [], 'triangles': [], 'components': [], 'lookup': {}})
    for o in added:
        key = (o.data.materials[0].name, o.get('WheelId'))
        g = groups[key]; g['components'].append(base_name(o))
        if o.get('WheelId'): g['wheel'] = {'id': o['WheelId'], 'pivot': list(to_roblox(Vector(o['WheelPivot']))), 'radius': o['WheelRadius']}
        me = o.data; me.calc_loop_triangles(); nm = o.matrix_world.to_3x3().inverted().transposed()
        for tri in me.loop_triangles:
            ids = []
            for li in tri.loops:
                vp = to_roblox(o.matrix_world @ me.vertices[me.loops[li].vertex_index].co)
                np_ = to_roblox((nm @ me.corner_normals[li].vector).normalized()); k = vp + np_
                if k not in g['lookup']:
                    g['lookup'][k] = len(g['vertices']); g['vertices'].append(vp); g['normals'].append(np_)
                ids.append(g['lookup'][k])
            if len(set(ids)) == 3: g['triangles'].append(ids)
    parts, points, triangles = [], [], 0
    for g in car.data['parts']:
        lo, hi = bounds([Vector(v) for v in g['vertices']])
        repaint = base_material(base, g)
        part = {'name': g['name'], 'clone': base, 'center': list((lo + hi) / 2), 'size': list(hi - lo),
                'triangles': len(g['triangles']), 'material': meta(repaint) if repaint else None}
        if g.get('wheel'): part['wheel'] = g['wheel']
        parts.append(part); points += [lo, hi]; triangles += len(g['triangles'])
    for (material, wheel), g in groups.items():
        g.pop('lookup')
        label = 'Phantom ' + material + (' ' + wheel if wheel else '')
        part = {'name': label, 'material': meta(material), **g}
        part['geometryHash'] = hashlib.sha256(json.dumps([g['vertices'], g['normals'], g['triangles']], separators=(',', ':')).encode()).hexdigest()
        parts.append(part); points += [Vector(v) for v in g['vertices']]; triangles += len(g['triangles'])
    lo, hi = bounds(points)
    wheel_ids = set(p['wheel']['id'] for p in parts if p.get('wheel'))
    data = {'name': name, 'base': base, 'addon': addon, 'displayName': name, 'rarity': 'spectral', 'noseAxis': '+Z',
            'expectedWheels': len(wheel_ids), 'targetSize': list(hi - lo), 'boundsCenter': list((lo + hi) / 2),
            'baseSize': car.data['targetSize'], 'parts': parts,
            'authoredComponents': car.data.get('authoredComponents', 0) + len(added)}
    path = OUT / (file_name(name) + '.json'); path.write_text(json.dumps(data, separators=(',', ':')))
    new = sum(len(g['triangles']) for g in groups.values())
    assert triangles < 90000, (name, triangles)
    manifest.append({'name': name, 'base': base, 'addon': addon, 'file': path.name, 'triangles': triangles,
                     'newTriangles': new, 'newParts': len(groups), 'size': list(hi - lo)})
    print('EXPORTED', name, 'size', [round(a, 2) for a in hi - lo], 'base', car.data['targetSize'], triangles, 'tris', new, 'new', flush=True)
    mid = (lo + hi) / 2
    built.append((name, max(hi - lo), car.ground, Vector((mid.x, -mid.z, mid.y))))
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2))

# Every build side by side, addon leftovers out of the way.
for n in ADDON_COLLECTIONS: bpy.data.collections[n].hide_render = True
spacing = 12.0
for k, (name, _, _, _) in enumerate(built):
    for o in bpy.data.collections[name].objects: o.matrix_world = Matrix.Translation((k * spacing, 0, 0)) @ o.matrix_world
if ONLY is None:
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'Phantom-Builds.blend'))

if RENDER:
    scene = bpy.context.scene; scene.render.engine = 'CYCLES'; scene.cycles.samples = 64
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
    scene.render.resolution_x = 960; scene.render.resolution_y = 720
    scene.world = bpy.data.worlds.new('Night'); scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.05, .045, .09, 1)
    scene.view_settings.view_transform = 'Standard'
    stage = bpy.data.collections.new('Stage'); scene.collection.children.link(stage)
    floor_mat = bpy.data.materials.new('Floor'); floor_mat.use_nodes = True
    floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.03, .028, .05, 1)
    floor_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .8
    bpy.ops.mesh.primitive_plane_add(size=60); floor = bpy.context.object; floor.data.materials.append(floor_mat)
    for c in list(floor.users_collection): c.objects.unlink(floor)
    stage.objects.link(floor)
    bpy.ops.object.camera_add(); cam = bpy.context.object; scene.camera = cam; cam.data.type = 'ORTHO'
    rig = [((5, -7, 9), 2600, 8), ((-7, -2, 5), 1500, 6), ((2, 8, 7), 2400, 6)]
    lights = []
    for loc, power, size in rig:
        bpy.ops.object.light_add(type='AREA'); o = bpy.context.object; o.data.energy = power; o.data.shape = 'DISK'; o.data.size = size; lights.append(o)
    for k, (name, extent, ground, focus) in enumerate(built):
        for n in [b[0] for b in built]: bpy.data.collections[n].hide_render = n != name
        middle = Vector((k * spacing, 0, 0)) + focus
        floor.location = Vector((k * spacing, 0, ground - .002))
        cam.data.ortho_scale = extent * 1.6
        for suffix, view in [('', Vector((7, -9, 5.5))), ('-rear', Vector((-7, 9, 5.5)))]:
            cam.location = middle + view; cam.rotation_euler = (middle - cam.location).to_track_quat('-Z', 'Y').to_euler()
            for o, (loc, power, size) in zip(lights, rig):
                flip = Vector((loc[0], loc[1], loc[2])) if not suffix else Vector((-loc[0], -loc[1], loc[2]))
                o.location = middle + flip; o.rotation_euler = (middle - o.location).to_track_quat('-Z', 'Y').to_euler()
            scene.render.filepath = str(OUT / (file_name(name) + suffix + '.png')); bpy.ops.render.render(write_still=True)
        print('RENDERED', name, flush=True)
print('PHANTOM_BUILDS_DONE', flush=True)
