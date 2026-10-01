"""Shared Blender helpers for the Llama Village character generators (Blender 5.2).

Adapted from the Llama Whisperer generators. Materials are named Principled
BSDFs whose base colour comes from the mesh's `Col` vertex colours; the game
tunes them into its PBR materials by name (`lib/render/character_look.dart`).
"""

import json
import math
import struct

import bpy
from mathutils import Matrix

R = math.radians
_materials = {}

# Authoring frame (+X forward, +Y left, +Z up) -> Blender world, where the
# character faces -Y so the glTF export (+Y up) faces +Z.
T = Matrix.Rotation(R(-90), 4, 'Z')


def hexc(h):
    """sRGB hex string to linear RGB (glTF colours are linear)."""
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def scale(c, k):
    return tuple(x * k for x in c)


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def mat(name, rough=0.8, metal=0.0, emission=0.0):
    """A material whose base colour is the `Col` vertex colour attribute."""
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emission:
        nt.links.new(attr.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emission
    nt.links.new(b.outputs[0], out.inputs[0])
    _materials[name] = m
    return m


def triangles(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def evaluated_mesh(o, matrix=None):
    """Mesh copy of `o` with modifiers applied, in world space (or `matrix`)."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    me.transform(matrix if matrix is not None else o.matrix_world)
    return me


def decimate(ob, target_tris):
    tris = triangles(ob)
    if tris <= target_tris:
        return
    md = ob.modifiers.new("dec", 'DECIMATE')
    md.ratio = target_tris / tris
    md.use_collapse_triangulate = True
    me = evaluated_mesh(ob, Matrix.Identity(4))
    ob.modifiers.clear()
    old = ob.data
    name = old.name
    ob.data = me
    bpy.data.meshes.remove(old)
    me.name = name


def set_colors(ob, color_of):
    """Writes a point-domain `Col` attribute from `color_of(index, co)`."""
    me = ob.data
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    attr = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    for v in me.vertices:
        r, g, b = color_of(v.index, v.co)
        attr.data[v.index].color = (r, g, b, 1.0)
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = 0


def export_glb(path, objects):
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objects)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', export_yup=True, export_apply=False, use_selection=True,
        export_cameras=False, export_lights=False, export_skins=True, export_morph=True,
        export_morph_normal=True, export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_frame_range=False, export_def_bones=False,
        export_texcoords=False, export_vertex_color='ACTIVE',
    )


def strip_channels(path, procedural):
    """Drops the animation channels of the `procedural` bones (and every
    scale channel, which no clip uses), so the game can drive those bones
    without the clips overwriting them each frame."""
    with open(path, 'rb') as f:
        data = f.read()
    json_len = struct.unpack('<I', data[12:16])[0]
    doc = json.loads(data[20:20 + json_len])
    rest = data[20 + json_len:]
    names = [n.get('name') for n in doc['nodes']]
    for anim in doc.get('animations', []):
        kept, remap, samplers = [], {}, []
        for ch in anim['channels']:
            if names[ch['target']['node']] in procedural or ch['target']['path'] == 'scale':
                continue
            s = ch['sampler']
            if s not in remap:
                remap[s] = len(samplers)
                samplers.append(anim['samplers'][s])
            ch['sampler'] = remap[s]
            kept.append(ch)
        anim['channels'] = kept
        anim['samplers'] = samplers
    out = json.dumps(doc, separators=(',', ':')).encode()
    out += b' ' * ((4 - len(out) % 4) % 4)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(out) + len(rest)))
        f.write(struct.pack('<II', len(out), 0x4E4F534A))
        f.write(out)
        f.write(rest)
