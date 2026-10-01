"""Builds assets/llama_<id>.glb: the five village llamas (Blender 5.2).

Every llama shares one skeleton (same bones, names and hierarchy; each
body moves the joints to fit) and the same clip generators, so every clip
works on every llama and the game drives them with one code path.

Layout (glTF, Y up, metres, facing +Z; flutter_scene negates Z on import,
so in the game a llama faces -Z):
  LlamaRig              armature, origin on the ground between the hooves
    Body                skinned: Wool (vertex coloured), Hoof
    Face                skinned to head and the lid bones; EyeGloss,
                        EyeShine, Face; morph targets Happy, Sulky,
                        Surprised, Sleepy, Talk (in that order)
    Acc_head/neck/spine rigid children of those bones (accessories)
    Scarf, ScarfTail    Pip only: rigid children of neck and scarf
Bones: root, spine, belly, neck_aim, neck, head_aim, head, ear_L, ear_R,
lid_L, lid_R, scarf, tail, leg_{FL,FR,HL,HR}_{upper,lower}. The game
drives neck_aim, head_aim (look-at), ear_*, lid_* (blinks and lids), tail,
scarf and belly (breathing); the clips never touch them.
Clips: Idle, Walk (per-llama gait), Gallop. All loop.
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

import common as c
from geo import Geo, basis_from, frame, sphere_grid

FPS = 30
K = 0.5748  # visual radius of an isolated metaball element of radius 1
MORPHS = ("Happy", "Sulky", "Surprised", "Sleepy", "Talk")
PROCEDURAL = ("root", "neck_aim", "head_aim", "ear_L", "ear_R", "lid_L", "lid_R", "scarf", "tail", "belly")
# Lid rotation range (degrees) from open to shut, about each lid bone's
# axis; the game reads it as LlamaRigSpec.lidTravel.
LID_OPEN = 38.0
LID_SHUT = -72.0

FWD = Vector((1, 0, 0))
UP = Vector((0, 0, 1))

BASE = dict(
    wool="#EBD9B8", muzzle="#FFF4E4", inner="#F2A6A6", hoof="#3B2A22", iris="#7A4A26", brow="#4A3226",
    lid="#E0CDAE",
    body=(0.0, 0.80), half=(0.50, 0.33, 0.31),
    leg_x=(0.31, -0.31), leg_y=0.17, leg_r=0.066, thigh_r=0.115, knee=0.36,
    neck=((0.36, 1.02), (0.44, 1.40)), neck_r=0.125,
    head=(0.48, 1.54), head_half=(0.235, 0.215, 0.215),
    snout=(0.19, -0.075), snout_half=(0.135, 0.135, 0.105),
    ear=dict(style="normal", length=0.27, width=0.052, at=(-0.04, 0.115, 0.15)),
    eye=dict(r=0.07, w=0.062, az=34, el=9, iris_cap=33, pupil_cap=17),
    wool_n=46, wool_r=0.10, wool_seed=3, wool_depth=0.97, wool_stiff=3.0, shaggy=0.0, collar=1.0,
    tuft="tuft", chin=False, bangs=False, lashes=0, blush="#F4A0A0", freckles=0, flour=False, messy=0.0,
    tail_r=0.10,
    gait=dict(cycle=0.85, stride=18, knee=50, front_knee=50, bounce=0.02, neck=0, head=0, head_bob=3, sway=0,
              pitch=1.5),
    idle=dict(rate=1.0, head=8, sway=1.0),
    gallop=dict(stride=32, knee=55, bob=0.05, neck_amp=10, lean=0),
)


def _llama(**over):
    p = {k: (dict(v) if isinstance(v, dict) else v) for k, v in BASE.items()}
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(p.get(k), dict):
            p[k].update(v)
        else:
            p[k] = v
    return p


LLAMAS = {
    # Vain singer: slender and tall, glossy lashes, a pompadour, the red scarf.
    "pip": _llama(
        wool="#F6F0E6", muzzle="#FFF8EE", lid="#EDE3D2", iris="#8A5426", brow="#7A5242",
        body=(0.0, 0.94), half=(0.47, 0.27, 0.27), leg_y=0.15, leg_r=0.052, thigh_r=0.095, knee=0.44,
        neck=((0.34, 1.12), (0.47, 1.62)), neck_r=0.105,
        head=(0.52, 1.76), head_half=(0.215, 0.195, 0.205), snout=(0.17, -0.07), snout_half=(0.12, 0.115, 0.095),
        ear=dict(length=0.25, width=0.046), eye=dict(r=0.074, w=0.064, az=33, el=10),
        wool_n=60, wool_r=0.085, tuft="pompadour", lashes=3, collar=0.8,
        gait=dict(cycle=0.72, stride=20, knee=78, front_knee=95, bounce=0.04, neck=-6, head=-4, head_bob=4, pitch=2),
        idle=dict(rate=1.1, head=6, sway=1.2),
        gallop=dict(stride=34, knee=65, bob=0.06),
    ),
    # Clumsy baker: big, round and stocky on short legs, floppy ears.
    "mo": _llama(
        wool="#C99A6B", muzzle="#F3DDBF", lid="#B98A5E", inner="#E7A08E", iris="#7A4A1E", brow="#5A3A22",
        hoof="#3A2A20",
        body=(0.0, 0.70), half=(0.58, 0.43, 0.40), leg_x=(0.33, -0.33), leg_y=0.21, leg_r=0.078, thigh_r=0.14,
        knee=0.22,
        neck=((0.42, 0.98), (0.50, 1.24)), neck_r=0.16,
        head=(0.56, 1.40), head_half=(0.27, 0.255, 0.245), snout=(0.21, -0.085), snout_half=(0.15, 0.165, 0.125),
        ear=dict(style="floppy", length=0.25, width=0.07, at=(-0.03, 0.17, 0.11)),
        eye=dict(r=0.068, w=0.06, az=33, el=8),
        wool_n=70, wool_r=0.105, tuft="puff", flour=True, collar=1.2, tail_r=0.12,
        gait=dict(cycle=1.05, stride=15, knee=26, front_knee=30, bounce=0.035, neck=4, head=4, head_bob=7, sway=4.5,
                  pitch=1),
        idle=dict(rate=0.8, head=5, sway=1.6),
        gallop=dict(stride=26, knee=45, bob=0.07, neck_amp=12),
    ),
    # Sharp gossip: small and quick with a pointy face, alert ears, freckles.
    "june": _llama(
        wool="#E6C9A3", muzzle="#FBEBD6", lid="#D5B48C", iris="#4E6B2E", brow="#6B4A30", freckles=110,
        body=(0.0, 0.66), half=(0.41, 0.27, 0.255), leg_x=(0.25, -0.25), leg_y=0.14, leg_r=0.05, thigh_r=0.09,
        knee=0.30,
        neck=((0.30, 0.86), (0.38, 1.16)), neck_r=0.1,
        head=(0.43, 1.29), head_half=(0.20, 0.18, 0.19), snout=(0.2, -0.06), snout_half=(0.16, 0.095, 0.08),
        ear=dict(style="alert", length=0.31, width=0.045, at=(-0.03, 0.095, 0.15)),
        eye=dict(r=0.062, w=0.055, az=31, el=11), blush="#EE9C8C",
        wool_n=50, wool_r=0.08, tuft="spiky", lashes=1, tail_r=0.085,
        gait=dict(cycle=0.48, stride=16, knee=48, front_knee=52, bounce=0.012, neck=6, head=-6, head_bob=2, pitch=1),
        idle=dict(rate=1.6, head=7, sway=0.6),
        gallop=dict(stride=30, knee=55, bob=0.035),
    ),
    # Brooding poet: lanky, shaggy and dark, bangs over the eyes, a beanie.
    "bramble": _llama(
        wool="#6A625C", muzzle="#B9AEA4", lid="#5A524C", inner="#C99A96", iris="#5C7486", brow="#2E2724",
        hoof="#2A2422", messy=0.55, blush="#C98C88",
        body=(0.0, 0.96), half=(0.5, 0.28, 0.27), leg_x=(0.32, -0.32), leg_y=0.15, leg_r=0.054, thigh_r=0.095,
        knee=0.46,
        neck=((0.38, 1.12), (0.62, 1.47)), neck_r=0.11,
        head=(0.70, 1.56), head_half=(0.225, 0.2, 0.205), snout=(0.18, -0.08), snout_half=(0.13, 0.12, 0.1),
        ear=dict(style="droop", length=0.26, width=0.05, at=(-0.05, 0.13, 0.11)),
        eye=dict(r=0.066, w=0.058, az=33, el=7),
        wool_n=58, wool_r=0.1, shaggy=1.0, tuft="none", chin=True, bangs=True, tail_r=0.11,
        gait=dict(cycle=1.15, stride=19, knee=34, front_knee=34, bounce=0.022, neck=12, head=10, head_bob=5, sway=2,
                  pitch=2.5),
        idle=dict(rate=0.6, head=4, sway=1.4),
        gallop=dict(stride=30, knee=50, bob=0.055, neck_amp=14),
    ),
    # Bossy organiser: neat and upright, trimmed wool, glasses, bow tie, clipboard.
    "clover": _llama(
        wool="#6E4A33", muzzle="#D9B99A", lid="#5E3E2A", inner="#D99A8A", iris="#3A2416", brow="#2A1A10",
        hoof="#2A1E18", blush="#D98A7A",
        body=(0.0, 0.84), half=(0.47, 0.3, 0.29),
        neck=((0.36, 1.05), (0.39, 1.46)), neck_r=0.115,
        head=(0.43, 1.6), head_half=(0.225, 0.205, 0.215), snout=(0.18, -0.07), snout_half=(0.13, 0.125, 0.1),
        ear=dict(length=0.24, width=0.048), eye=dict(r=0.064, w=0.056, az=33, el=9),
        wool_n=36, wool_r=0.065, wool_depth=0.93, wool_stiff=1.6, tuft="trim", collar=0.45, tail_r=0.085,
        gait=dict(cycle=0.8, stride=17, knee=46, front_knee=88, bounce=0.008, neck=-8, head=-3, head_bob=1.2,
                  pitch=0.6),
        idle=dict(rate=0.9, head=3, sway=0.5),
        gallop=dict(stride=30, knee=55, bob=0.04, neck_amp=7),
    ),
}

ORDER = ("pip", "mo", "june", "bramble", "clover")


def _materials():
    return dict(
        Wool=c.mat("Wool", rough=0.95),
        Hoof=c.mat("Hoof", rough=0.35),
        EyeGloss=c.mat("EyeGloss", rough=0.08),
        EyeShine=c.mat("EyeShine", rough=0.1, emission=3.0),
        Face=c.mat("Face", rough=0.7),
        Cloth=c.mat("Cloth", rough=0.85),
        Gloss=c.mat("Gloss", rough=0.15),
    )


# ---------------------------------------------------------------- body


def _v(*a):
    return Vector(a)


class Balls:
    """Metaball elements in the authoring frame, sized by their visual radii."""

    def __init__(self, name):
        self.mb = bpy.data.metaballs.new(name)
        self.mb.resolution = 0.012
        self.mb.render_resolution = 0.012
        self.mb.threshold = 0.6
        self.ob = bpy.data.objects.new(name, self.mb)
        bpy.context.scene.collection.objects.link(self.ob)

    def ball(self, co, r, stiff=2.0):
        e = self.mb.elements.new(type='BALL')
        e.co = co
        e.radius = r / K
        e.stiffness = stiff
        return e

    def ellipsoid(self, co, half, rot=None, stiff=2.0):
        e = self.mb.elements.new(type='ELLIPSOID')
        e.co = co
        e.radius = 1 / K
        e.size_x, e.size_y, e.size_z = half
        e.stiffness = stiff
        if rot is not None:
            e.rotation = rot
        return e

    def capsule(self, a, b, r, stiff=2.0):
        a, b = Vector(a), Vector(b)
        e = self.mb.elements.new(type='CAPSULE')
        e.co = (a + b) / 2
        e.radius = r / K
        e.size_x = (b - a).length / 2
        e.rotation = Vector((1, 0, 0)).rotation_difference((b - a).normalized())
        e.stiffness = stiff
        return e

    def to_mesh(self, name):
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.ob.evaluated_get(dg))
        bpy.data.objects.remove(self.ob)
        bpy.data.metaballs.remove(self.mb)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        return ob


def _fib(n, seed):
    rnd = random.Random(seed)
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - z * z)
        a = i * ga + rnd.uniform(-0.2, 0.2)
        out.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    return out


def _geometry(P):
    """Joint positions and the main shapes, from the llama's parameters."""
    bx, bz = P["body"]
    a, b, cz = P["half"]
    (nbx, nbz), (ntx, ntz) = P["neck"]
    hx, hz = P["head"]
    g = dict(
        body=_v(bx, 0, bz), half=_v(a, b, cz),
        neck_base=_v(nbx, 0, nbz), neck_top=_v(ntx, 0, ntz),
        head=_v(hx, 0, hz), head_half=_v(*P["head_half"]),
        snout=_v(hx + P["snout"][0], 0, hz + P["snout"][1]), snout_half=_v(*P["snout_half"]),
        leg_top=bz - cz * 0.35, neck_r=P["neck_r"],
    )
    g["knee"] = P["knee"]
    return g


