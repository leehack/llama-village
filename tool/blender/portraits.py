"""Renders the inspector portraits into assets/portraits/<id>.png (Blender 5.2).

Each llama's glb is imported in its rest pose and framed head and shoulders
from the front three-quarter, on a transparent background, so the UI can
put it on any card colour.
"""

import math
import os

import bpy
from mathutils import Vector

import common as c
import llama

SIZE = 256
# A touch of each llama's character in the portrait.
EXPRESSION = {"pip": ("Happy", 0.5), "mo": ("Happy", 0.6), "june": ("Happy", 0.3), "bramble": ("Sleepy", 0.35),
              "clover": ("Happy", 0.2)}


def setup_render(res_x, res_y, samples=32):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.eevee.taa_render_samples = samples
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.view_settings.view_transform = 'AgX'
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.75, 0.8, 0.9, 1)
    bg.inputs["Strength"].default_value = 0.7
    scene.world = world
    for name, rot, energy in (("Key", (50, 0, -35), 4.0), ("Fill", (65, 0, 140), 1.2), ("Rim", (20, 0, 180), 2.0)):
        ld = bpy.data.lights.new(name, 'SUN')
        ld.energy = energy
        ld.angle = math.radians(8)
        lo = bpy.data.objects.new(name, ld)
        lo.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(lo)


def camera(loc, target, lens=50):
    cd = bpy.data.cameras.new("Cam")
    cd.lens = lens
    co = bpy.data.objects.new("Cam", cd)
    bpy.context.scene.collection.objects.link(co)
    co.location = loc
    direction = Vector(target) - Vector(loc)
    co.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = co
    return co


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    assets = os.path.dirname(out_dir)
    for name in llama.ORDER:
        c.reset()
        setup_render(SIZE, SIZE, samples=48)
        for o in import_glb(os.path.join(assets, f"llama_{name}.glb")):
            if o.type == 'ARMATURE' and o.animation_data:
                o.animation_data.action = None
            if o.type == 'MESH' and o.data.shape_keys:
                morph, w = EXPRESSION[name]
                o.data.shape_keys.key_blocks[morph].value = w
        P = llama.LLAMAS[name]
        hx, hz = P["head"]
        # Blender frame: the llama faces -Y, its left is +X.
        target = Vector((0.0, -hx + 0.02, hz - 0.02))
        loc = target + Vector((-1.4, -2.6, 0.3))
        camera(loc, target, lens=80)
        bpy.context.scene.render.filepath = os.path.join(out_dir, f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print("PORTRAIT", name)
