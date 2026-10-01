"""Builds assets/dash.glb: Dash, the player's little blue bird (Blender 5.2).

A fan homage to the Flutter/Dart mascot, modelled from the plush and
Dashatar photos on docs.flutter.dev/dash: a round sky-blue hummingbird ball
with no neck, a darker-blue mask around big eyes, a white bib, a long
straight beak, a dark-blue fan crest and tail, paddle wings and thin legs.
Origin at the body centre; faces glTF +Z like the llamas.

  DashRig       armature: root, body, head, wing_L, wing_R, tail, lid_L, lid_R
    Body        skinned: Feather (vertex coloured)
    Face        skinned to head and the lid bones: EyeGloss, EyeShine, Face;
                morph targets Happy, Sad
Clips: Fly (fast flaps), Hover (slower flaps and a bob), Happy (a wiggle),
Sad (a droop). The game blends them, banks the bird into turns, adds the
landing hop and drives the lids.
"""

import math

import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

import common as c
import llama as L
from geo import Geo, basis_from, frame, sphere_grid

FPS = 30
MORPHS = ("Happy", "Sad")
PROCEDURAL = ("root", "lid_L", "lid_R")
BLUE, MASK, BIB, DEEP = "#45ACEF", "#2366CF", "#F6FAFF", "#1C4FC0"
BEAK, LEGS = "#8A7A6C", "#7A6656"
RAD = 0.36
FWD, UP = Vector((1, 0, 0)), Vector((0, 0, 1))
EYE_AZ, EYE_EL = 25, 13


def _v(*a):
    return Vector(a)


def _dir(az, el, side=1):
    return L._dir(az, el, side)


def _body():
    B = L.Balls("DashBalls")
    B.ellipsoid(_v(0, 0, 0), (RAD, RAD * 1.02, RAD * 0.98))
    return B


def _mask(d):
    """How far `d` is inside the goggle-shaped mask (0..1): two discs round
    the eyes joined across the face, soft at the edge."""
    best = 0.0
    for side in (1, -1):
        best = max(best, c.smoothstep(math.radians(33), math.radians(31), d.angle(_dir(EYE_AZ, EYE_EL, side))))
    return max(best, c.smoothstep(math.radians(27), math.radians(25), d.angle(_dir(0, EYE_EL - 4))))


def _colors():
    blue, mask, bib = c.hexc(BLUE), c.hexc(MASK), c.hexc(BIB)
    inv = c.T.inverted()
    bib_dir = _dir(0, -38)

    def col(i, co):
        d = (inv @ co).normalized()
        # The white bib, a crescent under the mask.
        out = c.mix(blue, bib, c.smoothstep(math.cos(math.radians(54)), math.cos(math.radians(52)), d.dot(bib_dir)))
        return c.mix(out, mask, _mask(d))
    return col


def _feather(geo, base, direction, length, width, color, group, side_axis=None):
    n, s, u = basis_from(direction, up=side_axis or UP)
    geo.sphere(frame(base + direction * length * 0.5, n, s, u, length * 0.5, width, 0.014), color, "Feather", seg=12,
               rings=6, group=group)


