"""Builds an Aegis-destroyer style bridge + mast as a GLB for Godot.
Units: metres. +Y up, bow toward -Z (Godot forward), starboard +X.
Origin: deck level, centreline, foot of the deckhouse front face.
"""
import sys
import numpy as np
import trimesh
from trimesh.creation import cylinder, icosphere, box
from trimesh.visual.material import PBRMaterial
from trimesh.visual import TextureVisuals

OUT = sys.argv[1] if len(sys.argv) > 1 else "destroyer_bridge.glb"

MATS = {
    "Hull_Grey":    PBRMaterial(name="Hull_Grey",    baseColorFactor=[0.47, 0.50, 0.53, 1], metallicFactor=0.0, roughnessFactor=0.75),
    "Deck_Grey":    PBRMaterial(name="Deck_Grey",    baseColorFactor=[0.27, 0.29, 0.31, 1], metallicFactor=0.0, roughnessFactor=0.9),
    "Window_Dark":  PBRMaterial(name="Window_Dark",  baseColorFactor=[0.03, 0.04, 0.05, 1], metallicFactor=0.6, roughnessFactor=0.15),
    "Radome_White": PBRMaterial(name="Radome_White", baseColorFactor=[0.86, 0.87, 0.85, 1], metallicFactor=0.0, roughnessFactor=0.55),
    "Mast_Dark":    PBRMaterial(name="Mast_Dark",    baseColorFactor=[0.20, 0.21, 0.23, 1], metallicFactor=0.2, roughnessFactor=0.6),
    "SPY_Panel":    PBRMaterial(name="SPY_Panel",    baseColorFactor=[0.39, 0.42, 0.45, 1], metallicFactor=0.1, roughnessFactor=0.5),
    "Seam_Grey":    PBRMaterial(name="Seam_Grey",    baseColorFactor=[0.36, 0.39, 0.42, 1], metallicFactor=0.0, roughnessFactor=0.8),
}

parts = {}   # node name -> {material name -> [meshes]}


def add(node, mat, mesh, smooth=False):
    if not smooth:
        mesh = mesh.copy()
        mesh.unmerge_vertices()
    parts.setdefault(node, {}).setdefault(mat, []).append((mesh, smooth))


def hull(pts):
    return trimesh.convex.convex_hull(np.asarray(pts, float))


def chamfer_rect(hw, zf, zb, c, cz=None):
    cz = c if cz is None else cz
    return [(-hw + c, zf), (hw - c, zf), (hw, zf + cz), (hw, zb), (-hw, zb), (-hw, zf + cz)]


def prism(base, top, y0, y1):
    return hull([(x, y0, z) for x, z in base] + [(x, y1, z) for x, z in top])


def cyl(p0, p1, r, sections=8):
    return cylinder(radius=r, segment=[p0, p1], sections=sections)


def vcyl(x, y0, y1, z, r, sections=12, r_top=None):
    if r_top is None:
        return cyl((x, y0, z), (x, y1, z), r, sections)
    a = np.linspace(0, 2 * np.pi, sections, endpoint=False)
    pts = [(x + r * np.cos(t), y0, z + r * np.sin(t)) for t in a]
    pts += [(x + r_top * np.cos(t), y1, z + r_top * np.sin(t)) for t in a]
    return hull(pts)


def bx(cx, cy, cz, sx, sy, sz):
    m = box(extents=(sx, sy, sz))
    m.apply_translation((cx, cy, cz))
    return m