def _body_balls(P, g):
    rnd = random.Random(P["wool_seed"])
    B = Balls("BodyBalls")
    body, (a, b, cz) = g["body"], g["half"]
    B.ellipsoid(body, (a * 0.84, b * 0.84, cz * 0.84))
    B.ball(body + _v(a * 0.58, 0, cz * 0.1), cz * 0.76)
    B.ball(body + _v(-a * 0.56, 0, cz * 0.06), cz * 0.8)
    wr, shag = P["wool_r"], P["shaggy"]
    for d in _fib(P["wool_n"], P["wool_seed"]):
        if d.z < -0.55:
            continue
        p = body + _v(d.x * a, d.y * b, d.z * cz) * P["wool_depth"]
        r = wr * rnd.uniform(0.85, 1.2)
        if shag:
            # Long locks hang off the sides and the back.
            hang = r * (1.0 + shag * 0.9 * max(0.0, 1 - d.z))
            B.ellipsoid(p - _v(0, 0, hang * 0.55), (r * 0.62, r * 0.62, hang), stiff=4.0)
        else:
            B.ball(p, r, stiff=P["wool_stiff"])
    # Neck and its wool collar.
    nb, nt = g["neck_base"], g["neck_top"]
    B.capsule(nb, nt, P["neck_r"])
    axis = (nt - nb).normalized()
    side = axis.cross(_v(0, 1, 0)).normalized()
    for i, t in enumerate((0.05, 0.3, 0.55)):
        ring = 7 if i == 0 else 6
        rr = P["neck_r"] * (0.62 if i == 0 else 0.48) * P["collar"]
        if rr <= 0.01:
            continue
        for k in range(ring):
            ang = 2 * math.pi * (k + 0.5 * i) / ring
            off = _v(0, math.cos(ang), 0) * P["neck_r"] * 0.9 + side * math.sin(ang) * P["neck_r"] * 0.9
            p = nb + (nt - nb) * t + off
            if shag:
                B.ellipsoid(p - _v(0, 0, rr * 0.5), (rr, rr, rr * 1.7))
            else:
                B.ball(p, rr)
    # Head and snout.
    h, hh = g["head"], g["head_half"]
    B.ellipsoid(h, (hh.x * 0.95, hh.y * 0.95, hh.z * 0.95))
    s, sh = g["snout"], g["snout_half"]
    B.ellipsoid(s, (sh.x * 0.95, sh.y * 0.95, sh.z * 0.95))
    B.ball(h + _v(0.02, 0, -hh.z * 0.55), hh.y * 0.7)  # jowls, so the head meets the neck softly
    _tuft(B, P, g)
    if P["chin"]:
        for y, l in ((0.0, 0.11), (0.04, 0.08), (-0.04, 0.085)):
            B.ellipsoid(s + _v(-0.02, y, -sh.z * 0.95), (0.03, 0.028, l), rot=Quaternion((0, 1, 0), math.radians(-18)))
    # Legs: wool "trousers" at the top, slim shins to the hooves.
    for lx in P["leg_x"]:
        for sgn in (1, -1):
            y = P["leg_y"] * sgn
            top = _v(lx, y, g["leg_top"])
            knee = _v(lx, y, g["knee"])
            foot = _v(lx, y, 0.1)
            B.ball(top + _v(0, 0, -0.03), P["thigh_r"])
            B.capsule(top, knee, P["leg_r"] * 1.25)
            B.capsule(knee, foot, P["leg_r"])
            B.ball(_v(lx, y, 0.13), P["leg_r"] * 1.25)  # a little fluff at the fetlock
    # Tail: a fluffy upturned puff.
    tb = body + _v(-a * 0.98, 0, cz * 0.45)
    tr = P["tail_r"]
    B.ellipsoid(tb + _v(-tr * 0.4, 0, tr * 0.2), (tr * 0.9, tr * 0.85, tr * 1.25), rot=Quaternion((0, 1, 0), math.radians(-30)))
    B.ball(tb + _v(-tr * 0.9, 0, -tr * 0.4), tr * 0.75)
    return B


