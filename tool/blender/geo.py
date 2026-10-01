"""A small mesh builder for the character details (Blender 5.2).

Geometry is generated in Python with per-vertex colours, bone weights and
morph positions, then turned into one Blender object. Primitives take a
4x4 matrix that maps their unit shape into the authoring frame, and an
optional `shapes` dict of matrices (or point functions) giving the same
primitive's placement in each morph target.
"""

import math

import bpy
from mathutils import Matrix, Vector

import common as c


class Geo:
    def __init__(self, shapes=()):
        self.shapes = list(shapes)
        self.v = []
        self.sv = {s: [] for s in self.shapes}
        self.col = []
        self.grp = []
        self.f = []
        self.fm = []
        self.mats = []

    def _mat(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def add(self, pts, faces, color, mat, group=(("head", 1.0),), shapes=None, local=None):
        """Adds raw geometry. `pts` are authoring-frame points; `shapes`
        maps a morph name to that morph's points; `color` is an RGB tuple
        or a function of (local point, point)."""
        base = len(self.v)
        mi = self._mat(mat)
        for i, p in enumerate(pts):
            self.v.append(Vector(p))
            lp = local[i] if local else p
            self.col.append(color(lp, p) if callable(color) else color)
            self.grp.append(group(lp, p) if callable(group) else group)
            for s in self.shapes:
                self.sv[s].append(Vector(shapes[s][i]) if shapes and s in shapes else Vector(p))
        for f in faces:
            self.f.append(tuple(base + i for i in f))
            self.fm.append(mi)
        return base

    def prim(self, unit_pts, faces, M, color, mat, group=(("head", 1.0),), shapes=None):
        pts = [M @ Vector(p) for p in unit_pts]
        sh = None
        if shapes:
            sh = {}
            for name, S in shapes.items():
                sh[name] = [S(Vector(p)) if callable(S) else S @ Vector(p) for p in unit_pts]
        return self.add(pts, faces, color, mat, group, sh, local=[Vector(p) for p in unit_pts])

    # ------------------------------------------------------------ primitives

    def sphere(self, M, color, mat, seg=16, rings=10, group=(("head", 1.0),), shapes=None, power=2.0,
               zmin=-1.0, zmax=1.0):
        pts, faces = sphere_grid(seg, rings, power, zmin, zmax)
        return self.prim(pts, faces, M, color, mat, group, shapes)

    def tube(self, path, radius, color, mat, seg=8, group=(("head", 1.0),), shapes=None, up=Vector((0, 0, 1)),
             flat=1.0, caps=True):
        """A tube along `path` (list of points); `radius` is a float or a
        function of t in [0, 1]. `shapes` maps morph names to other paths.
        `flat` squashes the cross-section along `up`."""
        def ring_pts(pth):
            out = []
            n = len(pth)
            for i, p in enumerate(pth):
                t = i / (n - 1)
                tan = (pth[min(n - 1, i + 1)] - pth[max(0, i - 1)]).normalized()
                side = tan.cross(up)
                if side.length < 1e-6:
                    side = tan.orthogonal()
                side.normalize()
                nrm = side.cross(tan).normalized()
                r = radius(t) if callable(radius) else radius
                for k in range(seg):
                    a = 2 * math.pi * k / seg
                    out.append(Vector(p) + side * math.cos(a) * r + nrm * math.sin(a) * r * flat)
            if caps:
                out.append(Vector(pth[0]))
                out.append(Vector(pth[-1]))
            return out

        n = len(path)
        faces = []
        for i in range(n - 1):
            for k in range(seg):
                a, b = i * seg + k, i * seg + (k + 1) % seg
                faces.append((a, a + seg, b + seg, b))
        if caps:
            s0, s1 = n * seg, n * seg + 1
            for k in range(seg):
                faces.append((s0, k, (k + 1) % seg))
                faces.append((s1, (n - 1) * seg + (k + 1) % seg, (n - 1) * seg + k))
        pts = ring_pts([Vector(p) for p in path])
        sh = {name: ring_pts([Vector(p) for p in pth]) for name, pth in (shapes or {}).items()}
        return self.add(pts, faces, color, mat, group, sh or None)

    def cylinder(self, M, color, mat, seg=16, r_top=1.0, group=(("head", 1.0),), caps=True, shapes=None):
        """Unit cylinder (radius 1 at z=-1 tapering to `r_top` at z=1)."""
        pts, faces = [], []
        for z, r in ((-1.0, 1.0), (1.0, r_top)):
            for k in range(seg):
                a = 2 * math.pi * k / seg
                pts.append((math.cos(a) * r, math.sin(a) * r, z))
        for k in range(seg):
            faces.append((k, (k + 1) % seg, seg + (k + 1) % seg, seg + k))
        if caps:
            pts += [(0, 0, -1), (0, 0, 1)]
            for k in range(seg):
                faces.append((2 * seg, (k + 1) % seg, k))
                faces.append((2 * seg + 1, seg + k, seg + (k + 1) % seg))
        return self.prim(pts, faces, M, color, mat, group, shapes)

    def torus(self, M, minor, color, mat, seg=24, ring=8, group=(("head", 1.0),), arc=2 * math.pi, shapes=None):
        """Unit-major-radius torus in the XY plane; `arc` < 2 pi makes an open bend."""
        closed = arc >= 2 * math.pi - 1e-6
        n = seg if closed else seg + 1
        pts, faces = [], []
        for i in range(n):
            a = arc * i / seg
            for k in range(ring):
                b = 2 * math.pi * k / ring
                r = 1 + minor * math.cos(b)
                pts.append((math.cos(a) * r, math.sin(a) * r, minor * math.sin(b)))
        for i in range(seg):
            j = (i + 1) % n
            for k in range(ring):
                faces.append((i * ring + k, j * ring + k, j * ring + (k + 1) % ring, i * ring + (k + 1) % ring))
        return self.prim(pts, faces, M, color, mat, group, shapes)

    # ------------------------------------------------------------ output

    def to_object(self, name, materials, matrix=c.T):
        me = bpy.data.meshes.new(name)
        me.from_pydata([matrix @ p for p in self.v], [], self.f)
        me.update()
        for m in self.mats:
            me.materials.append(materials[m])
        for p, mi in zip(me.polygons, self.fm):
            p.material_index = mi
            p.use_smooth = True
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        c.set_colors(ob, lambda i, _: self.col[i])
        groups = {}
        for i, g in enumerate(self.grp):
            for bone, w in g:
                if bone not in groups:
                    groups[bone] = ob.vertex_groups.new(name=bone)
                groups[bone].add([i], w, 'REPLACE')
        if self.shapes:
            ob.shape_key_add(name="Basis")
            for s in self.shapes:
                sk = ob.shape_key_add(name=s)
                for i, p in enumerate(self.sv[s]):
                    sk.data[i].co = matrix @ p
        return ob


def sphere_grid(seg, rings, power=2.0, zmin=-1.0, zmax=1.0, cap=None):
    """Unit (super)sphere: `power` 2 is round, higher is boxier. Rings run
    from the top pole to the bottom pole; `zmin`/`zmax` flatten it. With
    `cap` (radians) only the polar cap of that half-angle is made, closed
    by a flat disc."""
    def sp(x, e):
        return math.copysign(abs(x) ** e, x)

    e = 2.0 / power
    top = math.pi if cap is None else cap
    pts = [(0, 0, 1)]
    for r in range(1, rings):
        th = top * r / (rings - (0 if cap is None else 1))
        for k in range(seg):
            ph = 2 * math.pi * k / seg
            pts.append((sp(math.sin(th), e) * sp(math.cos(ph), e), sp(math.sin(th), e) * sp(math.sin(ph), e), sp(math.cos(th), e)))
    pts.append((0, 0, -1) if cap is None else (0, 0, math.cos(top)))
    pts = [(x, y, max(zmin, min(zmax, z))) for x, y, z in pts]
    faces = []
    for k in range(seg):
        faces.append((0, 1 + k, 1 + (k + 1) % seg))
    for r in range(rings - 2):
        for k in range(seg):
            a = 1 + r * seg + k
            b = 1 + r * seg + (k + 1) % seg
            faces.append((a, a + seg, b + seg, b))
    last = len(pts) - 1
    base = 1 + (rings - 2) * seg
    for k in range(seg):
        faces.append((last, base + (k + 1) % seg, base + k))
    return pts, faces


def frame(origin, x, y, z, sx=1.0, sy=1.0, sz=1.0):
    """Matrix placing a unit primitive at `origin` with axes x, y, z (scaled)."""
    m = Matrix((
        (x[0] * sx, y[0] * sy, z[0] * sz, origin[0]),
        (x[1] * sx, y[1] * sy, z[1] * sz, origin[1]),
        (x[2] * sx, y[2] * sy, z[2] * sz, origin[2]),
        (0, 0, 0, 1),
    ))
    return m


def basis_from(normal, up=Vector((0, 0, 1))):
    """(normal, side, up) orthonormal basis with `normal` as the first axis."""
    n = Vector(normal).normalized()
    s = up.cross(n)
    if s.length < 1e-6:
        s = n.orthogonal()
    s.normalize()
    u = n.cross(s).normalized()
    return n, s, u


def trs(loc, rot_deg=(0, 0, 0), size=(1, 1, 1)):
    """Translation @ Euler XYZ rotation (degrees) @ scale."""
    from mathutils import Euler
    rot = Euler([math.radians(a) for a in rot_deg], 'XYZ').to_matrix().to_4x4()
    return Matrix.Translation(loc) @ rot @ Matrix.Diagonal((*size, 1))
