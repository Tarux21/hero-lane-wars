# Burgkarte im Stil des Referenzbilds (sonnige goldene Wiese, Burgmauern, runde Türme, Banner).
# Probestück: ein Lane-Abschnitt aus der Spielkamera, zum Vergleich von Varianten.
#   blender -b -P make_burg.py -- probe <bild.png> <variante 1|2|3>
# Maße wie im Spiel: Lane 10,8 m breit, Wand 3,2 m, Kamera 58° / 28 m, Held 3 m.
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
NAT = os.path.join(ROOT, "tools-extern", "assets", "quaternius-nature")
HEROES = os.path.join(ROOT, "godot", "assets", "heroes")
LANE_HALF = 5.4
WALL = 3.2
RIVER = 5.0


def mat(name, col, rough=0.85, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def stone_mat():
    """Warmer Burgstein: jede Steinform bekommt per Zufall (Objekt-Info) einen eigenen Grauton, dazu feine Körnung."""
    m = bpy.data.materials.get("burgstein")
    if m:
        return m
    m = bpy.data.materials.new("burgstein")
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    oi = nt.nodes.new("ShaderNodeObjectInfo")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].color = (0.40, 0.34, 0.27, 1)                       # warmer Sandstein, wie im Referenzbild
    cr.elements[1].color = (0.74, 0.65, 0.51, 1)
    nt.links.new(oi.outputs["Random"], ramp.inputs["Fac"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 6.0
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
    mix.inputs["Factor"].default_value = 0.25
    nt.links.new(ramp.outputs["Color"], mix.inputs[6])
    nt.links.new(noise.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.9
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.25
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    return m


def ground_mat(name, c1, c2, scale=0.08):
    """Boden mit großen weichen Farbflecken (Wiese: gold/grün, Weg: Erde)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n1 = nt.nodes.new("ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = scale; n1.inputs["Detail"].default_value = 3
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35; ramp.color_ramp.elements[0].color = (*c1, 1)
    ramp.color_ramp.elements[1].position = 0.65; ramp.color_ramp.elements[1].color = (*c2, 1)
    nt.links.new(n1.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.95
    return m


def plane(name, x0, x1, y0, y1, z, m):
    bm = bmesh.new()
    vs = [bm.verts.new((x0, y0, z)), bm.verts.new((x1, y0, z)), bm.verts.new((x1, y1, z)), bm.verts.new((x0, y1, z))]
    bm.faces.new(vs)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    me.materials.append(m)
    return o


_TPL = {}


def _template(key, m, round_):
    """Musterstein (Würfel 1 m, runde Kanten) einmal als Mesh; alle Steine sind verknüpfte Kopien davon (schnell)."""
    round_ = round(round_ * 20) / 20                                   # wenige Musterformen (Rundung in 0,05-Stufen)
    k = (key, m.name, round_)
    if k not in _TPL:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        if round_ > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=round_ * 0.5, segments=2, affect="EDGES")
        me = bpy.data.meshes.new("stein_%s" % key); bm.to_mesh(me); bm.free()
        for f in me.polygons:
            f.use_smooth = True
        me.materials.append(m)
        _TPL[k] = me
    return _TPL[k]


def rock(size, loc, m, rot_z=0.0, seed=0, round_=0.35):
    """Ein Burgstein: verknüpfte Kopie des Mustersteins, skaliert und gedreht (Farbe per Objekt-Zufall)."""
    o = bpy.data.objects.new("stein", _template("r", m, round_))
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.scale = size
    o.rotation_euler.z = rot_z
    return o


_NAT = {}


def nature(name):
    """Modell aus dem Natur-Paket einmal laden (danach als verknüpfte Kopie verwenden)."""
    if name in _NAT:
        return _NAT[name]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(NAT, "glTF", name + ".gltf"))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == 'MESH']
    for o in new:
        o.hide_render = True; o.hide_viewport = True
    _NAT[name] = meshes
    return meshes


def place(name, loc, s=1.0, yaw=None):
    out = []
    for src in nature(name):
        o = bpy.data.objects.new(name, src.data)
        bpy.context.scene.collection.objects.link(o)
        o.location = Vector(loc) + src.location * s
        o.rotation_euler = (src.rotation_euler.x, src.rotation_euler.y, random.uniform(0, math.tau) if yaw is None else yaw)
        o.scale = Vector(src.scale) * s
        out.append(o)
    return out


# ---------------------------------------------------------------- Bauteile
def castle_wall(x, y0, y1, height=4.2, thick=2.2, m=None):
    """Burgmauer aus einzelnen, versetzten Steinen; oben ein gepflasterter Wehrgang und scharfe Zinnen zur Lane hin.
    Sichtbar schmaler als der Spielbereich der Wand (3,2 m): links und rechts bleibt ein Grasstreifen."""
    m = m or stone_mat()
    row_h = 0.55
    rows = int(height / row_h)
    for r in range(rows):
        z = r * row_h + row_h / 2
        y = y0 - (0.5 if r % 2 else 0.0)
        while y < y1:
            L = random.uniform(0.9, 1.5)
            if y + L > y1:
                L = y1 - y
            if L > 0.2:
                for sx in (-1, 1):                                       # zwei Schalen (vorn/hinten), dazwischen Kern
                    rock((random.uniform(0.45, 0.6), L * 0.95, row_h * 0.93), (x + sx * (thick / 2 - 0.27), y + L / 2, z), m, round_=0.25)
            y += L
    rock((thick - 0.5, y1 - y0, height), (x, (y0 + y1) / 2, height / 2), m, round_=0.02)
    top = height
    y = y0                                                             # Wehrgang: Steinplatten in zwei Reihen
    while y < y1:
        L = random.uniform(0.7, 1.1)
        for sx in (-0.5, 0.5):
            rock(((thick - 0.6) / 2 * 0.95, L * 0.93, 0.18), (x + sx * (thick - 0.6) / 2, y + L / 2, top + 0.05), m, round_=0.2)
        y += L
    y = y0
    k = 0
    while y < y1 - 0.6:                                                # Zinnen: außen durchgehend, zur Lane hin mit Lücken
        for sx in (-1, 1):
            if k % 2 == 0 or sx > 0:
                rock((0.42, 0.8 if k % 2 == 0 else 0.86, 0.8 if k % 2 == 0 else 0.35), (x + sx * (thick / 2 - 0.21), y + 0.45, top + (0.45 if k % 2 == 0 else 0.22)), m, round_=0.12)
        y += 0.9
        k += 1


def tower(x, y, r=2.6, height=7.0, banner=None, m=None):
    """Runder Turm aus Steinringen mit Zinnenkranz; optional Banner."""
    m = m or stone_mat()
    row_h = 0.6
    for k in range(int(height / row_h)):
        z = k * row_h + row_h / 2
        n = int(math.tau * r / 1.1)
        off = (k % 2) * 0.5
        for i in range(n):
            a = (i + off) / n * math.tau
            rock((0.6, 1.15, row_h * 0.94), (x + math.cos(a) * (r - 0.3), y + math.sin(a) * (r - 0.3), z), m, rot_z=a)
    bpy.ops.mesh.primitive_cylinder_add(radius=r - 0.45, depth=height, location=(x, y, height / 2))
    bpy.context.object.data.materials.append(m)
    n = 12
    for i in range(n):                                                 # Zinnenkranz, leicht vorstehend
        a = i / n * math.tau
        rock((0.7, 1.2, 0.5), (x + math.cos(a) * (r + 0.1), y + math.sin(a) * (r + 0.1), height + 0.25), m, rot_z=a)
        if i % 2 == 0:
            rock((0.6, 0.9, 0.8), (x + math.cos(a) * (r + 0.1), y + math.sin(a) * (r + 0.1), height + 0.9), m, rot_z=a)
    if banner:
        flag(x, y, r, height, banner)


def flag(x, y, r, height, col):
    """Langes Banner außen am Turm (Stoff mit Goldrand und Wappenzeichen)."""
    cloth = mat("banner_%s" % str(col), col, 0.8)
    gold = mat("gold", (0.85, 0.65, 0.2), 0.35, 0.8)
    a = -math.pi / 2 * 0 + math.pi                                       # zur Lane hin (x negativ)
    cx, cy = x + math.cos(a) * (r + 0.05), y
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, height - 2.4))
    b = bpy.context.object; b.scale = (0.05, 1.2, 4.2); b.data.materials.append(cloth)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=1.5, location=(cx - 0.05, cy, height - 0.25), rotation=(math.pi / 2, 0, 0))
    bpy.context.object.data.materials.append(gold)
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.6, depth=0.01, location=(cx - 0.06, cy, height - 2.2), rotation=(0, math.pi / 2, 0))
    bpy.context.object.data.materials.append(gold)


def low_wall(x, y0, y1, m=None):
    """Halbhohe, teils verfallene Feldsteinmauer."""
    m = m or stone_mat()
    y = y0
    while y < y1:
        L = random.uniform(0.7, 1.2)
        hgt = random.choice([2, 2, 3, 3, 1])
        for r in range(hgt):
            rock((random.uniform(1.0, 1.6), L * 0.95, 0.45), (x + random.uniform(-0.15, 0.15), y + L / 2 + (0.3 if r % 2 else 0), r * 0.42 + 0.22), m)
        y += L


def palisade(x, y0, y1):
    wood = mat("palisade", (0.36, 0.24, 0.13), 0.8)
    tip = mat("palisade_tip", (0.5, 0.36, 0.2), 0.8)
    y = y0
    while y < y1:
        h = random.uniform(2.6, 3.3)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.22, depth=h, location=(x + random.uniform(-0.05, 0.05), y, h / 2))
        o = bpy.context.object; o.data.materials.append(wood); o.rotation_euler.y = random.uniform(-0.04, 0.04)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.22, depth=0.5, location=(o.location.x, y, h + 0.25))
        bpy.context.object.data.materials.append(tip)
        y += 0.44
    for z in (0.9, 2.0):                                                 # Querbalken
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x + 0.3, (y0 + y1) / 2, z))
        o = bpy.context.object; o.scale = (0.12, y1 - y0, 0.18); o.data.materials.append(wood)


def cliff(x, y0, y1, side):
    """Felsklippe mit Graskante: große, gerundete Felsblöcke unterschiedlicher Höhe, oben eine Grasdecke mit Büschen.
    side = Richtung von der Lane weg (-1/+1): die Klippe fällt zur Lane hin ab."""
    rk = mat("klippe", (0.47, 0.42, 0.36), 0.95)
    grass = ground_mat("klippengras", (0.55, 0.52, 0.18), (0.35, 0.50, 0.14), 0.2)
    y = y0
    while y < y1:
        L = random.uniform(2.0, 3.6)
        h = random.uniform(2.2, 3.6)
        w = random.uniform(2.6, 3.4)
        cx = x + side * random.uniform(0.0, 0.5)
        rock((w, L, h), (cx, y + L / 2, h / 2), stone_mat(), rot_z=random.uniform(-0.15, 0.15), round_=0.3)
        rock((w + 0.3, L + 0.2, 0.35), (cx + side * 0.15, y + L / 2, h + 0.05), grass, rot_z=random.uniform(-0.1, 0.1), round_=0.45)
        if random.random() < 0.6:
            place(random.choice(["Bush_Common", "Bush_Common_Flowers", "Grass_Common_Tall"]), (cx + side * random.uniform(0.2, 1.0), y + L / 2, h + 0.2), random.uniform(0.8, 1.3))
        if random.random() < 0.5:                                           # Geröll am Fuß
            place(random.choice(["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]), (x - side * (w / 2 + 0.3), y + random.uniform(0, L), 0), random.uniform(0.5, 0.9))
        y += L * 0.85


def ruin(x, y0, y1, m=None):
    """Verfallene Burgmauer: Abschnitte mit unterschiedlicher Höhe, Lücken mit Geröll und Büschen, hier und da ein Bogen."""
    m = m or stone_mat()
    y = y0
    k = 0
    while y < y1:
        L = random.uniform(3.0, 6.0)
        kind = random.random()
        if kind < 0.22:                                                     # Lücke: Geröll und Busch
            for i in range(4):
                s_ = random.uniform(0.4, 0.8)
                rock((s_, s_ * 1.2, s_ * 0.7), (x + random.uniform(-1, 1), y + random.uniform(0, L), s_ * 0.3), m, rot_z=random.uniform(0, 3), round_=0.3)
            place(random.choice(["Bush_Common", "Bush_Common_Flowers"]), (x, y + L / 2, 0), random.uniform(1.2, 1.6))
        elif kind < 0.38 and L > 4.0:                                        # Bogen
            for py in (y + 0.5, y + L - 0.5):
                for r in range(6):
                    rock((1.0, 1.0, 0.5), (x, py, r * 0.5 + 0.25), m, round_=0.25)
            n = 9
            R = (L - 1.0) / 2
            for i in range(n + 1):
                a = math.pi * i / n
                rock((1.0, 0.6, 0.55), (x, y + L / 2 - math.cos(a) * R, 3.0 + math.sin(a) * R * 0.8), m, round_=0.2)
        else:                                                               # Mauerstück, oben schräg abgebrochen
            h0, h1 = random.uniform(1.0, 3.6), random.uniform(1.0, 3.6)
            yy = y
            while yy < y + L:
                ll = random.uniform(0.8, 1.3)
                hh = h0 + (h1 - h0) * (yy - y) / L
                for r in range(max(1, int(hh / 0.55))):
                    rock((1.4, ll * 0.95, 0.5), (x + random.uniform(-0.05, 0.05), yy + ll / 2 + (0.35 if r % 2 else 0), r * 0.52 + 0.26), m, round_=0.25)
                yy += ll
            if random.random() < 0.6:                                         # Efeu/Gras oben drauf
                place("Grass_Common_Tall", (x, y + L / 2, max(h0, h1) * 0.8), 1.0)
        y += L
        k += 1


def hedge(x, y0, y1, side):
    """Dichte Hecke mit Holzzaun zur Lane hin, dahinter Obstwiese."""
    wood = mat("zaun", (0.45, 0.30, 0.16), 0.8)
    leaf = ground_mat("hecke", (0.18, 0.34, 0.10), (0.30, 0.46, 0.14), 0.6)
    y = y0
    while y < y1:
        L = random.uniform(1.2, 1.8)
        h = random.uniform(1.9, 2.4)
        rock((1.8, L * 1.15, h), (x + side * 0.4, y + L / 2, h / 2), leaf, rot_z=random.uniform(-0.1, 0.1), round_=0.5)
        y += L * 0.8
    y = y0
    while y < y1:                                                           # Zaun: Pfosten und zwei Latten
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x - side * 1.1, y, 0.6))
        o = bpy.context.object; o.scale = (0.18, 0.18, 1.2); o.data.materials.append(wood)
        y += 2.0
    for z in (0.45, 0.95):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x - side * 1.1, (y0 + y1) / 2, z))
        o = bpy.context.object; o.scale = (0.08, y1 - y0, 0.14); o.data.materials.append(wood)


# ---------------------------------------------------------------- Szene
def lane_ground(cx, y0, y1):
    path = ground_mat("weg", (0.56, 0.42, 0.24), (0.70, 0.56, 0.34), 0.12)
    plane("lane", cx - LANE_HALF, cx + LANE_HALF, y0, y1, 0.01, path)
    for i in range(int((y1 - y0) * 1.2)):                              # einzelne, flache Steinplatten (ausgetretenes Pflaster)
        y = random.uniform(y0, y1)
        xx = cx + random.gauss(0, LANE_HALF * 0.3)
        if abs(xx - cx) < LANE_HALF - 0.8:
            s_ = random.uniform(0.5, 0.9)
            rock((s_, s_ * random.uniform(0.7, 1.1), 0.12), (xx, y, 0.02), stone_mat(), rot_z=random.uniform(0, 3.1), round_=0.35)
    for i in range(int((y1 - y0) * 3)):                                # Gras franst an den Rändern in den Weg
        sx = random.choice((-1, 1))
        place(random.choice(["Grass_Common_Short", "Grass_Wispy_Short"]), (cx + sx * random.uniform(LANE_HALF - 1.2, LANE_HALF), random.uniform(y0, y1), 0), random.uniform(0.8, 1.3))


def meadow(x0, x1, y0, y1, dens=1.0):
    for i in range(int((x1 - x0) * (y1 - y0) * 0.35 * dens)):
        p = (random.uniform(x0, x1), random.uniform(y0, y1), 0)
        r = random.random()
        name = (random.choice(["Grass_Common_Tall", "Grass_Wispy_Tall", "Grass_Common_Short"]) if r < 0.8 else
                random.choice(["Flower_3_Group", "Flower_4_Group", "Clover_1", "Bush_Common_Flowers"]) if r < 0.97 else
                random.choice(["Rock_Medium_1", "Rock_Medium_2", "Pebble_Round_3"]))
        place(name, p, random.uniform(0.9, 1.5))


def build_probe(variant):
    random.seed(4)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    y0, y1 = -30.0, 30.0
    meadow_m = ground_mat("wiese", (0.62, 0.52, 0.16), (0.36, 0.48, 0.12), 0.05)
    plane("boden", -60, 60, y0 - 20, y1 + 20, 0.0, meadow_m)
    lane_ground(0.0, y0, y1)
    wall_l, wall_r = -(LANE_HALF + WALL / 2), LANE_HALF + WALL / 2
    river_x = wall_r + WALL / 2 + RIVER / 2 + 1.0
    water = mat("wasser", (0.12, 0.38, 0.55), 0.08)
    plane("fluss", river_x - RIVER / 2, river_x + RIVER / 2, y0 - 20, y1 + 20, 0.04, water)
    enemy_x = river_x + RIVER / 2 + 1.0 + WALL + LANE_HALF
    lane_ground(enemy_x, y0, y1)
    blue, red = (0.12, 0.25, 0.62), (0.62, 0.14, 0.12)
    if variant == 1:                                                   # hohe Burgmauern mit Türmen und Bannern
        for wx, col in ((wall_l, blue), (wall_r, blue), (enemy_x - LANE_HALF - WALL / 2, red), (enemy_x + LANE_HALF + WALL / 2, red)):
            castle_wall(wx, y0 - 10, y1 + 10)
            for ty in (-14.0, 12.0):
                tower(wx, ty, banner=col)
        meadow(-60, wall_l - WALL, y0 - 15, y1 + 15)
        meadow(wall_r + WALL / 2, river_x - RIVER / 2, y0 - 15, y1 + 15, 1.5)
    elif variant == 2:                                                 # niedrige Feldsteinmauern, Wiese und Bäume dahinter
        for wx in (wall_l, wall_r, enemy_x - LANE_HALF - WALL / 2, enemy_x + LANE_HALF + WALL / 2):
            low_wall(wx, y0 - 10, y1 + 10)
        tower(wall_l - 1.0, -16.0, r=2.4, height=6.0, banner=blue)
        meadow(-60, wall_l - 0.8, y0 - 15, y1 + 15, 1.3)
        meadow(wall_r + 0.8, river_x - RIVER / 2, y0 - 15, y1 + 15, 1.5)
        for i in range(10):
            place(random.choice(["CommonTree_1", "CommonTree_2", "CommonTree_3"]), (random.uniform(-40, wall_l - 3), random.uniform(y0, y1), 0), random.uniform(1.2, 1.7))
    elif variant == 4:                                                 # Felsklippen mit Graskante: die Lane liegt in einer Schlucht
        for wx, sd in ((wall_l, -1), (wall_r, 1), (enemy_x - LANE_HALF - WALL / 2, -1), (enemy_x + LANE_HALF + WALL / 2, 1)):
            cliff(wx, y0 - 10, y1 + 10, sd)
        meadow(-60, wall_l - 2.5, y0 - 15, y1 + 15, 1.0)
        for i in range(8):
            place(random.choice(["CommonTree_1", "CommonTree_3", "Pine_2"]), (random.uniform(-40, wall_l - 4), random.uniform(y0, y1), 0), random.uniform(1.3, 1.8))
    elif variant == 5:                                                 # verfallene, überwachsene Burgruine
        for wx in (wall_l, wall_r, enemy_x - LANE_HALF - WALL / 2, enemy_x + LANE_HALF + WALL / 2):
            ruin(wx, y0 - 10, y1 + 10)
        tower(wall_l - 2.0, 8.0, r=2.4, height=4.5)
        meadow(-60, wall_l - 1.0, y0 - 15, y1 + 15, 1.3)
        meadow(wall_r + 1.0, river_x - RIVER / 2, y0 - 15, y1 + 15, 1.5)
        for i in range(8):
            place(random.choice(["CommonTree_1", "CommonTree_2", "TwistedTree_1"]), (random.uniform(-40, wall_l - 3), random.uniform(y0, y1), 0), random.uniform(1.2, 1.7))
    elif variant == 6:                                                 # Hecken mit Holzzaun, Obstwiese
        for wx, sd in ((wall_l, -1), (wall_r, 1), (enemy_x - LANE_HALF - WALL / 2, -1), (enemy_x + LANE_HALF + WALL / 2, 1)):
            hedge(wx, y0 - 10, y1 + 10, sd)
        meadow(-60, wall_l - 1.5, y0 - 15, y1 + 15, 1.2)
        meadow(wall_r + 1.5, river_x - RIVER / 2, y0 - 15, y1 + 15, 1.5)
        for i in range(12):
            place(random.choice(["CommonTree_2", "CommonTree_5", "CommonTree_1"]), (random.uniform(-40, wall_l - 3), random.uniform(y0, y1), 0), random.uniform(1.0, 1.5))
    else:                                                              # Palisaden und Waldrand, Burg nur an der Basis
        for wx in (wall_l, wall_r, enemy_x - LANE_HALF - WALL / 2, enemy_x + LANE_HALF + WALL / 2):
            palisade(wx, y0 - 10, y1 + 10)
        meadow(-60, wall_l - 0.8, y0 - 15, y1 + 15, 1.0)
        meadow(wall_r + 0.8, river_x - RIVER / 2, y0 - 15, y1 + 15, 1.5)
        for i in range(22):
            place(random.choice(["CommonTree_1", "CommonTree_2", "CommonTree_4", "Pine_2"]), (random.uniform(-38, wall_l - 2), random.uniform(y0 - 10, y1 + 10), 0), random.uniform(1.2, 1.8))
    for i in range(6):                                                 # Bäume am Rand
        place(random.choice(["CommonTree_1", "CommonTree_4", "Pine_1"]), (random.uniform(-55, -35), random.uniform(y0, y1), 0), random.uniform(1.4, 2.0))
    # Held zum Größenvergleich
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HEROES, "Tank.glb"))
    arm = next(o for o in bpy.data.objects if o not in before and o.type == 'ARMATURE')
    if arm.animation_data:
        for t in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(t)
        arm.animation_data.action = next((a for a in bpy.data.actions if a.name.startswith("Idle")), None)
    sc.frame_set(10)
    k = 3.0 / 1.85
    arm.scale = (k, k, k)
    arm.location = (0.5, -2.0, 0)
    arm.rotation_mode = 'XYZ'; arm.rotation_euler.z = math.pi
    # Licht: warme Nachmittagssonne, heller Himmel
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 5.5; sun.data.color = (1.0, 0.86, 0.62); sun.data.angle = math.radians(2)
    sun.rotation_euler = (math.radians(48), 0, math.radians(-55))       # warme Nachmittagssonne von links, lange Schatten
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.sensor_fit = 'VERTICAL'; cam.data.angle = math.radians(45)
    pitch = math.radians(58)
    focus = Vector((2.0, 0.0, 0.0))
    cam.location = focus + Vector((0, -math.cos(pitch) * 28, math.sin(pitch) * 28))
    cam.rotation_euler = (focus - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.eevee.use_shadows = True
    try:
        sc.eevee.use_gtao = True
    except Exception:
        pass
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Punchy'
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900


# ---------------------------------------------------------------- Gesamtkonzept: Wald -> Felder -> Stadt -> Burg
# Koordinaten: Blender y = -Welt-z des Spiels (Basislinie y = 0, Spawn bei y ~ 147). Team A: Lane bei x = 0, Team B bei x = 38,8.
LANE_LEN = 150.0
TEAM_GAP = 28.0
LANE_B = 2 * LANE_HALF + TEAM_GAP
RIVER_X = LANE_B / 2
GATE_Y = 1.5                    # Tor kurz hinter der Durchbruchlinie (leakX = 30 -> 1,5 m)
TOWN = (GATE_Y + 4.0, 52.0)     # Stadtstraße
FIELDS = (52.0, 118.0)          # Felder und Höfe
FOREST = 118.0                  # ab hier Wald (Spawn verdeckt)


def cobble_mat():
    """Kopfsteinpflaster: Voronoi-Zellen als einzelne Steine, dunkle Fugen, jeder Stein etwas anders getönt."""
    m = bpy.data.materials.get("pflaster")
    if m:
        return m
    m = bpy.data.materials.new("pflaster")
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vo = nt.nodes.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 1.6
    vo.feature = 'DISTANCE_TO_EDGE'
    vc = nt.nodes.new("ShaderNodeTexVoronoi"); vc.inputs["Scale"].default_value = 1.6
    nt.links.new(tc.outputs["Object"], vo.inputs["Vector"]); nt.links.new(tc.outputs["Object"], vc.inputs["Vector"])
    edge = nt.nodes.new("ShaderNodeMapRange"); edge.inputs["From Min"].default_value = 0.0; edge.inputs["From Max"].default_value = 0.08
    nt.links.new(vo.outputs["Distance"], edge.inputs["Value"])
    tone = nt.nodes.new("ShaderNodeValToRGB")
    tone.color_ramp.elements[0].color = (0.42, 0.37, 0.31, 1); tone.color_ramp.elements[1].color = (0.66, 0.59, 0.48, 1)
    nt.links.new(vc.outputs["Color"], tone.inputs["Fac"])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'
    mix.inputs[7].default_value = (0.0, 0.0, 0.0, 1)
    nt.links.new(edge.outputs["Result"], mix.inputs["Factor"])
    mix.inputs[6].default_value = (0.2, 0.17, 0.13, 1)
    nt.links.new(tone.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6
    nt.links.new(edge.outputs["Result"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    p.inputs["Roughness"].default_value = 0.9
    return m


def roof_mat(col, name):
    """Dachziegel/Schindeln: waagerechte Reihen (Wellenmuster), leicht versetzt."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wv = nt.nodes.new("ShaderNodeTexWave"); wv.wave_type = 'BANDS'; wv.bands_direction = 'Z'; wv.inputs["Scale"].default_value = 3.0
    wv.inputs["Distortion"].default_value = 1.5
    nt.links.new(tc.outputs["Object"], wv.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (col[0] * 0.55, col[1] * 0.55, col[2] * 0.55, 1); ramp.color_ramp.elements[1].color = (*col, 1)
    nt.links.new(wv.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.8
    return m


HOUSE_STYLES = {
    "A": dict(roof=(0.62, 0.24, 0.13), plaster=(0.86, 0.78, 0.62), beam=(0.28, 0.17, 0.09)),     # Fachwerk, rote Ziegel
    "B": dict(roof=(0.20, 0.25, 0.33), plaster=(0.80, 0.80, 0.76), beam=(0.22, 0.20, 0.18)),     # Steinhaus, Schieferdach
    "farm": dict(roof=(0.72, 0.60, 0.30), plaster=(0.82, 0.74, 0.58), beam=(0.30, 0.19, 0.10)),   # Bauernhof, Strohdach
}


def box(size, loc, m, rot_z=0.0, bev=0.05):
    """Quader als verknüpfte Kopie eines Musterwürfels (schnell, auch bei tausenden Teilen)."""
    return rock(size, loc, m, rot_z, round_=min(0.45, bev / max(0.05, min(size)) * 2) if bev else 0.0)


_SPH = {}


def ball(r, loc, m, sz=(1, 1, 1)):
    """Kugel als verknüpfte Kopie."""
    if m.name not in _SPH:
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        me = bpy.data.meshes.new("kugel"); bm.to_mesh(me); bm.free()
        for f in me.polygons:
            f.use_smooth = True
        me.materials.append(m); _SPH[m.name] = me
    o = bpy.data.objects.new("kugel", _SPH[m.name]); bpy.context.scene.collection.objects.link(o)
    o.location = loc; o.scale = (r * sz[0], r * sz[1], r * sz[2])
    return o


def house(x, y, rot, style="A", w=None, d=None, floors=None):
    """Stadthaus: Steinsockel, Fachwerk-Obergeschoss, Satteldach mit Überstand, Schornstein. Vorderseite zeigt in Richtung rot."""
    st = HOUSE_STYLES[style]
    w = w or random.uniform(3.8, 4.8)
    d = d or random.uniform(4.2, 5.2)
    floors = floors or random.choice([1, 2, 2])
    stone = stone_mat()
    plaster = mat("putz_" + style, st["plaster"], 0.9)
    beam = mat("balken_" + style, st["beam"], 0.8)
    tint = random.choice((0.8, 0.92, 1.0, 1.12))                         # jedes Dach etwas anders getönt
    roof = roof_mat(tuple(min(1.0, c * tint) for c in st["roof"]), "dach_%s_%.2f" % (style, tint))
    R = Matrix.Rotation(rot, 4, 'Z')
    parts = []

    def at(v):
        return Vector((x, y, 0)) + (R @ Vector(v).to_4d()).to_3d()
    h0 = 2.2
    parts.append(box((w, d, h0), at((0, 0, h0 / 2)), stone if style != "farm" else plaster, rot))
    h = h0
    for f in range(floors - 1):
        parts.append(box((w + 0.3, d + 0.3, 2.2), at((0, 0, h + 1.1)), plaster, rot, 0.03))
        for k in range(5):                                             # Fachwerkbalken vorn und hinten
            for sy in (-1, 1):
                parts.append(box((0.16, 0.1, 2.2), at((-w / 2 + k * w / 4, sy * (d / 2 + 0.17), h + 1.1)), beam, rot, 0.0))
        for sy in (-1, 1):
            parts.append(box((w + 0.35, 0.12, 0.18), at((0, sy * (d / 2 + 0.17), h + 0.1)), beam, rot, 0.0))
        h += 2.2
    rh = w * 0.55                                                      # Satteldach (First entlang y)
    bm = bmesh.new()
    ov = 0.3
    pts = [(-w / 2 - ov, -d / 2 - ov, h), (w / 2 + ov, -d / 2 - ov, h), (0, -d / 2 - ov, h + rh),
           (-w / 2 - ov, d / 2 + ov, h), (w / 2 + ov, d / 2 + ov, h), (0, d / 2 + ov, h + rh)]
    vs = [bm.verts.new(p) for p in pts]
    bm.faces.new((vs[0], vs[2], vs[5], vs[3])); bm.faces.new((vs[1], vs[4], vs[5], vs[2]))
    bm.faces.new((vs[0], vs[1], vs[2])); bm.faces.new((vs[3], vs[5], vs[4]))
    me = bpy.data.meshes.new("dach"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("dach", me); bpy.context.scene.collection.objects.link(o)
    me.materials.append(roof)
    so = o.modifiers.new("s", "SOLIDIFY"); so.thickness = 0.25
    o.location = (x, y, 0); o.rotation_euler.z = rot
    parts.append(o)
    gable = mat("giebel_" + style, st["plaster"], 0.9)
    bm = bmesh.new()                                                   # Giebelwände
    for sy in (-1, 1):
        g = [bm.verts.new((-w / 2, sy * d / 2, h)), bm.verts.new((w / 2, sy * d / 2, h)), bm.verts.new((0, sy * d / 2, h + rh - 0.1))]
        bm.faces.new(g)
    me = bpy.data.meshes.new("giebel"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("giebel", me); bpy.context.scene.collection.objects.link(o)
    me.materials.append(gable); o.location = (x, y, 0); o.rotation_euler.z = rot
    if style != "farm" or random.random() < 0.5:
        parts.append(box((0.6, 0.6, 1.6), at((w * 0.25, d * 0.2, h + rh * 0.6)), stone, rot, 0.05))       # Schornstein
    door = mat("tuer", (0.33, 0.2, 0.1), 0.8)
    win = mat("fenster", (0.95, 0.78, 0.42), 0.5, emit=(1.0, 0.75, 0.35), strength=0.6)
    parts.append(box((1.0, 0.12, 1.8), at((0, -d / 2 - 0.05, 0.9)), door, rot, 0.02))
    for sx in (-1, 1):
        parts.append(box((0.7, 0.1, 0.8), at((sx * w * 0.3, -d / 2 - 0.05, 1.4 if floors == 1 else 3.3)), win, rot, 0.02))
    return parts


def fence(x, y0, y1):
    wood = mat("zaun", (0.45, 0.30, 0.16), 0.8)
    y = y0
    while y < y1:
        box((0.18, 0.18, 1.3), (x, y, 0.65), wood, random.uniform(-0.1, 0.1), 0.02)
        y += 2.2
    for z in (0.5, 1.05):
        box((0.08, y1 - y0, 0.13), (x, (y0 + y1) / 2, z), wood, 0.0, 0.0)


def haystack(x, y):
    hay = mat("heu", (0.82, 0.66, 0.30), 0.9)
    ball(1.0, (x, y, 0.9), hay, (1.0, 1.0, 1.1))


def street(cx, y0, y1, kind):
    m = cobble_mat() if kind == "pflaster" else ground_mat("weg", (0.56, 0.42, 0.24), (0.70, 0.56, 0.34), 0.12)
    plane("strasse", cx - LANE_HALF, cx + LANE_HALF, y0, y1, 0.012, m)
    if kind == "pflaster":                                              # Bordsteine
        for sx in (-1, 1):
            y = y0
            while y < y1:
                L = random.uniform(0.8, 1.2)
                rock((0.4, L * 0.95, 0.22), (cx + sx * (LANE_HALF + 0.2), y + L / 2, 0.08), stone_mat(), round_=0.3)
                y += L
    else:
        for i in range(int((y1 - y0) * 2)):
            sx = random.choice((-1, 1))
            place(random.choice(["Grass_Common_Short", "Grass_Wispy_Short"]), (cx + sx * random.uniform(LANE_HALF - 1.0, LANE_HALF), random.uniform(y0, y1), 0), random.uniform(0.8, 1.2))


def quay(x, y0, y1):
    """Kaimauer am Stadtfluss."""
    y = y0
    while y < y1:
        L = random.uniform(1.0, 1.5)
        for r in range(2):
            rock((0.8, L * 0.95, 0.5), (x, y + L / 2 + (0.4 if r else 0), -0.15 + r * 0.45), stone_mat(), round_=0.25)
        y += L


def bridge(x0, x1, y):
    """Steinbrücke mit Bogen über den Fluss."""
    m = stone_mat()
    n = 10
    for i in range(n + 1):
        t = i / n
        xx = x0 + (x1 - x0) * t
        z = 0.4 + math.sin(t * math.pi) * 1.2
        rock(((x1 - x0) / n * 1.05, 3.2, 0.5), (xx, y, z), m, round_=0.2)
        for sy in (-1, 1):
            rock(((x1 - x0) / n * 0.95, 0.35, 0.6), (xx, y + sy * 1.45, z + 0.5), m, round_=0.25)


def pier(x, y, side):
    wood = mat("steg", (0.42, 0.29, 0.17), 0.85)
    box((3.0, 2.0, 0.15), (x + side * 1.5, y, 0.25), wood, 0.0, 0.02)
    for px in (0.3, 2.7):
        for py in (-0.8, 0.8):
            box((0.18, 0.18, 1.2), (x + side * px, y + py, -0.2), wood, 0.0, 0.0)


def castle_gate(cx, y, open_=False, banner=(0.12, 0.25, 0.62)):
    """Burgtor: Torbogen in der Mauer, zwei Tortürme, Holztor (offen oder zu) mit Eisenbeschlägen, Fallgitter oben."""
    m = stone_mat()
    gw = 5.0                                                           # Torbreite
    for sx in (-1, 1):                                                 # Tortürme
        tower(cx + sx * (gw / 2 + 2.6), y, r=2.6, height=9.0, banner=banner)
    for r in range(int(8.5 / 0.55)):                                   # Mauer über dem Tor
        z = r * 0.55 + 0.27
        if z < 5.2:
            continue
        rock((gw + 0.5, 2.6, 0.52), (cx, y, z), m, round_=0.15)
    n = 9
    for i in range(n + 1):                                             # Torbogen
        a = math.pi * i / n
        rock((0.8, 2.8, 0.6), (cx - math.cos(a) * gw / 2, y, 4.0 + math.sin(a) * 1.3), m, rot_z=0, round_=0.2)
    wood = mat("torholz", (0.40, 0.24, 0.12), 0.8)
    iron = mat("eisen", (0.18, 0.18, 0.2), 0.5, 0.8)
    for sx in (-1, 1):                                                 # zwei Torflügel
        hinge = Vector((cx + sx * gw / 2, y - 0.9, 0))
        ang = (sx * 1.35) if open_ else 0.0
        R = Matrix.Rotation(-ang, 4, 'Z')
        for k in range(4):
            off = (R @ Vector((-sx * (0.33 + k * 0.62), 0, 0, 1))).to_3d()
            box((0.6, 0.25, 4.6), hinge + off + Vector((0, 0, 2.3)), wood, -ang, 0.03)
        for z in (1.0, 3.4):
            off = (R @ Vector((-sx * gw / 4, -0.15, 0, 1))).to_3d()
            box((gw / 2 - 0.1, 0.08, 0.2), hinge + off + Vector((0, 0, z)), iron, -ang, 0.0)
    for i in range(7):                                                 # Fallgitter (hochgezogen)
        box((0.12, 0.12, 2.0), (cx - gw / 2 + 0.5 + i * (gw - 1.0) / 6, y + 0.6, 5.5), iron, 0.0, 0.0)


def keep(x, y, style="A"):
    """Bergfried: großer, eckiger Turm im Burghof, Zinnen, Spitzdach."""
    m = stone_mat()
    w = 7.0
    for r in range(int(12 / 0.6)):
        z = r * 0.6 + 0.3
        off = (r % 2) * 0.6
        for side in range(4):
            a = side * math.pi / 2
            n = 8
            for i in range(n):
                t = -w / 2 + (i + 0.5 + off / 1.2) * w / n
                if t > w / 2:
                    continue
                v = Vector((t, -w / 2, 0)); v.rotate(Matrix.Rotation(a, 3, 'Z'))
                rock((w / n * 0.96, 0.6, 0.57), (x + v.x, y + v.y, z), m, rot_z=a, round_=0.2)
    box((w - 1.0, w - 1.0, 12), (x, y, 6), m, 0.0, 0.0)
    roof = roof_mat(HOUSE_STYLES[style]["roof"], "dach_" + style)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=w * 0.78, depth=6.0, location=(x, y, 12 + 3.0), rotation=(0, 0, math.pi / 4))
    bpy.context.object.data.materials.append(roof)


def market_stall(x, y, col):
    wood = mat("standholz", (0.42, 0.28, 0.15), 0.8)
    cloth = mat("markise_%s" % str(col), col, 0.9)
    box((3.0, 1.6, 0.9), (x, y, 0.45), wood, 0.0, 0.03)
    for px in (-1.4, 1.4):
        for py in (-0.7, 0.7):
            box((0.12, 0.12, 2.6), (x + px, y + py, 1.3), wood, 0.0, 0.0)
    o = box((3.4, 2.0, 0.12), (x, y, 2.6), cloth, 0.0, 0.02); o.rotation_euler.x = 0.25
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.6, location=(x - 0.8, y - 0.3, 1.2))
    bpy.context.object.data.materials.append(mat("fass", (0.45, 0.3, 0.16), 0.8))


# ---------------------------------------------------------------- Bausätze (Quaternius Medieval Village + Fantasy Props, Source)
_VMOD = None
_HOUSES = {}
PROPS = os.path.join(ROOT, "tools-extern", "assets", "quaternius-props-src", "Exports", "glTF")
_PROP = {}


def _village():
    global _VMOD
    if _VMOD is None:
        import types
        src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "make_village.py")
        mod = types.ModuleType("make_village")
        mod.__file__ = src
        code = open(src, encoding="utf-8").read()
        exec(code[:code.rindex("if __name__ ==")], mod.__dict__)
        _VMOD = mod
    return _VMOD


def house_size(kind):
    """Grundriss (Breite x, Tiefe y) eines Paket-Hauses, Vorderseite nach -y."""
    V = _village()
    if not _HOUSES:
        _HOUSES.update(V.groups(V.parse_tscn(V.SCENE)))
    key = "_c_" + kind
    if key not in _HOUSES:
        objs = V.build(_HOUSES[kind], "tmp")
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), 0))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), 0))
        _HOUSES[key] = ((lo + hi) / 2, hi - lo)
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    return _HOUSES[key]


