# Bauteile der Burgkarte für Godot: alles nach godot/assets/burg/ (glTF mit gemeinsamen Texturen im selben Ordner).
#   blender -b -P make_burg_assets.py -- [nature] [props] [houses] [castle]     (ohne Angabe: alles)
# Quellen (gekauft, CC0, in tools-extern/assets, nicht im Repo): Quaternius Stylized Nature / Medieval Village / Fantasy Props MegaKit [Source].
# Texturen werden verkleinert (Farbe 1024 px, Normal/Rauheit/ORM 512 px): von oben aus der Spielkamera reicht das.
import bpy, sys, os, re, math, shutil
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
A = os.path.join(ROOT, "tools-extern", "assets")
NAT = os.path.join(A, "quaternius-nature-src", "glTF")
PROPS = os.path.join(A, "quaternius-props-src", "Exports", "glTF")
VIL = os.path.join(A, "quaternius-village-src", "glTF")
OUT = os.path.join(ROOT, "godot", "assets", "burg")

NATURE = ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5", "Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5",
          "GiantPine_1", "GiantPine_2", "GiantPine_3", "Birch_1", "Birch_2", "Birch_3", "TwistedTree_1", "TwistedTree_3",
          "Bush_Common", "Bush_Common_Flowers", "Bush_Large", "Bush_Large_Flowers", "Bush_Long_1",
          "Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Short", "Grass_Wispy_Tall", "Grass_Wide_Short", "Grass_Wheat",
          "Flower_1_Group", "Flower_2_Group", "Flower_3_Group", "Flower_4_Group", "Flower_7_Group", "Clover_1", "Fern_1", "Plant_1",
          "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Rock_Big_1", "Pebble_Round_1", "Pebble_Round_3", "Mushroom_Common"]
PROP_LIST = ["Barrel", "Barrel_Apples", "Barrel_Holder", "Crate_Wooden", "Bag", "Bench", "Bucket_Wooden_1", "Bucket_Wooden_2",
             "Stall_Blacksmith", "Stall_Vegetables_Full", "Stall_Potions", "Stall_Cart_Empty", "Stall_Empty", "Wagon", "Lantern_Wall", "Torch_Metal",
             "Banner_1", "Banner_2", "Banner_Vertical_1", "Banner_Vertical_2", "Banner_SmallTriangles_Long", "FarmCrate_Apple", "FarmCrate_Carrot",
             "FarmCrate_Radish", "FarmCrate_Empty", "Leek", "Carrot", "Radish", "Anvil", "WeaponStand", "Sign_Pub", "Sign_Blacksmith", "Sign_Potions",
             "Table_Large", "Stool", "CampfireTripod", "FirePit", "Pot_1", "Cauldron", "Dummy", "Ladder", "Rope_1",
             "Anvil_Log", "Bellows", "Hammer_Rack", "Workbench", "Workbench_Vice", "Bucket_Metal", "Pouch_Large", "FarmCrate_GreenApples", "Shield_Metal", "Shield_Wooden", "Sword_Steel", "Axe_Steel", "Whetstone", "Chain_Coil"]
SMALL = ("normal", "rough", "orm")


def _texsize(name):
    return 512 if any(k in name.lower() for k in SMALL) else 1024


def copy_tex(src_dir, name):
    """Textur verkleinert nach OUT kopieren (einmal)."""
    dst = os.path.join(OUT, name)
    if os.path.exists(dst):
        return
    img = bpy.data.images.load(os.path.join(src_dir, name))
    w, h = img.size
    t = _texsize(name)
    if w > t:
        img.scale(t, int(h * t / w))
    img.filepath_raw = dst
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)


def copy_gltf(src_dir, name):
    """glTF + bin unverändert kopieren, Texturen verkleinert dazu."""
    txt = open(os.path.join(src_dir, name + ".gltf"), encoding="utf-8").read()
    for b in set(re.findall(r'"uri"\s*:\s*"([^"]+\.bin)"', txt)):
        shutil.copyfile(os.path.join(src_dir, b), os.path.join(OUT, b))
    for t in set(re.findall(r'"uri"\s*:\s*"([^"]+\.png)"', txt)):
        copy_tex(src_dir, t)
    open(os.path.join(OUT, name + ".gltf"), "w", encoding="utf-8").write(txt)


# ---------------------------------------------------------------- Häuser und Burg (aus dem Dorfpaket zusammengesetzt)
def _village():
    import types
    src = os.path.join(HERE, "make_village.py")
    mod = types.ModuleType("make_village")
    mod.__file__ = src
    code = open(src, encoding="utf-8").read()
    exec(code[:code.rindex("if __name__ ==")], mod.__dict__)
    return mod