class Face:
    """A quad face of a prism, with bilinear (u,v) addressing and outward normal."""

    def __init__(self, bl, br, tr, tl, inside):
        self.bl, self.br, self.tr, self.tl = [np.asarray(p, float) for p in (bl, br, tr, tl)]
        n = np.cross(self.br - self.bl, self.tl - self.bl)
        n /= np.linalg.norm(n)
        c = (self.bl + self.br + self.tr + self.tl) / 4
        if np.dot(n, c - np.asarray(inside, float)) < 0:
            n = -n
        self.n = n

    def pt(self, u, v):
        b = self.bl + (self.br - self.bl) * u
        t = self.tl + (self.tr - self.tl) * u
        return b + (t - b) * v

    def panel(self, u0, u1, v0, v1, t=0.04, lift=0.0):
        q = [self.pt(u0, v0), self.pt(u1, v0), self.pt(u1, v1), self.pt(u0, v1)]
        return hull([p + self.n * lift for p in q] + [p + self.n * (lift + t) for p in q])

    def width(self, v=0.5):
        return np.linalg.norm(self.pt(1, v) - self.pt(0, v))

    def height(self):
        return np.linalg.norm(self.pt(0.5, 1) - self.pt(0.5, 0))

    def frame(self, u, v):
        """4x4 with local Z = normal, local Y = up along the face."""
        z = self.n
        x = np.cross((0, 1, 0), z)
        x /= np.linalg.norm(x)
        y = np.cross(z, x)
        m = np.eye(4)
        m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3] = x, y, z, self.pt(u, v)
        return m


def faces_of(base, top, y0, y1):
    n = len(base)
    inside = (np.mean([p[0] for p in base]), (y0 + y1) / 2, np.mean([p[1] for p in base]))
    out = []
    for i in range(n):
        j = (i + 1) % n
        out.append(Face((base[i][0], y0, base[i][1]), (base[j][0], y0, base[j][1]),
                        (top[j][0], y1, top[j][1]), (top[i][0], y1, top[i][1]), inside))
    return out


def railing(node, pts, h=1.05, closed=False, post_every=1.6):
    pts = [np.asarray(p, float) for p in pts]
    segs = list(zip(pts[:-1], pts[1:])) + ([(pts[-1], pts[0])] if closed else [])
    up = np.array((0, h, 0))
    for a, b in segs:
        L = np.linalg.norm(b - a)
        k = max(1, int(round(L / post_every)))
        for i in range(k + 1):
            p = a + (b - a) * i / k
            add(node, "Mast_Dark", cyl(p, p + up, 0.025, 4))
        for f in (0.5, 1.0):
            add(node, "Mast_Dark", cyl(a + up * f, b + up * f, 0.022, 4))


# ---------------------------------------------------------------- deckhouse
SWEEP = 1.5   # forward chamfers run this much further aft than they run sideways
A_Y0, A_Y1 = 0.0, 14.5
A_base = chamfer_rect(9.8, 0.0, 26.0, 6.5, 6.5 * SWEEP)
A_top = chamfer_rect(8.6, 1.6, 26.0, 6.0, 6.0 * SWEEP)
add("Deckhouse", "Hull_Grey", prism(A_base, A_top, A_Y0, A_Y1))
A_front, A_stbd_ch, A_stbd, A_back, A_port, A_port_ch = faces_of(A_base, A_top, A_Y0, A_Y1)

# deck-level seams and doors
for f in (A_front, A_stbd_ch, A_stbd, A_port, A_port_ch):
    for v in (0.2, 0.42, 0.66):
        add("Deckhouse", "Seam_Grey", f.panel(0.0, 1.0, v, v + 0.008, t=0.03))
for f in (A_stbd, A_port):
    for u in (0.18, 0.5, 0.8):
        add("Deckhouse", "Seam_Grey", f.panel(u, u + 0.045, 0.005, 0.15, t=0.05))     # doors
        add("Deckhouse", "Seam_Grey", f.panel(u - 0.01, u + 0.055, 0.43, 0.445, t=0.25))  # catwalk lip
    add("Deckhouse", "Seam_Grey", f.panel(0.30, 0.42, 0.72, 0.9, t=0.9))   # EW box
    add("Deckhouse", "Mast_Dark", f.panel(0.31, 0.41, 0.75, 0.87, t=0.05, lift=0.9))

# SPY-style octagonal array faces on the two forward chamfers
for f in (A_stbd_ch, A_port_ch):
    m = f.frame(0.5, 0.76)
    rot = trimesh.transformations.rotation_matrix(np.pi / 8, (0, 0, 1))
    frame = cylinder(radius=2.55, height=0.10, sections=8)
    frame.apply_transform(m @ rot @ trimesh.transformations.translation_matrix((0, 0, 0.05)))
    add("SPY_Panels", "Seam_Grey", frame)
    face = cylinder(radius=2.3, height=0.10, sections=8)
    face.apply_transform(m @ rot @ trimesh.transformations.translation_matrix((0, 0, 0.13)))
    add("SPY_Panels", "SPY_Panel", face)
    add("Deckhouse", "Seam_Grey", f.panel(0.2, 0.8, 0.08, 0.3, t=0.06))    # access hatch plate
    add("Deckhouse", "Mast_Dark", f.panel(0.42, 0.58, 0.02, 0.16, t=0.07))  # door

