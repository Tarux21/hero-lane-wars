# Helden im neuen Stil: Quaternius-Heldenkörper (Superhelden-Proportionen, gemeinsames Skelett) + Outfit als Grundkleidung
# + eigene Rüstungsteile + KayKit-Waffen.
# Blender 4.2 headless:
#   blender -b -P make_heroes.py -- preview <bild.png> [tank_v1 tank_v2 tank_v3]     (Vorschaubild, Helden nebeneinander in Pose)
# Rüstungsteile hängen starr an Knochen (Bone-Parent), damit sie mit jeder Animation des gemeinsamen Skeletts mitgehen.
import bpy, bmesh, sys, math, os
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
A = os.path.join(ROOT, "tools-extern", "assets")
BASE = os.path.join(A, "quaternius-base", "Universal Base Characters[Standard]")
BODY = os.path.join(BASE, "Base Characters", "Godot - UE", "Superhero_Male_FullBody.gltf")
HAIR = os.path.join(BASE, "Hairstyles", "Rigged to Head Bone", "glTF (Godot -Unreal)")
OUTFIT = os.path.join(A, "quaternius-outfits-src", "Modular Character Outfits - Fantasy[Source]", "Exports", "glTF (Godot-Unreal)", "Outfits")
UAL2 = os.path.join(A, "quaternius-anim", "Universal Animation Library 2 [Standard]", "Unreal-Godot", "UAL2_Standard.glb")
KK = os.path.join(A, "kaykit-adventurers", "KayKit-Character-Pack-Adventures-1.0-main", "addons", "kaykit_character_pack_adventures", "Assets", "gltf")


# ---------------------------------------------------------------- Materialien
def mat(name, col, metal=0.0, rough=0.6, emit=None):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = 3.0
    return m


def tint(obj, col):
    """Färbt eine texturierte Outfit-Fläche um (Textur × Farbe), ohne die Textur zu verlieren."""
    for slot in obj.material_slots:
        m = slot.material.copy(); slot.material = m
        nt = m.node_tree
        p = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        link = next((l for l in nt.links if l.to_socket == p.inputs["Base Color"]), None)
        if link is None:
            p.inputs["Base Color"].default_value = (*col, 1)
            continue
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[7].default_value = (*col, 1)
        nt.links.new(link.from_socket, mix.inputs[6])
        nt.links.new(mix.outputs[2], p.inputs["Base Color"])


# ---------------------------------------------------------------- Formen (rund, stilisiert)
def _finish(o, m, sub=2):
    if sub > 0:
        s = o.modifiers.new("sub", "SUBSURF"); s.levels = sub; s.render_levels = sub
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    return o


def shell(name, loc, size, m, cut_z=None, cut_y=None, rot=(0, 0, 0), thick=0.035, sub=1):
    """Gewölbte Platte: Kugel, abgeschnitten (unten und/oder hinten), mit Dicke – Grundform für Panzer, Schultern, Helme."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=14, radius=1, location=(0, 0, 0))
    o = bpy.context.object; o.name = name
    bm = bmesh.new(); bm.from_mesh(o.data)
    kill = [v for v in bm.verts if (cut_z is not None and v.co.z < cut_z) or (cut_y is not None and v.co.y > cut_y)]
    bmesh.ops.delete(bm, geom=kill, context='VERTS')
    bm.to_mesh(o.data); bm.free()
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    so = o.modifiers.new("solid", "SOLIDIFY"); so.thickness = thick; so.offset = 1.0
    o.rotation_euler = rot; o.location = loc
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(o, m, sub)


def box(name, loc, size, m, rot=(0, 0, 0), sub=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    b = o.modifiers.new("bev", "BEVEL"); b.width = min(size) * 0.25; b.segments = 2
    return _finish(o, m, sub)


def ring(name, loc, r, minor, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=minor, location=loc, rotation=rot, major_segments=32, minor_segments=8)
    o = bpy.context.object; o.name = name
    return _finish(o, m, 0)


def attach(o, arm, bone):
    mw = o.matrix_world.copy()
    o.parent = arm; o.parent_type = 'BONE'; o.parent_bone = bone
    o.matrix_world = mw
    return o


# ---------------------------------------------------------------- Figur: Körper (nur Kopf) + Outfit + Haare
def _import(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def _rebind(objs, arm):
    """Skinned Meshes eines zweiten Imports auf unser Skelett umhängen und dessen Skelett löschen."""
    names = [o.name for o in objs]
    for n in names:
        if n.startswith("Icosphere"):
            bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
    objs = [bpy.data.objects[n] for n in names if n in bpy.data.objects]
    for o in [o for o in objs if o.type == 'MESH']:
        o.parent = arm
        for md in o.modifiers:
            if md.type == 'ARMATURE':
                md.object = arm
    for o in [o for o in objs if o.type == 'ARMATURE']:
        bpy.data.objects.remove(o, do_unlink=True)


def load_figure(outfit, hair=None, outfit_tint=None):
    new = _import(BODY)
    arm = [o for o in new if o.type == 'ARMATURE'][0]
    for o in new:
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    body = max((o for o in arm.children if o.type == "MESH"), key=lambda o: len(o.data.vertices))   # Körper = größtes Mesh (Mann und Frau)
    bm = bmesh.new(); bm.from_mesh(body.data)                      # Körper unter dem Hals weg: das Outfit trägt den Rest
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (body.matrix_world @ v.co).z < 1.5 or abs((body.matrix_world @ v.co).x) > 0.105], context='VERTS')
    bm.to_mesh(body.data); bm.free()
    out = _import(os.path.join(OUTFIT, outfit + ".gltf"))
    keep = [o.name for o in out if not o.name.startswith("Icosphere") and o.type == 'MESH']
    _rebind(out, arm)
    if outfit_tint:
        for o in [bpy.data.objects[n] for n in keep]:
            if True:
                tint(o, outfit_tint)
    if hair:
        _rebind(_import(os.path.join(HAIR, hair + ".gltf")), arm)
    return arm


def bone_head(arm, name):
    return arm.matrix_world @ arm.data.bones[name].head_local


def weapon(arm, file, bone, scale, loc, rot):
    new = _import(os.path.join(KK, file))
    w = [o for o in new if o.parent is None][0]
    w.scale = (scale,) * 3; w.rotation_euler = rot; w.location = loc
    bpy.context.view_layer.update()
    return attach(w, arm, bone)


# ---------------------------------------------------------------- Angepasste Rüstung: aus der Outfit-Form ausgeschnitten
def mesh_of(arm, key):
    return next(o for o in arm.children if o.type == 'MESH' and key in o.name)


def metal(name, col, rough=0.3, var=0.12):
    """Gebürsteter Stahl/Gold: Farbe und Rauheit leicht verrauscht (Gebrauchsspuren), damit es nicht wie Plastik wirkt."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = mat(name, col, 0.9, rough)
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = 38.0
    n.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (col[0] * (1 - var * 2), col[1] * (1 - var * 2), col[2] * (1 - var * 2), 1)
    ramp.color_ramp.elements[1].color = (min(1, col[0] * (1 + var)), min(1, col[1] * (1 + var)), min(1, col[2] * (1 + var)), 1)
    nt.links.new(n.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    r = nt.nodes.new("ShaderNodeMapRange")
    r.inputs["To Min"].default_value = rough * 0.6
    r.inputs["To Max"].default_value = rough * 1.6
    nt.links.new(n.outputs["Fac"], r.inputs["Value"])
    nt.links.new(r.outputs["Result"], p.inputs["Roughness"])
    return m


def plate(arm, src, name, keep, m, off=0.02, thick=0.018, rim=None, grow=1.0, flat=10, rivets=0, ridge=0.0, bevel=0.004):
    """Schneidet aus einem Outfit-/Körper-Mesh die Flächen aus, für die keep(p) (Weltposition) wahr ist; glättet Stofffalten weg
    (flat), schiebt die Fläche entlang der Normalen nach außen (off), gibt ihr Dicke mit Kante im rim-Material, setzt Nieten
    an die Kante (rivets = jede n-te Kanten-Ecke) und optional einen Mittelgrat (ridge). Die Platte behält die Skin-Gewichte
    und verformt sich mit jeder Animation des gemeinsamen Skeletts."""
    o = src.copy()
    o.data = src.data.copy()
    o.name = name
    bpy.context.scene.collection.objects.link(o)
    for md in list(o.modifiers):
        o.modifiers.remove(md)
    o.data.materials.clear()
    o.data.materials.append(m)
    o.data.materials.append(rim or m)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    mw = o.matrix_world
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep(mw @ f.calc_center_median())], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    for f in bm.faces:
        f.material_index = 0
    inner = [v for v in bm.verts if not v.is_boundary]
    edge = [v for v in bm.verts if v.is_boundary]
    for _ in range(flat):                                              # Stofffalten weg: glatte Metallfläche
        bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    for _ in range(3):
        bmesh.ops.smooth_vert(bm, verts=edge, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        push = off
        if ridge > 0:                                                  # Mittelgrat über die Körpermitte
            push += ridge * max(0.0, 1.0 - abs((mw @ v.co).x) / 0.035)
        v.co += v.normal * push
    if grow != 1.0 and bm.verts:
        c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        for v in bm.verts:
            v.co = c + (v.co - c) * grow
    rim_pts = [(v.co.copy(), v.normal.copy(), dict(v[bm.verts.layers.deform.active]) if bm.verts.layers.deform.active else {}) for v in edge] if rivets else []
    bm.to_mesh(o.data)
    bm.free()
    so = o.modifiers.new("solid", "SOLIDIFY")
    so.thickness = thick
    so.offset = 1.0
    so.use_rim = True
    so.material_offset_rim = 1
    if bevel:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = 'ANGLE'
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    for p in o.data.polygons:
        p.use_smooth = True
    if rim_pts:                                                        # Nieten an der Außenkante, Abstand mind. rivets cm
        bm = bmesh.new()
        bm.from_mesh(o.data)
        dl = bm.verts.layers.deform.verify()
        placed = []
        for co, nrm, wts in sorted(rim_pts, key=lambda t: (round(t[0].z, 2), t[0].x)):
            if any((co - q).length < rivets * 0.01 for q in placed):
                continue
            placed.append(co)
            r = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.0065)
            for nv in r["verts"]:
                nv.co = nv.co + co + nrm * (thick * 0.6)
                for g, w in wts.items():
                    nv[dl][g] = w
            for f in {f for nv in r["verts"] for f in nv.link_faces}:
                f.material_index = 1
                f.smooth = True
        bm.to_mesh(o.data)
        bm.free()
    o.parent = arm
    am = o.modifiers.new("arm", "ARMATURE")
    am.object = arm
    return o


def band(lo, hi, axis=2):
    return lambda p: lo <= p[axis] <= hi


# ---------------------------------------------------------------- Eigene Waffen (passend zum Figurenstil)
def _join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    return o


def _prim(kind, mat_, **kw):
    getattr(bpy.ops.mesh, "primitive_" + kind + "_add")(**kw)
    o = bpy.context.object
    o.data.materials.append(mat_)
    return o