def vhouse(kind, x, y, rot, s=1.0, sz=1.0):
    """Haus aus der Beispielszene des Dorfpakets (House C, House C2, Houses A, Houses D, Tower); Vorderseite zeigt nach -y, gedreht um rot.
    Mitte des Grundrisses auf (x, y). Rückgabe: Grundriss (Breite, Tiefe) vor dem Drehen."""
    V = _village()
    c, size = house_size(kind)
    M = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rot, 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Diagonal((1.0, 1.0, sz, 1.0)) @ Matrix.Translation(-c)
    for res, Mg in _HOUSES[kind]:
        Mb = V.C @ Mg @ V.C.inverted()
        for me, mw in V.piece(res):
            o = bpy.data.objects.new(kind, me)
            bpy.context.scene.collection.objects.link(o)
            o.matrix_world = M @ Mb @ mw
    return size * s


def prop(name, x, y, rot=None, s=1.0, z=0.0):
    """Requisite aus dem Fantasy Props MegaKit (verknüpfte Kopie)."""
    if name not in _PROP:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(PROPS, name + ".gltf"))
        new = [o for o in bpy.data.objects if o not in before]
        _PROP[name] = [(o.data, o.matrix_world.copy()) for o in new if o.type == 'MESH']
        for o in new:
            bpy.data.objects.remove(o, do_unlink=True)
    rot = random.uniform(0, math.tau) if rot is None else rot
    M = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, 'Z') @ Matrix.Scale(s, 4)
    for me, mw in _PROP[name]:
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        o.matrix_world = M @ mw