# central bastion that carries the CIWS platform
B_Y1 = 9.0
bas_base = [(-3.2, -4.0), (3.2, -4.0), (3.2, 1.0), (-3.2, 1.0)]
bas_top = [(-2.8, -3.2), (2.8, -3.2), (2.8, 2.5), (-2.8, 2.5)]
add("Deckhouse", "Hull_Grey", prism(bas_base, bas_top, 0, B_Y1))
bas_front = faces_of(bas_base, bas_top, 0, B_Y1)[0]
add("Deckhouse", "Window_Dark", bas_front.panel(0.34, 0.66, 0.0, 0.78, t=0.05))    # dark recess slot
add("Deckhouse", "Seam_Grey", bas_front.panel(0.30, 0.70, 0.78, 0.80, t=0.25))
add("Deckhouse", "Seam_Grey", bas_front.panel(0.40, 0.60, 0.30, 0.47, t=0.12))     # crest plate
for s in (-1, 1):                                                                  # slanted blast walls
    x1, x2 = s * 3.2, s * 4.1
    add("Deckhouse", "Hull_Grey", hull([
        (x1, 0, -7.5), (x2, 0, -7.5), (x1, 1.4, -7.5), (x2, 1.4, -7.5),
        (x1, 0, 0.6), (x2, 0, 0.6), (x1, 7.8, -2.6), (x2, 7.8, -2.6), (x1, 7.8, 0.9), (x2, 7.8, 0.9)]))

# CIWS platform + pedestal (the gun itself is the player camera, so only a marker is exported)
PLAT_Y, PLAT_Z = B_Y1, -1.9
plat = chamfer_rect(3.9, -5.0, 1.6, 1.4)
add("Deckhouse", "Deck_Grey", prism(plat, plat, PLAT_Y, PLAT_Y + 0.22))
add("Deckhouse", "Hull_Grey", prism([(-2.8, -3.2), (2.8, -3.2), (2.8, 1.5), (-2.8, 1.5)], plat, PLAT_Y - 1.2, PLAT_Y))
railing("Railings", [(-3.9, PLAT_Y + 0.22, 1.2), (-3.9, PLAT_Y + 0.22, -3.6), (-2.5, PLAT_Y + 0.22, -5.0),
                     (2.5, PLAT_Y + 0.22, -5.0), (3.9, PLAT_Y + 0.22, -3.6), (3.9, PLAT_Y + 0.22, 1.2)])
add("Deckhouse", "Hull_Grey", vcyl(0, PLAT_Y + 0.22, PLAT_Y + 0.75, PLAT_Z, 1.15, 16, r_top=0.95))
CIWS_MOUNT = (0, PLAT_Y + 0.75, PLAT_Z)

# ---------------------------------------------------------------- bridge
BR_Y0, BR_Y1 = A_Y1, 16.5
br_base = chamfer_rect(7.2, 0.6, 15.0, 3.6, 3.6 * SWEEP)
br_top = chamfer_rect(7.6, 0.1, 15.0, 3.8, 3.8 * SWEEP)
add("Bridge", "Hull_Grey", prism(br_base, br_top, BR_Y0, BR_Y1))
br_faces = faces_of(br_base, br_top, BR_Y0, BR_Y1)
for i, f in enumerate(br_faces):
    if i == 3:
        continue                                  # aft face has no windows
    u_end = 0.45 if i in (2, 4) else 1.0          # side windows only on the forward part
    u_a, u_b = (0.0, u_end) if i != 4 else (1 - u_end, 1.0)
    n = max(2, int(round(f.width() * (u_b - u_a) / 1.15)))
    for k in range(n):
        u0 = u_a + (u_b - u_a) * (k + 0.12) / n
        u1 = u_a + (u_b - u_a) * (k + 0.88) / n
        add("Windows", "Window_Dark", f.panel(u0, u1, 0.34, 0.86, t=0.03))
    add("Bridge", "Seam_Grey", f.panel(0, 1, 0.26, 0.30, t=0.07))     # sill
