# Test: Blender (Kommandozeile) erzeugt einen Würfel und exportiert ihn als GLB.
# Aufruf: tools-extern/blender-4.2.9-windows-x64/blender.exe --background --python godot/tools/blender/test_export.py -- <ausgabe.glb>
import bpy, sys

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "test.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
print("EXPORT OK:", out)