def longsword(arm, steel, gold, leather):
    """Langschwert: Klinge mit Spitze und dünnen Schneiden, Parierstange mit Kugelenden, Ledergriff, Knauf.
    In der T-Pose zeigt die Klinge vom rechten Arm weg (-X): bei hängendem Arm zeigt sie nach unten, die breite Seite nach vorn."""
    hx, hy, hz = -0.745, 0.065, 1.456
    L = 0.84
    bl = _prim("cube", steel, size=1, location=(hx - 0.12 - L / 2, hy, hz))
    bl.scale = (L, 0.012, 0.055)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=6)
    bpy.ops.object.mode_set(mode='OBJECT')
    for v in bl.data.vertices:
        t = (hx - 0.12 - v.co.x) / L                                   # 0 an der Parierstange, 1 an der Spitze
        if t > 0.82:
            v.co.z = hz + (v.co.z - hz) * max(0.05, (1 - t) / 0.18)
        if abs(v.co.z - hz) > 0.02:                                     # Schneiden dünn
            v.co.y = hy + (v.co.y - hy) * 0.3
    parts = [bl, _prim("cube", gold, size=1, location=(hx - 0.1, hy, hz))]
    parts[-1].scale = (0.035, 0.035, 0.24)
    for s_ in (-1, 1):
        parts.append(_prim("uv_sphere", gold, radius=0.025, location=(hx - 0.1, hy, hz + s_ * 0.12)))
    parts.append(_prim("cylinder", leather, radius=0.018, depth=0.18, location=(hx, hy, hz), rotation=(0, math.pi / 2, 0)))
    parts.append(_prim("uv_sphere", gold, radius=0.03, location=(hx + 0.1, hy, hz)))
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(scale=True, rotation=True)
    s = _join(parts, "longsword")
    b = s.modifiers.new("bev", "BEVEL")
    b.width = 0.003
    b.segments = 2
    bpy.context.view_layer.objects.active = s
    bpy.ops.object.modifier_apply(modifier="bev")
    for p in s.data.polygons:
        p.use_smooth = True
    return attach(s, arm, "hand_r")