# visor / roof
roof = chamfer_rect(8.1, -0.5, 15.3, 4.0, 4.0 * SWEEP)
add("Bridge", "Hull_Grey", prism(roof, roof, BR_Y1, BR_Y1 + 0.3))
ROOF_Y = BR_Y1 + 0.3
railing("Railings", [(-8.0, ROOF_Y, 14), (-8.0, ROOF_Y, 5.4), (-4.1, ROOF_Y, -0.4), (4.1, ROOF_Y, -0.4),
                     (8.0, ROOF_Y, 5.4), (8.0, ROOF_Y, 14)])
for s in (-1, 1):
    # floodlights under the visor
    add("Bridge", "Mast_Dark", bx(s * 2.6, BR_Y1 + 0.55, -0.15, 0.5, 0.4, 0.4))

# ---------------------------------------------------------------- top house, director, radomes
C_Y0, C_Y1 = ROOF_Y, 18.7
c_base = chamfer_rect(4.6, 2.6, 14.0, 2.0)
c_top = chamfer_rect(4.1, 3.2, 14.0, 1.9)
add("Bridge", "Hull_Grey", prism(c_base, c_top, C_Y0, C_Y1))
for f in faces_of(c_base, c_top, C_Y0, C_Y1)[:3]:
    add("Bridge", "Seam_Grey", f.panel(0, 1, 0.5, 0.52, t=0.03))
railing("Railings", [(-4.0, C_Y1, 13.5), (-4.0, C_Y1, 5.2), (-2.2, C_Y1, 3.3), (2.2, C_Y1, 3.3), (4.0, C_Y1, 5.2), (4.0, C_Y1, 13.5)])

# missile illuminator (dish on a pedestal) above the bridge
D = np.array((0, C_Y1, 5.0))
add("Director", "Hull_Grey", vcyl(D[0], D[1], D[1] + 1.1, D[2], 0.75, 12, r_top=0.6))
add("Director", "Hull_Grey", bx(D[0], D[1] + 1.55, D[2], 2.3, 0.9, 0.9))
aim = np.array((0, 0.35, -1.0)); aim /= np.linalg.norm(aim)
dc = D + (0, 1.65, -0.55)
a = np.linspace(0, 2 * np.pi, 20, endpoint=False)
rx = np.array((1, 0, 0)); ry = np.cross(aim, rx)
rim = [dc + aim * 0.55 + (rx * np.cos(t) + ry * np.sin(t)) * 1.25 for t in a]
back = [dc + (rx * np.cos(t) + ry * np.sin(t)) * 0.45 for t in a]
add("Director", "Hull_Grey", hull(rim + back))
add("Director", "SPY_Panel", hull(rim + [p + aim * 0.06 for p in rim]))
add("Director", "Mast_Dark", cyl(dc + aim * 0.6, dc + aim * 1.15, 0.09, 6))

# white satcom radomes either side
for s in (-1, 1):
    add("Radomes", "Hull_Grey", vcyl(s * 6.2, ROOF_Y, ROOF_Y + 1.0, 7.0, 0.7, 12, r_top=0.55))
    sp = icosphere(subdivisions=3, radius=1.2); sp.apply_translation((s * 6.2, ROOF_Y + 1.9, 7.0))
    add("Radomes", "Radome_White", sp, smooth=True)
    sp = icosphere(subdivisions=2, radius=0.55); sp.apply_translation((s * 3.0, C_Y1 + 0.75, 11.5))
    add("Radomes", "Hull_Grey", vcyl(s * 3.0, C_Y1, C_Y1 + 0.4, 11.5, 0.3, 8))
    add("Radomes", "Radome_White", sp, smooth=True)
    # whip antennas at the roof corners
    add("Mast", "Mast_Dark", cyl((s * 7.6, ROOF_Y, 13.0), (s * 8.6, ROOF_Y + 7.5, 13.6), 0.035, 4))