def vpiece(name, x, y, rot, s=1.0, z=0.0, sx=1.0, sy=1.0, sz=1.0):
    """Einzelteil aus dem Dorfpaket (z. B. Prop_WoodenFence_Extension1). sx/sy/sz: Streckung (lokal)."""
    V = _village()
    M = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, 'Z') @ Matrix.Scale(s, 4) @ Matrix.Diagonal((sx, sy, sz, 1.0))
    for me, mw in V.piece(name + ".gltf"):
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        o.matrix_world = M @ mw


def kit_fence(x, y0, y1, rot):
    """Holzzaun aus dem Dorfpaket entlang der Lane."""
    y = y0
    while y < y1:
        vpiece("Prop_WoodenFence_Extension1" if random.random() < 0.8 else "Prop_WoodenFence_Extension2", x, y, rot)
        y += 2.0


def town_row(cx, sx, team, y0, y1):
    """Häuserzeile an der Stadtstraße: Paket-Häuser mit Vorderseite zur Straße, Lücken mit Baum, Fässern, Kisten, Karren."""
    rot = -math.pi / 2 if sx < 0 else math.pi / 2
    riverside = (team == 0 and sx > 0) or (team == 1 and sx < 0)
    y = y0
    while y < y1:
        if riverside and 25 < y < 35:                                   # Platz für die Brücke
            y += 10.0
            continue
        if random.random() < 0.25:
            place(random.choice(["CommonTree_1", "CommonTree_4"]), (cx + sx * (LANE_HALF + 5.0), y + 2.5, 0), random.uniform(0.9, 1.2))
            for k in range(3):
                prop(random.choice(["Barrel", "Crate_Wooden", "Barrel_Holder", "Bucket_Wooden_1", "Bench"]),
                     cx + sx * (LANE_HALF + random.uniform(1.0, 2.5)), y + random.uniform(0.5, 4.5), None, 1.2)
            if random.random() < 0.5:
                prop("Stall_Cart_Empty", cx + sx * (LANE_HALF + 3.0), y + 2.5, rot, 1.2)
            y += 5.5
            continue
        kind = random.choice(["House C", "House C2", "Houses D", "Houses D"])
        c, size = house_size(kind)
        if riverside and size.y > 11.0:
            kind = "Houses D"
            c, size = house_size(kind)
        if y + size.x > y1 + 2:
            break
        vhouse(kind, cx + sx * (LANE_HALF + 0.8 + size.y / 2), y + size.x / 2, rot)
        y += size.x + random.uniform(0.5, 2.0)
        if random.random() < 0.5:
            prop("Lantern_Wall", cx + sx * (LANE_HALF + 0.5), y - 1.0, rot, 1.2, 2.6)