def _tuft(B, P, g):
    h, hh = g["head"], g["head_half"]
    top = h + _v(0, 0, hh.z * 0.85)
    style = P["tuft"]
    if style == "tuft":
        for x, y, z, r in ((0.0, 0.0, 0.07, 0.07), (-0.05, 0.06, 0.04, 0.06), (-0.05, -0.06, 0.04, 0.06), (0.04, 0.0, 0.05, 0.055)):
            B.ball(top + _v(x, y, z), r)
    elif style == "pompadour":
        # A tall forward swoop, curling over at the front.
        for i in range(9):
            t = i / 8
            ang = math.radians(-60 + 200 * t)
            p = top + _v(-0.07 + 0.16 * t, 0, 0.03 + 0.11 * math.sin(math.pi * min(1, t * 1.1)))
            p += _v(0.03 * math.cos(ang) * t, 0, 0.025 * t * math.sin(ang))
            B.ball(p, 0.07 - 0.025 * t)
        for y in (0.055, -0.055):
            B.ball(top + _v(-0.04, y, 0.03), 0.05)
    elif style == "puff":
        B.ball(top + _v(0.0, 0, 0.04), 0.085)
        for k in range(5):
            ang = 2 * math.pi * k / 5
            B.ball(top + _v(math.cos(ang) * 0.06, math.sin(ang) * 0.06, 0.02), 0.055)
    elif style == "spiky":
        for x, y, tilt_x, tilt_y in ((0.03, 0, 0, -25), (-0.04, 0.045, 18, -10), (-0.04, -0.045, -18, -10)):
            q = Quaternion((1, 0, 0), math.radians(tilt_x)) @ Quaternion((0, 1, 0), math.radians(tilt_y))
            B.ellipsoid(top + _v(x, y, 0.06), (0.035, 0.03, 0.08), rot=q)
    elif style == "trim":
        B.ellipsoid(top + _v(0.01, 0, 0.01), (0.1, 0.09, 0.045))


def _bangs(P, g):
    """Bramble's fringe: long locks from the crown over the eyes."""
    B = Balls("Bangs")
    h, hh = g["head"], g["head_half"]
    for i, y in enumerate((-0.11, -0.055, 0.0, 0.055, 0.11)):
        drop = 0.12 + 0.03 * (i % 2)
        start = h + _v(hh.x * 0.55, y * 0.85, hh.z * 0.72)
        end = h + _v(hh.x * 1.08, y * 1.05, hh.z * 0.72 - drop)
        mid = (start + end) / 2 + _v(0.04, 0, 0.025)
        B.capsule(start, mid, 0.038)
        B.capsule(mid, end, 0.03)
    return B


def _hooves_and_ears(P, g, geo, surf):
    """Two-toed hooves on each leg and banana ears, in `geo` (body parts)."""
    hoof = c.hexc(P["hoof"])
    for lx, legs in ((P["leg_x"][0], ("FL", "FR")), (P["leg_x"][1], ("HL", "HR"))):
        for sgn, name in ((1, legs[0]), (-1, legs[1])):
            y = P["leg_y"] * sgn
            r = P["leg_r"]
            grp = ((f"leg_{name}_lower", 1.0),)
            for toe in (1, -1):
                M = frame(_v(lx + r * 0.35, y + toe * r * 0.48, 0.055), _v(1, 0, 0), _v(0, 1, 0), _v(0, 0, 1),
                          r * 1.05, r * 0.62, 0.06)
                geo.sphere(M, hoof, "Hoof", seg=12, rings=8, group=grp, zmin=-0.92)
            geo.cylinder(frame(_v(lx, y, 0.075), FWD, _v(0, 1, 0), UP, r * 1.12, r * 1.12, 0.035), hoof, "Hoof",
                         seg=12, group=grp)
    _ears(P, g, geo, surf)


def _ears(P, g, geo, surf):
    E = P["ear"]
    h = g["head"]
    wool, inner = c.hexc(P["wool"]), c.hexc(P["inner"])
    length, width = E["length"], E["width"]
    for side, bone in ((1, "ear_L"), (-1, "ear_R")):
        ax, ay, az = E["at"]
        base_dir = _v(ax, ay * side, az).normalized()
        base, _ = surf(h, base_dir)
        base -= base_dir * 0.025
        style = E["style"]
        if style == "floppy":
            d1, d2 = _v(-0.1, 0.9 * side, 0.35), _v(0.25, 0.65 * side, -0.75)
        elif style == "alert":
            d1, d2 = _v(-0.05, 0.22 * side, 1.0), _v(0.12, 0.05 * side, 1.0)
        elif style == "droop":
            d1, d2 = _v(-0.25, 0.7 * side, 0.6), _v(-0.15, 0.85 * side, -0.05)
        else:
            d1, d2 = _v(-0.12, 0.3 * side, 1.0), _v(0.05, -0.12 * side, 1.0)
        p0 = base
        p1 = base + d1.normalized() * length * 0.55
        p2 = p1 + d2.normalized() * length * 0.5
        path = [p0 * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t for t in [i / 10 for i in range(11)]]

        def radius(t, k=1.0):
            return (width * (0.75 + 0.55 * math.sin(math.pi * min(1, t * 1.1))) * (1 - t) ** 0.5 + 0.004) * k

        facing = (FWD + _v(0, 0.35 * side, 0)).normalized()
        grp = ((bone, 1.0),)
        geo.tube(path, radius, wool, "Wool", seg=10, group=grp, up=facing, flat=0.38)
        inner_path = [p + facing * width * 0.22 for p in path[1:-1]]
        geo.tube(inner_path, lambda t: radius(0.1 + t * 0.8, 0.62), inner, "Wool", seg=8, group=grp, up=facing, flat=0.3)
        E.setdefault("bases", {})[bone] = (base, path[-1])


# ---------------------------------------------------------------- face


def _surface(tree):
    def surf(origin, direction, outward=True):
        d = Vector(direction).normalized()
        if outward:
            loc, nrm, _, _ = tree.ray_cast(Vector(origin) + d * 3.0, -d)
        else:
            loc, nrm, _, _ = tree.ray_cast(Vector(origin), d)
        if loc is None:
            raise RuntimeError(f"no surface from {origin} along {d}")
        return loc, nrm
    return surf


def _dir(az, el, side=1):
    a, e = math.radians(az), math.radians(el)
    return _v(math.cos(e) * math.cos(a), side * math.cos(e) * math.sin(a), math.sin(e))