def _wings_tail_legs_crest(geo):
    blue, deep, legs = c.hexc(BLUE), c.hexc(DEEP), c.hexc(LEGS)
    for side, bone in ((1, "wing_L"), (-1, "wing_R")):
        root = _v(-0.03, side * (RAD - 0.03), 0.02)
        grp = ((bone, 1.0),)

        def shade(lp, p, root=root):
            return c.mix(blue, c.mix(blue, deep, 0.45), c.smoothstep(0.08, 0.22, (p - root).length))
        # A rounded paddle, out and a little up.
        M = Matrix.Translation(root + _v(-0.02, side * 0.13, 0.1)) @ Matrix.Rotation(math.radians(-55 * side), 4, 'X') \
            @ Matrix.Diagonal((0.11, 0.17, 0.04, 1))
        geo.sphere(M, shade, "Feather", seg=14, rings=8, group=grp)
    # Fan crest on top, in the body's mid plane.
    # The crest fans out side to side, so it reads from the front.
    for k, a in enumerate((-48, -24, 0, 24, 48)):
        d = (Matrix.Rotation(math.radians(-14), 3, 'Y') @ Matrix.Rotation(math.radians(a), 3, 'X') @ UP).normalized()
        _feather(geo, _v(-0.04, 0, RAD - 0.05), d, 0.2 - 0.02 * abs(k - 2), 0.05, c.hexc(DEEP), (("head", 1.0),),
                 side_axis=FWD)
    # Fan tail.
    for a in (-34, -12, 12, 34):
        d = (Matrix.Rotation(math.radians(a), 3, 'Z') @ _v(-1, 0, 0.45)).normalized()
        _feather(geo, _v(-RAD + 0.05, 0, -0.02), d, 0.24, 0.06, c.hexc(DEEP), (("tail", 1.0),))
    # Thin legs and three-toed feet.
    for side in (1, -1):
        hip = _v(0.02, side * 0.1, -RAD + 0.04)
        foot = hip + _v(0.02, side * 0.01, -0.17)
        geo.tube([hip, (hip + foot) / 2 + _v(-0.01, 0, 0), foot], 0.014, legs, "Feather", seg=6, group=(("body", 1.0),))
        for a in (-30, 0, 30):
            d = Matrix.Rotation(math.radians(a), 3, 'Z') @ FWD
            geo.tube([foot, foot + d * 0.06 - UP * 0.01], lambda t: 0.012 * (1 - 0.5 * t), legs, "Feather", seg=5,
                     group=(("body", 1.0),))


def _face(surf, materials):
    geo = Geo(MORPHS)
    white, pupil, iris = c.hexc("#FFFFFF"), c.hexc("#0A0A10"), c.hexc("#1E6E78")
    lid = c.hexc(MASK)
    origin = _v(0, 0, 0)
    eyes = {}
    for side, bone in ((1, "lid_L"), (-1, "lid_R")):
        hit, nrm = surf(origin, _dir(EYE_AZ, EYE_EL, side))
        n, sv, u = basis_from((nrm + FWD * 0.5).normalized())
        r, w = 0.09, 0.085
        centre = hit - n * r * 0.62
        M = frame(centre, n, sv, u, r, w, r)
        geo.sphere(M, white, "EyeGloss", seg=20, rings=12,
                   shapes={"Happy": frame(centre, n, sv, u, r * 1.06, w * 1.06, r * 1.06)})
        gaze = (n + FWD * 0.6).normalized()
        gl = Vector((gaze.dot(n) / r, gaze.dot(sv) / w, gaze.dot(u) / r)).normalized()
        q = Vector((0, 0, 1)).rotation_difference(gl).to_matrix().to_4x4()
        for scale, cap, col, seg in ((1.012, 36, iris, 18), (1.022, 31, pupil, 16)):
            pts, faces = sphere_grid(seg, 6, 2.0, cap=math.radians(cap))
            geo.add([M @ (q @ Vector(p) * scale) for p in pts], faces, col, "EyeGloss",
                    shapes={"Happy": [frame(centre, n, sv, u, r * 1.06, w * 1.06, r * 1.06) @ (q @ Vector(p) * scale) for p in pts]})
        for off, size in (((0.5, 0.35), 0.3), ((-0.3, -0.3), 0.13)):
            d = (gl + Vector((0, 0, 1)) * off[0] + Vector((0, side, 0)) * off[1]).normalized()
            d, t1, t2 = basis_from(d)
            geo.sphere(M @ frame(d * 1.03, d, t1, t2, size * 0.15, size, size), (1, 1, 1), "EyeShine", seg=8, rings=6)
        grp = ((bone, 1.0),)
        open_rot = Matrix.Rotation(math.radians(L.LID_OPEN + 46), 4, -sv)
        Ml = Matrix.Translation(centre) @ open_rot @ Matrix.Translation(-centre) @ frame(centre, n, sv, u, r * 1.08, w * 1.09, r * 1.08)
        geo.sphere(Ml, lid, "Face", seg=18, rings=10, group=grp, zmin=0.0)
        rim = [Ml @ Vector((math.cos(a), math.sin(a), 0.0)) for a in [math.radians(-100 + 200 * i / 14) for i in range(15)]]
        geo.tube(rim, lambda t: 0.006 * (0.6 + 0.4 * math.sin(math.pi * t)), c.hexc("#123E86"), "Face", seg=6, group=grp)
        eyes[side] = dict(centre=centre, n=n, s=sv, u=u, r=r)
    # The long straight beak, from the middle of the face, angled down.
    root, _ = surf(origin, _dir(0, 2))
    beak = c.hexc(BEAK)

    def cone(tilt):
        d = (Matrix.Rotation(math.radians(tilt), 3, 'Y') @ FWD).normalized()
        n, s, u = basis_from(d)
        base = root - d * 0.03
        return frame(base + d * 0.19, s, u, d, 0.066, 0.056, 0.19)
    geo.cylinder(cone(20), beak, "Face", seg=14, r_top=0.14, shapes={"Happy": cone(10), "Sad": cone(38)})
    return geo.to_object("Face", materials, matrix=Matrix.Identity(4)), eyes