def kit_wall_segment(x, y, rot, tiers=2, depth=2.4):
    """2 m Burgmauer aus Paket-Wänden: Außen- und Innenschale, oben Wehrgang-Pflaster und Zinnen."""
    R = Matrix.Rotation(rot, 4, 'Z')
    for t in range(tiers):
        for side in (1, -1):                                          # Schale nach +y (außen) und -y (innen), Ziegelseite nach außen
            off = (R @ Vector((0, side * depth / 2, 0, 1))).to_3d()
            vpiece("Wall_UnevenBrick_Straight", x + off.x, y + off.y, rot + (0 if side < 0 else math.pi), 1.0, z=t * 3.12)
    top = tiers * 3.12
    off = Vector((0, 0, 0))
    vpiece("Floor_UnevenBrick", x, y, rot, 1.0, z=top, sy=depth / 2.0)
    for side in (1, -1):                                              # Zinnen: halbe Wandstücke
        off = (R @ Vector((0.5, side * depth / 2, 0, 1))).to_3d()
        vpiece("Wall_UnevenBrick_Straight", x + off.x, y + off.y, rot + (0 if side < 0 else math.pi), 1.0, z=top, sx=0.5, sz=0.35)


def castle_kit(cx, y, open_=False, banner=(0.12, 0.25, 0.62), half=17.0, keep_x=-11.0):
    """Burg an der Basis: Mauer quer über die Lane aus Paket-Teilen, Tortürme und Ecktürme (Turm aus der Beispielszene),
    Torbogen über der Lane mit Holztor, Banner an den Tortürmen."""
    gate_half = 3.0
    xs = []
    x = cx - half
    while x < cx + half - 0.1:
        if abs(x + 1.0 - cx) > gate_half + 3.5:                     # Lücke für Tor und Tortürme
            kit_wall_segment(x + 1.0, y, 0.0)
        x += 2.0
    tw = house_size("Tower")[1]
    for sx in (-1, 1):
        vhouse("Tower", cx + sx * (gate_half + 3.0), y, 0.0, 0.85, 0.55)  # Tortürme (niedriger, verdecken die Lane nicht)
        vhouse("Tower", cx + sx * (half + 1.0), y, 0.0, 0.85, 0.5)       # Ecktürme
        bpy.ops.mesh.primitive_cube_add(size=1, location=(cx + sx * (gate_half + 3.0) - sx * 0.0, y - 3.4, 6.0))
        b = bpy.context.object; b.scale = (1.4, 0.05, 4.5); b.data.materials.append(mat("banner_%s" % str(banner), banner, 0.8))
    for k, xx in enumerate((cx - gate_half + 1.0, cx + gate_half - 1.0)):     # Torbogen (Paket-Bogen, vergrößert) innen und außen
        pass
    for side in (1, -1):
        vpiece("Wall_Arch", cx, y + side * 1.2, 0.0 if side < 0 else math.pi, 1.0, sx=gate_half / 1.0, sz=2.1)
    for t in range(2):                                                # Mauer über dem Bogen
        pass
    vpiece("Floor_UnevenBrick", cx, y, 0.0, 1.0, z=6.3, sx=gate_half, sy=1.2)
    for sx in (-1, 1):
        for side in (1, -1):
            vpiece("Wall_UnevenBrick_Straight", cx + sx * 1.5, y + side * 1.2, 0.0 if side < 0 else math.pi, 1.0, z=6.3, sx=0.75, sz=0.35)
    wood = mat("torholz", (0.40, 0.24, 0.12), 0.8)
    iron = mat("eisen", (0.18, 0.18, 0.2), 0.5, 0.8)
    for sx in (-1, 1):                                                 # zwei Torflügel
        hinge = Vector((cx + sx * gate_half, y - 0.6, 0))
        ang = (sx * 1.35) if open_ else 0.0
        Rg = Matrix.Rotation(-ang, 4, 'Z')
        for k in range(5):
            off = (Rg @ Vector((-sx * (0.3 + k * 0.6), 0, 0, 1))).to_3d()
            box((0.58, 0.25, 5.4), hinge + off + Vector((0, 0, 2.7)), wood, -ang, 0.03)
        for z in (1.2, 4.0):
            off = (Rg @ Vector((-sx * gate_half / 2, -0.15, 0, 1))).to_3d()
            box((gate_half - 0.1, 0.08, 0.22), hinge + off + Vector((0, 0, z)), iron, -ang, 0.0)
    vhouse("Tower", cx + keep_x * 1.3, y - 14.0, 0.0, 1.1, 0.7)       # Bergfried hinten seitlich im Hof