def _face(P, g, surf, materials):
    """Eyes, lids, brows, nose, mouth and cheeks, with the expression morphs."""
    geo = Geo(MORPHS)
    h, s = g["head"], g["snout"]
    E = P["eye"]
    white, iris, pupil = c.hexc("#FFFFFF"), c.hexc(P["iris"]), c.hexc("#0B0806")
    lid = c.hexc(P["lid"])
    liner = c.hexc("#2A1A12") if P["wool"] != "#6E4A33" else c.hexc("#1A0F0A")
    brow_col = c.hexc(P["brow"])
    eyes = {}
    for side, bone in ((1, "lid_L"), (-1, "lid_R")):
        hit, nrm = surf(h, _dir(E["az"], E["el"], side))
        n = (nrm + FWD * 0.7).normalized()
        n, sv, u = basis_from(n)
        r, w = E["r"], E["w"]
        centre = hit - n * r * 0.42
        M = frame(centre, n, sv, u, r, w, r)
        surprised = frame(centre, n, sv, u, r * 1.14, w * 1.14, r * 1.14)
        sh = {"Surprised": surprised}
        geo.sphere(M, white, "EyeGloss", seg=20, rings=12, group=(("head", 1.0),), shapes=sh)
        # Iris and pupil are caps of slightly larger shells, looking a little
        # forward of the eye's own normal so the llama looks ahead.
        gaze = (n + FWD * 0.35).normalized()
        gl = Vector((gaze.dot(n) / r, gaze.dot(sv) / w, gaze.dot(u) / r)).normalized()
        q = Vector((0, 0, 1)).rotation_difference(gl).to_matrix().to_4x4()
        def iris_col(lp, p, centre=centre, u=u, r=r):
            return c.mix(iris, c.mix(iris, (1, 1, 1), 0.45), c.smoothstep(-0.05 * r, -0.45 * r, (p - centre).dot(u)))
        for scale, cap, col, seg in ((1.012, E["iris_cap"], iris_col, 18), (1.022, E["pupil_cap"], pupil, 14)):
            pts, faces = sphere_grid(seg, 6, 2.0, cap=math.radians(cap))
            pts = [q @ Vector(p) * scale for p in pts]
            geo.add([M @ p for p in pts], faces, col, "EyeGloss", shapes={"Surprised": [surprised @ p for p in pts]})
        # Highlights, up and toward the outside.
        up_l = Vector((0, 0, 1))
        out_l = Vector((0, side, 0))
        for off, size in (((0.45, 0.25), 0.26), ((-0.32, -0.3), 0.12)):
            d = (gl + up_l * off[0] + out_l * off[1]).normalized()
            d, t1, t2 = basis_from(d)
            local = frame(d * 1.01, d, t1, t2, size * 0.15, size, size)
            geo.sphere(M @ local, (1, 1, 1), "EyeShine", seg=8, rings=6, shapes={"Surprised": surprised @ local})
        # Upper lid: a solid half-shell over the eye, built open; the game
        # rotates its bone about +side by up to LID_OPEN - LID_SHUT degrees.
        grp = ((bone, 1.0),)
        open_rot = Matrix.Rotation(math.radians(LID_OPEN), 4, -sv)
        Ml = Matrix.Translation(centre) @ open_rot @ Matrix.Translation(-centre) @ frame(centre, n, sv, u, r * 1.09, w * 1.1, r * 1.09)
        geo.sphere(Ml, lid, "Face", seg=18, rings=10, group=grp, zmin=0.0)
        # Lash line along the lid's edge (the shell's rim), and lashes.
        rim = [Ml @ Vector((math.cos(a), math.sin(a), 0.0)) for a in [math.radians(-100 + 200 * i / 14) for i in range(15)]]
        geo.tube(rim, lambda t: 0.0075 * (0.6 + 0.4 * math.sin(math.pi * t)), liner, "Face", seg=6, group=grp)
        for i in range(P["lashes"]):
            t = 0.68 + 0.3 * (i + 1) / (P["lashes"] + 0.5)
            a0 = math.radians(-100 + 200 * (1 - t) if side < 0 else -100 + 200 * t)
            root = Ml @ Vector((math.cos(a0), math.sin(a0), 0.0))
            outward = (root - centre).normalized()
            length = 0.032 + 0.008 * i
            tip = root + outward * length * 0.7 + u * length * 0.2
            tip2 = tip + (outward * 0.2 + u * 1.0).normalized() * length * 0.45
            geo.tube([root, (root + tip) / 2, tip, tip2], lambda t: 0.011 * (1 - t) + 0.002, pupil,
                     "EyeGloss", seg=6, group=grp)
        eyes[side] = dict(centre=centre, n=n, s=sv, u=u, r=r, w=w, hit=hit)
        _brow(geo, P, g, surf, eyes[side], side, brow_col)
    _mouth(geo, P, g, surf)
    _cheeks(geo, P, g, surf)
    ob = geo.to_object("Face", materials, matrix=Matrix.Identity(4))
    return ob, eyes


def _brow(geo, P, g, surf, eye, side, col):
    h = g["head"]
    c0 = eye["centre"] + eye["u"] * eye["r"] * 1.55 + eye["n"] * eye["r"] * 0.2
    span = eye["w"] * 1.0

    def path(lift=0.0, arch=0.012, inner=0.0, outer=0.0):
        pts = []
        for i in range(7):
            k = -1 + 2 * i / 6
            p = c0 + eye["s"] * k * span
            # inner end: the one nearer the head's midline.
            inner_t = max(0.0, (-k if (eye["s"].y * side) > 0 else k))
            outer_t = max(0.0, (k if (eye["s"].y * side) > 0 else -k))
            p = p + eye["u"] * (lift + arch * (1 - k * k) + inner * inner_t + outer * outer_t)
            hit, nrm = surf(h, p - h)
            pts.append(hit + nrm * 0.006)
        return pts

    shapes = {
        "Happy": path(lift=0.022, arch=0.02),
        "Sulky": path(lift=-0.01, inner=-0.042, outer=0.014),
        "Surprised": path(lift=0.045, arch=0.022),
        "Sleepy": path(lift=-0.012, outer=-0.018, arch=0.004),
    }
    radius = lambda t: 0.013 * (0.55 + 0.45 * math.sin(math.pi * (0.15 + 0.7 * t)))  # noqa: E731
    geo.tube(path(), radius, col, "Face", seg=6, shapes=shapes, flat=0.7)


def _mouth(geo, P, g, surf):
    s, sh = g["snout"], g["snout_half"]
    mc, mn = surf(s, _dir(0, -38))
    n, sv, u = basis_from((mn + FWD).normalized())
    mw = sh.y * 0.5
    dark = c.hexc("#3A1E1A")
    inside = c.hexc("#7A2E2E")

    def curve(top, bot, xs=1.0, k=13):
        tp, bp = [], []
        for i in range(k):
            x = -1 + 2 * i / (k - 1)
            for f, out in ((top, tp), (bot, bp)):
                q = mc + sv * x * xs * mw + u * f(x) * mw
                hit, nrm = surf(s, q - s)
                out.append(hit + nrm * 0.005)
        return tp, bp

    smile = lambda x: 0.22 * x * x - 0.06  # noqa: E731
    forms = {
        None: (smile, smile, 1.0),
        "Happy": (lambda x: 0.5 * x * x - 0.1, lambda x: 0.5 * x * x - 0.1 - 0.5 * (1 - x * x), 1.05),
        "Sulky": (lambda x: -0.5 * x * x + 0.1, lambda x: -0.5 * x * x + 0.1, 0.8),
        "Surprised": (lambda x: 0.28 * math.sqrt(max(0.0, 1 - x * x)), lambda x: -0.5 * math.sqrt(max(0.0, 1 - x * x)), 0.4),
        "Sleepy": (lambda x: 0.08 * x * x - 0.02, lambda x: 0.08 * x * x - 0.02, 0.8),
        "Talk": (lambda x: smile(x) + 0.03, lambda x: smile(x) - 0.32 * (1 - x * x), 0.95),
    }
    curves = {k: curve(*v) for k, v in forms.items()}
    base_top, base_bot = curves[None]
    morph_top = {k: v[0] for k, v in curves.items() if k}
    morph_bot = {k: v[1] for k, v in curves.items() if k}
    r = lambda t: 0.0065 + 0.0035 * math.sin(math.pi * t)  # noqa: E731
    geo.tube(base_top, r, dark, "Face", seg=6, shapes=morph_top)
    geo.tube(base_bot, r, dark, "Face", seg=6, shapes=morph_bot)

    # The inside of the mouth, closed flat in the basis.
    def fill(top, bot):
        pts = []
        for a, b in zip(top, bot):
            pts += [a - n * 0.004, b - n * 0.004]
        return pts

    k = len(base_top)
    faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(k - 1)]
    geo.add(fill(base_top, base_bot), faces, inside, "Face",
            shapes={m: fill(morph_top[m], morph_bot[m]) for m in morph_top})
    # Nostrils and the split lip.
    for side in (1, -1):
        hit, nrm = surf(s, _dir(14, 16, side) + _v(0.5, 0, 0))
        nn, ns, nu = basis_from(nrm)
        geo.sphere(frame(hit - nn * 0.004, nn, ns, nu, 0.01, 0.022, 0.012), dark, "Face", seg=8, rings=6)
    lip = []
    for i in range(5):
        t = i / 4
        q = mc + u * (0.06 + 0.42 * t) * mw * 1.6
        hit, nrm = surf(s, q - s)
        lip.append(hit + nrm * 0.004)
    geo.tube(lip, 0.004, dark, "Face", seg=5)


def _cheeks(geo, P, g, surf):
    h = g["head"]
    blush = c.hexc(P["blush"])
    for side in (1, -1):
        if P["freckles"]:
            rnd = random.Random(11 + side)
            for _ in range(5):
                hit, nrm = surf(h, _dir(48 + rnd.uniform(-8, 8), -8 + rnd.uniform(-6, 6), side))
                nn, ns, nu = basis_from(nrm)
                geo.sphere(frame(hit - nn * 0.003, nn, ns, nu, 0.006, 0.009, 0.009), c.hexc("#B0784A"), "Face", seg=6,
                           rings=4)
        hit, nrm = surf(h, _dir(56, -20, side))
        nn, ns, nu = basis_from(nrm)
        geo.sphere(frame(hit - nn * 0.006, nn, ns, nu, 0.009, 0.04, 0.026), blush, "Face", seg=12, rings=6)