def _rig(eyes):
    arm_data = bpy.data.armatures.new("DashRig")
    arm = bpy.data.objects.new("DashRig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    rot3 = c.T.to_3x3()

    def bone(name, head, tail, parent=None, deform=True, roll_up=UP):
        b = eb.new(name)
        b.head = c.T @ Vector(head)
        b.tail = c.T @ Vector(tail)
        b.align_roll(rot3 @ roll_up)
        b.use_deform = deform
        if parent:
            b.parent = eb[parent]
        return b

    bone("root", (0, 0, -0.35), (0, 0, -0.15), deform=False, roll_up=FWD)
    bone("body", (0, 0, -0.2), (0, 0, 0.05), "root", roll_up=FWD)
    bone("head", (0.0, 0, 0.05), (0.05, 0, 0.32), "body", roll_up=FWD)
    for side, name in ((1, "wing_L"), (-1, "wing_R")):
        bone(name, (-0.02, side * 0.26, 0.04), (-0.02, side * 0.6, 0.04), "body", deform=False)
    bone("tail", (-0.26, 0, -0.04), (-0.48, 0, 0.04), "body", deform=False)
    for side, name in ((1, "lid_L"), (-1, "lid_R")):
        e = eyes[side]
        bone(name, e["centre"], e["centre"] + e["s"] * 0.05, "head", deform=False, roll_up=e["u"])
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def _pose_fly(t):
    w = 2 * math.pi
    flap = math.sin(w * t)
    return {
        "body": ([("lat", 4 * math.sin(w * t + 1.2))], (0, 0, -0.025 * flap)),
        "wing_L": ([("fwd", -(10 + 55 * flap)), ("lat", 8 * math.cos(w * t))], None),
        "wing_R": ([("fwd", 10 + 55 * flap), ("lat", 8 * math.cos(w * t))], None),
        "tail": ([("lat", -6 + 6 * math.sin(w * t + 0.5))], None),
        "head": ([("lat", -3 * math.sin(w * t + 0.4))], None),
    }


def _pose_hover(t):
    w = 2 * math.pi
    flap = math.sin(2 * w * t)
    return {
        "body": ([("lat", -6 + 2 * math.sin(w * t))], (0, 0, 0.04 * math.sin(w * t))),
        "wing_L": ([("fwd", -(15 + 45 * flap)), ("lat", 15 * math.cos(2 * w * t))], None),
        "wing_R": ([("fwd", 15 + 45 * flap), ("lat", 15 * math.cos(2 * w * t))], None),
        "tail": ([("lat", 10 + 8 * math.sin(w * t + 0.8))], None),
        "head": ([("lat", 6 - 3 * math.sin(w * t + 0.5)), ("up", 6 * math.sin(w * t))], None),
    }


def _pose_happy(t):
    w = 2 * math.pi
    wig = math.sin(2 * w * t)
    flut = math.sin(6 * w * t)
    return {
        "body": ([("fwd", 16 * wig), ("lat", -8)], (0, 0.03 * wig, 0.05 * abs(math.sin(2 * w * t)))),
        "wing_L": ([("fwd", 45 + 20 * flut)], None),
        "wing_R": ([("fwd", -(45 + 20 * flut))], None),
        "tail": ([("up", 25 * math.sin(4 * w * t)), ("lat", -10)], None),
        "head": ([("fwd", -10 * wig), ("lat", -6)], None),
    }


def _pose_sad(t):
    w = 2 * math.pi
    flap = math.sin(2 * w * t)
    return {
        "body": ([("lat", 10)], (0, 0, -0.05 + 0.015 * math.sin(w * t))),
        "wing_L": ([("fwd", -(40 + 10 * flap)), ("lat", 15)], None),
        "wing_R": ([("fwd", 40 + 10 * flap), ("lat", 15)], None),
        "tail": ([("lat", 30)], None),
        "head": ([("lat", 22), ("fwd", 6 * math.sin(w * t))], None),
    }


def _actions(arm):
    bpy.context.scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = 'LINEAR'
    arm.animation_data_create()
    rot3 = c.T.to_3x3()
    axes = {"lat": rot3 @ Vector((0, 1, 0)), "fwd": rot3 @ Vector((1, 0, 0)), "up": rot3 @ Vector((0, 0, 1))}
    keyed = [b.name for b in arm.pose.bones if b.name not in PROCEDURAL]
    for name, frames, pose in (("Fly", 8, _pose_fly), ("Hover", 15, _pose_hover), ("Happy", 24, _pose_happy), ("Sad", 36, _pose_sad)):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for f in range(frames + 1):
            p = pose(f / frames)
            for bn in keyed:
                pb = arm.pose.bones[bn]
                pb.rotation_mode = 'QUATERNION'
                rots, loc = p.get(bn, ([], None))
                to_local = pb.bone.matrix_local.to_3x3().inverted()
                q = Quaternion()
                for axis, deg in rots:
                    q = Quaternion((to_local @ axes[axis]).normalized(), math.radians(deg)) @ q
                pb.rotation_quaternion = q
                pb.location = to_local @ (rot3 @ Vector(loc)) if loc else Vector()
                pb.keyframe_insert("rotation_quaternion", frame=f)
                pb.keyframe_insert("location", frame=f)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, act)
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()


