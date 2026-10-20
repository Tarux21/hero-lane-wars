# Häuser aus dem Medieval Village MegaKit (Quaternius, Source): liest die Beispielszene des Pakets (Godot .tscn),
# setzt die Häuser Stück für Stück in Blender zusammen und speichert sie als Vorlagen (GLB) für die Burgkarte.
#   blender -b -P make_village.py -- show <bild.png>            (alle Häuser der Beispielszene nebeneinander)
#   blender -b -P make_village.py -- export <ordner>             (je Haus eine GLB-Datei)
# Godot ist y-oben, Blender z-oben: Godot (x, y, z) -> Blender (x, -z, y).
import bpy, sys, os, re, math
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
VSRC = os.path.join(ROOT, "tools-extern", "assets", "quaternius-village-src")
ADDON = os.path.join(VSRC, "godot", "Godot")
SCENE = os.path.join(ADDON, "addons", "quaternius", "medievalvillagemegakit", "L_SampleScene_1.tscn")
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))     # Godot -> Blender


def parse_tscn(path):
    txt = open(path, encoding="utf-8").read()
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource type="PackedScene"[^\]]*path="res://([^"]+)" id="([^"]+)"\]', txt)}
    nodes = []
    for blk in re.split(r'\n(?=\[node )', txt):
        m = re.match(r'\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]*)")?(?: instance=ExtResource\("([^"]+)"\))?', blk)
        if not m:
            continue
        name, typ, parent, inst = m.groups()
        t = re.search(r'transform = Transform3D\(([^)]+)\)', blk)
        M = Matrix.Identity(4)
        if t:
            v = [float(x) for x in t.group(1).split(",")]
            M = Matrix(((v[0], v[1], v[2], v[9]), (v[3], v[4], v[5], v[10]), (v[6], v[7], v[8], v[11]), (0, 0, 0, 1)))
        nodes.append(dict(name=name, type=typ, parent=parent, inst=ext.get(inst) if inst else None, M=M))
    return nodes


_PIECES = {}


def piece(res_path):
    """Bauteil einmal importieren (Objekte versteckt), danach verknüpfte Kopien."""
    if res_path in _PIECES:
        return _PIECES[res_path]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(VSRC, "glTF", os.path.basename(res_path)))     # Exportordner: Texturen liegen daneben
    new = [o for o in bpy.data.objects if o not in before]
    meshes = []
    for o in new:
        if o.type == 'MESH':
            meshes.append((o.data, o.matrix_world.copy()))
        bpy.data.objects.remove(o, do_unlink=True)
    _PIECES[res_path] = meshes
    return meshes


def groups(nodes):
    """Direkte Kinder der Wurzel mit eigenen Bauteilen = ein Haus/Turm. Ergebnis: {Gruppe: [(Pfad, Godot-Matrix relativ zur Gruppe)]}"""
    by = {}
    for n in nodes:
        if n["parent"] is None:
            continue
        path = n["name"] if n["parent"] == "." else n["parent"] + "/" + n["name"]
        n["path"] = path
        by[path] = n
    out = {}
    for n in nodes:
        if n["parent"] is None or not n["inst"]:
            continue
        chain = []
        p = n["parent"]
        M = n["M"]
        while p and p != ".":
            g = by.get(p)
            if g is None:
                break
            chain.append(p)
            if "/" not in p:
                break
            M = g["M"] @ M
            p = g["parent"]
        top = chain[-1] if chain else None
        if top is None:
            continue
        out.setdefault(top, []).append((n["inst"], M))
    return out


def build(group_items, name, at=Vector()):
    objs = []
    for res, M in group_items:
        Mb = C @ M @ C.inverted()
        for me, mw in piece(res):
            o = bpy.data.objects.new(name, me)
            bpy.context.scene.collection.objects.link(o)
            o.matrix_world = Matrix.Translation(at) @ Mb @ mw
            objs.append(o)
    return objs


def show(out):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    gs = groups(parse_tscn(SCENE))
    x = 0.0
    for gname, items in sorted(gs.items()):
        objs = build(items, gname)
        bpy.context.view_layer.update()
        xs = [(o.matrix_world @ Vector(c)).x for o in objs for c in o.bound_box]
        ys = [(o.matrix_world @ Vector(c)).y for o in objs for c in o.bound_box]
        dx = x - min(xs)
        cy = (min(ys) + max(ys)) / 2
        for o in objs:
            o.location += Vector((dx, -cy, 0))
        print("GRUPPE", gname, len(items), "Breite %.1f Tiefe %.1f" % (max(xs) - min(xs), max(ys) - min(ys)))
        x += max(xs) - min(xs) + 3.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 4.5; sun.data.color = (1.0, 0.88, 0.7); sun.rotation_euler = (math.radians(50), 0, math.radians(-40))
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(x / 2, 0, 0))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 30
    cam.location = (x / 2, -x * 0.75, x * 0.55)
    cam.rotation_euler = (Vector((x / 2, 0, 3)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.view_settings.view_transform = 'AgX'
    sc.render.resolution_x, sc.render.resolution_y = 1800, 800
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "show":
        show(argv[1])