# ---------------------------------------------------------------- accessories


def _neck_radius(surf, g, t):
    """Centre, axis, side and outer wool radius of the neck at `t` (0 base,
    1 top); rays that slip down into the chest are ignored."""
    nb, nt = g["neck_base"], g["neck_top"]
    centre = nb + (nt - nb) * t
    axis = (nt - nb).normalized()
    side = axis.cross(_v(0, 1, 0)).normalized()
    dists = []
    for k in range(24):
        a = 2 * math.pi * k / 24
        d = _v(0, math.cos(a), 0) + side * math.sin(a)
        hit, _ = surf(centre, d)
        dists.append((hit - centre).length)
    dists.sort()
    return centre, axis, side, min(dists[int(len(dists) * 0.8)], g["neck_r"] * 2.0)


def _conform(surf, origin, pts, offset, smooth=2):
    """Projects `pts` onto the surface along rays from `origin`, lifts them
    by `offset`, then relaxes them so cloth does not follow every wool
    bump (never letting a point sink below the surface)."""
    out = []
    for p in pts:
        hit, nrm = surf(origin, p - origin)
        out.append((hit, (hit - origin).normalized()))
    return [h + d * offset for h, d in out]


def _outside(surf, g, p, margin):
    """Pushes `p` out of the body (measured from the nearest point on the
    spine or neck axis) so cloth never sinks into the wool."""
    body, half = g["body"], g["half"]
    best = None
    for a, b in ((body - _v(half.x * 0.8, 0, 0), body + _v(half.x * 0.8, 0, 0)), (g["neck_base"], g["neck_top"])):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        o = a + ab * t
        if best is None or (p - o).length < (p - best).length:
            best = o
    d = p - best
    hit, _ = surf(best, d)
    need = (hit - best).length + margin
    return p if d.length >= need else best + d.normalized() * need


def _accessories(P, name, g, surf, eyes, materials):
    """Accessory meshes keyed by the bone they ride on."""
    parts = {}

    def geo_for(bone):
        if bone not in parts:
            parts[bone] = Geo()
        return parts[bone]

    h, hh = g["head"], g["head_half"]
    if name == "pip":
        _scarf(P, g, surf, parts)
        # A small flower behind the left ear.
        base, tip = P["ear"]["bases"]["ear_L"]
        hit, nrm = surf(h, (base - h) + _v(-0.08, 0.02, -0.03))
        geo = geo_for("head")
        n, sv, u = basis_from((nrm - FWD * 0.3).normalized())
        centre = hit + n * 0.012
        petal = c.hexc("#F27BA0")
        for k in range(5):
            a = 2 * math.pi * k / 5
            d = sv * math.cos(a) + u * math.sin(a)
            geo.sphere(frame(centre + d * 0.034, n, sv, u, 0.012, 0.03, 0.03) @ Matrix.Rotation(a, 4, 'X'), petal, "Cloth",
                       seg=10, rings=6)
        geo.sphere(frame(centre + n * 0.01, n, sv, u, 0.016, 0.018, 0.018), c.hexc("#FFD24A"), "Cloth", seg=8, rings=6)
        geo.sphere(frame(centre - u * 0.05 - n * 0.005, n, sv, u, 0.008, 0.02, 0.04) @ Matrix.Rotation(0.6, 4, 'X'),
                   c.hexc("#5E9E4A"), "Cloth", seg=8, rings=6)
    elif name == "mo":
        _toque(P, g, surf, geo_for("head"))
        _apron(P, g, surf, geo_for("spine"))
    elif name == "june":
        _basket(P, g, surf, geo_for("spine"))
    elif name == "bramble":
        _beanie(P, g, surf, geo_for("head"))
    elif name == "clover":
        _glasses(P, g, surf, eyes, geo_for("head"))
        _bow_tie(P, g, surf, geo_for("neck"))
        _clipboard(P, g, surf, geo_for("spine"))
    return parts


def _scarf(P, g, surf, parts):
    red, dark, cream = c.hexc("#C8282E"), c.hexc("#951B22"), c.hexc("#F6E7D2")
    centre, axis, side, rad = _neck_radius(surf, g, 0.32)
    geo = parts.setdefault("Scarf", Geo())
    tilt = Matrix.Rotation(math.radians(-14), 4, _v(0, 1, 0))
    up = (tilt @ axis.to_4d()).to_3d().normalized()
    _, sv, fw = basis_from(up, up=FWD)
    for i, (dz, height) in enumerate(((-0.035, 0.095), (0.04, 0.085))):
        loop = []
        for k in range(33):
            a = 2 * math.pi * k / 32
            loop.append(centre + up * (dz + 0.012 * math.sin(a + i)) + (fw * math.cos(a) + sv * math.sin(a)) * (rad + 0.028 + 0.012 * i))

        def stripe(lp, p, i=i):
            rel = p - centre
            a = math.atan2(rel.dot(sv), rel.dot(fw))
            return dark if int((a + math.pi) / (2 * math.pi) * 12 + i) % 2 else red
        geo.tube(loop, 0.03, stripe, "Cloth", seg=10, group=(("neck", 1.0),), up=up, flat=height / 0.03 / 2,
                 caps=False)
    knot_dir = (FWD * 0.6 + _v(0, 0.8, 0)).normalized()
    knot = centre + knot_dir * (rad + 0.05) - up * 0.04
    geo.sphere(frame(knot, FWD, _v(0, 1, 0), UP, 0.055, 0.05, 0.05), red, "Cloth", seg=12, rings=8, group=(("neck", 1.0),))
    g["scarf_knot"] = knot
    tail = parts.setdefault("ScarfTail", Geo())
    for k, (length, spread) in enumerate(((0.62, 0.05), (0.5, -0.04))):
        pts = []
        for i in range(12):
            t = i / 11
            p = knot + _v(-0.06 - 0.28 * t * t, 0.03 + spread * t, -length * t) + _v(0.015 * math.sin(6 * t + k), 0, 0)
            pts.append(_outside(surf, g, p, 0.05))

        def band(lp, p, length=length, knot=knot):
            d = (knot.z - p.z) / length
            return cream if 0.72 < d < 0.8 or 0.86 < d < 0.92 else red
        tail.tube(pts, lambda t: 0.042 * (1 - 0.15 * t), band, "Cloth", seg=10, group=(("scarf", 1.0),), up=_v(0, 1, 0),
                  flat=0.28)
        end = pts[-1]
        for f in range(5):
            y = -0.03 + 0.015 * f
            tail.tube([end + _v(0, y, 0), end + _v(-0.01, y, -0.04)], 0.006, red, "Cloth", seg=4, group=(("scarf", 1.0),))


def _toque(P, g, surf, geo):
    h, hh = g["head"], g["head_half"]
    top, nrm = surf(h, _v(-0.15, 0, 1))
    white, band = c.hexc("#FBF8F2"), c.hexc("#EFE9DD")
    up = (UP + _v(-0.12, 0, 0)).normalized()
    up, sv, fw = basis_from(up, up=FWD)
    base = top - up * 0.03
    r = hh.y * 0.62
    geo.cylinder(frame(base + up * 0.05, fw, sv, up, r, r, 0.055), band, "Cloth", seg=20, r_top=1.02)
    for k in range(6):
        a = 2 * math.pi * k / 6
        d = fw * math.cos(a) + sv * math.sin(a)
        geo.sphere(frame(base + up * 0.17 + d * r * 0.55, fw, sv, up, r * 0.62, r * 0.62, r * 0.62), white, "Cloth",
                   seg=12, rings=8)
    geo.sphere(frame(base + up * 0.22, fw, sv, up, r * 0.75, r * 0.75, r * 0.6), white, "Cloth", seg=14, rings=8)