_TINT = {}


def place_tinted(name, loc, s, hue, sat, val, yaw=None):
    """Naturmodell mit umgefärbtem Material (z. B. Gras golden als Weizen); Mesh-Kopie einmal je Farbe."""
    key = (name, hue, sat, val)
    if key not in _TINT:
        out = []
        for src in nature(name):
            me = src.data.copy()
            for i, m in enumerate(me.materials):
                if m is None:
                    continue
                m2 = m.copy()
                nt = m2.node_tree
                p = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
                if p is not None:
                    link = next((l for l in nt.links if l.to_socket == p.inputs["Base Color"]), None)
                    hs = nt.nodes.new("ShaderNodeHueSaturation")
                    hs.inputs["Hue"].default_value = hue; hs.inputs["Saturation"].default_value = sat; hs.inputs["Value"].default_value = val
                    if link:
                        nt.links.new(link.from_socket, hs.inputs["Color"])
                    else:
                        hs.inputs["Color"].default_value = p.inputs["Base Color"].default_value
                    nt.links.new(hs.outputs["Color"], p.inputs["Base Color"])
                me.materials[i] = m2
            out.append((me, src))
        _TINT[key] = out
    for me, src in _TINT[key]:
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        o.location = Vector(loc) + src.location * s
        o.rotation_euler = (src.rotation_euler.x, src.rotation_euler.y, random.uniform(0, math.tau) if yaw is None else yaw)
        o.scale = Vector(src.scale) * s