def heater_shield(arm, steel, gold, cloth, round_=False):
    """Wappenschild am linken Unterarm. In der T-Pose liegt er flach über dem Arm (Vorderseite +Z, Spitze Richtung Hand),
    bei hängendem Arm zeigt er dadurch nach außen. Teamfarbe, Goldrand, Buckel, Querstreifen."""
    cx, cy, cz = 0.6, 0.065, 1.53
    if round_:
        pts = [(math.cos(k / 32 * math.tau) * 0.3, math.sin(k / 32 * math.tau) * 0.3) for k in range(32)]
    else:
        pts = [(-0.24, 0.19), (-0.24, -0.19)]
        for k in range(1, 12):
            t = k / 12
            pts.append((-0.24 + 0.5 * t, -0.19 * math.cos(t * math.pi / 2) ** 0.8))
        pts.append((0.27, 0.0))
        for k in range(11, 0, -1):
            t = k / 12
            pts.append((-0.24 + 0.5 * t, 0.19 * math.cos(t * math.pi / 2) ** 0.8))
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new((cx + x, cy + y, cz)) for x, y in pts])
    ins = bmesh.ops.inset_region(bm, faces=[face], thickness=0.035, depth=0.0)
    for f in bm.faces:
        f.material_index = 0 if f in [face] else 1
    for v in bm.verts:                                                 # leicht gewölbt
        d = ((v.co.x - cx) ** 2 + (v.co.y - cy) ** 2) ** 0.5
        v.co.z += 0.05 - d * 0.12
    me = bpy.data.meshes.new("shield")
    bm.to_mesh(me)
    bm.free()
    sh = bpy.data.objects.new("shield", me)
    bpy.context.scene.collection.objects.link(sh)
    me.materials.append(cloth)
    me.materials.append(gold)
    so = sh.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.03
    so.use_rim = True
    so.material_offset_rim = 1
    b = sh.modifiers.new("bev", "BEVEL")
    b.width = 0.006
    b.segments = 2
    bpy.context.view_layer.objects.active = sh
    for md in list(sh.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    boss = _prim("uv_sphere", steel, radius=0.07, location=(cx - 0.02, cy, cz + 0.07))
    boss.scale.z = 0.5
    st = _prim("cube", gold, size=1, location=(cx + 0.02, cy, cz + 0.056))
    st.scale = (0.34, 0.04, 0.01)
    for o in (boss, st):
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(scale=True)
    s = _join([sh, boss, st], "shield")
    for p in s.data.polygons:
        p.use_smooth = True
    bpy.context.scene.cursor.location = (cx, cy, 1.456)                 # um die Unterarm-Achse 40° nach vorn kippen
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    s.rotation_euler = (math.radians(-40), 0, 0)
    bpy.ops.object.transform_apply(rotation=True)
    bpy.context.scene.cursor.location = (0, 0, 0)
    return attach(s, arm, "lowerarm_l")


# ---------------------------------------------------------------- Tank (Ritter, Variante v2 des Projektleiters)
def chainmail(obj, col=(0.3, 0.32, 0.36), hands_leather=False):
    """Kettenhemd: Stoff des Outfits wird zu feinem Metallgeflecht (Farbe, Metall, feine Ring-Struktur als Relief)."""
    for slot in obj.material_slots:
        m = slot.material.copy(); slot.material = m
        nt = m.node_tree
        p = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        for l in [l for l in nt.links if l.to_socket in (p.inputs["Base Color"], p.inputs["Normal"])]:
            nt.links.remove(l)
        tc = nt.nodes.new("ShaderNodeTexCoord")
        vo = nt.nodes.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 260.0
        vo.feature = 'DISTANCE_TO_EDGE'
        nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
        bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6; bump.inputs["Distance"].default_value = 0.002
        nt.links.new(vo.outputs["Distance"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (col[0] * 0.35, col[1] * 0.35, col[2] * 0.35, 1)
        ramp.color_ramp.elements[1].position = 0.12
        ramp.color_ramp.elements[1].color = (*col, 1)
        nt.links.new(vo.outputs["Distance"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
        p.inputs["Metallic"].default_value = 0.85
        if hands_leather:                                              # Hände (|x| > 0.66 in der T-Pose) als Lederhandschuhe
            sep = nt.nodes.new("ShaderNodeSeparateXYZ")
            nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
            ab = nt.nodes.new("ShaderNodeMath"); ab.operation = 'ABSOLUTE'
            nt.links.new(sep.outputs["X"], ab.inputs[0])
            gt = nt.nodes.new("ShaderNodeMath"); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.66
            nt.links.new(ab.outputs[0], gt.inputs[0])
            mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = 'RGBA'
            nt.links.new(gt.outputs[0], mx.inputs["Factor"])
            nt.links.new(ramp.outputs["Color"], mx.inputs[6])
            mx.inputs[7].default_value = (0.22, 0.13, 0.07, 1)
            nt.links.new(mx.outputs[2], p.inputs["Base Color"])
            mm = nt.nodes.new("ShaderNodeMapRange"); mm.inputs["To Min"].default_value = 0.85; mm.inputs["To Max"].default_value = 0.0
            nt.links.new(gt.outputs[0], mm.inputs["Value"])
            nt.links.new(mm.outputs["Result"], p.inputs["Metallic"])
        p.inputs["Roughness"].default_value = 0.45


def cape(arm, cloth, gold, top=1.47, bottom=0.52, w_top=0.42, w_bot=0.62, back=0.13):
    """Umhang von den Schultern bis zu den Knien: Gitter mit Faltenwurf, hinten am Oberkörper (starr am Rückenknochen),
    unten weiter und etwas vom Körper weg. Goldsaum unten."""
    nx, nz = 18, 22
    bm = bmesh.new()
    rows = []
    for j in range(nz + 1):
        t = j / nz
        z = top + (bottom - top) * t
        w = w_top + (w_bot - w_top) * t
        row = []
        for i in range(nx + 1):
            u = i / nx - 0.5
            x = u * w
            y = back + 0.05 * t + 0.09 * (1 - (2 * u) ** 2) * (0.35 + 0.65 * t) + 0.025 * math.sin(u * math.tau * 3.5) * t ** 1.5
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for j in range(nz):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    me = bpy.data.meshes.new("cape"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("cape", me); bpy.context.scene.collection.objects.link(o)
    me.materials.append(cloth); me.materials.append(gold)
    so = o.modifiers.new("solid", "SOLIDIFY"); so.thickness = 0.012; so.use_rim = True; so.material_offset_rim = 1
    sub = o.modifiers.new("sub", "SUBSURF"); sub.levels = 1
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    for p in me.polygons:
        p.use_smooth = True
    for b in (box("clasp_l", Vector((0.17, -0.02, 1.47)), (0.05, 0.02, 0.05), gold), box("clasp_r", Vector((-0.17, -0.02, 1.47)), (0.05, 0.02, 0.05), gold)):
        attach(b, arm, "spine_03")
    return attach(o, arm, "spine_03")


def fist(arm, side="r", curl=1.25):
    """Finger zur Faust schließen (um den Schwertgriff)."""
    for pb in arm.pose.bones:
        n = pb.name
        if n.endswith("_" + side) and any(k in n for k in ("index", "middle", "ring", "pinky")) and "leaf" not in n:
            pb.rotation_mode = 'XYZ'
            pb.rotation_euler = (0, 0, curl if side == "r" else -curl)
        if n.endswith("_" + side) and "thumb" in n and "leaf" not in n:
            pb.rotation_mode = 'XYZ'
            pb.rotation_euler = (0, 0, 0.5 if side == "r" else -0.5)


def _radius(src, a, b, t):
    """Mittlerer Abstand der Mesh-Punkte zur Knochenachse a->b an der Stelle t (0..1) – Grundlage für passende Schienen."""
    mw = src.matrix_world
    d = (b - a).normalized()
    L = (b - a).length
    rs = []
    for v in src.data.vertices:
        p = mw @ v.co
        h = (p - a).dot(d)
        r = ((p - a) - d * h).length
        if abs(h - L * t) < L * 0.06 and r < 0.16:
            rs.append(r)
    rs.sort()
    return rs[len(rs) // 2] if rs else 0.06


def limb_plate(arm, src, bone, t0, t1, m, rim, extra=0.012, arc=220, front=Vector((0, -1, 0)), flare=0.0, thick=0.008, name=None):
    """Saubere, gebogene Schiene um einen Knochenabschnitt (t0..t1): Radius aus dem Körper gemessen + extra, Bogen arc Grad
    um die Vorderseite front, unten optional aufgeweitet (flare), Goldkante, starr am Knochen."""
    bn = arm.data.bones[bone]
    a = arm.matrix_world @ bn.head_local
    b = arm.matrix_world @ bn.tail_local
    d = (b - a).normalized()
    side = front - d * front.dot(d)
    side.normalize()
    up = d.cross(side)
    nr, na = 10, 24
    bm = bmesh.new()
    rows = []
    for j in range(nr + 1):
        t = t0 + (t1 - t0) * j / nr
        r = _radius(src, a, b, t) + extra + flare * (j / nr) ** 2
        c = a.lerp(b, t)
        row = []
        for i in range(na + 1):
            ang = math.radians(-arc / 2 + arc * i / na)
            row.append(bm.verts.new(c + (side * math.cos(ang) + up * math.sin(ang)) * r))
        rows.append(row)
    for j in range(nr):
        for i in range(na):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    bm.normal_update()
    for f in bm.faces:                                                  # Normalen nach außen (weg von der Knochenachse)
        c = f.calc_center_median()
        radial = (c - a) - d * (c - a).dot(d)
        if f.normal.dot(radial) < 0:
            f.normal_flip()
    me = bpy.data.meshes.new(name or bone)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name or ("plate_" + bone), me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(m)
    me.materials.append(rim)
    so = o.modifiers.new("solid", "SOLIDIFY")
    so.thickness = thick
    so.use_rim = True
    so.material_offset_rim = 1
    so.offset = 1.0
    bv = o.modifiers.new("bev", "BEVEL")
    bv.width = 0.002
    bv.segments = 2
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    for pg in me.polygons:
        pg.use_smooth = True
    return attach(o, arm, bone)


def panel(arm, bone, top, bottom, w_top, w_bot, y, m, rim, sway=0.0, name="panel"):
    """Stoffbahn (Wappenrock vorn): von top bis bottom, leicht gewölbt, Goldsaum, starr am Knochen."""
    nx, nz = 10, 14
    bm = bmesh.new()
    rows = []
    for j in range(nz + 1):
        t = j / nz
        z = top + (bottom - top) * t
        w = w_top + (w_bot - w_top) * t
        rows.append([bm.verts.new(((i / nx - 0.5) * w, y - 0.045 * (1 - (2 * (i / nx - 0.5)) ** 2) - sway * t * t + 0.008 * math.sin((i / nx) * math.tau * 2) * t, z)) for i in range(nx + 1)])
    for j in range(nz):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(m)
    me.materials.append(rim)
    so = o.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.008
    so.use_rim = True
    so.material_offset_rim = 1
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    for pg in me.polygons:
        pg.use_smooth = True
    return attach(o, arm, bone)


def belt(arm, body, z, m, gold):
    """Gürtel als sauberer Ring, Breite und Tiefe am Körper gemessen."""
    mw = body.matrix_world
    pts = [mw @ v.co for v in body.data.vertices if abs((mw @ v.co).z - z) < 0.02]
    rx = max(abs(p.x) for p in pts) + 0.012
    ry = (max(p.y for p in pts) - min(p.y for p in pts)) / 2 + 0.012
    cy = (max(p.y for p in pts) + min(p.y for p in pts)) / 2
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=1, depth=0.05, location=(0, cy, z), end_fill_type='NOTHING')
    o = bpy.context.object
    o.name = "belt"
    o.scale = (rx, ry, 1)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    so = o.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.01
    bpy.ops.object.modifier_apply(modifier="solid")
    for pg in o.data.polygons:
        pg.use_smooth = True
    attach(o, arm, "pelvis")
    attach(box("buckle", Vector((0, cy - ry - 0.008, z)), (0.06, 0.012, 0.045), gold), arm, "pelvis")
    return o


# ---------------------------------------------------------------- Abgetastete Formen: Panzer und Helm passen genau, saubere Kanten
from mathutils import kdtree


def skin_from(o, srcs):
    """Skin-Gewichte vom nächstgelegenen Punkt der Quell-Meshes übernehmen (Platte biegt sich mit dem Körper)."""
    pts = []
    for src in srcs:
        mw = src.matrix_world
        for v in src.data.vertices:
            pts.append((mw @ v.co, src, v))
    kd = kdtree.KDTree(len(pts))
    for i, (p, _, _) in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    groups = {}
    mw = o.matrix_world
    for v in o.data.vertices:
        _, i, _ = kd.find(mw @ v.co)
        _, src, sv = pts[i]
        for g in sv.groups:
            name = src.vertex_groups[g.group].name
            if name not in groups:
                groups[name] = o.vertex_groups.new(name=name)
            groups[name].add([v.index], g.weight, 'REPLACE')
    o.parent = None
    o.parent = bpy.data.objects[srcs[0].parent.name]
    am = o.modifiers.new("arm", "ARMATURE")
    am.object = srcs[0].parent
    return o


def _grid_mesh(name, grid, m, rim, thick, closed_u=False, sub=1, bevel=0.002):
    """Gitter (Liste von Zeilen mit Punkten) -> Fläche mit Dicke, Goldkante, weich."""
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in row] for row in grid]
    nu = len(rows[0])
    for j in range(len(rows) - 1):
        for i in range(nu - (0 if closed_u else 1)):
            i2 = (i + 1) % nu
            bm.faces.new((rows[j][i], rows[j][i2], rows[j + 1][i2], rows[j + 1][i]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(m)
    me.materials.append(rim)
    if sub:
        sm = o.modifiers.new("sub", "SUBSURF"); sm.levels = sub
    so = o.modifiers.new("solid", "SOLIDIFY"); so.thickness = thick; so.use_rim = True; so.material_offset_rim = 1; so.offset = 1.0
    if bevel:
        bv = o.modifiers.new("bev", "BEVEL"); bv.width = bevel; bv.segments = 2; bv.limit_method = 'ANGLE'
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    for pg in me.polygons:
        pg.use_smooth = True
    return o


def _smooth_grid(r, iters=4, wrap=False):
    nz, na = len(r), len(r[0])
    for _ in range(iters):
        n = [row[:] for row in r]
        for j in range(nz):
            for i in range(na):
                acc, c = r[j][i] * 2, 2
                for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    jj, ii = j + dj, i + di
                    if wrap:
                        ii %= na
                    if 0 <= jj < nz and 0 <= ii < na:
                        acc += r[jj][ii]; c += 1
                n[j][i] = acc / c
        r = n
    return r


def torso_shell(srcs, z0, z1, a0, a1, off, nz=16, na=28, top_cut=None):
    """Tastet den Rumpf zylindrisch ab (Winkel 0 = vorn/-Y, Höhe z) und gibt ein glattes Gitter knapp darüber zurück.
    top_cut(a) -> maximale Höhe am Winkel a (Halsausschnitt, Armöffnungen)."""
    pts = []
    for src in srcs:
        mw = src.matrix_world
        pts += [mw @ v.co for v in src.data.vertices]
    cy = sum(p.y for p in pts if z0 <= p.z <= z1) / max(1, len([p for p in pts if z0 <= p.z <= z1]))
    r = [[0.0] * na for _ in range(nz)]
    for p in pts:
        if not (z0 - 0.03 <= p.z <= z1 + 0.03):
            continue
        a = math.degrees(math.atan2(p.x, -(p.y - cy)))
        if a1 > 180 and a < a0:
            a += 360
        j = round((p.z - z0) / (z1 - z0) * (nz - 1))
        i = round((a - a0) / (a1 - a0) * (na - 1))
        if 0 <= j < nz and 0 <= i < na:
            r[j][i] = max(r[j][i], math.hypot(p.x, p.y - cy))
    for j in range(nz):                                                 # Lücken füllen
        for i in range(na):
            if r[j][i] == 0.0:
                cand = [r[j][k] for k in range(na) if r[j][k] > 0]
                r[j][i] = sum(cand) / len(cand) if cand else 0.15
    r = _smooth_grid(r, 6)
    grid = []
    for j in range(nz):
        z = z0 + (z1 - z0) * j / (nz - 1)
        row = []
        for i in range(na):
            a = a0 + (a1 - a0) * i / (na - 1)
            zz = min(z, top_cut(a)) if top_cut else z
            rr = r[j][i] + off
            row.append(Vector((math.sin(math.radians(a)) * rr, cy - math.cos(math.radians(a)) * rr, zz)))
        grid.append(row)
    return grid


def head_shell(head, center, el0, el1, az0, az1, off, nel=14, naz=30, max_r=1.0):
    """Tastet den Kopf kugelförmig ab (Azimut 0 = vorn, Elevation in Grad) und gibt ein glattes Gitter knapp darüber zurück."""
    mw = head.matrix_world
    r = [[0.0] * naz for _ in range(nel)]
    for v in head.data.vertices:
        p = mw @ v.co - center
        rr = p.length
        if rr < 1e-4 or rr > max_r:
            continue
        el = math.degrees(math.asin(max(-1, min(1, p.z / rr))))
        az = math.degrees(math.atan2(p.x, -p.y))
        j = round((el - el0) / (el1 - el0) * (nel - 1))
        i = round((az - az0) / (az1 - az0) * (naz - 1))
        if 0 <= j < nel and 0 <= i < naz:
            r[j][i] = max(r[j][i], rr)
    for j in range(nel):
        cand = [x for x in r[j] if x > 0]
        for i in range(naz):
            if r[j][i] == 0:
                r[j][i] = sum(cand) / len(cand) if cand else 0.11
    r = _smooth_grid(r, 5)
    grid = []
    for j in range(nel):
        el = math.radians(el0 + (el1 - el0) * j / (nel - 1))
        row = []
        for i in range(naz):
            az = math.radians(az0 + (az1 - az0) * i / (naz - 1))
            rr = r[j][i] + off
            row.append(center + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * rr)
        grid.append(row)
    return grid


def cloth_drape(o, pin_top_rows, colliders, frames=40):
    """Stoffsimulation: obere Reihen festgehalten, fällt über die Kollisions-Meshes; Ergebnis wird übernommen."""
    zmax = max(v.co.z for v in o.data.vertices)
    vg = o.vertex_groups.new(name="pin")
    vg.add([v.index for v in o.data.vertices if v.co.z >= zmax - pin_top_rows], 1.0, 'REPLACE')
    cl = o.modifiers.new("cloth", "CLOTH")
    cl.settings.vertex_group_mass = "pin"
    cl.settings.quality = 8
    cl.settings.mass = 0.4
    cl.settings.tension_stiffness = 25
    cl.settings.bending_stiffness = 2.0
    cl.collision_settings.distance_min = 0.008
    for c in colliders:
        c.modifiers.new("col", "COLLISION")
        c.collision.thickness_outer = 0.006
    sc = bpy.context.scene
    sc.frame_start = 1
    sc.frame_end = frames
    cl.point_cache.frame_start = 1
    cl.point_cache.frame_end = frames
    for f in range(1, frames + 1):
        sc.frame_set(f)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="cloth")
    o.vertex_groups.clear()
    for c in colliders:
        for md in [m for m in c.modifiers if m.type == 'COLLISION']:
            c.modifiers.remove(md)
    sc.frame_set(1)
    return o


def cloth_sheet(name, top, bottom, w_top, w_bot, y, m, rim, bulge, nx=16, nz=22):
    """Ebene Stoffbahn (vor der Simulation), leicht gewölbt; bulge > 0 wölbt nach +Y (Umhang hinten), < 0 nach -Y (vorn)."""
    grid = []
    for j in range(nz + 1):
        t = j / nz
        z = top + (bottom - top) * t
        w = w_top + (w_bot - w_top) * t
        grid.append([Vector(((i / nx - 0.5) * w, y + bulge * (1 - (2 * (i / nx - 0.5)) ** 2) + 0.012 * math.sin(i / nx * math.tau * 3) * t, z)) for i in range(nx + 1)])
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in row] for row in grid]
    for j in range(nz):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(m)
    me.materials.append(rim)
    return o


def cloth_finish(o, arm, bone, thick=0.008):
    so = o.modifiers.new("solid", "SOLIDIFY"); so.thickness = thick; so.use_rim = True; so.material_offset_rim = 1
    sm = o.modifiers.new("sub", "SUBSURF"); sm.levels = 1
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    for pg in o.data.polygons:
        pg.use_smooth = True
    return attach(o, arm, bone)


def build_tank(variant="v2"):
    steel = metal("steel", (0.6, 0.62, 0.66), 0.26)
    gold = metal("gold", (0.86, 0.62, 0.24), 0.25, 0.08)
    leather = mat("leather", (0.28, 0.17, 0.1), 0.0, 0.7)
    cloth = mat("cloth_blue", (0.08, 0.19, 0.48), 0.0, 0.85)
    arm = load_figure("Male_Peasant", outfit_tint=(0.35, 0.38, 0.5))
    body, legs, arms_m = mesh_of(arm, "Peasant_Body"), mesh_of(arm, "Peasant_Legs"), mesh_of(arm, "Peasant_Arms")
    head = max((o for o in arm.children if o.type == "MESH" and o.name.lower().startswith("superhero")), key=lambda o: len(o.data.vertices))
    chainmail(body)
    chainmail(arms_m, hands_leather=True)
    T = 0.009
    # Brustpanzer: abgetastet, Halsausschnitt in der Mitte, Armöffnungen außen; Rückenpanzer; zwei Bauchschienen
    neck = lambda a: 1.5 - 0.05 * max(0.0, 1 - abs(a) / 32) - 0.09 * max(0.0, (abs(a) - 58) / 32)
    chest = _grid_mesh("chest", torso_shell([body], 1.24, 1.5, -90, 90, 0.016, top_cut=neck), steel, gold, T)
    skin_from(chest, [body])
    backneck = lambda a: 1.49 - 0.04 * max(0.0, 1 - abs(abs(a) - 180) / 30) - 0.08 * max(0.0, (180 - abs(a) - 58) / 32)
    back = _grid_mesh("back", torso_shell([body], 1.26, 1.49, 92, 268, 0.014, top_cut=lambda a: backneck(a - 360 if a > 180 else a)), steel, gold, T)
    skin_from(back, [body])
    for k, (z0, z1) in enumerate(((1.17, 1.23), (1.105, 1.165))):
        lame = _grid_mesh("lame%d" % k, torso_shell([body], z0, z1, -95, 95, 0.02 + 0.004 * k, nz=4), steel, gold, T)
        skin_from(lame, [body])
    belt(arm, body, 1.05, leather, gold)
    # Schultern, Ellbogen, Armschienen, Beine wie bisher (saubere Schienen)
    for s in (1, -1):
        sd = "l" if s > 0 else "r"
        sc_ = Vector((s * 0.24, 0.06, 1.45))
        sp = _grid_mesh("spaulder%d" % s, head_shell(arms_m, sc_, 10, 88, -180, 180, 0.022, nel=10, naz=28, max_r=0.15), steel, gold, T)
        attach(sp, arm, "upperarm_" + sd)
        lo, hi = (25, 155) if s > 0 else (-155, -25)
        sp2 = _grid_mesh("spaulder_b%d" % s, head_shell(arms_m, sc_ + Vector((s * 0.05, 0, 0)), -24, 12, lo, hi, 0.03, nel=5, naz=16, max_r=0.16), steel, gold, T)
        attach(sp2, arm, "upperarm_" + sd)
        limb_plate(arm, arms_m, "lowerarm_" + sd, 0.25, 0.85, steel, gold, extra=0.008, arc=360, front=Vector((0, 0, 1)), name="vambrace_" + sd)
        limb_plate(arm, arms_m, "lowerarm_" + sd, 0.0, 0.14, steel, gold, extra=0.016, arc=160, front=Vector((0, 1, 0)), name="couter_" + sd)
    for sd in ("l", "r"):
        limb_plate(arm, legs, "calf_" + sd, 0.12, 0.82, steel, gold, extra=0.01, arc=200, flare=0.012, name="greave_" + sd)
        limb_plate(arm, legs, "calf_" + sd, -0.06, 0.1, steel, gold, extra=0.02, arc=150, name="knee_" + sd)
    # Helm: Kalotte abgetastet (Elevation 18..90°), Stirnband, Wangenklappen, Nasenschutz
    hc = Vector((0, 0.01, 1.66))
    helm = _grid_mesh("helm", head_shell(head, hc, 14, 88, -180, 180, 0.014), steel, gold, 0.01)
    attach(helm, arm, "Head")
    brow = _grid_mesh("brow", head_shell(head, hc, 10, 20, -180, 180, 0.024, nel=3), gold, gold, 0.008, sub=0)
    attach(brow, arm, "Head")
    for s in (1, -1):
        ck = _grid_mesh("cheek%d" % s, head_shell(head, hc, -26, 12, s * 40 - 14, s * 40 + 14, 0.016, nel=8, naz=6), steel, gold, 0.007, sub=1)
        attach(ck, arm, "Head")
    attach(box("nose", Vector((0, -0.122, 1.665)), (0.014, 0.012, 0.085), steel, sub=0), arm, "Head")
    # Stoff: Umhang hinten und Wappenrock vorn, per Stoffsimulation über Körper und Panzer gelegt
    cl = cloth_sheet("cape", 1.47, 0.5, 0.4, 0.62, 0.16, cloth, gold, bulge=0.06)
    tb = cloth_sheet("tabard", 1.03, 0.64, 0.2, 0.23, -0.16, cloth, gold, bulge=-0.02, nx=10, nz=14)
    cloth_drape(cl, 0.02, [body, legs, chest, back])
    cloth_drape(tb, 0.02, [body, legs])
    cloth_finish(cl, arm, "spine_03", 0.012)
    cloth_finish(tb, arm, "pelvis", 0.008)
    for b in (box("clasp_l", Vector((0.17, -0.03, 1.46)), (0.05, 0.02, 0.05), gold), box("clasp_r", Vector((-0.17, -0.03, 1.46)), (0.05, 0.02, 0.05), gold)):
        attach(b, arm, "spine_03")
    longsword(arm, steel, gold, leather)
    heater_shield(arm, steel, gold, cloth)
    return arm


# ---------------------------------------------------------------- Pose und Vorschau
def pose(arms, action_name, frame):
    new = _import(UAL2)
    act = next((a for a in bpy.data.actions if a.name.startswith(action_name)), None)
    for n in [o.name for o in new]:
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
    if act:
        for a in arms:
            a.animation_data_create(); a.animation_data.action = act
    bpy.context.scene.frame_set(frame)


def preview(out, names, action="Idle_No_Loop", frame=5):
    """Ein Held aus drei Blickwinkeln (vorn schräg, Seite, hinten) nebeneinander."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    arms = []
    for i, yaw in enumerate((-0.45, -1.57, 3.0)):
        arm = build_tank()
        arm.location.x = (i - 1) * 1.25
        arm.rotation_mode = 'XYZ'
        arm.rotation_euler.z = yaw
        arms.append(arm)
    pose(arms, action, frame)
    for a in arms:
        fist(a, "r")
    bpy.context.view_layer.update()
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    bpy.context.object.data.materials.append(mat("floor", (0.06, 0.07, 0.07), 0.0, 0.9))
    def light(kind, energy, col, rot, loc=(0, 0, 5)):
        l = bpy.data.objects.new(kind, bpy.data.lights.new(kind, kind)); sc.collection.objects.link(l)
        l.data.energy = energy; l.data.color = col; l.rotation_euler = rot; l.location = loc
        return l
    light('SUN', 3.0, (1.0, 0.92, 0.82), (math.radians(48), 0, math.radians(-35)))
    fill = light('AREA', 150, (0.6, 0.7, 1.0), (math.radians(70), 0, math.radians(40)), (3, -3, 3)); fill.data.size = 4
    rim = light('AREA', 700, (0.45, 1.0, 0.35), (math.radians(-65), 0, 0), (0, 4, 3)); rim.data.size = 6
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.08, 1)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 45
    cam.location = (0, -6.2, 1.9)
    cam.rotation_euler = (Vector((0, 0, 1.0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x, sc.render.resolution_y = 1800, 1000
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- Alle Helden aus den gekauften Outfits (Quaternius Source)
PARTS = os.path.join(os.path.dirname(OUTFIT), "Modular Parts")


def recolor(obj, hue=0.5, sat=1.0, val=1.0, mul=None):
    """Färbt ein texturiertes Teil um, ohne die Textur zu verlieren: Farbton verschieben (0.5 = gleich), Sättigung, Helligkeit."""
    for slot in obj.material_slots:
        if slot.material is None:
            continue
        m = slot.material.copy()
        slot.material = m
        nt = m.node_tree
        p = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if p is None:
            continue
        link = next((l for l in nt.links if l.to_socket == p.inputs["Base Color"]), None)
        hs = nt.nodes.new("ShaderNodeHueSaturation")
        hs.inputs["Hue"].default_value = hue
        hs.inputs["Saturation"].default_value = sat
        hs.inputs["Value"].default_value = val
        if link:
            nt.links.new(link.from_socket, hs.inputs["Color"])
        else:
            hs.inputs["Color"].default_value = p.inputs["Base Color"].default_value
        out = hs.outputs["Color"]
        if mul:
            mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'
            mx.inputs["Factor"].default_value = 1.0
            nt.links.new(out, mx.inputs[6]); mx.inputs[7].default_value = (*mul, 1)
            out = mx.outputs[2]
        nt.links.new(out, p.inputs["Base Color"])


def figure(gender, outfit, parts=(), hair=(), look=None):
    """Heldenkörper (Kopf) + Outfit + Zusatzteile + Haare; look = {Name-Teil: (hue, sat, val)} färbt passende Teile um."""
    global BODY
    BODY = os.path.join(BASE, "Base Characters", "Godot - UE", "Superhero_%s_FullBody.gltf" % gender)
    arm = load_figure(outfit)
    for p_ in parts:
        _rebind(_import(os.path.join(PARTS, p_ + ".gltf")), arm)
    for h in hair:
        _rebind(_import(os.path.join(HAIR, h + ".gltf")), arm)
    names = {o.name for o in arm.children}
    for o in [o for o in arm.children if o.type == 'MESH' and o.name[-4:-3] == "." and o.name[:-4] in names]:   # Teil steckt schon im Outfit: Doppel weg
        bpy.data.objects.remove(o, do_unlink=True)
    if look:
        skin = ("superhero", "eye", "hair", "brow")
        for o in [o for o in arm.children if o.type == 'MESH' and not o.name.lower().startswith(skin)]:
            for key, v in look.items():
                if key == "*" or key in o.name:
                    recolor(o, *v)
                    break
    return arm


def hand(arm, side):
    b = arm.data.bones["hand_" + side]
    return (arm.matrix_world @ b.head_local).lerp(arm.matrix_world @ b.tail_local, 0.6)


def _finish_joined(parts, name, arm, bone, bevel=0.003):
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, scale=True, rotation=True)
    s = _join(parts, name)
    if bevel:
        b = s.modifiers.new("bev", "BEVEL"); b.width = bevel; b.segments = 2
        bpy.context.view_layer.objects.active = s
        bpy.ops.object.modifier_apply(modifier="bev")
    for p in s.data.polygons:
        p.use_smooth = True
    return attach(s, arm, bone)


def blade_weapon(arm, side, length, width, steel, gold, leather, guard=0.24, name="blade"):
    """Klinge in der Hand: zeigt in der T-Pose vom Arm weg, bei hängendem Arm nach unten; breite Seite nach vorn."""
    c = hand(arm, side)
    sg = -1 if side == "r" else 1                                       # Richtung vom Körper weg (entlang X)
    hx, hy, hz = c.x, c.y, c.z
    bl = _prim("cube", steel, size=1, location=(hx + sg * (0.12 + length / 2), hy, hz))
    bl.scale = (length, 0.012, width)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=6); bpy.ops.object.mode_set(mode='OBJECT')
    for v in bl.data.vertices:
        t = (sg * (v.co.x - hx) - 0.12) / length
        if t > 0.8:
            v.co.z = hz + (v.co.z - hz) * max(0.05, (1 - t) / 0.2)
        if abs(v.co.z - hz) > width * 0.35:
            v.co.y = hy + (v.co.y - hy) * 0.3
    parts = [bl, _prim("cube", gold, size=1, location=(hx + sg * 0.1, hy, hz))]
    parts[-1].scale = (0.03, 0.03, guard)
    parts.append(_prim("cylinder", leather, radius=0.017, depth=0.16, location=(hx, hy, hz), rotation=(0, math.pi / 2, 0)))
    parts.append(_prim("uv_sphere", gold, radius=0.026, location=(hx - sg * 0.09, hy, hz)))
    return _finish_joined(parts, name, arm, "hand_" + side)


def staff(arm, side, wood, tip_mat, tip="crystal", length=1.55):
    """Stab in der Hand: bei hängendem Arm senkrecht, oben (Richtung Schulter) Kristall, Blattkrone oder Schädel."""
    c = hand(arm, side)
    sg = -1 if side == "r" else 1
    top, bottom = c.x - sg * 0.95, c.x + sg * (length - 0.95)
    parts = [_prim("cylinder", wood, radius=0.022, depth=length, location=((top + bottom) / 2, c.y, c.z), rotation=(0, math.pi / 2, 0))]
    tx = top - sg * 0.08
    if tip == "crystal":
        k = _prim("ico_sphere", tip_mat, radius=0.07, subdivisions=1, location=(tx, c.y, c.z))
        k.scale = (1.7, 1, 1)
        parts.append(k)
        for a in range(3):
            prong = _prim("cone", wood, radius1=0.015, radius2=0.004, depth=0.16, location=(top, c.y + 0.04 * math.cos(a * 2.1), c.z + 0.04 * math.sin(a * 2.1)), rotation=(0, -sg * math.pi / 2, 0))
            parts.append(prong)
    elif tip == "leaves":
        for a in range(7):
            lf = _prim("uv_sphere", tip_mat, radius=0.05, location=(tx + 0.03 * math.sin(a), c.y + 0.07 * math.cos(a * 0.9), c.z + 0.07 * math.sin(a * 0.9)))
            lf.scale = (0.5, 1.2, 0.6)
            parts.append(lf)
        parts.append(_prim("ico_sphere", tip_mat, radius=0.035, subdivisions=2, location=(tx, c.y, c.z)))
    else:                                                               # Schädel mit Augenglühen
        sk = _prim("uv_sphere", wood, radius=0.075, location=(tx, c.y, c.z))
        sk.scale = (1.15, 0.95, 0.9)
        parts.append(sk)
        for e in (-1, 1):
            parts.append(_prim("uv_sphere", tip_mat, radius=0.018, location=(tx + sg * 0.01, c.y - 0.065, c.z + e * 0.028)))
    return _finish_joined(parts, "staff", arm, "hand_" + side, bevel=0.0)


def bow(arm, wood, string):
    """Langbogen in der linken Hand: bei hängendem Arm senkrecht, nach vorn gewölbt."""
    c = hand(arm, "l")
    bm = bmesh.new()
    pts = []
    for k in range(25):
        t = k / 24 - 0.5
        pts.append(Vector((c.x + t * 1.25, c.y - 0.16 * (1 - (2 * t) ** 2) + 0.04, c.z)))
    me = bpy.data.meshes.new("bowcurve")
    bm.free()
    cu = bpy.data.curves.new("bow", 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = 0.016; cu.bevel_resolution = 3
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1)
        sp.points[i].radius = 1.2 - abs(i / 24 - 0.5) * 1.4
    o = bpy.data.objects.new("bow", cu); bpy.context.scene.collection.objects.link(o)
    cu.materials.append(wood)
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    st = _prim("cylinder", string, radius=0.003, depth=1.22, location=(c.x, c.y + 0.035, c.z), rotation=(0, math.pi / 2, 0))
    return _finish_joined([o, st], "bow", arm, "hand_l", bevel=0.0)


def quiver(arm, leather, wood, feather):
    """Köcher auf dem Rücken, schräg, mit Pfeilen."""
    parts = [_prim("cylinder", leather, radius=0.06, depth=0.5, location=(0.08, 0.2, 1.3), rotation=(0.0, 0.35, 0))]
    for k in range(5):
        a = _prim("cylinder", wood, radius=0.006, depth=0.2, location=(0.08 + 0.09 + 0.012 * k, 0.2 + 0.01 * (k - 2), 1.6), rotation=(0, 0.35, 0))
        f = _prim("cube", feather, size=1, location=(0.08 + 0.12 + 0.012 * k, 0.2 + 0.01 * (k - 2), 1.68), rotation=(0, 0.35, 0))
        f.scale = (0.005, 0.03, 0.06)
        parts += [a, f]
    return _finish_joined(parts, "quiver", arm, "spine_03", bevel=0.0)


def heater_shield_at(arm, steel, gold, cloth):
    """Wappenschild am linken Unterarm (Position aus dem Skelett, passt auch für den Frauenkörper)."""
    b = arm.data.bones["lowerarm_l"]
    mid = (arm.matrix_world @ b.head_local).lerp(arm.matrix_world @ b.tail_local, 0.55)
    s = heater_shield(arm, steel, gold, cloth)
    s.location.x += mid.x - 0.6
    return s


# ---------------------------------------------------------------- Waffen: Quaternius Medieval Weapons Pack (CC0) + eigene im gleichen Stil
WPACK = os.path.join(A, "quaternius-weapons", "OBJ")
_WMOD = None


def wmod():
    """make_weapons.py (eigene Waffen im Low-Poly-Stil des Waffensets) einmal laden."""
    global _WMOD
    if _WMOD is None:
        import types
        src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "make_weapons.py")
        mod = types.ModuleType("make_weapons")
        mod.__file__ = src
        exec(open(src, encoding="utf-8").read().split('if __name__ == "__main__":')[0], mod.__dict__)
        _WMOD = mod
    return _WMOD


def _upright(o):
    """Längste Achse nach +Z, flachste nach Y (Vorderseite -Y)."""
    from mathutils import Matrix
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    d = o.dimensions
    thin, mid, long_ = sorted(range(3), key=lambda i: d[i])
    cols = [None, None, None]
    cols[mid] = (1, 0, 0); cols[thin] = (0, 1, 0); cols[long_] = (0, 0, 1)
    R = Matrix((cols[0], cols[1], cols[2])).transposed()
    if R.determinant() < 0:
        R = Matrix((cols[0], cols[1], tuple(-c for c in cols[2]))).transposed()
    o.data.transform(R.to_4x4())
    o.data.update()


def _grip(o, frac, flip=False):
    """Griffpunkt (Anteil frac der Länge von unten) in den Ursprung; flip dreht die Waffe um (Griff oben im Modell)."""
    from mathutils import Matrix
    if flip:
        o.data.transform(Matrix.Rotation(math.pi, 4, 'Y'))
    zs = [v.co.z for v in o.data.vertices]
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    z = min(zs) + (max(zs) - min(zs)) * frac
    o.data.transform(Matrix.Translation((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -z)))
    o.data.update()


def pack_weapon(name, colors, frac=0.1, length=None, flip=False, stretch=None):
    """Waffe aus dem Set laden, aufrichten, Griff in den Ursprung, Materialien umfärben (colors: Materialname -> (Farbe, Metall, Rauheit))."""
    bpy.ops.wm.obj_import(filepath=os.path.join(WPACK, name + ".obj"))
    objs = list(bpy.context.selected_objects)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    _upright(o)
    if stretch:
        from mathutils import Matrix
        o.data.transform(Matrix.Diagonal((stretch[0], stretch[1], stretch[2], 1)))
    if length:
        from mathutils import Matrix
        zs = [v.co.z for v in o.data.vertices]
        k = length / (max(zs) - min(zs))
        o.data.transform(Matrix.Scale(k, 4))
    _grip(o, frac, flip)
    for slot in o.material_slots:
        base = slot.material.name.split(".")[0]
        if base in colors:
            col, metal, rough = colors[base]
            m = mat("%s_%s_%s" % (name, base, "%.2f%.2f%.2f" % col), col, metal, rough)
            slot.material = m
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def place(o, arm, side, tip="down", lift=0.0):
    """Waffe in die Hand: Griff an die Handmitte, Spitze bei hängendem Arm nach unten (tip='down') oder oben ('up'), Vorderseite nach vorn."""
    from mathutils import Matrix
    c = hand(arm, side)
    away = -1 if side == "r" else 1                                     # Richtung vom Körper weg (T-Pose, entlang X)
    d = -away if tip == "down" else away
    o.data.transform(Matrix.Rotation(math.radians(90 * d), 4, 'Y'))
    o.data.transform(Matrix.Translation((d * lift, 0, 0)))
    o.location = c
    bpy.context.view_layer.update()
    return attach(o, arm, "hand_" + side)


def place_shield(o, arm, out=0.12, tilt=40):
    """Schild am linken Unterarm: Vorderseite nach außen, Oberkante Richtung Schulter, etwas nach vorn gekippt."""
    from mathutils import Matrix
    o.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))                  # Vorderseite (Wappen) nach außen, Griffe zum Arm
    R = Matrix(((0, 1, 0), (0, 0, 1), (1, 0, 0))).transposed()         # lokal Z -> +X (bei hängendem Arm oben), lokal -Y -> -Z (außen)
    o.data.transform(R.to_4x4())
    o.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))                  # Spitze nach unten (bei hängendem Arm), Vorderseite bleibt außen
    o.data.transform(Matrix.Rotation(math.radians(-tilt), 4, 'X'))
    b = arm.data.bones["lowerarm_l"]
    mid = (arm.matrix_world @ b.head_local).lerp(arm.matrix_world @ b.tail_local, 0.55)
    o.location = mid + Vector((0, 0, out))
    bpy.context.view_layer.update()
    return attach(o, arm, "lowerarm_l")


def tower_from_heater(colors):
    """Set-Schild Nr. 16 (Wappenschild) zum Turmschild gestreckt, mit Stacheln im Stil des Sets (kantig, flach schattiert)."""
    W = wmod()
    s = pack_weapon("Shield_Heater", colors, frac=0.5, stretch=(1.15, 0.45, 1.55), length=SHIELD_LEN)
    zs = [v.co.z for v in s.data.vertices]
    xs = [v.co.x for v in s.data.vertices]
    ys = [v.co.y for v in s.data.vertices]
    front = min(ys)
    top, bot, half = max(zs), min(zs), max(xs)
    dark = mat("spike_dark", (0.14, 0.14, 0.16), 0.85, 0.35)
    parts = [s]
    parts.append(W.spike(dark, (0, front + 0.01, 0.02), (0, front - 0.2, 0.02), 0.05))
    for z in (top * 0.72, bot * 0.55):
        for sx in (-1, 1):
            parts.append(W.spike(dark, (sx * half * 0.92, front * 0.4, z), (sx * (half + 0.13), front * 0.4, z), 0.03))
    for sx in (-0.5, 0.0, 0.5):
        parts.append(W.spike(dark, (sx * half, front * 0.4, top * 0.98), (sx * half, front * 0.4, top + 0.12), 0.03))
    for p in parts[1:]:
        for f in p.data.polygons:
            f.use_smooth = False
    o = W.join(parts, "tower_shield", smooth=False)
    return o


# ---------------------------------------------------------------- Figuren-Korrekturen
def drop_meshes(arm, keys):
    for o in [o for o in arm.children if o.type == 'MESH' and any(k in o.name for k in keys)]:
        bpy.data.objects.remove(o, do_unlink=True)


def shrink(arm, key, k=0.88, dz=-0.01):
    """Teil (z. B. Kapuze) um die Kopfmitte verkleinern, damit der Kopf nicht zu klein darin wirkt."""
    from mathutils import Matrix
    hb = arm.data.bones["Head"]
    c = arm.matrix_world @ hb.head_local + Vector((0, 0.0, 0.08))
    for o in [o for o in arm.children if o.type == 'MESH' and key in o.name]:
        M_ = Matrix.Translation(c + Vector((0, 0, dz))) @ Matrix.Diagonal((k, k, k, 1)) @ Matrix.Translation(-c)
        o.data.transform(o.matrix_world.inverted() @ M_ @ o.matrix_world)
        o.data.update()


MASK_VARIANT = 1


def face_mask(arm, head, ec, variant=1):
    """Mundschutz des Nekromanten als glatte Hülle um den Kopf (Nase und Mund zeichnen sich nicht ab):
    Kopf kugelförmig abgetastet, stark geglättet; oberer Rand ein weicher Bogen unter den Augen (Spitze am Nasenrücken).
    1 = Stofftuch, 2 = Tuch, das vorn über Hals und Brust fällt, 3 = eiserne Halbmaske mit Atemschlitzen."""
    W = wmod()
    ez = (ec[0].z + ec[1].z) / 2
    c = Vector((0, (ec[0].y + ec[1].y) / 2 + 0.085, ez - 0.02))
    mw = head.matrix_world
    pts = [mw @ v.co - c for v in head.data.vertices]
    naz, nel = 26, 12
    az0, az1, el0 = -105.0, 105.0, -62.0
    top = lambda az: 2.0 - 16.0 * (abs(az) / 105.0) ** 1.3 + 4.0 * max(0.0, 1 - abs(az) / 14)
    r = [[0.0] * naz for _ in range(nel)]
    for q in pts:
        rr = q.length
        if rr < 1e-4 or rr > 0.2:
            continue
        el = math.degrees(math.asin(max(-1, min(1, q.z / rr))))
        az = math.degrees(math.atan2(q.x, -q.y))
        if not (az0 <= az <= az1):
            continue
        t = (el - el0) / (top(az) - el0)
        j = round(t * (nel - 1))
        i = round((az - az0) / (az1 - az0) * (naz - 1))
        if 0 <= j < nel and 0 <= i < naz:
            r[j][i] = max(r[j][i], rr)
    for j in range(nel):
        cand = [x for x in r[j] if x > 0]
        for i in range(naz):
            if r[j][i] == 0:
                r[j][i] = sum(cand) / len(cand) if cand else 0.1
    r = _smooth_grid(r, 14)                                             # stark glätten: keine Nase, kein Mund
    off = 0.016 if variant != 3 else 0.02
    grid = []
    for j in range(nel):
        row = []
        for i in range(naz):
            az = az0 + (az1 - az0) * i / (naz - 1)
            el = el0 + (top(az) - el0) * j / (nel - 1)
            d = Vector((math.sin(math.radians(az)) * math.cos(math.radians(el)), -math.cos(math.radians(az)) * math.cos(math.radians(el)), math.sin(math.radians(el))))
            row.append(c + d * (r[j][i] + off))
        grid.append(row)
    grid = grid[::-1]                                                   # oben zuerst
    if variant == 2:                                                    # Tuch fällt vorn über Hals und Brust, mit Falten
        last = grid[-1]
        for k in range(1, 7):
            t = k / 6
            row = []
            for i, q in enumerate(last):
                u = i / (naz - 1) - 0.5
                w_ = 1.0 - 0.55 * t                                     # läuft nach unten spitz zu
                row.append(Vector((q.x * w_, min(q.y, -0.1) - 0.05 * t + 0.01 * math.sin(u * math.tau * 3) * t, q.z - 0.22 * t - 0.06 * abs(u) * t)))
            grid.append(row)
    if variant == 3:
        m = mat("necro_iron", (0.12, 0.12, 0.13), 0.85, 0.45)
        rim = mat("necro_iron_rim", (0.22, 0.22, 0.24), 0.9, 0.35)
    else:
        m = mat("necro_mask", (0.045, 0.05, 0.045), 0.0, 0.92)
        rim = m
    o = _grid_mesh("facemask", grid, m, rim, 0.004 if variant != 3 else 0.007, sub=2, bevel=0.0)
    skin_from(o, [head])
    if variant == 3:                                                    # Atemschlitze und Nieten
        slit = mat("necro_slit", (0.0, 0.0, 0.0), 0.0, 1.0)
        mid = grid[int(len(grid) * 0.55)][naz // 2]
        parts = []
        for k in range(4):
            parts.append(W.cube(slit, mid + Vector((-0.024 + k * 0.016, -0.004, 0.0)), (0.005, 0.008, 0.026)))
        for i in (2, naz - 3):
            for jj in (1, len(grid) - 2):
                parts.append(W.ball(rim, 0.005, grid[jj][i] + (grid[jj][i] - c).normalized() * 0.006, seg=8))
        skin_from(W.join(parts, "maskdetail", smooth=True), [head])
    return o


def hide_head(arm):
    """Augen und Brauen entfernen (für den Schädelkopf)."""
    for o in [o for o in arm.children if o.type == 'MESH' and o.name.lower().startswith(("eye",))]:
        bpy.data.objects.remove(o, do_unlink=True)


def skull_head(arm, bone_m=None, eye_m=None):
    """Nekromant: der echte Heldenkopf wird zum Schädel umgeformt (Form und Größe eines Kopfes bleiben).
    Augenhöhlen und Nase tief eingedrückt, Wangen eingefallen, Ohren angelegt, Kiefer kantiger. Farbe als Vertex-Farbe:
    alter Knochen, dunkle Höhlen, Zahnreihe, feine Risse. Kleine grüne Glut tief in den Augenhöhlen."""
    head = max((o for o in arm.children if o.type == 'MESH' and o.name.lower().startswith("superhero")), key=lambda o: len(o.data.vertices))
    eyes = [o for o in arm.children if o.type == 'MESH' and o.name.lower().startswith("eye") and "brow" not in o.name.lower()]
    ec = []
    if eyes:
        pts = [eyes[0].matrix_world @ v.co for v in eyes[0].data.vertices]
        for sx in (-1, 1):
            side = [q for q in pts if q.x * sx > 0]
            ec.append(sum(side, Vector()) / len(side))
    else:
        ec = [Vector((-0.032, -0.085, 1.665)), Vector((0.032, -0.085, 1.665))]
    ez = (ec[0].z + ec[1].z) / 2
    face_mask(arm, head, ec, MASK_VARIANT)
    hide_head(arm)
    mw = head.matrix_world
    inv = mw.inverted()
    bm = bmesh.new()
    bm.from_mesh(head.data)
    bm.normal_update()
    nose = Vector((0, (ec[0].y + ec[1].y) / 2 - 0.02, ec[0].z - 0.035))
    mouth_z = ec[0].z - 0.068
    dark = {}
    for v in bm.verts:
        w = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        push = 0.0
        shade = 0.0
        for c in ec:                                                     # Augenhöhlen
            d = ((w.x - c.x) / 0.026) ** 2 + ((w.z - c.z) / 0.022) ** 2
            if w.y < c.y + 0.03 and d < 1.0:
                push += 0.022 * (1 - d) ** 0.7
                shade = max(shade, (1 - d) ** 0.5)
        dn = ((w.x - nose.x) / 0.014) ** 2 + ((w.z - nose.z) / 0.016) ** 2  # Nasenloch (Dreieck: unten breiter)
        if w.y < nose.y + 0.03 and dn < 1.0:
            push += 0.012 * (1 - dn)
            shade = max(shade, (1 - dn) ** 0.6)
        if 0.035 < abs(w.x) < 0.07 and ec[0].z - 0.075 < w.z < ec[0].z - 0.02 and w.y < -0.03:   # eingefallene Wangen
            push += 0.01
            shade = max(shade, 0.25)
        if abs(w.x) > 0.07 and ec[0].z - 0.06 < w.z < ec[0].z + 0.03:      # Ohren anlegen
            v.co = inv @ Vector((w.x * 0.88, w.y, w.z))
            w = mw @ v.co
        if abs(w.z - mouth_z) < 0.018 and abs(w.x) < 0.034 and w.y < -0.05:   # Lippen weg: Zähne liegen frei
            push += 0.007
        if push:
            v.co = inv @ (w - n * push)
        dark[v.index] = shade
    col = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        for lp in f.loops:
            w = mw @ lp.vert.co
            base = Vector((0.62, 0.58, 0.48))
            sh = dark.get(lp.vert.index, 0.0)
            if abs(w.z - mouth_z) < 0.016 and abs(w.x) < 0.034 and w.y < -0.05:   # Zahnreihe: helle Zähne mit dunklen Fugen, Mittelspalt
                gap = abs(math.sin(w.x * 300)) < 0.3 or abs(w.z - mouth_z) < 0.0025 or abs(w.z - mouth_z) > 0.013
                sh = max(sh, 0.85 if gap else 0.0)
                base = Vector((0.75, 0.72, 0.62))
            crack = abs(math.sin(w.x * 90 + w.z * 140 + math.sin(w.y * 60) * 3)) < 0.03 and w.z > ec[0].z + 0.02   # feine Risse
            if crack:
                sh = max(sh, 0.6)
            c = base * (1 - 0.95 * sh)
            lp[col] = (c.x, c.y, c.z, 1.0)
    bm.to_mesh(head.data)
    bm.free()
    m = bpy.data.materials.new("skull_bone")
    m.use_nodes = True
    nt = m.node_tree
    pb = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], pb.inputs["Base Color"])
    pb.inputs["Roughness"].default_value = 0.8
    head.data.materials.clear()
    head.data.materials.append(m)
    W = wmod()
    glow = mat("necro_eye", (0.3, 1.0, 0.2), 0.0, 0.3, emit=(0.25, 1.0, 0.15))
    glow.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 9.0
    for c in ec:
        attach(W.ball(glow, 0.006, c + Vector((0, 0.012, 0)), seg=8), arm, "Head")
    return head


def leaf_crown(arm, leaf_m):
    """Gleichmäßiger Blätterkranz: dünner Holzreif, 12 gleiche Blätter im gleichen Winkel, vorn ein kleines Leuchtblatt."""
    W = wmod()
    hb = arm.data.bones["Head"]
    c = arm.matrix_world @ hb.head_local + Vector((0, 0.01, 0.155))
    parts = []
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.06, major_segments=24, minor_segments=6, location=c)
    ring = bpy.context.object
    ring.scale = (0.104, 0.118, 0.1)
    ring.data.materials.append(mat("crownwood", (0.22, 0.13, 0.07), 0.0, 0.8))
    parts.append(ring)
    for k in range(12):
        a_ = k / 12 * math.tau
        bm = bmesh.new()
        L, Wd = 0.06, 0.022
        bm.faces.new([bm.verts.new(p) for p in ((0, 0, 0), (Wd, 0, L * 0.4), (0, 0, L), (-Wd, 0, L * 0.4))])
        me = bpy.data.meshes.new("leaf"); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new("leaf", me); bpy.context.scene.collection.objects.link(o)
        me.materials.append(leaf_m)
        so = o.modifiers.new("s", "SOLIDIFY"); so.thickness = 0.004
        bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier="s")
        o.rotation_euler = (math.radians(-60), 0, a_ + math.pi)
        o.location = c + Vector((math.sin(a_) * 0.104, -math.cos(a_) * 0.118, 0))
        parts.append(o)
    parts.append(W.ball(mat("crownglow", (0.4, 0.95, 0.35), 0.0, 0.4, emit=(0.35, 0.95, 0.3)), 0.012, c + Vector((0, -0.124, 0.008)), seg=8))
    return attach(W.join(parts, "leafcrown", smooth=False), arm, "Head")


def skull_pauldron(arm, side, plate_m, bone_m, eye_m):
    """Schulterplatte mit Totenkopf (statt Löwe): kantige Kuppel + Schädel obenauf."""
    W = wmod()
    s = 1 if side == "l" else -1
    c = Vector((s * 0.24, 0.05, 1.52))
    parts = [W.ball(plate_m, 0.11, c, (1.15, 1.0, 0.75), seg=8)]
    parts += W.skull(bone_m, eye_m, c + Vector((s * 0.03, -0.01, 0.07)), 0.75)
    for k in range(3):
        parts.append(W.spike(plate_m, c + Vector((s * 0.05, 0.05 - k * 0.05, 0.05)), c + Vector((s * 0.12, 0.06 - k * 0.06, 0.16)), 0.018))
    return attach(W.join(parts, "skullpauldron_" + side, smooth=False), arm, "upperarm_" + side)


# ---------------------------------------------------------------- Die sechs Helden
STEEL = ((0.42, 0.44, 0.48), 0.85, 0.35)
HERO_LOOK = {
    "tank":   dict(gender="Male", outfit="Male_Knight", parts=["Male_Knight_Head_Armet", "Male_Knight_Acc_Pauldron_Round", "Male_Knight_Acc_Scarf"], hair=[],
                   look={"Scarf": (0.12, 1.1, 0.9)}),
    "damage": dict(gender="Male", outfit="Male_Ranger", parts=["Male_Ranger_Head_Hood", "Male_Ranger_Acc_Pauldron"], hair=[],
                   look={"*": (0.17, 0.75, 0.45)}, shrink=("Hood", 0.93)),
    "caster": dict(gender="Male", outfit="Male_Wizard", parts=[], hair=["Hair_Long", "Hair_Beard"], look=None),
    "ranger": dict(gender="Female", outfit="Female_Ranger", parts=["Female_Ranger_Head_Hood", "Female_Ranger_Acc_Pauldrons"], hair=[], look=None, shrink=("Hood", 0.99)),
    "druid":  dict(gender="Female", outfit="Female_Wizard", parts=[], hair=["Hair_Long"], look={"Wizard": (0.5, 0.35, 1.0, (0.62, 0.8, 0.45))}),
    "necro":  dict(gender="Male", outfit="Male_Noble", parts=["Male_Ranger_Head_Hood", "Male_Knight_Acc_Pauldron_Spike"], hair=[], drop=["Lion", "Crown", "Noble_Acc_Pauldron"],
                   look={"Hood": (0.5, 0.1, 0.12), "Knight": (0.5, 0.25, 0.4), "Noble": (0.75, 0.25, 0.33)}, shrink=("Hood", 1.0)),
}


def build_hero(cls):
    L = HERO_LOOK[cls]
    arm = figure(L["gender"], L["outfit"], L["parts"], L["hair"], L["look"])
    if L.get("drop"):
        drop_meshes(arm, L["drop"])
    if L.get("shrink"):
        key, k = L["shrink"] if isinstance(L["shrink"], tuple) else (L["shrink"], 0.88)
        shrink(arm, key, k)
    W = wmod()
    if cls == "tank":                                                   # 16 als Turmschild + 23 Großschwert; Stahl wie die Ritterrüstung, Holz dunkel, blaue Teamfarbe
        cols = {"Steel": STEEL, "LightSteel": ((0.55, 0.57, 0.6), 0.85, 0.3), "DarkSteel": ((0.2, 0.2, 0.22), 0.8, 0.4),
                "DarkWood": ((0.05, 0.11, 0.3), 0.0, 0.7), "LightWood": ((0.08, 0.17, 0.42), 0.0, 0.7)}
        place_shield(tower_from_heater(cols), arm)
        place(pack_weapon("Sword_Big", {"Steel": STEEL, "LightSteel": ((0.6, 0.62, 0.66), 0.9, 0.25), "DarkSteel": ((0.2, 0.2, 0.22), 0.8, 0.4),
                                         "DarkWood": ((0.1, 0.06, 0.04), 0.0, 0.7), "LightWood": ((0.22, 0.12, 0.06), 0.0, 0.7)}, frac=0.09, length=1.15), arm, "r", tip="up")
    elif cls == "damage":                                               # 11 doppelt, dunkle Klingen, Violett/Rot wie die Kleidung
        cols = {"Steel": ((0.16, 0.15, 0.18), 0.85, 0.3), "LightSteel": ((0.3, 0.29, 0.33), 0.9, 0.25), "Gold": ((0.35, 0.05, 0.08), 0.6, 0.35),
                "DarkWood": ((0.06, 0.04, 0.06), 0.0, 0.7), "LightWood": ((0.14, 0.07, 0.12), 0.0, 0.7)}
        place(pack_weapon("Dagger_2", cols, frac=0.14, length=0.48), arm, "r", tip="up")
        place(pack_weapon("Dagger_2", cols, frac=0.14, length=0.48), arm, "l", tip="up")
    elif cls == "caster":                                               # eigenes Kristallzepter (M3) im Set-Stil, Gold wie die Magierrobe
        o = W.mage_weapon(None, 3)
        _grip(o, 0.12)
        place(o, arm, "r", tip="down")
    elif cls == "ranger":                                               # 7 Holzbogen, Holz wie das Lederzeug
        b = pack_weapon("Bow_Wooden", {"DarkWood": ((0.16, 0.08, 0.04), 0.0, 0.7), "LightWood": ((0.3, 0.16, 0.07), 0.0, 0.7)}, frac=0.5, length=1.3)
        place(b, arm, "l", tip="up")
        quiver(arm, mat("leather", (0.28, 0.17, 0.1), 0.0, 0.7), mat("wood", (0.3, 0.19, 0.1), 0.0, 0.75), mat("feather", (0.3, 0.45, 0.2), 0.0, 0.8))
    elif cls == "druid":                                                # eigener Geweihstab (Dr2) im Set-Stil + Blätterkranz
        o = W.druid_weapon(None, 2)
        _grip(o, 0.35)
        place(o, arm, "r", tip="up")
        leaf_crown(arm, mat("leafcrown", (0.2, 0.5, 0.14), 0.0, 0.6))
    elif cls == "necro":                                                # 14 Sense (schwarz, Knochen), Kapuze mit Totenschädel, Totenkopf-Schulterplatten
        sc_ = pack_weapon("Scythe", {"Steel": ((0.12, 0.13, 0.14), 0.85, 0.3), "LightSteel": ((0.3, 0.42, 0.32), 0.9, 0.25),
                                     "DarkWood": ((0.05, 0.04, 0.05), 0.0, 0.7), "LightWood": ((0.12, 0.1, 0.1), 0.0, 0.7)}, frac=0.38, length=1.8, flip=True)
        place(sc_, arm, "r", tip="up")
        bone = mat("necro_bone", (0.78, 0.74, 0.62), 0.0, 0.6)
        soul = mat("necro_soul", (0.4, 1.0, 0.45), 0.0, 0.3, emit=(0.4, 1.0, 0.45))
        skull_head(arm)
    return arm


def preview_all(out, order=None):
    """Helden nebeneinander, leicht schräg von vorn."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    order = order or ["tank", "damage", "caster", "ranger", "druid", "necro"]
    arms = []
    for i, c in enumerate(order):
        a = build_hero(c)
        a.rotation_mode = 'XYZ'
        a.rotation_euler.z = -0.3
        a.location.x = (i - (len(order) - 1) / 2) * 1.15
        arms.append(a)
    pose(arms, "Idle_No_Loop", 5)
    for a in arms:
        fist(a, "r"); fist(a, "l")
    bpy.context.view_layer.update()
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    bpy.context.object.data.materials.append(mat("floor", (0.06, 0.07, 0.07), 0.0, 0.9))
    def light(kind, energy, col, rot, loc=(0, 0, 5)):
        l = bpy.data.objects.new(kind, bpy.data.lights.new(kind, kind)); sc.collection.objects.link(l)
        l.data.energy = energy; l.data.color = col; l.rotation_euler = rot; l.location = loc
        return l
    light('SUN', 3.2, (1.0, 0.93, 0.84), (math.radians(48), 0, math.radians(-30)))
    fill = light('AREA', 300, (0.6, 0.7, 1.0), (math.radians(70), 0, math.radians(40)), (4, -4, 3)); fill.data.size = 8
    rim = light('AREA', 1100, (0.45, 1.0, 0.35), (math.radians(-65), 0, 0), (0, 4, 3)); rim.data.size = 12
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.08, 1)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 38 if len(order) > 2 else 55
    cam.location = (0, -8.4 if len(order) > 2 else -5.0, 1.9 if len(order) > 2 else 1.5)
    cam.rotation_euler = (Vector((0, 0, 1.0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.engine = 'BLENDER_EEVEE_NEXT'; sc.render.resolution_x, sc.render.resolution_y = 2200, 1000
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- Export nach Godot (GLB mit Animationen)
UAL1 = os.path.join(A, "quaternius-anim1", "Animation Library[Standard]", "Godot", "AnimationLibrary_Godot_Standard.glb")
# UAL1 hat ein Rigify-Skelett (DEF-…); Namen auf unser Skelett (UE-Stil) abbilden
_RIG_MAP = {"DEF-hips": "pelvis", "DEF-spine.001": "spine_01", "DEF-spine.002": "spine_02", "DEF-spine.003": "spine_03",
            "DEF-neck": "neck_01", "DEF-head": "Head"}
for _s, _t in (("L", "l"), ("R", "r")):
    _RIG_MAP.update({"DEF-shoulder." + _s: "clavicle_" + _t, "DEF-upper_arm." + _s: "upperarm_" + _t, "DEF-forearm." + _s: "lowerarm_" + _t,
                     "DEF-hand." + _s: "hand_" + _t, "DEF-thigh." + _s: "thigh_" + _t, "DEF-shin." + _s: "calf_" + _t,
                     "DEF-foot." + _s: "foot_" + _t, "DEF-toe." + _s: "ball_" + _t})
# Animationen je Held: Name im Spiel -> (Bibliothek, Aktion). Namen wie im Spielcode (Angriff, Laufen, Ruhe, Fähigkeiten-Posen).
# Schild: Länge (m) und ob der Schildarm in Ruhe und beim Laufen seitlich hängt (statt das Schild vor den Körper zu halten)
SHIELD_LEN = float(os.environ.get("SHIELD_LEN", "1.3"))
SHIELD_SIDE = os.environ.get("SHIELD_SIDE", "1") == "1"
SHIELD_ARM = ("clavicle_l", "upperarm_l", "lowerarm_l", "hand_l")
HERO_ANIMS = {
    "tank": {"Idle": ("UAL1", "Sword_Idle"), "Run": ("UAL1", "Jog_Fwd_Loop"), "Sword_Attack": ("UAL2", "Sword_Regular_A"),
             "Sword_Attack2": ("UAL2", "Sword_Regular_B"), "Punch": ("UAL2", "Shield_OneShot"), "Death": ("UAL1", "Death01"),
             "Hit": ("UAL1", "Hit_Chest"), "Roll": ("UAL1", "Roll")},
}
_FINGERS = ("index", "middle", "ring", "pinky", "thumb")


def _fist_q(name):
    """Faust-Rotation eines Fingerknochens (wie fist()), als Quaternion; None für andere Knochen."""
    from mathutils import Euler
    if "leaf" in name or not any(k in name for k in _FINGERS):
        return None
    sgn = 1 if name.endswith("_r") else -1
    return Euler((0, 0, (0.5 if "thumb" in name else 1.25) * sgn)).to_quaternion()


def _posed(arm, action, frame):
    """Welt-Matrizen aller Knochen bei Aktion/Bild."""
    arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_set(int(frame))
    return {pb.name: arm.matrix_world @ pb.matrix for pb in arm.pose.bones}


def _bake(arm, name, frames, world_of, fixed=None):
    """Aktion `name` auf `arm` schreiben: world_of(f) liefert gewünschte Welt-Matrizen (nur Rotation zählt; Becken auch Position).
    Nicht gelieferte Knochen bleiben in Ruhelage, Finger immer zur Faust; fixed = {Knochen: feste lokale Matrix} (z. B. Schildarm)."""
    fixed = fixed or {}
    act = bpy.data.actions.new(name)
    inv = arm.matrix_world.inverted()
    bones = [b for b in arm.data.bones]                                  # Eltern stehen vor Kindern
    prev = {}
    for i, f in enumerate(frames):
        want = world_of(f)
        M = {}
        for b in bones:
            rest = b.matrix_local
            par = b.parent
            rel = (par.matrix_local.inverted() @ rest) if par else rest
            chain = (M[par.name] @ rel) if par else rel
            q = _fist_q(b.name)
            if b.name in fixed:
                basis = fixed[b.name]
                Mb = chain @ basis
            elif b.name in want and q is None:
                w = inv @ want[b.name]
                loc = w.to_translation() if b.name == "pelvis" else chain.to_translation()
                Mb = Matrix.Translation(loc) @ w.to_quaternion().to_matrix().to_4x4()
                basis = rel.inverted() @ (M[par.name].inverted() if par else Matrix()) @ Mb
            else:
                basis = q.to_matrix().to_4x4() if q else Matrix()
                Mb = chain @ basis
            M[b.name] = Mb
            bq = basis.to_quaternion()
            if b.name in prev:
                bq.make_compatible(prev[b.name])
            prev[b.name] = bq
            pth = 'pose.bones["%s"].' % b.name
            for k in range(4):
                fc = act.fcurves.find(pth + "rotation_quaternion", index=k) or act.fcurves.new(pth + "rotation_quaternion", index=k, action_group=b.name)
                fc.keyframe_points.insert(i, bq[k], options={'FAST'})
            if b.name == "pelvis":
                bt = basis.to_translation()
                for k in range(3):
                    fc = act.fcurves.find(pth + "location", index=k) or act.fcurves.new(pth + "location", index=k, action_group=b.name)
                    fc.keyframe_points.insert(i, bt[k], options={'FAST'})
    return act


def add_anims(arm, cls):
    """Animationen aus beiden Bibliotheken auf das Heldenskelett übertragen (als NLA-Spuren mit den Spielnamen).
    Übertragung über die gemeinsame Bezugspose A_TPose beider Bibliotheken: Welt-Drehung je Knochen relativ zu dieser Pose."""
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    libs = {}
    for key, path in (("UAL1", UAL1), ("UAL2", UAL2)):
        new = _import(path)
        src = next(o for o in new if o.type == 'ARMATURE')
        acts = {a.name.rsplit("_", 1)[0]: a for a in bpy.data.actions if a.name.endswith("_Rig" if key == "UAL1" else "_Armature")}
        libs[key] = (src, new, acts)
    ref_t = _posed(arm, libs["UAL2"][2]["A_TPose"], 0)
    for key, (src, new, acts) in libs.items():
        src.animation_data_create()
    ref_s = {}
    for key, (src, new, acts) in libs.items():
        ref_s[key] = _posed(src, acts["A_TPose"], 0)
    arm.animation_data_create()
    arm.animation_data.action = libs["UAL2"][2]["Idle_No_Loop"]          # Schildarm wie im Vorschaubild (seitlich)
    bpy.context.scene.frame_set(5)
    side_arm = {n: arm.pose.bones[n].matrix_basis.copy() for n in SHIELD_ARM}
    arm.animation_data_create()
    arm.animation_data.action = None
    for game_name, (lib, aname) in HERO_ANIMS[cls].items():
        src, new, acts = libs[lib]
        act = acts[aname]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        bmap = _RIG_MAP if lib == "UAL1" else {n: n for n in arm.pose.bones.keys() if n != "root"}
        hk = "DEF-hips" if lib == "UAL1" else "pelvis"
        h0, h1 = _posed(src, act, f0)[hk].to_translation(), _posed(src, act, f1)[hk].to_translation()
        drift = Vector((h1.x - h0.x, h1.y - h0.y, 0))                  # Vorwärtsbewegung im Clip herausrechnen (Held bleibt am Platz)
        hip_s = ref_s[lib]["DEF-hips" if lib == "UAL1" else "pelvis"].to_translation()
        hip_t = ref_t["pelvis"].to_translation()
        sc = hip_t.z / max(0.01, hip_s.z)

        def world_of(f, src=src, act=act, bmap=bmap, lib=lib, f0=f0, f1=f1, drift=drift):
            P = _posed(src, act, f)
            dr = drift * ((f - f0) / max(1, f1 - f0))
            out = {}
            for sn, tn in bmap.items():
                if sn not in P or tn not in ref_t:
                    continue
                rs = ref_s[lib][sn]
                rot = P[sn].to_quaternion() @ rs.to_quaternion().inverted() @ ref_t[tn].to_quaternion()
                loc = ref_t[tn].to_translation() + (P[sn].to_translation() - dr - rs.to_translation()) * sc
                out[tn] = Matrix.Translation(loc) @ rot.to_matrix().to_4x4()
            return out
        a = _bake(arm, game_name, range(f0, f1 + 1), world_of, side_arm if SHIELD_SIDE and game_name in ("Idle", "Run") else None)
        tr = arm.animation_data.nla_tracks.new()
        tr.name = game_name
        tr.strips.new(game_name, 0, a)
        tr.mute = False
    for key, (src, new, acts) in libs.items():
        for n in [o.name for o in new]:
            if n in bpy.data.objects:
                bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
    arm.animation_data.action = None
    return arm


def _hsv_bake(img, hue, sat, val, mul):
    """Umfärbung (wie recolor) fest ins Bild rechnen, damit glTF sie mitnimmt."""
    import numpy as np
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    rgb = px[:, :3]
    mx, mn = rgb.max(1), rgb.min(1)
    d = mx - mn
    hh = np.zeros_like(mx)
    nz = d > 1e-6
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    i0 = nz & (mx == r); i1 = nz & (mx == g) & ~i0; i2 = nz & ~i0 & ~i1
    hh[i0] = ((g - b)[i0] / d[i0]) % 6
    hh[i1] = (b - r)[i1] / d[i1] + 2
    hh[i2] = (r - g)[i2] / d[i2] + 4
    hh = (hh / 6 + hue - 0.5) % 1.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0) * sat
    s = np.clip(s, 0, 1)
    v = mx * val
    k = lambda n: (n + hh * 6) % 6
    f = lambda n: v - v * s * np.clip(np.minimum(k(n), 4 - k(n)), 0, 1)
    out = np.stack([f(5), f(3), f(1)], 1)
    if mul:
        out *= np.array(mul, dtype=np.float32)
    px[:, :3] = np.clip(out, 0, 1)
    ni = bpy.data.images.new(img.name + "_hsv", w, h, alpha=True)
    ni.pixels[:] = px.ravel()
    ni.pack()
    return ni


def bake_recolors(arm):
    """Farbknoten (Farbton/Sättigung/Multiplizieren) aller Materialien ins Bild backen und die Knoten entfernen."""
    for o in [o for o in arm.children if o.type == 'MESH']:
        for slot in o.material_slots:
            m = slot.material
            if m is None or not m.use_nodes:
                continue
            nt = m.node_tree
            hs = next((n for n in nt.nodes if n.type == 'HUE_SAT'), None)
            p = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if hs is None or p is None:
                continue
            mx = next((n for n in nt.nodes if n.type == 'MIX'), None)
            mul = tuple(mx.inputs[7].default_value)[:3] if mx else None
            src = next((l.from_node for l in nt.links if l.to_socket == hs.inputs["Color"]), None)
            args = [hs.inputs[k].default_value for k in ("Hue", "Saturation", "Value")]
            if src is not None and src.type == 'TEX_IMAGE' and src.image:
                src.image = _hsv_bake(src.image, *args, mul)
                nt.links.new(src.outputs["Color"], p.inputs["Base Color"])
            else:
                import colorsys
                c = hs.inputs["Color"].default_value
                h, s, v = colorsys.rgb_to_hsv(*c[:3])
                c2 = colorsys.hsv_to_rgb((h + args[0] - 0.5) % 1, min(1, s * args[1]), v * args[2])
                if mul:
                    c2 = [a * b for a, b in zip(c2, mul)]
                p.inputs["Base Color"].default_value = (*c2, 1)
            nt.nodes.remove(hs)
            if mx:
                nt.nodes.remove(mx)


def export_hero(cls, out):
    """Held bauen, Animationen übertragen, Umfärbungen backen und als GLB speichern (für Godot)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = 30
    arm = build_hero(cls)
    arm.name = "Hero"
    bake_recolors(arm)
    for img in list(bpy.data.images):                                  # gleiche Textur nur einmal, höchstens 1024 px (Held ist im Spiel klein)
        base = bpy.data.images.get(img.name[:-4]) if img.name[-4:-3] == "." else None
        if base is not None:
            img.user_remap(base)
            bpy.data.images.remove(img)
    for img in bpy.data.images:
        if img.size[0] > 1024:
            img.scale(1024, 1024)
    add_anims(arm, cls)
    bpy.ops.object.select_all(action='DESELECT')
    keep = [arm] + [o for o in bpy.data.objects if o.parent == arm]
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in keep:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_animation_mode='NLA_TRACKS',
                              export_force_sampling=True, export_optimize_animation_size=True, export_def_bones=False,
                              export_apply=False, export_yup=True)
    print("EXPORT", out)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "export":
        export_hero(argv[1], argv[2])
    if argv and argv[0] == "preview":
        preview(argv[1], argv[2:])
    elif argv and argv[0] == "all":
        preview_all(argv[1], argv[2:] or None)