def _apron(P, g, surf, geo):
    body, (a, b, cz) = g["body"], g["half"]
    rnd = random.Random(5)
    cloth, flour = c.hexc("#F4EEE2"), c.hexc("#FFFFFF")
    trim = c.hexc("#E0A93B")
    nb = g["neck_base"]
    origin = body + _v(-0.1, 0, 0.05)
    cols, rows = 9, 10
    top_z, bot_z = nb.z + 0.02, body.z - cz * 0.62
    width = b * 0.6
    grid = []
    for j in range(rows):
        t = j / (rows - 1)
        z = top_z + (bot_z - top_z) * t
        w = width * (0.75 + 0.25 * t)
        for i in range(cols):
            y = -w + 2 * w * i / (cols - 1)
            grid.append(_v(a + 0.4, y, z))
    pts = _conform(surf, origin, grid, 0.03)
    # Relax toward a smooth sheet, then keep it outside the wool.
    for _ in range(3):
        nxt = []
        for idx, p in enumerate(pts):
            j, i = divmod(idx, cols)
            nb_ = [pts[jj * cols + ii] for jj, ii in ((j - 1, i), (j + 1, i), (j, i - 1), (j, i + 1)) if 0 <= jj < rows and 0 <= ii < cols]
            nxt.append(p * 0.4 + sum(nb_, Vector()) / len(nb_) * 0.6)
        pts = []
        for p in nxt:
            hit, _ = surf(origin, p - origin)
            d = (p - origin)
            pts.append(p if d.length > (hit - origin).length + 0.018 else hit + d.normalized() * 0.018)
    back = [p - (p - origin).normalized() * 0.012 for p in pts]
    faces = []
    for j in range(rows - 1):
        for i in range(cols - 1):
            a0 = j * cols + i
            faces.append((a0, a0 + 1, a0 + cols + 1, a0 + cols))
    n = len(pts)
    faces += [(n + f[3], n + f[2], n + f[1], n + f[0]) for f in faces[: (rows - 1) * (cols - 1)]]
    for j in range(rows - 1):
        for i in (0, cols - 1):
            a0, b0 = j * cols + i, (j + 1) * cols + i
            faces.append((a0, b0, n + b0, n + a0) if i == 0 else (a0, n + a0, n + b0, b0))
    for i in range(cols - 1):
        a0, b0 = (rows - 1) * cols + i, (rows - 1) * cols + i + 1
        faces.append((a0, n + a0, n + b0, b0))
    dust = [(_v(a + 0.4, rnd.uniform(-width, width), rnd.uniform(bot_z, top_z)), rnd.uniform(0.015, 0.035)) for _ in range(14)]

    def colour(lp, p):
        if p.z < bot_z + 0.03:
            return trim
        for q, r in dust:
            if (_v(0, p.y, p.z) - _v(0, q.y, q.z)).length < r:
                return flour
        return cloth
    geo.add(pts + back, faces, colour, "Cloth", group=(("spine", 1.0),))
    # Straps from the top corners up round the back of the neck.
    centre, axis, side, rad = _neck_radius(surf, g, 0.18)
    for corner in (0, cols - 1):
        start = pts[corner]
        sgn = 1 if start.y > 0 else -1
        via = centre + _v(0, (rad + 0.02) * sgn, 0)
        end = centre - FWD * (rad + 0.02)
        path = []
        for i in range(9):
            t = i / 8
            p = start * (1 - t) ** 2 + via * 2 * t * (1 - t) + end * t * t
            path.append(_outside(surf, g, p, 0.02))
        geo.tube(path, 0.011, trim, "Cloth", seg=6, group=(("spine", 1.0),), up=axis, flat=0.6)


def _basket(P, g, surf, geo):
    body, (a, b, cz) = g["body"], g["half"]
    at = body + _v(-a * 0.25, 0, 0)
    top, nrm = surf(at, UP)
    straw, dark = c.hexc("#C9964E"), c.hexc("#9A6A30")
    r, height = b * 0.62, 0.17
    base = top - UP * 0.03

    def weave(lp, p):
        a_ = math.atan2(lp.y, lp.x)
        row = int((lp.z + 1) * 3)
        return dark if (int(a_ / (2 * math.pi) * 16) + row) % 2 else straw
    geo.cylinder(frame(base + UP * height / 2, FWD, _v(0, 1, 0), UP, r * 0.85, r * 0.85, height / 2), weave, "Cloth",
                 seg=20, r_top=1.18)
    geo.torus(frame(base + UP * height, FWD, _v(0, 1, 0), UP, r * 1.0, r * 1.0, r * 1.0), 0.018 / r, dark, "Cloth",
              seg=24, ring=6)
    geo.torus(frame(base + UP * height, _v(0, 1, 0), UP, FWD, r * 0.95, r * 1.1, r * 0.95), 0.012 / r, dark, "Cloth",
              seg=20, ring=6, arc=math.pi)
    rnd = random.Random(3)
    berries = (c.hexc("#C2183A"), c.hexc("#5B2A86"), c.hexc("#E0405A"))
    for k in range(16):
        ang = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0, r * 0.75)
        p = base + _v(math.cos(ang) * rr, math.sin(ang) * rr, height + 0.01 + 0.035 * (1 - rr / r) + rnd.uniform(-0.01, 0.01))
        s = rnd.uniform(0.022, 0.03)
        geo.sphere(frame(p, FWD, _v(0, 1, 0), UP, s, s, s), berries[k % 3], "Gloss", seg=8, rings=6)
    for ang in (0.6, 2.8):
        p = base + _v(math.cos(ang) * r * 0.5, math.sin(ang) * r * 0.5, height + 0.04)
        geo.sphere(frame(p, FWD, _v(0, 1, 0), UP, 0.05, 0.022, 0.008) @ Matrix.Rotation(ang, 4, 'Z'), c.hexc("#4E8E3A"),
                   "Cloth", seg=8, rings=4)
    # A strap around her middle holds it on.
    x = at.x
    ring = []
    for k in range(17):
        ang = 2 * math.pi * k / 16
        d = _v(0, math.sin(ang), math.cos(ang))
        hit, nrm = surf(_v(x, 0, body.z), d)
        ring.append(hit + d * 0.012)
    geo.tube(ring, 0.014, dark, "Cloth", seg=6, up=FWD, flat=0.5, caps=False)


def _beanie(P, g, surf, geo):
    h, hh = g["head"], g["head_half"]
    green, rib = c.hexc("#4E7A3E"), c.hexc("#3E6630")
    centre = h + _v(-0.03, 0, hh.z * 0.15)
    rows, cols = 7, 24
    rings = []
    for j in range(rows + 1):
        el = math.radians(90 - 62 * (j + 1) / (rows + 1))
        ring = []
        for i in range(cols):
            az = 2 * math.pi * i / cols
            d = _v(math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))
            hit, _ = surf(centre, d)
            back = max(0.0, -d.x) * (1 - j / rows)
            ring.append(hit + d * (0.03 + 0.05 * back))
        rings.append(ring)
    # Relax so the knit does not follow the tufts underneath.
    for _ in range(3):
        rings = [[(r[i] * 0.5 + (r[i - 1] + r[(i + 1) % cols]) * 0.25) for i in range(cols)] for r in rings]
    pts = [p for r in rings for p in r]
    faces = []
    for j in range(rows):
        for i in range(cols):
            a0, b0 = j * cols + i, j * cols + (i + 1) % cols
            faces.append((a0, a0 + cols, b0 + cols, b0))
    crown, _ = surf(centre, UP)
    pts.append(crown + UP * 0.03 - FWD * 0.02)
    top = len(pts) - 1
    for i in range(cols):
        faces.append((top, i, (i + 1) % cols))

    def knit(lp, p):
        az = math.atan2(p.y - centre.y, p.x - centre.x)
        return rib if int((az + math.pi) / (2 * math.pi) * 24) % 2 else green
    geo.add(pts, faces, knit, "Cloth")
    brim = rings[-1] + [rings[-1][0]]
    geo.tube(brim, 0.03, lambda lp, p: rib, "Cloth", seg=8, up=UP, flat=0.8, caps=False)
    geo.sphere(frame(pts[top] + _v(-0.03, 0, 0.04), FWD, _v(0, 1, 0), UP, 0.055, 0.055, 0.05), green, "Cloth", seg=10,
               rings=8)


def _glasses(P, g, surf, eyes, geo):
    gold = c.hexc("#C9A24A")
    fronts = []
    for side in (1, -1):
        e = eyes[side]
        gaze = (e["n"] + FWD * 0.6).normalized()
        n, sv, u = basis_from(gaze)
        centre = e["centre"] + e["n"] * e["r"] * 1.22 + gaze * 0.01
        R = e["r"] * 1.12
        geo.torus(frame(centre, sv, u, n, R, R, R), 0.008 / R, gold, "Gloss", seg=28, ring=6)
        fronts.append((centre, sv, u, n, R))
        # The arm runs back over the cheek to the ear.
        start = centre + sv * R * (1 if (sv.y * side) > 0 else -1)
        pts = []
        for i in range(6):
            t = i / 5
            q = start + _v(-0.22 * t, side * 0.02 * t, 0.01 * t)
            hit, nrm = surf(g["head"], q - g["head"])
            pts.append(hit + nrm * 0.012 if (q - g["head"]).length < (hit - g["head"]).length + 0.012 else q)
        geo.tube(pts, 0.006, gold, "Gloss", seg=5)
    (c1, s1, _, _, r1), (c2, s2, _, _, r2) = fronts
    a = c1 - (c1 - c2).normalized() * r1
    b = c2 + (c1 - c2).normalized() * r2
    mid = (a + b) / 2 + UP * 0.012 + FWD * 0.01
    geo.tube([a, mid, b], 0.006, gold, "Gloss", seg=5)