def field(x0, x1, y0, y1, kind):
    """Acker mit Furchen: Weizen (goldenes, dichtes Gras), Gemüsebeete (Lauch, Karotten, Rettich aus dem Requisitenpaket) oder Brache."""
    soil = mat("acker", (0.36, 0.25, 0.14), 0.95)
    plane("acker", x0, x1, y0, y1, 0.02, soil)
    dark = mat("furche", (0.26, 0.18, 0.10), 0.95)
    n = int((x1 - x0) / 0.9)
    for i in range(n):                                               # Furchen
        box((0.35, y1 - y0 - 0.4, 0.12), (x0 + 0.45 + i * 0.9, (y0 + y1) / 2, 0.06), dark, 0.0, 0.05)
    if kind == "brache":
        return
    if kind == "weizen":
        for i in range(n):
            y = y0 + 0.4
            while y < y1 - 0.4:
                place_tinted(random.choice(["Grass_Wispy_Tall", "Grass_Common_Tall"]), (x0 + 0.45 + i * 0.9 + random.uniform(-0.15, 0.15), y, 0),
                             random.uniform(1.1, 1.4), 0.43, 0.9, 1.25)
                y += random.uniform(0.45, 0.65)
    else:
        veg = random.choice(["Leek", "Carrot", "Radish"])
        for i in range(n):
            y = y0 + 0.5
            while y < y1 - 0.4:
                prop(veg, x0 + 0.45 + i * 0.9, y, None, 2.2, 0.05)
                y += 0.7


