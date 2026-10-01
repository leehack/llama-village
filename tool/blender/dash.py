"""Builds assets/dash.glb: Dash, the player's little blue bird (Blender 5.2).

A round blue bird with a lighter belly, big glossy eyes, a small beak, a
head tuft, wing meshes on wing bones and tail feathers. Origin at the body
centre; faces glTF +Z like the llamas.

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
BLUE, BELLY, DEEP, TUFT = "#3E8EF0", "#BDE6FF", "#2462C4", "#2FB6E8"
BEAK = "#F5A623"
RAD = (0.36, 0.33, 0.34)
FWD, UP = Vector((1, 0, 0)), Vector((0, 0, 1))


def _v(*a):
    return Vector(a)


def _body():
    B = L.Balls("DashBalls")
    B.ellipsoid(_v(0, 0, 0), RAD)
    B.ball(_v(0.12, 0, -0.1), 0.24)  # a round chest
    B.ball(_v(-0.16, 0, 0.02), 0.22)
    for i, (y, tilt, length) in enumerate(((0.0, -35, 0.13), (0.05, -50, 0.1), (-0.05, -50, 0.1))):
        q = Quaternion((1, 0, 0), math.radians(y * 300)) @ Quaternion((0, 1, 0), math.radians(tilt))
        B.ellipsoid(_v(-0.02 - 0.03 * i, y, RAD[2] + 0.05), (0.035, 0.03, length), rot=q, stiff=3.0)
    return B


def _colors():
    blue, belly, deep, tuft = c.hexc(BLUE), c.hexc(BELLY), c.hexc(DEEP), c.hexc(TUFT)
    inv = c.T.inverted()
    belly_dir = _v(0.75, 0, -0.62).normalized()

    def col(i, co):
        p = inv @ co
        if p.z > RAD[2] + 0.02:
            return tuft
        d = p.normalized() if p.length > 1e-6 else p
        out = c.mix(blue, belly, c.smoothstep(0.45, 0.72, d.dot(belly_dir)))
        return c.mix(out, deep, c.smoothstep(0.3, 0.8, -d.x) * 0.5)
    return col


def _wings_tail_feet(geo):
    blue, deep, beak = c.hexc(BLUE), c.hexc(DEEP), c.hexc(BEAK)
    for side, bone in ((1, "wing_L"), (-1, "wing_R")):
        root = _v(-0.02, side * 0.3, 0.04)
        grp = ((bone, 1.0),)

        def shade(lp, p, root=root):
            t = (abs(p.y) - abs(root.y)) / 0.36
            return c.mix(blue, deep, c.smoothstep(0.3, 0.9, t))
        # Three overlapping feathers make a scalloped wing edge.
        for dx, dy, dz, sx, sy, a in ((0.02, 0.12, 0.0, 0.17, 0.15, 0), (-0.06, 0.24, -0.02, 0.12, 0.13, -15),
                                      (-0.12, 0.32, -0.04, 0.08, 0.1, -30)):
            centre = root + _v(dx, side * dy, dz)
            M = Matrix.Translation(centre) @ Matrix.Rotation(math.radians(a * side), 4, 'Z') @ Matrix.Diagonal((sx, sy, 0.035, 1))
            geo.sphere(M, shade, "Feather", seg=14, rings=8, group=grp)
    for a, length in ((0, 0.2), (22, 0.17), (-22, 0.17)):
        d = (Matrix.Rotation(math.radians(a), 3, 'Z') @ _v(-1, 0, 0.35)).normalized()
        centre = _v(-0.3, 0, -0.04) + d * length * 0.7
        n, s, u = basis_from(d, up=UP)
        geo.sphere(frame(centre, n, s, u, length, 0.05, 0.016), c.mix(blue, deep, 0.6), "Feather", seg=12, rings=6,
                   group=(("tail", 1.0),))
    for side in (1, -1):
        for a in (-25, 0, 25):
            d = Matrix.Rotation(math.radians(a), 3, 'Z') @ FWD
            p = _v(0.06, side * 0.1, -0.33) + d * 0.04
            geo.sphere(frame(p, d, UP.cross(d).normalized(), UP, 0.04, 0.012, 0.012), beak, "Feather", seg=8, rings=5,
                       group=(("body", 1.0),))


def _face(surf, materials):
    geo = Geo(MORPHS)
    white, pupil, iris = c.hexc("#FFFFFF"), c.hexc("#0B0A12"), c.hexc("#2A3A5E")
    lid, brow_col = c.hexc(BLUE), c.hexc("#173C7A")
    origin = _v(0, 0, 0.06)
    eyes = {}
    for side, bone in ((1, "lid_L"), (-1, "lid_R")):
        hit, nrm = surf(origin, L._dir(30, 16, side))
        n, sv, u = basis_from((nrm + FWD * 0.9).normalized())
        r, w = 0.105, 0.088
        centre = hit - n * r * 0.38
        M = frame(centre, n, sv, u, r, w, r)
        geo.sphere(M, white, "EyeGloss", seg=20, rings=12)
        gaze = (n + FWD * 0.5).normalized()
        gl = Vector((gaze.dot(n) / r, gaze.dot(sv) / w, gaze.dot(u) / r)).normalized()
        q = Vector((0, 0, 1)).rotation_difference(gl).to_matrix().to_4x4()
        for scale, cap, col, seg in ((1.012, 44, iris, 18), (1.022, 30, pupil, 16)):
            pts, faces = sphere_grid(seg, 6, 2.0, cap=math.radians(cap))
            geo.add([M @ (q @ Vector(p) * scale) for p in pts], faces, col, "EyeGloss")
        for off, size in (((0.5, 0.3), 0.3), ((-0.35, -0.3), 0.14)):
            d = (gl + Vector((0, 0, 1)) * off[0] + Vector((0, side, 0)) * off[1]).normalized()
            d, t1, t2 = basis_from(d)
            geo.sphere(M @ frame(d * 1.01, d, t1, t2, size * 0.15, size, size), (1, 1, 1), "EyeShine", seg=8, rings=6)
        grp = ((bone, 1.0),)
        open_rot = Matrix.Rotation(math.radians(L.LID_OPEN + 14), 4, -sv)
        Ml = Matrix.Translation(centre) @ open_rot @ Matrix.Translation(-centre) @ frame(centre, n, sv, u, r * 1.08, w * 1.09, r * 1.08)
        geo.sphere(Ml, lid, "Face", seg=18, rings=10, group=grp, zmin=0.0)
        rim = [Ml @ Vector((math.cos(a), math.sin(a), 0.0)) for a in [math.radians(-100 + 200 * i / 14) for i in range(15)]]
        geo.tube(rim, lambda t: 0.008 * (0.6 + 0.4 * math.sin(math.pi * t)), c.hexc("#0E2450"), "Face", seg=6, group=grp)
        eyes[side] = dict(centre=centre, n=n, s=sv, u=u, r=r)
        c0 = centre + u * r * 1.5 + n * r * 0.25

        def path(lift=0.0, inner=0.0, side=side, sv=sv, u=u, c0=c0, w=w):
            pts = []
            for i in range(6):
                k = -1 + 2 * i / 5
                inner_t = max(0.0, -k if (sv.y * side) > 0 else k)
                p = c0 + sv * k * w * 0.85 + u * (lift + inner * inner_t + 0.01 * (1 - k * k))
                h2, n2 = surf(origin, p - origin)
                pts.append(h2 + n2 * 0.008)
            return pts
        geo.tube(path(), lambda t: 0.012 * (0.6 + 0.4 * math.sin(math.pi * t)), brow_col, "Face", seg=6,
                 shapes={"Happy": path(lift=0.03), "Sad": path(inner=0.035)}, flat=0.7)
    # Beak: upper and lower halves; Happy opens it in a chirp.
    tip, _ = surf(_v(0, 0, 0.0), L._dir(0, 2))
    base = tip - FWD * 0.03
    beak, beak_dark = c.hexc(BEAK), c.hexc("#D9861A")
    up_beak = frame(base + FWD * 0.045 + UP * 0.012, FWD, _v(0, 1, 0), UP, 0.1, 0.05, 0.035)
    geo.sphere(up_beak, beak, "Face", seg=12, rings=8, zmin=-0.1, shapes={"Sad": Matrix.Translation((0, 0, -0.008)) @ up_beak})
    low = frame(base + FWD * 0.03 - UP * 0.005, FWD, _v(0, 1, 0), UP, 0.07, 0.045, 0.03)
    happy_low = Matrix.Translation(base) @ Matrix.Rotation(math.radians(22), 4, 'Y') @ Matrix.Translation(-base) @ low
    geo.sphere(low, beak_dark, "Face", seg=12, rings=8, zmax=0.2, shapes={"Happy": happy_low})
    for side in (1, -1):
        hit, nrm = surf(_v(0, 0, 0), L._dir(48, -12, side))
        nn, ns, nu = basis_from(nrm)
        geo.sphere(frame(hit - nn * 0.006, nn, ns, nu, 0.01, 0.045, 0.03), c.hexc("#FF9AB8"), "Face", seg=12, rings=6)
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
    c.decimate(body, 5200)
    body.data.materials.append(materials["Feather"])
    surf = L._surface(BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get()))
    parts = Geo()
    _wings_tail_feet(parts)
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