def _bow_tie(P, g, surf, geo):
    blue, dark = c.hexc("#3F7BC9"), c.hexc("#2C5C9C")
    centre, axis, side, rad = _neck_radius(surf, g, 0.2)
    front, nrm = surf(centre, FWD)
    p = front + nrm * 0.03
    n, sv, u = basis_from(nrm)
    grp = (("neck", 1.0),)
    geo.sphere(frame(p, n, sv, u, 0.03, 0.03, 0.032), dark, "Cloth", seg=10, rings=8, group=grp)
    for s_ in (1, -1):
        d = sv * s_
        M = frame(p + d * 0.07, n, d, u, 0.03, 0.075, 0.055)
        geo.sphere(M, blue, "Cloth", seg=12, rings=8, group=grp, power=2.6)


def _clipboard(P, g, surf, geo):
    body, (a, b, cz) = g["body"], g["half"]
    at = body + _v(a * 0.1, 0, cz * 0.05)
    hit, nrm = surf(at, _v(0, -1, 0.25))
    n, sv, u = basis_from(_v(0, -1, 0.12).normalized(), up=UP)
    tilt = Matrix.Rotation(math.radians(10), 4, n)
    sv = (tilt @ sv.to_4d()).to_3d()
    u = (tilt @ u.to_4d()).to_3d()
    board, paper, clip, ink = c.hexc("#9A6A3C"), c.hexc("#FBFAF5"), c.hexc("#C8CCD2"), c.hexc("#7A8AA8")
    centre = hit + n * 0.035
    geo.sphere(frame(centre, n, sv, u, 0.01, 0.15, 0.2), board, "Cloth", seg=16, rings=8, power=8)

    def lines(lp, p):
        rel = (p - centre).dot(u)
        return ink if (int((rel + 0.2) / 0.035) % 2 == 0 and abs((p - centre).dot(sv)) < 0.1 and rel < 0.12) else paper
    geo.sphere(frame(centre + n * 0.01 - u * 0.012, n, sv, u, 0.004, 0.13, 0.17), lines, "Cloth", seg=24, rings=16, power=10)
    geo.sphere(frame(centre + n * 0.016 + u * 0.18, n, sv, u, 0.015, 0.06, 0.025), clip, "Gloss", seg=10, rings=6, power=4)
    # Strap around her middle.
    ring = []
    x = at.x
    for k in range(17):
        ang = 2 * math.pi * k / 16
        d = _v(0, math.sin(ang), math.cos(ang))
        h2, _ = surf(_v(x, 0, body.z), d)
        ring.append(h2 + d * 0.012)
    geo.tube(ring, 0.013, c.hexc("#3F7BC9"), "Cloth", seg=6, up=FWD, flat=0.5, caps=False)


# ---------------------------------------------------------------- rig