# ---------------------------------------------------------------- mast
M_Y0, M_Y1 = C_Y1, 33.0
add("Mast", "Mast_Dark", hull(
    [(x, M_Y0, z) for x in (-1.7, 1.7) for z in (8.2, 12.8)] + [(x, M_Y0, z) for x in (-1.2, 1.2) for z in (7.7, 13.3)] +
    [(x, M_Y1, z) for x in (-0.6, 0.6) for z in (11.4, 12.9)] + [(x, M_Y1, z) for x in (-0.4, 0.4) for z in (11.2, 13.1)]))


def mast_z(y):          # centreline of the raked trunk
    t = (y - M_Y0) / (M_Y1 - M_Y0)
    return 10.5 + (12.15 - 10.5) * t


# tripod legs and bracing
for s in (-1, 1):
    add("Mast", "Mast_Dark", cyl((s * 2.6, M_Y0, 6.4), (s * 0.5, 28.2, mast_z(28.2) - 0.6), 0.24, 8))
    add("Mast", "Mast_Dark", cyl((s * 2.0, 21.2, 7.6), (s * 0.9, 22.6, mast_z(22.6)), 0.10, 6))
    add("Mast", "Mast_Dark", cyl((s * 1.3, 24.6, 9.2), (-s * 1.3, 24.6, 9.2), 0.10, 6))
add("Mast", "Mast_Dark", cyl((-2.0, 21.2, 7.6), (2.0, 21.2, 7.6), 0.10, 6))
# white dome on the mast front, above the director
add("Mast", "Mast_Dark", bx(0, 21.0, 8.1, 1.6, 0.25, 2.2))
sp = icosphere(subdivisions=3, radius=0.85); sp.apply_translation((0, 21.9, 7.7))
add("Radomes", "Radome_White", sp, smooth=True)

# main yardarm
YA_Y, YA_Z, YA_HW = 24.6, 11.3, 7.6
add("Mast", "Mast_Dark", bx(0, YA_Y, YA_Z, YA_HW * 2, 0.28, 0.34))
add("Mast", "Mast_Dark", bx(0, YA_Y + 0.9, YA_Z, YA_HW * 1.5, 0.12, 0.12))
for s in (-1, 1):
    add("Mast", "Mast_Dark", cyl((s * YA_HW, YA_Y, YA_Z), (s * 0.6, 28.0, mast_z(28.0)), 0.07, 5))
    add("Mast", "Mast_Dark", cyl((s * YA_HW * 0.75, YA_Y, YA_Z), (s * 0.9, 22.4, mast_z(22.4)), 0.07, 5))
    for k, fx in enumerate((1.0, 0.82, 0.62, 0.42, 0.24)):
        x = s * YA_HW * fx
        add("Mast", "Mast_Dark", cyl((x, YA_Y, YA_Z), (x, YA_Y + 0.9, YA_Z), 0.05, 4))
        if k in (0, 2):
            add("Mast", "Mast_Dark", cyl((x, YA_Y + 0.9, YA_Z), (x, YA_Y + 3.4 - k * 0.5, YA_Z), 0.035, 4))   # whips
        if k in (1, 3):
            add("Mast", "Mast_Dark", bx(x, YA_Y - 0.45, YA_Z, 0.45, 0.6, 0.45))                              # lights / ESM boxes
        if k == 4:
            add("Mast", "Radome_White", vcyl(x, YA_Y + 0.9, YA_Y + 1.7, YA_Z, 0.28, 8))
    # signal halyards down to the bridge roof
    for fx, rx_ in ((0.95, 6.4), (0.78, 5.2), (0.58, 3.9), (0.40, 2.7)):
        add("Halyards", "Mast_Dark", cyl((s * YA_HW * fx, YA_Y - 0.14, YA_Z), (s * rx_, ROOF_Y + 0.1, 12.6), 0.02, 3))
# short upper spreader
add("Mast", "Mast_Dark", bx(0, 27.0, mast_z(27.0), 8.6, 0.2, 0.25))
for s in (-1, 1):
    add("Mast", "Mast_Dark", cyl((s * 4.3, 27.0, mast_z(27.0)), (s * 4.3, 28.4, mast_z(27.0)), 0.04, 4))
    add("Mast", "Mast_Dark", bx(s * 4.3, 26.7, mast_z(27.0), 0.4, 0.5, 0.4))