def build(out_path):
    c.reset()
    materials = dict(
        Feather=c.mat("Feather", rough=0.55),
        EyeGloss=c.mat("EyeGloss", rough=0.08),
        EyeShine=c.mat("EyeShine", rough=0.1, emission=3.0),
        Face=c.mat("Face", rough=0.6),
    )
    body = _body().to_mesh("Body")
    c.decimate(body, 7000)
    body.data.materials.append(materials["Feather"])
    surf = L._surface(BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get()))
    parts = Geo()
    _wings_tail_legs_crest(parts)
    face, eyes = _face(surf, materials)
    extra = parts.to_object("Parts", materials, matrix=Matrix.Identity(4))
    for ob in (body, face, extra):
        if ob.data.shape_keys:
            ob.data.transform(c.T, shape_keys=True)
        else:
            ob.data.transform(c.T)
    c.set_colors(body, _colors())
    arm = _rig(eyes)
    L._skin(body, [extra], arm)
    body.name = body.data.name = "Body"
    L._bind_rigid(face, arm)
    for b in ("wing_L", "wing_R", "tail", "lid_L", "lid_R"):
        arm.data.bones[b].use_deform = True
    _actions(arm)
    face.data.name = "Face"
    print("DASH tris", {o.name: c.triangles(o) for o in (body, face)})
    c.export_glb(out_path, [arm, body, face])
    c.strip_channels(out_path, PROCEDURAL)
    print("EXPORTED", out_path)