def _export_joined(objs, name, center=True):
    """Objekte zu einem Mesh verbinden (Mitte des Grundrisses auf 0, Boden auf 0) und als glTF mit Texturen im Ordner speichern."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.data = o.data.copy()
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    if center:
        vs = [v.co for v in o.data.vertices]
        c = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / 2, (min(v.y for v in vs) + max(v.y for v in vs)) / 2, 0))
        o.data.transform(Matrix.Translation(-c))
    for img in bpy.data.images:                                        # Texturen klein halten
        if img.size[0] > _texsize(img.name):
            img.scale(_texsize(img.name), int(img.size[1] * _texsize(img.name) / img.size[0]))
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".gltf"), export_format='GLTF_SEPARATE', use_selection=True,
                              export_texture_dir="", export_yup=True, export_apply=True)
    bpy.data.objects.remove(o, do_unlink=True)
    print("EXPORT", name)


def houses():
    V = _village()
    gs = V.groups(V.parse_tscn(V.SCENE))
    for kind, items in gs.items():
        objs = V.build(items, kind)
        _export_joined(objs, "Haus_" + kind.replace(" ", "_"))


def _pieces(V, specs):
    """specs: [(Teil, Matrix)] -> Objekte"""
    objs = []
    for res, M in specs:
        for me, mw in V.piece(res + ".gltf"):
            o = bpy.data.objects.new(res, me)
            bpy.context.scene.collection.objects.link(o)
            o.matrix_world = M @ mw
            objs.append(o)
    return objs


def castle():
    """Burgmauer-Stück (2 m, zwei Stockwerke, Wehrgang, Zinnen), Torbau (Bogen 6 m breit) und Torflügel."""
    V = _village()
    T = lambda x, y, z=0.0, rot=0.0, sx=1.0, sy=1.0, sz=1.0: Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, 'Z') @ Matrix.Diagonal((sx, sy, sz, 1.0))
    depth = 2.4
    # Mauer (entlang x, Außenseite +y = zur Lane)
    sp = []
    for t in range(2):
        sp.append(("Wall_UnevenBrick_Straight", T(0, -depth / 2, t * 3.12)))
        sp.append(("Wall_UnevenBrick_Straight", T(0, depth / 2, t * 3.12, math.pi)))
    sp.append(("Floor_UnevenBrick", T(0, 0, 6.24, 0, 1, depth / 2)))
    for side in (-1, 1):
        sp.append(("Wall_UnevenBrick_Straight", T(0.5, side * depth / 2, 6.24, 0 if side < 0 else math.pi, 0.5, 1, 0.35)))
    _export_joined(_pieces(V, sp), "Burg_Mauer")
    # Torbau: Bogen über 6 m, Mauer darüber, Wehrgang
    gh = 3.0
    sp = []
    for side in (-1, 1):
        sp.append(("Wall_Arch", T(0, side * 1.2, 0, 0 if side < 0 else math.pi, gh, 1, 2.1)))
        for sx in (-1, 1):
            sp.append(("Wall_UnevenBrick_Straight", T(sx * 1.5, side * 1.2, 6.3, 0 if side < 0 else math.pi, 0.75, 1, 0.35)))
    sp.append(("Floor_UnevenBrick", T(0, 0, 6.3, 0, gh, 1.2)))
    _export_joined(_pieces(V, sp), "Burg_Torbau")
    # Torflügel (3 m breit, 5,4 m hoch), Drehpunkt an der Angel (x = 0), Flügel reicht nach +x
    wood = bpy.data.materials.new("Torholz"); wood.use_nodes = True
    wood.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.40, 0.24, 0.12, 1)
    iron = bpy.data.materials.new("Eisen"); iron.use_nodes = True
    p = iron.node_tree.nodes["Principled BSDF"]; p.inputs["Base Color"].default_value = (0.18, 0.18, 0.2, 1); p.inputs["Metallic"].default_value = 0.8
    for variant, broken in (("Burg_Tor", False), ("Burg_Tor_kaputt", True)):
        objs = []
        for k in range(5):
            h = 5.4 if not broken else [5.4, 3.6, 4.6, 2.2, 4.9][k]
            bpy.ops.mesh.primitive_cube_add(size=1, location=(0.3 + k * 0.6, 0, h / 2))
            o = bpy.context.object; o.scale = (0.57, 0.25, h)
            if broken:
                o.rotation_euler.y = [0.0, 0.05, -0.04, 0.12, 0.02][k]
            b = o.modifiers.new("b", "BEVEL"); b.width = 0.04; b.segments = 2
            o.data.materials.append(wood); objs.append(o)
        for z in (1.2, 4.0):
            if broken and z > 3.0:
                continue
            bpy.ops.mesh.primitive_cube_add(size=1, location=(1.5, -0.15, z))
            o = bpy.context.object; o.scale = (2.9, 0.08, 0.22); o.data.materials.append(iron); objs.append(o)
        bpy.context.view_layer.update()
        for o in objs:
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier="b") if o.modifiers else None
        _export_joined(objs, variant, center=False)


def _vmat(V, piece_name, contains):
    """Material eines Dorfpaket-Teils (z. B. Stein-, Holztextur) für eigene Formen."""
    for me, mw in V.piece(piece_name + ".gltf"):
        for m in me.materials:
            if m and contains.lower() in m.name.lower():
                return m
    return me.materials[0]


def extras():
    """Burgbrunnen (Heilbrunnen im Hof) und Unterstand der Schmiede (Holzpfosten, Bretterdach aus dem Dorfpaket)."""
    V = _village()
    stone = _vmat(V, "Wall_UnevenBrick_Straight", "brick")
    wood = _vmat(V, "Prop_Support", "")
    objs = []
    # Brunnen: achteckiges Steinbecken, Wasser, Mittelsäule mit Schale
    walls = []
    for k in range(8):                                                 # Beckenrand aus 8 Mauerstücken mit Abdeckplatte
        a = (k + 0.5) / 8 * math.tau
        L = 2 * 2.2 * math.tan(math.pi / 8) + 0.05
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 2.2, math.sin(a) * 2.2, 0.36))
        o = bpy.context.object; o.scale = (0.4, L, 0.72); o.rotation_euler.z = a; walls.append(o)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 2.2, math.sin(a) * 2.2, 0.78))
        o = bpy.context.object; o.scale = (0.58, L + 0.12, 0.14); o.rotation_euler.z = a; walls.append(o)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.32, depth=1.8, location=(0, 0, 0.9))
    col = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.25, radius2=0.85, depth=0.35, location=(0, 0, 1.95))
    bowl = bpy.context.object
    for o in walls + [col, bowl]:
        o.data.materials.append(stone)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.cube_project(cube_size=3.0); bpy.ops.object.mode_set(mode='OBJECT')
        objs.append(o)
    water = bpy.data.materials.new("Wasser"); water.use_nodes = True
    p = water.node_tree.nodes["Principled BSDF"]; p.inputs["Base Color"].default_value = (0.05, 0.22, 0.34, 1); p.inputs["Roughness"].default_value = 0.35; p.inputs["Emission Color"].default_value = (0.06, 0.25, 0.32, 1); p.inputs["Emission Strength"].default_value = 0.6
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=2.05, depth=0.05, location=(0, 0, 0.55))
    w1 = bpy.context.object; w1.data.materials.append(water); objs.append(w1)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.8, depth=0.04, location=(0, 0, 2.08))
    w2 = bpy.context.object; w2.data.materials.append(water); objs.append(w2)
    _export_joined(objs, "Brunnen", center=False)
    # Unterstand: 6,8 m breit, 3,4 m tief; hinten 3,4 m hoch, vorn 2,6 m (Pultdach fällt nach vorn = -y)
    objs = []
    for x in (-3.0, 0.0, 3.0):
        for y, h in ((0.0, 3.3), (-3.0, 2.5)):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, h / 2))
            o = bpy.context.object; o.scale = (0.22, 0.22, h); o.data.materials.append(wood); objs.append(o)
    for y, h in ((0.0, 3.3), (-3.0, 2.5)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, y, h - 0.1))
        o = bpy.context.object; o.scale = (6.6, 0.2, 0.22); o.data.materials.append(wood); objs.append(o)
    M = lambda x: Matrix.Translation((x, 0.35, 2.35)) @ Matrix.Rotation(-0.06, 4, 'X') @ Matrix.Diagonal((1.0, 2.6, 1.0, 1.0))
    for x in (-2.25, 0.0, 2.25):
        objs += _pieces(V, [("Roof_Wooden_2x1", M(x))])
    for o in objs:
        bpy.context.view_layer.objects.active = o
        if o.type == 'MESH' and not o.data.uv_layers:
            bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.uv.cube_project(cube_size=2.0); bpy.ops.object.mode_set(mode='OBJECT')
    _export_joined(objs, "Unterstand", center=False)


def nature():
    for n in NATURE:
        copy_gltf(NAT, n)
    for t in ("Noise_Wind.png",):
        copy_tex(NAT, t)
    print("EXPORT natur", len(NATURE))


def props():
    for n in PROP_LIST:
        copy_gltf(PROPS, n)
    for n in ("Prop_WoodenFence_Extension1", "Prop_WoodenFence_Extension2", "Prop_WoodenFence_Single", "Prop_Wagon", "Prop_Crate", "Prop_Chimney"):
        copy_gltf(VIL, n)
    print("EXPORT props", len(PROP_LIST))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    os.makedirs(OUT, exist_ok=True)
    todo = argv or ["nature", "props", "houses", "castle"]
    for step in todo:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        {"nature": nature, "props": props, "houses": houses, "castle": castle, "extras": extras}[step]()