def _rig(P, g, eyes):
    scene = bpy.context.scene
    arm_data = bpy.data.armatures.new("LlamaRig")
    arm = bpy.data.objects.new("LlamaRig", arm_data)
    scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    rot3 = c.T.to_3x3()

    def bone(name, head, tail, parent=None, connect=False, deform=True, roll_up=None):
        bn = eb.new(name)
        bn.head = c.T @ Vector(head)
        bn.tail = c.T @ Vector(tail)
        d = Vector(tail) - Vector(head)
        ref = roll_up if roll_up is not None else (UP if abs(d.z) < abs(d.x) + abs(d.y) else FWD)
        bn.align_roll(rot3 @ ref)
        bn.use_deform = deform
        if parent:
            bn.parent = eb[parent]
            bn.use_connect = connect
        return bn

    body, (a, b, cz) = g["body"], g["half"]
    nb, nt, h, hh = g["neck_base"], g["neck_top"], g["head"], g["head_half"]
    bone("root", (0, 0, 0), (0, 0, 0.25), deform=False)
    bone("spine", body + _v(-a * 0.85, 0, cz * 0.25), body + _v(a * 0.55, 0, cz * 0.3), "root")
    bone("belly", body + _v(-a * 0.3, 0, -cz * 0.15), body + _v(a * 0.3, 0, -cz * 0.15), "spine")
    axis = (nt - nb).normalized()
    bone("neck_aim", nb, nb + axis * 0.06, "spine", deform=False, roll_up=FWD)
    bone("neck", nb, nt, "neck_aim")
    head_axis = (h + _v(0, 0, hh.z) - nt).normalized()
    bone("head_aim", nt, nt + head_axis * 0.05, "neck", deform=False, roll_up=FWD)
    bone("head", nt, h + _v(0.05, 0, hh.z), "head_aim")
    for bn, (base, tip) in P["ear"]["bases"].items():
        bone(bn, base, base + (tip - base).normalized() * 0.1, "head", deform=False)
    for side, bn in ((1, "lid_L"), (-1, "lid_R")):
        e = eyes[side]
        # Bone Y runs along the eye's side axis: the lids turn about it.
        bone(bn, e["centre"], e["centre"] + e["s"] * 0.05, "head", deform=False, roll_up=e["u"])
    knot = g.get("scarf_knot", nb + axis * 0.2 + FWD * 0.1)
    bone("scarf", knot, knot - UP * 0.1, "neck", deform=False)
    tb = body + _v(-a * 0.98, 0, cz * 0.45)
    bone("tail", tb + _v(0.05, 0, -0.02), tb + _v(-0.22, 0, 0.08), "spine")
    names = {"FL": (P["leg_x"][0], 1), "FR": (P["leg_x"][0], -1), "HL": (P["leg_x"][1], 1), "HR": (P["leg_x"][1], -1)}
    for k, (x, sgn) in names.items():
        y = P["leg_y"] * sgn
        bone(f"leg_{k}_upper", (x, y, g["leg_top"]), (x, y, g["knee"]), "spine")
        bone(f"leg_{k}_lower", (x, y, g["knee"]), (x, y, 0.0), f"leg_{k}_upper", connect=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm, arm_data


def _skin(body, extra, arm):
    """Heat weights for the fused body; `extra` (hooves, ears, bangs) is
    joined afterwards with its own fixed weights."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    missing = [v.index for v in body.data.vertices if not any(gw.weight > 0 for gw in v.groups)]
    if missing:
        _nearest_weights(body, arm.data, missing)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in extra:
        o.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    print("WEIGHTS filled", len(missing), "with nearest")


def _segdist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def _nearest_weights(ob, arm_data, only):
    segs = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in arm_data.bones if b.use_deform]
    groups = {n: ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n) for n, _, _ in segs}
    for i in only:
        co = ob.data.vertices[i].co
        d = [_segdist(co, a, b) for _, a, b in segs]
        lo = min(d)
        w = [math.exp(-(x - lo) / 0.035) for x in d]
        s = sum(w)
        top = sorted(range(len(segs)), key=lambda j: -w[j])[:3]
        for j in top:
            if w[j] / s > 0.02:
                groups[segs[j][0]].add([i], w[j] / s, 'REPLACE')


def _attach(ob, arm, bone_name):
    """Parents a rigid mesh to a bone, origin at the bone's head."""
    head = arm.data.bones[bone_name].head_local
    ob.data.transform(Matrix.Translation(-head))
    ob.matrix_world = Matrix.Translation(head)
    world = ob.matrix_world.copy()
    ob.parent = arm
    ob.parent_type = 'BONE'
    ob.parent_bone = bone_name
    bpy.context.view_layer.update()
    ob.matrix_world = world


# ---------------------------------------------------------------- clips


def _pose_idle(t, P):
    w = 2 * math.pi
    I = P["idle"]
    G = P["gait"]
    return {
        "spine": ([("lat", 0.8 * I["sway"] * math.sin(w * t)), ("fwd", 0.6 * I["sway"] * math.sin(w * t + 1))],
                  (0, 0, -0.006 + 0.006 * math.sin(w * t))),
        "neck": ([("lat", G["neck"] * 0.5 - 2 + 2.5 * math.sin(w * t + 0.8))], None),
        "head": ([("lat", G["head"] * 0.5 + I["head"] * 0.5 * math.sin(w * t)), ("fwd", 3 * math.sin(2 * w * t + 0.3))], None),
    }


def _pose_walk(t, P):
    """Four-beat lateral walk: hind left, fore left, hind right, fore right."""
    G = P["gait"]
    w = 2 * math.pi
    duty = 0.62
    A = G["stride"]
    out = {}
    for k, ph in (("HL", 0.0), ("FL", 0.25), ("HR", 0.5), ("FR", 0.75)):
        f = (t + ph) % 1.0
        if f < duty:
            ang = A - 2 * A * (f / duty)
            lift = 0.0
        else:
            s = (f - duty) / (1 - duty)
            ang = -A + 2 * A * (s * s * (3 - 2 * s))
            lift = math.sin(math.pi * s)
        knee = (G["front_knee"] if k[0] == "F" else G["knee"]) * lift
        out[f"leg_{k}_upper"] = ([("lat", -ang - (knee * 0.35 if k[0] == "F" else -knee * 0.2))], None)
        out[f"leg_{k}_lower"] = ([("lat", knee if k[0] == "F" else -knee * 0.8)], None)
    bounce = G["bounce"] * (0.5 + 0.5 * math.cos(2 * w * t))
    out["spine"] = ([("lat", G["pitch"] * math.sin(2 * w * t)), ("fwd", G["sway"] * math.sin(w * t))],
                    (0, G["sway"] * 0.004 * math.sin(w * t), bounce - G["bounce"] * 0.6))
    out["neck"] = ([("lat", G["neck"] + G["head_bob"] * 0.6 * math.sin(2 * w * t + 0.6))], None)
    out["head"] = ([("lat", G["head"] - G["head_bob"] * 0.5 * math.sin(2 * w * t + 0.6)), ("fwd", -G["sway"] * 0.5 * math.sin(w * t))], None)
    return out


def _pose_gallop(t, P):
    p = P["gallop"]
    w = 2 * math.pi
    lean = p["lean"]
    out = {
        "spine": ([("lat", lean + 5 * math.sin(w * t + 1.2))], (0, 0, p["bob"] * math.sin(w * t))),
        "neck": ([("lat", p["neck_amp"] * math.sin(w * t + 2.2))], None),
        "head": ([("lat", -0.6 * p["neck_amp"] * math.sin(w * t + 2.2))], None),
    }
    for k, ph in (("FL", 0.0), ("FR", 0.12), ("HL", 0.5), ("HR", 0.62)):
        s = math.sin(w * (t + ph))
        cc = math.cos(w * (t + ph))
        out[f"leg_{k}_upper"] = ([("lat", -lean * 0.8 + p["stride"] * s)], None)
        out[f"leg_{k}_lower"] = ([("lat", p["knee"] * max(0.0, cc) * (1 if k[0] == "F" else -1))], None)
    return out


def walk_frames(P):
    return max(8, round(P["gait"]["cycle"] * FPS))


def _actions(arm, P):
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = 'LINEAR'
    arm.animation_data_create()
    rot3 = c.T.to_3x3()
    axes = {"lat": rot3 @ Vector((0, 1, 0)), "fwd": rot3 @ Vector((1, 0, 0)), "up": rot3 @ Vector((0, 0, 1))}
    idle_frames = round(2.4 / P["idle"]["rate"] * FPS)
    clips = (
        ("Idle", idle_frames, _pose_idle),
        ("Walk", walk_frames(P), _pose_walk),
        ("Gallop", 18, _pose_gallop),
    )
    keyed = [b.name for b in arm.pose.bones if b.name not in PROCEDURAL]
    for name, frames, pose in clips:
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for f in range(frames + 1):
            p = pose(f / frames, P)
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


# ---------------------------------------------------------------- build


BODY_TRIS = {"pip": 10000, "mo": 11500, "june": 10500, "bramble": 10800, "clover": 10500}


def _body_colors(P, name, g, ob):
    wool, muzzle = c.hexc(P["wool"]), c.hexc(P["muzzle"])
    s, sh = g["snout"], g["snout_half"]
    rnd = random.Random(21)
    spots = []
    if P["freckles"]:
        for d in _fib(P["freckles"], 9):
            if d.z > 0.05:
                spots.append((g["body"] + _v(d.x * g["half"].x, d.y * g["half"].y, d.z * g["half"].z) * 1.05, rnd.uniform(0.028, 0.042)))
    spot_col = c.hexc("#9A6438")
    patches = [(_v(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.4, 0.4), rnd.uniform(0.4, 1.4)), rnd.uniform(0.08, 0.16), rnd.uniform(-1, 1))
               for _ in range(30)] if P["messy"] else []
    flour = [(s + _v(0.1, 0.03, 0.05), 0.05), (g["head"] + _v(0.15, -0.08, 0.12), 0.04)] if P["flour"] else []
    inv = c.T.inverted()

    def col(i, co):
        p = inv @ co
        q = (p - s)
        m = math.sqrt((q.x / (sh.x * 1.15)) ** 2 + (q.y / (sh.y * 1.15)) ** 2 + (q.z / (sh.z * 1.2)) ** 2)
        out = c.mix(wool, muzzle, 1 - c.smoothstep(0.75, 1.05, m))
        # A touch darker toward the hooves.
        out = c.scale(out, 0.86 + 0.14 * c.smoothstep(0.1, 0.5, p.z))
        for q2, r in spots:
            dd = (p - q2).length
            if dd < r:
                out = c.mix(out, spot_col, 1 - c.smoothstep(r * 0.6, r, dd))
        for q2, r, k in patches:
            dd = (p - q2).length
            if dd < r:
                out = c.scale(out, 1 + P["messy"] * 0.18 * k * (1 - dd / r))
        for q2, r in flour:
            dd = (p - q2).length
            if dd < r:
                out = c.mix(out, (0.95, 0.95, 0.93), 0.8 * (1 - c.smoothstep(r * 0.5, r, dd)))
        return out
    return col


def build(name, out_path):
    P = LLAMAS[name]
    c.reset()
    materials = _materials()
    g = _geometry(P)
    body = _body_balls(P, g).to_mesh("Body")
    c.decimate(body, BODY_TRIS[name])
    body.data.materials.append(materials["Wool"])
    tree = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    surf = _surface(tree)

    parts = Geo()
    _hooves_and_ears(P, g, parts, surf)
    face, eyes = _face(P, g, surf, materials)
    acc = _accessories(P, name, g, surf, eyes, materials)
    extras = [parts.to_object("Parts", materials, matrix=Matrix.Identity(4))]
    if P["bangs"]:
        bangs = _bangs(P, g).to_mesh("Bangs")
        c.decimate(bangs, 1400)
        bangs.data.materials.append(materials["Wool"])
        grp = bangs.vertex_groups.new(name="head")
        grp.add(list(range(len(bangs.data.vertices))), 1.0, 'REPLACE')
        extras.append(bangs)
    # Into the Blender frame (the character faces -Y).
    for ob in [body, face, *extras]:
        ob.data.transform(c.T, shape_keys=True) if ob.data.shape_keys else ob.data.transform(c.T)
    c.set_colors(body, _body_colors(P, name, g, body))
    if P["bangs"]:
        bc = _body_colors(P, name, g, extras[-1])
        c.set_colors(extras[-1], lambda i, co: c.scale(bc(i, co), 0.9))
    arm, arm_data = _rig(P, g, eyes)
    _skin(body, extras, arm)
    body.name = "Body"
    body.data.name = "Body"
    _bind_rigid(face, arm)
    for bone in ("ear_L", "ear_R", "lid_L", "lid_R"):
        arm_data.bones[bone].use_deform = True
    gear = []
    for bone, geo in acc.items():
        target = {"Scarf": "neck", "ScarfTail": "scarf"}.get(bone, bone)
        ob = geo.to_object(bone if bone in ("Scarf", "ScarfTail") else f"Acc_{bone}", materials)
        for vg in list(ob.vertex_groups):
            ob.vertex_groups.remove(vg)
        _attach(ob, arm, target)
        gear.append(ob)
    _actions(arm, P)
    for o in [body, face, *gear]:
        o.data.name = o.name
    tris = {o.name: c.triangles(o) for o in [body, face, *gear]}
    print("LLAMA", name, "tris", tris, "total", sum(tris.values()))
    c.export_glb(out_path, [arm, body, face, *gear])
    c.strip_channels(out_path, PROCEDURAL)
    print("EXPORTED", out_path)
    return dict(arm=arm, body=body, face=face, gear=gear, g=g, P=P)


def _bind_rigid(ob, arm):
    ob.parent = arm
    md = ob.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