# big radar platform
P_Y, P_Z, P_R = 29.2, 11.2, 3.7
ang = np.linspace(0, 2 * np.pi, 8, endpoint=False) + np.pi / 8
ring = [(P_R * np.cos(t), P_Z + P_R * np.sin(t)) for t in ang]
add("Mast", "Mast_Dark", prism(ring, ring, P_Y, P_Y + 0.35))
neck = [(0.9 * np.cos(t), mast_z(27.2) + 0.9 * np.sin(t)) for t in ang]
add("Mast", "Mast_Dark", prism(neck, [(x * 0.82, P_Z + (z - P_Z) * 0.82) for x, z in ring], 27.2, P_Y))
railing("Railings", [(x, P_Y + 0.35, z) for x, z in ring], h=1.0, closed=True, post_every=1.4)
# surface search radar: pedestal + bar antenna, forward on the platform
add("Mast", "Mast_Dark", vcyl(0, P_Y + 0.35, P_Y + 1.2, P_Z - 2.2, 0.35, 8))
add("Mast", "Radome_White", bx(0, P_Y + 1.4, P_Z - 2.2, 3.4, 0.38, 0.3))
for s in (-1, 1):   # ESM cans on the platform edge
    add("Mast", "Mast_Dark", vcyl(s * 2.9, P_Y + 0.35, P_Y + 1.5, P_Z + 0.2, 0.42, 10, r_top=0.3))

# upper platform, dome and topmast
U_Y = 31.8
ring2 = [(2.1 * np.cos(t), mast_z(U_Y) + 2.1 * np.sin(t)) for t in ang]
add("Mast", "Mast_Dark", prism(ring2, ring2, U_Y, U_Y + 0.25))
add("Mast", "Mast_Dark", prism([(x * 0.35, mast_z(30.6) + (z - mast_z(U_Y)) * 0.35) for x, z in ring2], [(x * 0.85, mast_z(U_Y) + (z - mast_z(U_Y)) * 0.85) for x, z in ring2], 30.6, U_Y))
sp = icosphere(subdivisions=2, radius=0.6); sp.apply_translation((0, U_Y + 0.8, mast_z(U_Y) - 1.3))
add("Radomes", "Radome_White", sp, smooth=True)
TZ = 12.2
add("Mast", "Mast_Dark", vcyl(0, M_Y1, 38.6, TZ, 0.32, 10, r_top=0.2))
add("Mast", "Mast_Dark", vcyl(0, 34.0, 34.14, TZ, 1.0, 12))
add("Mast", "Radome_White", vcyl(0, 35.2, 36.3, TZ, 0.72, 14))          # TACAN drum
add("Mast", "Mast_Dark", vcyl(0, 36.3, 36.42, TZ, 0.85, 12))
add("Mast", "Mast_Dark", vcyl(0, 37.4, 37.5, TZ, 0.55, 10))
add("Mast", "Mast_Dark", vcyl(0, 38.3, 38.4, TZ, 0.4, 10))
add("Mast", "Mast_Dark", vcyl(0, 38.6, 42.0, TZ, 0.07, 5, r_top=0.03))
for s in (-1, 1):
    add("Mast", "Mast_Dark", cyl((s * 0.9, 34.14, TZ), (s * 0.9, 35.6, TZ), 0.03, 4))

# ---------------------------------------------------------------- export
scene = trimesh.Scene()
tri = 0
for node, bymat in parts.items():
    for mat, items in bymat.items():
        for smooth in (False, True):
            ms = [m for m, s in items if s == smooth]
            if not ms:
                continue
            m = trimesh.util.concatenate(ms)
            if not smooth:
                m.unmerge_vertices()
            m.visual = TextureVisuals(material=MATS[mat])
            tri += len(m.faces)
            name = f"{node}_{mat}" + ("_smooth" if smooth else "")
            scene.add_geometry(m, node_name=name, geom_name=name)
scene.graph.update(frame_to="CIWS_Mount", frame_from=scene.graph.base_frame,
                   matrix=trimesh.transformations.translation_matrix(CIWS_MOUNT))
data = scene.export(file_type="glb", include_normals=True)
open(OUT, "wb").write(data)
print("triangles", tri, "bytes", len(data), "bounds", scene.bounds.round(2).tolist(), "ciws", CIWS_MOUNT)