def build_concept(style="A", gate_open=False):
    random.seed(7)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    meadow_m = ground_mat("wiese", (0.62, 0.52, 0.16), (0.36, 0.48, 0.12), 0.05)
    plane("boden", -80, LANE_B + 80, -40, LANE_LEN + 40, 0.0, meadow_m)
    water = mat("wasser", (0.10, 0.36, 0.52), 0.06)
    plane("fluss", RIVER_X - RIVER / 2, RIVER_X + RIVER / 2, -40, LANE_LEN + 40, -0.25, water)
    for sx in (-1, 1):
        quay(RIVER_X + sx * (RIVER / 2 + 0.3), -20, TOWN[1])
    bridge(RIVER_X - RIVER / 2 - 1.5, RIVER_X + RIVER / 2 + 1.5, 30.0)
    pier(RIVER_X - RIVER / 2 - 0.2, 14.0, 1)
    pier(RIVER_X + RIVER / 2 + 0.2, 44.0, -1)
    for team, cx, ban in ((0, 0.0, (0.12, 0.25, 0.62)), (1, LANE_B, (0.62, 0.14, 0.12))):
        street(cx, TOWN[0] - 6, TOWN[1], "pflaster")
        street(cx, TOWN[1], LANE_LEN + 10, "weg")
        # Burg: Mauer quer, Tor auf der Lane, Hof dahinter mit Bergfried und Marktständen
        castle_kit(cx, GATE_Y, gate_open, ban, keep_x=-11.0 if team == 0 else 11.0)
        for i, st_ in enumerate(("Stall_Blacksmith", "Stall_Vegetables_Full", "Stall_Potions")):
            prop(st_, cx - 5.5 + i * 4.5, -4.5, 0.0, 1.3)
        for i in range(6):
            prop(random.choice(["Barrel", "Crate_Wooden", "Barrel_Apples", "FarmCrate_Apple", "Bag"]), cx + random.uniform(-9, 9), random.uniform(-12, -7), None, 1.3)
        prop("Wagon", cx + 5.0, -11.0, 0.4, 1.3)
        plane("hof", cx - 15, cx + 15, -16, GATE_Y - 1.2, 0.011, cobble_mat())
        # Stadt: Häuserreihen beidseits der Straße (im Wandbereich und dahinter)
        for sx in (-1, 1):
            town_row(cx, sx, team, TOWN[0] + 1.0, TOWN[1] - 4)
        # Felder: Zaun an der Lane, Äcker, Höfe, Heu
        for sx in (-1, 1):
            kit_fence(cx + sx * (LANE_HALF + 0.4), FIELDS[0], FIELDS[1], math.pi / 2)
            y = FIELDS[0] + 2
            while y < FIELDS[1] - 6:
                L = random.uniform(10, 16)
                field(cx + sx * (LANE_HALF + 1.5) if sx > 0 else cx - LANE_HALF - 13.5, cx + LANE_HALF + 13.5 if sx > 0 else cx - LANE_HALF - 1.5,
                      y, min(y + L, FIELDS[1] - 2), random.choice(["weizen", "weizen", "kohl", "brache"]))
                y += L + 2.0
            fy = random.uniform(70, 100)
            vhouse("Houses D", cx + sx * (LANE_HALF + 22), fy, random.choice((0, math.pi / 2, math.pi)))
            for k in range(4):
                prop(random.choice(["FarmCrate_Apple", "FarmCrate_Carrot", "FarmCrate_Radish", "Barrel", "Bucket_Wooden_2"]), cx + sx * (LANE_HALF + 16 + random.uniform(0, 3)), fy + random.uniform(-4, 4), None, 1.2)
            prop("Wagon", cx + sx * (LANE_HALF + 17), fy + 7, random.uniform(0, 3), 1.2)
            haystack(cx + sx * (LANE_HALF + 17), random.uniform(60, 110))
        # Wald am Spawn: dichte Baumkronen über dem Wegende
        for i in range(140):
            tx = cx + random.uniform(-22, 22)
            ty = random.uniform(FOREST, LANE_LEN + 20)
            if abs(tx - cx) < LANE_HALF and ty < FOREST + 12:
                continue
            place(random.choice(["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "Pine_1", "Pine_3"]), (tx, ty, 0), random.uniform(1.1, 1.5))
    # Wiese außen und zwischen den Höfen
    meadow(-50, -LANE_HALF - 15, 40, 120, 0.4)
    # Licht
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 5.5; sun.data.color = (1.0, 0.86, 0.62); sun.data.angle = math.radians(2)
    sun.rotation_euler = (math.radians(48), 0, math.radians(-55))
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Punchy'
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.sensor_fit = 'VERTICAL'; cam.data.angle = math.radians(45)
    return cam


def put_hero(x, y):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HEROES, "Tank.glb"))
    arm = next(o for o in bpy.data.objects if o not in before and o.type == 'ARMATURE')
    if arm.animation_data:
        for t in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(t)
        arm.animation_data.action = next((a for a in bpy.data.actions if a.name.startswith("Idle")), None)
    k = 3.0 / 1.85
    arm.scale = (k, k, k); arm.location = (x, y, 0)
    arm.rotation_mode = 'XYZ'; arm.rotation_euler.z = math.pi


def shoot(cam, out, focus, dist=28.0, pitch=58.0, yaw=0.0):
    p = math.radians(pitch)
    off = Vector((0, -math.cos(p) * dist, math.sin(p) * dist))
    off.rotate(Matrix.Rotation(math.radians(yaw), 3, 'Z'))
    cam.location = Vector(focus) + off
    cam.rotation_euler = (Vector(focus) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.frame_set(10)
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


def concept(outdir, style="A"):
    cam = build_concept(style, gate_open=False)
    put_hero(0.5, 22.0)
    os.makedirs(outdir, exist_ok=True)
    shoot(cam, os.path.join(outdir, "%s_uebersicht.png" % style), (RIVER_X, 60.0, 0), dist=150.0, pitch=50.0, yaw=-20.0)
    shoot(cam, os.path.join(outdir, "%s_burg.png" % style), (1.0, -1.0, 0), dist=34.0)
    shoot(cam, os.path.join(outdir, "%s_stadt.png" % style), (3.0, 24.0, 0))
    shoot(cam, os.path.join(outdir, "%s_felder.png" % style), (3.0, 85.0, 0))
    shoot(cam, os.path.join(outdir, "%s_wald.png" % style), (3.0, 125.0, 0))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "probe":
        build_probe(int(argv[2]) if len(argv) > 2 else 1)
        bpy.context.scene.render.filepath = argv[1]
        bpy.ops.render.render(write_still=True)
    elif argv and argv[0] == "konzept":
        concept(argv[1], argv[2] if len(argv) > 2 else "A")
