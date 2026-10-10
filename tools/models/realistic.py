"""Realistic creature models: real anatomy (segmented bodies, jointed legs,
compound eyes, elbowed antennae, glossy chitin), still readable at game
distance. Each faces -Y; the export normalises height."""

import math

from lib import cone, ellipsoid, gloss, tube, wing


def lerp3(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def ring(role, centre, rx, rz, color, thickness, material="SmoothPlastic", axis="y", n=28):
    """A closed band around an axis (segment edges on abdomens)."""
    cx, cy, cz = centre
    pts = []
    for k in range(n + 1):
        t = k / n * math.tau
        if axis == "y":
            pts.append((cx + math.cos(t) * rx, cy, cz + math.sin(t) * rz))
        else:
            pts.append((cx, cy + math.cos(t) * rx, cz + math.sin(t) * rz))
    return tube(role, pts, [thickness] * len(pts), color, material, sides=6)


def jointed_leg(role, points, thick, color, joint_color=None, tarsi=4, material="SmoothPlastic"):
    """coxa -> femur -> tibia -> tarsus: `points` = [hip, knee, ankle, foot].
    Femur thickest, tibia thinner, tarsus a chain of small beads + claw."""
    hip, knee, ankle, foot = points
    tube(role, [hip, lerp3(hip, knee, 0.5), knee], [thick * 1.1, thick * 1.2, thick * 0.85], color, material, sides=8)
    tube(role, [knee, lerp3(knee, ankle, 0.5), ankle], [thick * 0.8, thick * 0.7, thick * 0.55], color, material, sides=8)
    jc = joint_color or color
    ellipsoid(role + "Joint", knee, (thick * 0.95,) * 3, jc, material, segments=10)
    ellipsoid(role + "Joint", ankle, (thick * 0.6,) * 3, jc, material, segments=8)
    for i in range(tarsi):
        t0, t1 = i / tarsi, (i + 0.85) / tarsi
        a, b = lerp3(ankle, foot, t0), lerp3(ankle, foot, t1)
        tube(role, [a, b], [thick * 0.45, thick * 0.38], jc, material, sides=6)
    d = [foot[i] - ankle[i] for i in range(3)]
    n = math.sqrt(sum(c * c for c in d)) or 1
    cone(role, foot, tuple(foot[i] + d[i] / n * thick * 1.2 for i in range(3)), thick * 0.35, jc, material, sides=5)


def elbow_antenna(role, base, elbow, tip, thick, color, beads=10, club=0):
    """Scape (long first segment) then a segmented flagellum: one tube whose
    radius pulses per segment, thickening into a club at the tip."""
    tube(role, [base, elbow], [thick, thick * 0.85], color, sides=8)
    pts, radii = [], []
    steps = beads * 2
    for i in range(steps + 1):
        t = i / steps
        p = lerp3(elbow, tip, t)
        pts.append((p[0], p[1], p[2] - math.sin(t * math.pi) * 0.03))
        seg = i // 2
        bulge = 1.0 if i % 2 else 0.72
        radii.append(thick * bulge * (1.5 if seg >= beads - club else 0.85))
    tube(role, pts, radii, color, sides=8)


def compound_eye(centre, radii, color=(40, 30, 28), role="CompoundEye"):
    eye = ellipsoid(role, centre, radii, color, "SmoothPlastic", segments=16)
    gloss(role, 0.25)
    return eye


def bristles(role, anchors, length, color, thick=0.006):
    for (x, y, z), (dx, dy, dz) in anchors:
        tube(role, [(x, y, z), (x + dx * length, y + dy * length, z + dz * length)], [thick, thick * 0.3], color, sides=4)


def mirror_pairs(fn):
    for side in (-1, 1):
        fn(side)


# --------------------------------------------------------------------- ant
def ant():
    shell = "Tint"
    dark = "TintDark"
    # Head: heart-shaped from two rear lobes and a broad face.
    ellipsoid("Head", (0, -0.78, 0.5), (0.17, 0.15, 0.14), shell, segments=22)
    for side in (-1, 1):
        ellipsoid("Head", (side * 0.08, -0.7, 0.53), (0.11, 0.11, 0.12), shell, segments=16)
    ellipsoid("Clypeus", (0, -0.91, 0.47), (0.09, 0.05, 0.06), dark)
    gloss("Head", 0.1)

    def head_side(side):
        compound_eye((side * 0.155, -0.8, 0.55), (0.04, 0.055, 0.045))
        # Mandibles: curved blades with teeth along the inner edge.
        base = (side * 0.07, -0.92, 0.44)
        mid = (side * 0.07, -1.02, 0.42)
        tip = (side * 0.0, -1.07, 0.41)
        tube("Mandible", [base, mid, tip], [0.032, 0.024, 0.008], dark, sides=8)
        for k in range(3):
            p = lerp3(mid, tip, 0.15 + k * 0.3)
            cone("Mandible", p, (p[0] - side * 0.02, p[1] - 0.005, p[2]), 0.008, dark, sides=4)
        elbow_antenna(
            "Antenna",
            (side * 0.06, -0.9, 0.55),
            (side * 0.2, -1.0, 0.82),
            (side * 0.3, -1.3, 0.72),
            0.016,
            dark,
            beads=10,
            club=3,
        )

    mirror_pairs(head_side)
    # Mesosoma: pronotum, mesonotum, propodeum (stepping down).
    ellipsoid("Thorax", (0, -0.5, 0.5), (0.1, 0.13, 0.1), shell, segments=18)
    ellipsoid("Thorax", (0, -0.33, 0.49), (0.085, 0.1, 0.085), shell, segments=16)
    ellipsoid("Thorax", (0, -0.2, 0.45), (0.075, 0.08, 0.075), shell, segments=16)
    gloss("Thorax", 0.1)
    # Waist: petiole node standing up, then the gaster.
    tube("Petiole", [(0, -0.13, 0.43), (0, -0.07, 0.47), (0, -0.02, 0.45)], [0.03, 0.045, 0.03], dark, sides=10)
    ellipsoid("Petiole", (0, -0.07, 0.5), (0.04, 0.025, 0.055), dark)
    ellipsoid("Gaster", (0, 0.25, 0.5), (0.24, 0.3, 0.21), shell, segments=28)
    gloss("Gaster", 0.18)
    for k, (y, rx, rz) in enumerate(((0.12, 0.225, 0.2), (0.27, 0.235, 0.205), (0.41, 0.19, 0.17))):
        ring("Band", (0, y, 0.5), rx, rz, dark, 0.012)
    cone("Sting", (0, 0.53, 0.47), (0, 0.6, 0.44), 0.02, dark, sides=6)
    bristles("Hair", [((0.05 * (k % 3 - 1), 0.2 + 0.08 * (k // 3), 0.7 - 0.02 * (k // 3)), (0.2, 0.4, 0.9)) for k in range(9)], 0.06, (200, 170, 140))
    # Six long legs from the mesosoma underside, front pair reaching forward.
    legs = [(-0.48, -0.5), (-0.34, 0.0), (-0.22, 0.55)]
    for hip_y, swing in legs:
        for side in (-1, 1):
            hip = (side * 0.06, hip_y, 0.42)
            knee = (side * 0.26, hip_y + swing * 0.2, 0.56)
            ankle = (side * 0.42, hip_y + swing * 0.45, 0.14)
            foot = (side * 0.5, hip_y + swing * 0.6, 0.0)
            jointed_leg("Leg", [hip, knee, ankle, foot], 0.028, shell, dark)


def leg_set(hips, reach, lift, thick, color, joint, splay=(-0.5, 0.0, 0.55), hip_z=0.4, foot_scale=1.0):
    """Three pairs of jointed legs from hip y-positions."""
    for hip_y, swing in zip(hips, splay):
        for side in (-1, 1):
            hip = (side * 0.07, hip_y, hip_z)
            knee = (side * reach * 0.5, hip_y + swing * 0.2 * reach, hip_z + lift)
            ankle = (side * reach * 0.82, hip_y + swing * 0.45 * reach, 0.12)
            foot = (side * reach * foot_scale, hip_y + swing * 0.6 * reach, 0.0)
            jointed_leg("Leg", [hip, knee, ankle, foot], thick, color, joint)


# ------------------------------------------------------------------ spider
def spider():
    fur = "Tint"
    dark = "TintDark"
    # Cephalothorax (front) and a big hairy opisthosoma (abdomen).
    ellipsoid("Cephalothorax", (0, -0.25, 0.4), (0.24, 0.28, 0.15), fur, "Fabric", segments=24)
    ellipsoid("Carapace", (0, -0.27, 0.48), (0.18, 0.22, 0.08), dark, "SmoothPlastic", segments=20)
    gloss("Carapace", 0.08)
    tube("Pedicel", [(0, -0.02, 0.4), (0, 0.06, 0.42)], [0.06, 0.07], dark, sides=10)
    ellipsoid("Abdomen", (0, 0.42, 0.5), (0.34, 0.42, 0.3), fur, "Fabric", segments=28)
    # Chevron markings down the abdomen.
    for k in range(4):
        y = 0.22 + k * 0.12
        w = 0.14 - k * 0.025
        for side in (-1, 1):
            tube("Marking", [(0, y + 0.04, 0.79 - k * 0.02), (side * w, y - 0.02, 0.765 - k * 0.025)], [0.018, 0.012], (225, 205, 170), "Fabric", sides=5)
    bristles("Hair", [((0.12 * math.cos(k), 0.42 + 0.25 * math.sin(k * 1.7), 0.74), (math.cos(k) * 0.4, 0.2, 0.9)) for k in range(14)], 0.07, (90, 75, 65))
    # Eight eyes: two big forward, six small around.
    for side in (-1, 1):
        compound_eye((side * 0.05, -0.5, 0.52), (0.045, 0.035, 0.045), (20, 15, 15), "Eye")
        compound_eye((side * 0.12, -0.46, 0.53), (0.028,) * 3, (20, 15, 15), "Eye")
        compound_eye((side * 0.09, -0.42, 0.58), (0.022,) * 3, (20, 15, 15), "Eye")
        compound_eye((side * 0.15, -0.38, 0.55), (0.02,) * 3, (20, 15, 15), "Eye")
        # Chelicerae with fangs, and pedipalps.
        tube("Chelicera", [(side * 0.05, -0.5, 0.38), (side * 0.05, -0.56, 0.28)], [0.04, 0.035], dark, sides=8)
        cone("Fang", (side * 0.05, -0.56, 0.27), (side * 0.02, -0.6, 0.2), 0.02, (30, 25, 25), sides=6)
        tube("Palp", [(side * 0.1, -0.48, 0.36), (side * 0.18, -0.6, 0.3), (side * 0.16, -0.68, 0.15)], [0.025, 0.022, 0.02], fur, "Fabric", sides=6)
    # Eight long jointed legs: high knees, feet planted wide.
    angles = [-62, -25, 15, 50]
    for i, a in enumerate(angles):
        ar = math.radians(a)
        for side in (-1, 1):
            dx, dy = math.cos(ar) * side, math.sin(ar)
            hip = (side * 0.14, -0.3 + i * 0.07, 0.38)
            reach = 0.95 if i in (0, 3) else 0.85
            knee = (hip[0] + dx * reach * 0.38, hip[1] + dy * reach * 0.38, 0.85)
            ankle = (hip[0] + dx * reach * 0.78, hip[1] + dy * reach * 0.78, 0.3)
            foot = (hip[0] + dx * reach, hip[1] + dy * reach, 0.0)
            jointed_leg("Leg", [hip, knee, ankle, foot], 0.034, fur, dark, tarsi=3, material="Fabric")


# ------------------------------------------------------------------ beetle
def beetle():
    shell = "Tint"
    dark = "TintDark"
    # Elytra: two domed wing cases meeting at a seam, with grooves.
    for side in (-1, 1):
        ellipsoid("Elytra", (side * 0.085, 0.15, 0.42), (0.2, 0.52, 0.27), shell, segments=26)
        for k in range(3):
            x = side * (0.06 + k * 0.07)
            tube("Groove", [(x, -0.25, 0.6 - k * 0.04), (x, 0.15, 0.68 - k * 0.06), (x * 0.9, 0.55, 0.5 - k * 0.05)], [0.006] * 3, dark, sides=5)
    gloss("Elytra", 0.28)
    tube("Seam", [(0, -0.3, 0.64), (0, 0.15, 0.69), (0, 0.62, 0.42)], [0.012, 0.012, 0.008], dark, sides=6)
    ellipsoid("Pronotum", (0, -0.42, 0.4), (0.28, 0.17, 0.2), shell, segments=22)
    gloss("Pronotum", 0.28)
    ellipsoid("Scutellum", (0, -0.27, 0.6), (0.05, 0.04, 0.02), dark)
    ellipsoid("Head", (0, -0.62, 0.34), (0.15, 0.12, 0.12), dark, segments=18)
    gloss("Head", 0.2)
    # Rhinoceros horn curving up, a smaller thoracic horn.
    tube("Horn", [(0, -0.7, 0.36), (0, -0.85, 0.45), (0, -0.93, 0.62), (0, -0.9, 0.76)], [0.06, 0.045, 0.03, 0.01], dark, sides=10)
    cone("Horn", (0, -0.5, 0.56), (0, -0.62, 0.7), 0.045, dark, sides=8)
    gloss("Horn", 0.25)
    for side in (-1, 1):
        compound_eye((side * 0.12, -0.66, 0.38), (0.03, 0.035, 0.03))
        elbow_antenna("Antenna", (side * 0.09, -0.72, 0.32), (side * 0.16, -0.8, 0.36), (side * 0.22, -0.88, 0.34), 0.012, dark, beads=4, club=2)
    leg_set((-0.42, -0.2, 0.05), 0.52, 0.16, 0.046, dark, dark, hip_z=0.26)


# -------------------------------------------------------------------- wasp
def wasp():
    yellow = "Tint"
    black = (28, 24, 22)
    # Head with big kidney-shaped eyes, ocelli, mandibles, elbowed antennae.
    ellipsoid("Head", (0, -0.66, 0.62), (0.16, 0.11, 0.15), yellow, segments=20)
    ellipsoid("Mask", (0, -0.75, 0.55), (0.09, 0.05, 0.09), black)
    for side in (-1, 1):
        compound_eye((side * 0.12, -0.66, 0.66), (0.055, 0.06, 0.1), (40, 30, 25))
        tube("Mandible", [(side * 0.05, -0.76, 0.48), (side * 0.02, -0.8, 0.44)], [0.025, 0.01], (180, 130, 30), sides=6)
        elbow_antenna("Antenna", (side * 0.04, -0.76, 0.66), (side * 0.07, -0.86, 0.82), (side * 0.2, -1.02, 0.86), 0.014, black, beads=10)
    for k in range(3):
        ellipsoid("Ocellus", ((k - 1) * 0.03, -0.66, 0.77 - abs(k - 1) * 0.01), (0.012,) * 3, (40, 30, 25))
    # Thorax (black with yellow marks), the narrow waist, banded gaster.
    ellipsoid("Thorax", (0, -0.36, 0.62), (0.15, 0.2, 0.15), black, segments=20)
    for side in (-1, 1):
        ellipsoid("Mark", (side * 0.08, -0.42, 0.72), (0.04, 0.06, 0.02), yellow)
    ellipsoid("Mark", (0, -0.25, 0.74), (0.06, 0.03, 0.02), yellow)
    gloss("Thorax", 0.15)
    tube("Waist", [(0, -0.17, 0.6), (0, -0.08, 0.58)], [0.035, 0.035], black, sides=8)
    bands = [(0.02, 0.15), (0.17, 0.2), (0.33, 0.21), (0.49, 0.19), (0.63, 0.15), (0.75, 0.1)]
    for i, (y, r) in enumerate(bands):
        ellipsoid("Gaster", (0, y + 0.05, 0.56 - y * 0.15), (r, 0.1, r * 0.9), yellow, segments=20)
        ring("Stripe", (0, y + 0.11, 0.56 - y * 0.15), r * 0.98, r * 0.88, black, 0.03)
    gloss("Gaster", 0.15)
    tube("Sting", [(0, 0.86, 0.43), (0, 0.98, 0.38)], [0.022, 0.002], black, sides=6)
    # Two pairs of veined wings folded back over the body.
    for side in (-1, 1):
        wing("Wing", (side * 0.08, -0.4, 0.74), (side * 0.75, 0.75, 0.2), 0.8, 0.17, (210, 190, 140), "Glass")
        wing("Wing", (side * 0.07, -0.3, 0.73), (side * 0.6, 0.95, 0.12), 0.55, 0.11, (210, 190, 140), "Glass")
        for k, (dx, dy) in enumerate(((0.45, 0.25), (0.5, 0.45), (0.35, 0.55))):
            tube("Vein", [(side * 0.08, -0.4, 0.745), (side * dx, -0.4 + dy, 0.79 - k * 0.01)], [0.006, 0.003], (110, 80, 40), sides=4)
    # Legs: yellow tibiae, dangling as in flight.
    for i, hip_y in enumerate((-0.45, -0.36, -0.27)):
        for side in (-1, 1):
            hip = (side * 0.08, hip_y, 0.52)
            knee = (side * 0.2, hip_y + 0.05 + i * 0.04, 0.4)
            ankle = (side * 0.22, hip_y + 0.22 + i * 0.1, 0.18)
            foot = (side * 0.2, hip_y + 0.32 + i * 0.13, 0.04)
            jointed_leg("Leg", [hip, knee, ankle, foot], 0.022, (210, 160, 40), black, tarsi=4)


# --------------------------------------------------------------------- fly
def fly():
    body = "Tint"
    ellipsoid("Head", (0, -0.5, 0.52), (0.19, 0.12, 0.16), (60, 55, 50), segments=20)
    for side in (-1, 1):
        compound_eye((side * 0.12, -0.52, 0.56), (0.11, 0.1, 0.13), (150, 40, 35))
    tube("Proboscis", [(0, -0.6, 0.44), (0, -0.66, 0.34), (0, -0.66, 0.29)], [0.03, 0.025, 0.045], (60, 55, 50), sides=8)
    ellipsoid("Thorax", (0, -0.2, 0.55), (0.22, 0.25, 0.22), body, "Fabric", segments=22)
    for side in (-1, 1):
        tube("ThoraxStripe", [(side * 0.06, -0.4, 0.73), (side * 0.07, -0.05, 0.75)], [0.025, 0.02], (140, 140, 135), "Fabric", sides=6)
    ellipsoid("Abdomen", (0, 0.22, 0.5), (0.22, 0.27, 0.18), body, segments=22)
    ellipsoid("Sheen", (0, 0.22, 0.6), (0.17, 0.22, 0.08), (70, 120, 90), "Foil")
    gloss("Abdomen", 0.2)
    bristles(
        "Bristle",
        [((0.12 * math.cos(k * 0.9), -0.3 + k * 0.05, 0.74), (math.cos(k * 0.9) * 0.3, 0.3, 0.9)) for k in range(12)],
        0.08,
        (20, 20, 20),
    )
    for side in (-1, 1):
        wing("Wing", (side * 0.1, -0.22, 0.74), (side * 0.55, 0.85, -0.02), 0.66, 0.2, (215, 225, 235), "Glass")
        for k, (dx, dy) in enumerate(((0.35, 0.35), (0.45, 0.5), (0.3, 0.55))):
            tube("Vein", [(side * 0.1, -0.22, 0.745), (side * dx * 0.8, -0.22 + dy, 0.74 - k * 0.01)], [0.005, 0.003], (60, 60, 60), sides=4)
        tube("Haltere", [(side * 0.12, -0.05, 0.62), (side * 0.18, 0.0, 0.62)], [0.008, 0.008], (180, 170, 150), sides=4)
    leg_set((-0.32, -0.2, -0.08), 0.4, 0.06, 0.028, (40, 38, 36), (40, 38, 36), hip_z=0.36)


# ------------------------------------------------------------------- roach
def roach():
    shell = "Tint"
    dark = "TintDark"
    for side in (-1, 1):
        ellipsoid("Wings", (side * 0.11, 0.18, 0.26), (0.17, 0.62, 0.12), shell, segments=26)
    gloss("Wings", 0.3)
    tube("Seam", [(0, -0.35, 0.37), (0, 0.2, 0.39), (0, 0.78, 0.28)], [0.008, 0.01, 0.006], dark, sides=5)
    # Shield-like pronotum with the classic pale rim and dark spot.
    ellipsoid("Pronotum", (0, -0.5, 0.28), (0.27, 0.17, 0.09), (200, 165, 115), segments=22)
    ellipsoid("PronotumSpot", (0, -0.49, 0.34), (0.15, 0.1, 0.05), dark)
    gloss("Pronotum", 0.2)
    ellipsoid("Head", (0, -0.68, 0.22), (0.11, 0.08, 0.09), dark, segments=16)
    for side in (-1, 1):
        compound_eye((side * 0.08, -0.7, 0.25), (0.035, 0.04, 0.04))
        # Very long whip antennae.
        pts = [(side * (0.04 + 0.08 * t * t * 6), -0.74 - 0.9 * t, 0.26 + 0.25 * math.sin(t * 3.0)) for t in [k / 10 for k in range(11)]]
        tube("Antenna", pts, [0.012 - 0.0009 * k for k in range(11)], dark, sides=5)
        tube("Cercus", [(side * 0.05, 0.78, 0.22), (side * 0.12, 0.95, 0.24)], [0.018, 0.004], dark, sides=5)
    # Spiny legs.
    for i, (hip_y, swing) in enumerate(((-0.45, -0.7), (-0.2, 0.0), (0.05, 0.9))):
        for side in (-1, 1):
            reach = 0.55 + i * 0.1
            hip = (side * 0.1, hip_y, 0.16)
            knee = (side * reach * 0.55, hip_y + swing * 0.15, 0.36)
            ankle = (side * reach * 0.9, hip_y + swing * 0.4, 0.1)
            foot = (side * reach * 1.05, hip_y + swing * 0.55, 0.0)
            jointed_leg("Leg", [hip, knee, ankle, foot], 0.026, dark, dark, tarsi=4)
            for k in range(3):
                p = lerp3(knee, ankle, 0.25 + k * 0.25)
                cone("Spine", p, (p[0] + side * 0.05, p[1] + 0.02, p[2] + 0.04), 0.008, dark, sides=4)


# -------------------------------------------------------------------- moth
def moth():
    fur = "Tint"
    light = "TintLight"
    dark = "TintDark"
    ellipsoid("Body", (0, 0.12, 0.38), (0.12, 0.4, 0.12), fur, "Fabric", segments=20)
    for k in range(5):
        ring("Band", (0, 0.0 + k * 0.1, 0.38), 0.115 - k * 0.012, 0.115 - k * 0.012, dark, 0.01, "Fabric")
    ellipsoid("Thorax", (0, -0.28, 0.42), (0.15, 0.15, 0.14), light, "Fabric", segments=20)
    ellipsoid("Head", (0, -0.45, 0.4), (0.1, 0.08, 0.09), fur, "Fabric", segments=16)
    for side in (-1, 1):
        compound_eye((side * 0.07, -0.5, 0.42), (0.04, 0.04, 0.045))
        # Feathery (bipectinate) antennae.
        stem = [(side * 0.03, -0.52, 0.48), (side * 0.12, -0.66, 0.64), (side * 0.24, -0.72, 0.76)]
        tube("Antenna", stem, [0.01, 0.008, 0.005], dark, sides=5)
        for k in range(9):
            t = (k + 1) / 10
            p = lerp3(stem[0], stem[2], t)
            for s2 in (-1, 1):
                tube("Antenna", [p, (p[0] + s2 * 0.035, p[1] - 0.02, p[2] + 0.01)], [0.004, 0.002], dark, sides=4)
        # Broad forewings and hindwings, held flat and slightly open.
        wing("Wing", (side * 0.08, -0.3, 0.46), (side * 1.0, -0.15, 0.08), 0.95, 0.45, light, "Fabric")
        wing("Wing", (side * 0.08, -0.12, 0.44), (side * 0.85, 0.6, 0.0), 0.65, 0.3, fur, "Fabric")
        # Eyespots and a wavy line across each forewing.
        ellipsoid("Spot", (side * 0.55, -0.24, 0.505), (0.12, 0.1, 0.012), (240, 200, 120), "Fabric")
        ellipsoid("SpotCentre", (side * 0.55, -0.24, 0.51), (0.06, 0.05, 0.012), (40, 30, 25), "Fabric")
        tube("WingLine", [(side * (0.2 + k * 0.08), -0.08 - 0.03 * math.sin(k * 1.5), 0.505) for k in range(8)], [0.01] * 8, dark, "Fabric", sides=4)
    leg_set((-0.32, -0.25, -0.18), 0.32, 0.12, 0.016, fur, dark, hip_z=0.3)


# -------------------------------------------------------------------- mite
def mite():
    body = "Tint"
    dark = "TintDark"
    # Dust mite: one rounded, ribbed sac with long bristles and stubby legs.
    ellipsoid("Body", (0, 0.05, 0.4), (0.4, 0.5, 0.32), body, segments=30)
    for k in range(7):
        y = -0.3 + k * 0.1
        ring("Fold", (0, y, 0.42), 0.38 * math.sqrt(max(0.05, 1 - (y - 0.05) ** 2 / 0.27)), 0.3 * math.sqrt(max(0.05, 1 - (y - 0.05) ** 2 / 0.27)), "TintLight", 0.012, axis="y")
    gloss("Body", 0.06)
    ellipsoid("Gnathosoma", (0, -0.5, 0.3), (0.12, 0.12, 0.09), dark, segments=14)
    for side in (-1, 1):
        tube("Chelicera", [(side * 0.04, -0.58, 0.29), (side * 0.03, -0.66, 0.25)], [0.03, 0.015], dark, sides=6)
    bristles(
        "Bristle",
        [((0.3 * math.cos(a), 0.05 + 0.4 * math.sin(a), 0.48), (math.cos(a), math.sin(a) * 0.6, 0.5)) for a in [k * 0.52 for k in range(12)]],
        0.3,
        (200, 190, 175),
        thick=0.008,
    )
    for i in range(4):
        a = math.radians(-50 + i * 33)
        for side in (-1, 1):
            hip = (side * 0.28, -0.1 + i * 0.12, 0.25)
            dx, dy = math.cos(a) * side, math.sin(a)
            knee = (hip[0] + dx * 0.16, hip[1] + dy * 0.16, 0.3)
            ankle = (hip[0] + dx * 0.3, hip[1] + dy * 0.3, 0.12)
            foot = (hip[0] + dx * 0.36, hip[1] + dy * 0.36, 0.0)
            jointed_leg("Leg", [hip, knee, ankle, foot], 0.04, body, dark, tarsi=2)


# -------------------------------------------------------------------- frog
def frog():
    skin = "Tint"
    dark = "TintDark"
    belly = (230, 220, 175)
    # Low, wide body sloping up to the back; broad flat head.
    ellipsoid("Body", (0, 0.08, 0.3), (0.38, 0.46, 0.25), skin, segments=30, rotation=(math.radians(-12), 0, 0))
    ellipsoid("Head", (0, -0.36, 0.33), (0.33, 0.25, 0.16), skin, segments=26)
    ellipsoid("Snout", (0, -0.55, 0.3), (0.2, 0.12, 0.1), skin, segments=18)
    ellipsoid("Belly", (0, -0.12, 0.18), (0.32, 0.4, 0.14), belly, segments=22)
    ellipsoid("Throat", (0, -0.45, 0.2), (0.22, 0.14, 0.08), belly, segments=16)
    gloss("Body", 0.12)
    gloss("Head", 0.12)
    # Mouth line wrapping round the snout.
    tube("Mouth", [(-0.3, -0.38, 0.27), (-0.19, -0.56, 0.26), (0, -0.62, 0.26), (0.19, -0.56, 0.26), (0.3, -0.38, 0.27)], [0.007] * 5, (50, 40, 35), sides=5)
    for side in (-1, 1):
        # Bulging eyes: gold iris, horizontal pupil, glossy.
        ellipsoid("EyeBulge", (side * 0.17, -0.38, 0.44), (0.1, 0.1, 0.09), skin, segments=18)
        ellipsoid("Iris", (side * 0.19, -0.42, 0.48), (0.075, 0.07, 0.07), (215, 170, 60), segments=18)
        ellipsoid("Pupil", (side * 0.2, -0.48, 0.49), (0.05, 0.02, 0.025), (15, 12, 10))
        gloss("Iris", 0.3)
        ellipsoid("Eardrum", (side * 0.29, -0.26, 0.38), (0.02, 0.06, 0.06), dark, segments=14)
        ellipsoid("Nostril", (side * 0.05, -0.64, 0.36), (0.012, 0.01, 0.008), (30, 25, 20))
        # Ridge along each side of the back.
        tube("Ridge", [(side * 0.2, -0.25, 0.45), (side * 0.23, 0.05, 0.5), (side * 0.2, 0.35, 0.42)], [0.022, 0.025, 0.015], "TintLight", sides=6)
        # Folded hind leg: thigh, shin, long foot with webbed toes.
        ellipsoid("Thigh", (side * 0.34, 0.28, 0.2), (0.14, 0.26, 0.13), skin, segments=18, rotation=(0, 0, side * -0.4))
        ellipsoid("Shin", (side * 0.42, 0.06, 0.1), (0.09, 0.25, 0.08), skin, segments=14, rotation=(0, 0, side * 0.3))
        for k in range(5):
            a = math.radians(-40 + k * 18)
            base = (side * 0.46, -0.12, 0.02)
            tip = (base[0] + side * math.sin(a) * 0.2, base[1] - math.cos(a) * 0.22, 0.01)
            tube("Toe", [base, tip], [0.022, 0.014], skin, sides=6)
            ellipsoid("ToePad", tip, (0.022, 0.022, 0.012), "TintLight", segments=8)
        ellipsoid("Web", (side * 0.5, -0.24, 0.012), (0.12, 0.1, 0.008), dark, "Fabric")
        # Front arm with splayed fingers.
        tube("Arm", [(side * 0.2, -0.38, 0.2), (side * 0.28, -0.46, 0.1), (side * 0.27, -0.52, 0.02)], [0.05, 0.04, 0.035], skin, sides=8)
        for k in range(4):
            a = math.radians(-50 + k * 33)
            base = (side * 0.27, -0.52, 0.02)
            tip = (base[0] + side * math.sin(a) * 0.08, base[1] - math.cos(a) * 0.08, 0.01)
            tube("Toe", [base, tip], [0.015, 0.01], skin, sides=5)
            ellipsoid("ToePad", tip, (0.016, 0.016, 0.01), "TintLight", segments=8)
    # Warty spots on the back.
    import random

    rng = random.Random(7)
    for _ in range(26):
        x, y = rng.uniform(-0.28, 0.28), rng.uniform(-0.25, 0.4)
        z = 0.27 + 0.24 * math.sqrt(max(0.0, 1 - (x / 0.38) ** 2 - ((y - 0.08) / 0.46) ** 2))
        r = rng.uniform(0.02, 0.05)
        ellipsoid("Spot" if r > 0.035 else "Wart", (x, y, z), (r, r, r * 0.4), dark if r > 0.035 else "TintLight", segments=8)


# -------------------------------------------------------------------- crow
def crow():
    black = "Tint"
    sheen = (40, 45, 70)
    body_tilt = math.radians(-18)
    ellipsoid("Body", (0, 0.08, 0.52), (0.17, 0.46, 0.2), black, "Fabric", rotation=(body_tilt, 0, 0), segments=26)
    ellipsoid("Breast", (0, -0.2, 0.5), (0.16, 0.17, 0.19), black, "Fabric", segments=20)
    ellipsoid("Neck", (0, -0.3, 0.68), (0.13, 0.13, 0.13), black, "Fabric", segments=18)
    ellipsoid("Head", (0, -0.38, 0.8), (0.115, 0.15, 0.11), black, "Fabric", segments=20)
    # Heavy beak: curved upper mandible over the lower, nasal bristles.
    tube("Beak", [(0, -0.5, 0.82), (0, -0.62, 0.81), (0, -0.72, 0.77), (0, -0.76, 0.73)], [0.055, 0.042, 0.025, 0.006], (40, 40, 44), sides=10)
    tube("Beak", [(0, -0.5, 0.77), (0, -0.64, 0.75), (0, -0.71, 0.74)], [0.045, 0.03, 0.006], (50, 50, 55), sides=10)
    gloss("Beak", 0.2)
    bristles("Bristle", [((0.02 * s2, -0.52, 0.85), (0, -0.8, -0.2)) for s2 in (-1, 0, 1)], 0.06, (30, 30, 34), thick=0.01)
    for side in (-1, 1):
        compound_eye((side * 0.085, -0.45, 0.84), (0.026, 0.026, 0.028), (20, 15, 15), "Eye")
        # Folded wing: layers of long primaries reaching past the tail base.
        ellipsoid("Wing", (side * 0.16, 0.08, 0.57), (0.06, 0.4, 0.15), black, "Fabric", rotation=(body_tilt, 0, side * 0.08), segments=18)
        for k in range(6):
            y = 0.18 + k * 0.06
            ellipsoid(
                "Feather" if k % 2 else "FeatherSheen",
                (side * (0.165 - k * 0.008), y + 0.12, 0.5 - k * 0.04),
                (0.025, 0.3, 0.05),
                black if k % 2 else sheen,
                "Fabric",
                rotation=(body_tilt * 1.3, 0, side * 0.05),
                segments=10,
            )
        # Scaly legs and four toes (three forward, one back).
        tube("Leg", [(side * 0.07, -0.02, 0.32), (side * 0.08, -0.04, 0.14), (side * 0.08, -0.05, 0.02)], [0.03, 0.02, 0.018], (40, 38, 36), sides=8)
        for a in (-0.45, 0.0, 0.45, math.pi):
            tip = (side * 0.08 + math.sin(a) * 0.1, -0.05 - math.cos(a) * 0.1, 0.0)
            tube("Toe", [(side * 0.08, -0.05, 0.02), tip], [0.016, 0.01], (40, 38, 36), sides=6)
            cone("Claw", tip, (tip[0] + math.sin(a) * 0.03, tip[1] - math.cos(a) * 0.03, -0.005), 0.01, (25, 22, 20), sides=4)
    # Fanned tail.
    for k in range(7):
        a = (k - 3) * 0.09
        ellipsoid("Tail" if k % 2 else "FeatherSheen", (math.sin(a) * 0.16, 0.66 + math.cos(a) * 0.14, 0.32), (0.045, 0.32, 0.018), black if k % 2 else sheen, "Fabric", rotation=(math.radians(25), 0, a), segments=10)


# ----------------------------------------------------------- machine helpers
from lib import cylinder, rounded_box  # noqa: E402


def knobby_tire(centre, radius, width, side, tread=18, color=(30, 30, 32)):
    """A tire on the X axis with raised tread blocks and a 5-spoke rim."""
    x, y, z = centre
    cylinder("Tire", centre, radius * 0.92, width, color, "Rubber", rotation=(0, math.pi / 2, 0), sides=32, bevel=radius * 0.12)
    for k in range(tread):
        a = k / tread * math.tau
        p = (x, y + math.cos(a) * radius * 0.94, z + math.sin(a) * radius * 0.94)
        rounded_box("Tread", p, (width * 0.9, radius * 0.16, radius * 0.1), color, "Rubber", bevel=0.3, rotation=(-a, 0, 0), segments=2)
    rim_x = x + side * width * 0.45
    cylinder("Rim", (rim_x, y, z), radius * 0.55, width * 0.15, (200, 200, 205), "Metal", rotation=(0, math.pi / 2, 0), sides=24)
    for k in range(5):
        a = k / 5 * math.tau
        tube("Spoke", [(rim_x + side * 0.004, y, z), (rim_x + side * 0.004, y + math.cos(a) * radius * 0.5, z + math.sin(a) * radius * 0.5)], [radius * 0.06, radius * 0.05], (170, 170, 175), "Metal", sides=6)
    cylinder("Hub", (rim_x + side * 0.01, y, z), radius * 0.14, width * 0.2, (90, 90, 95), "Metal", rotation=(0, math.pi / 2, 0), sides=12)


def rivets(points, r, color=(170, 170, 175)):
    for p in points:
        ellipsoid("Rivet", p, (r, r, r * 0.6), color, "Metal", segments=6)


# --------------------------------------------------------------------- car
def car():
    """An RC off-road buggy: tub chassis, shell body, roll cage, coil-over
    shocks, knobby tires, rear wing."""
    paint = "Tint"
    rounded_box("Chassis", (0, 0.0, 0.28), (0.5, 1.1, 0.07), (45, 45, 50), "Metal", bevel=0.4)
    rounded_box("Body", (0, -0.05, 0.42), (0.52, 0.82, 0.18), paint, bevel=0.45)
    rounded_box("Body", (0, -0.5, 0.36), (0.48, 0.22, 0.12), paint, bevel=0.5)
    gloss("Body", 0.15)
    rounded_box("Window", (0, 0.06, 0.56), (0.36, 0.34, 0.12), (40, 60, 80), "Glass", bevel=0.45)
    rounded_box("Decal", (0, -0.05, 0.515), (0.1, 0.84, 0.01), (245, 245, 245), bevel=0.3)
    for side in (-1, 1):
        rounded_box("Decal", (side * 0.262, -0.1, 0.42), (0.01, 0.4, 0.05), (245, 210, 50), bevel=0.3)
        ellipsoid("Headlight", (side * 0.15, -0.61, 0.38), (0.05, 0.02, 0.035), (255, 245, 200), "Neon")
        ellipsoid("Taillight", (side * 0.18, 0.37, 0.43), (0.04, 0.015, 0.02), (255, 40, 40), "Neon")
        # Roll cage.
        tube("Cage", [(side * 0.2, -0.18, 0.5), (side * 0.18, -0.08, 0.7), (side * 0.18, 0.22, 0.7), (side * 0.2, 0.32, 0.5)], [0.016] * 4, (30, 30, 34), "Metal", sides=6)
        for y in (-0.4, 0.4):
            # Suspension arm + coil-over shock to each wheel.
            tube("Arm", [(side * 0.18, y, 0.27), (side * 0.36, y, 0.22)], [0.018, 0.018], (60, 60, 66), "Metal", sides=6)
            tube("Shock", [(side * 0.2, y, 0.42), (side * 0.33, y, 0.26)], [0.018, 0.018], (230, 160, 40), "Metal", sides=8)
            for k in range(5):
                p = lerp3((side * 0.21, y, 0.4), (side * 0.32, y, 0.28), k / 4)
                ring("Spring", p, 0.026, 0.026, (230, 230, 235), 0.005, "Metal", axis="x", n=10)
            knobby_tire((side * 0.4, y, 0.2), 0.2, 0.17, side)
    tube("Cage", [(-0.18, -0.08, 0.7), (0.18, -0.08, 0.7)], [0.016] * 2, (30, 30, 34), "Metal", sides=6)
    rounded_box("Spoiler", (0, 0.5, 0.7), (0.56, 0.14, 0.02), paint, bevel=0.4)
    for side in (-1, 1):
        rounded_box("Spoiler", (side * 0.27, 0.5, 0.66), (0.015, 0.14, 0.08), paint, bevel=0.3)
        tube("Strut", [(side * 0.12, 0.42, 0.45), (side * 0.12, 0.5, 0.69)], [0.012, 0.012], (30, 30, 34), "Metal", sides=6)
    tube("Antenna", [(0.18, 0.35, 0.45), (0.2, 0.42, 1.0)], [0.008, 0.004], (30, 30, 34), sides=5)
    ellipsoid("AntennaTip", (0.2, 0.42, 1.0), (0.018,) * 3, (255, 60, 60), "Neon")


# ------------------------------------------------------------------- drone
def drone():
    """A quadcopter: moulded body, carbon arms, brushless motors, two-blade
    props in guards, a gimbal camera."""
    shell = "Tint"
    carbon = (35, 36, 40)
    rounded_box("Body", (0, 0, 0.5), (0.34, 0.5, 0.12), shell, bevel=0.45)
    rounded_box("Lid", (0, -0.02, 0.57), (0.26, 0.36, 0.05), carbon, bevel=0.5)
    gloss("Body", 0.18)
    rounded_box("Battery", (0, 0.12, 0.6), (0.18, 0.2, 0.04), (220, 200, 60), bevel=0.4)
    for side in (-1, 1):
        ellipsoid("Led", (side * 0.12, -0.25, 0.52), (0.02, 0.01, 0.01), (255, 60, 60) if side < 0 else (60, 255, 120), "Neon")
    for k in range(4):
        a = math.radians(45 + k * 90)
        dx, dy = math.cos(a), math.sin(a)
        tube("Arm", [(dx * 0.12, dy * 0.18, 0.5), (dx * 0.6, dy * 0.6, 0.53)], [0.03, 0.022], carbon, sides=8)
        m = (dx * 0.6, dy * 0.6, 0.56)
        cylinder("Motor", m, 0.05, 0.07, (60, 62, 68), "Metal", bevel=0.01, sides=16)
        cylinder("MotorBell", (m[0], m[1], m[2] + 0.04), 0.045, 0.02, (200, 60, 50), "Metal", sides=16)
        for b in (0, math.pi):
            ang = b + k * 0.7
            tube("Prop", [(m[0], m[1], m[2] + 0.06), (m[0] + math.cos(ang) * 0.22, m[1] + math.sin(ang) * 0.22, m[2] + 0.065)], [0.022, 0.012], (30, 30, 34), sides=6)
        tube("Guard", [(m[0] + math.cos(t / 20 * math.tau) * 0.25, m[1] + math.sin(t / 20 * math.tau) * 0.25, m[2] + 0.05) for t in range(21)], [0.012] * 21, shell, sides=6)
    # Gimbal and camera under the nose.
    cylinder("Gimbal", (0, -0.22, 0.42), 0.035, 0.06, carbon, "Metal", sides=12)
    ellipsoid("Camera", (0, -0.26, 0.38), (0.06, 0.06, 0.05), (40, 42, 48), segments=16)
    ellipsoid("Lens", (0, -0.31, 0.38), (0.035, 0.012, 0.035), (255, 60, 60), "Neon")
    # Landing legs.
    for side in (-1, 1):
        tube("Skid", [(side * 0.12, -0.15, 0.45), (side * 0.16, -0.12, 0.04)], [0.015, 0.015], carbon, sides=6)
        tube("Skid", [(side * 0.12, 0.15, 0.45), (side * 0.16, 0.12, 0.04)], [0.015, 0.015], carbon, sides=6)
        tube("Skid", [(side * 0.16, -0.26, 0.02), (side * 0.16, 0.26, 0.02)], [0.016, 0.016], carbon, sides=6)


# ------------------------------------------------------------------ vacuum
def vacuum():
    """A robot vacuum boss: real Roomba-style details plus a glowing glare."""
    shell = "Tint"
    cylinder("Shell", (0, 0, 0.28), 0.9, 0.34, shell, "Metal", sides=64, bevel=0.07)
    gloss("Shell", 0.2)
    cylinder("Bumper", (0, 0, 0.17), 0.915, 0.16, (30, 30, 34), "Rubber", sides=64, bevel=0.04)
    cylinder("Lid", (0, 0.05, 0.46), 0.62, 0.03, (35, 38, 46), "Glass", sides=64)
    tube("Trim", [(math.cos(t / 48 * math.tau) * 0.62, 0.05 + math.sin(t / 48 * math.tau) * 0.62, 0.475) for t in range(49)], [0.012] * 49, (180, 180, 190), "Metal", sides=6)
    cylinder("Button", (0, -0.1, 0.48), 0.12, 0.03, (60, 64, 72), sides=32)
    tube("ButtonRing", [(math.cos(t / 32 * math.tau) * 0.12, -0.1 + math.sin(t / 32 * math.tau) * 0.12, 0.495) for t in range(33)], [0.01] * 33, (255, 60, 60), "Neon", sides=5)
    # Lidar turret and a camera window that glares like an angry eye.
    cylinder("Turret", (0, 0.42, 0.52), 0.13, 0.08, (40, 42, 48), "Metal", sides=32, bevel=0.01)
    rounded_box("Glare", (0, -0.86, 0.3), (0.5, 0.05, 0.07), (255, 60, 60), "Neon", bevel=0.45)
    for side in (-1, 1):
        rounded_box("Brow", (side * 0.16, -0.885, 0.38), (0.2, 0.03, 0.03), (20, 20, 22), bevel=0.4, rotation=(0, side * 0.35, 0))
        # Spinning side brush with three bristle bunches.
        cylinder("BrushHub", (side * 0.62, -0.58, 0.04), 0.06, 0.03, (60, 60, 64), sides=12)
        for k in range(3):
            a = k / 3 * math.tau + side
            tube("Bristle", [(side * 0.62, -0.58, 0.03), (side * 0.62 + math.cos(a) * 0.3, -0.58 + math.sin(a) * 0.3, 0.005)], [0.022, 0.012], (200, 200, 205), sides=5)
        knobby_tire((side * 0.6, 0.08, 0.08), 0.1, 0.08, side, tread=12)
    rounded_box("Intake", (0, -0.45, 0.05), (0.7, 0.18, 0.06), (20, 20, 22), bevel=0.4)
    for k in range(7):
        rounded_box("Vent", (-0.3 + k * 0.1, 0.8, 0.3), (0.05, 0.04, 0.12), (25, 25, 28), bevel=0.4)


# ------------------------------------------------------------------- mower
def mower():
    """A push mower boss: steel deck, engine with pull cord and fuel cap,
    grass bag, treaded wheels, headlights that glare."""
    red = "Tint"
    rounded_box("Deck", (0, -0.05, 0.3), (1.0, 1.15, 0.22), red, "Metal", bevel=0.35)
    gloss("Deck", 0.15)
    rounded_box("DeckSkirt", (0, -0.05, 0.17), (1.04, 1.19, 0.06), (40, 40, 44), "Metal", bevel=0.3)
    cylinder("Engine", (0, -0.15, 0.56), 0.27, 0.3, (55, 56, 60), "Metal", sides=32, bevel=0.03)
    for k in range(6):
        tube("Fin", [(math.cos(t / 32 * math.tau) * 0.28, -0.15 + math.sin(t / 32 * math.tau) * 0.28, 0.46 + k * 0.035) for t in range(33)], [0.008] * 33, (85, 87, 93), "Metal", sides=4)
    cylinder("EngineTop", (0, -0.15, 0.73), 0.24, 0.05, red, "Metal", sides=32, bevel=0.015)
    cylinder("FuelCap", (0.12, -0.25, 0.78), 0.05, 0.05, (240, 200, 40), sides=16, bevel=0.01)
    rounded_box("AirFilter", (-0.12, -0.3, 0.68), (0.18, 0.1, 0.12), (40, 40, 44), bevel=0.3)
    # Pull-cord handle on the engine.
    tube("Cord", [(0.2, -0.05, 0.7), (0.32, 0.2, 0.9), (0.38, 0.55, 1.15)], [0.006, 0.006, 0.006], (220, 220, 220), sides=4)
    rounded_box("CordGrip", (0.38, 0.56, 1.16), (0.1, 0.03, 0.03), (30, 30, 32), bevel=0.4)
    # Grass catcher bag behind.
    rounded_box("Bag", (0, 0.68, 0.45), (0.62, 0.36, 0.4), (60, 70, 60), "Fabric", bevel=0.35)
    rounded_box("BagFrame", (0, 0.68, 0.66), (0.66, 0.4, 0.03), (40, 40, 44), "Metal", bevel=0.3)
    # Handle.
    for side in (-1, 1):
        tube("Handle", [(side * 0.38, 0.45, 0.4), (side * 0.38, 0.9, 1.05), (side * 0.38, 1.1, 1.35)], [0.026] * 3, (55, 56, 60), "Metal", sides=8)
        rivets([(side * 0.385, 0.72, 0.8)], 0.025)
    tube("Grip", [(-0.4, 1.1, 1.35), (0.4, 1.1, 1.35)], [0.04, 0.04], (30, 30, 32), "Rubber", sides=10)
    tube("Bail", [(-0.36, 1.05, 1.3), (-0.36, 0.98, 1.38), (0.36, 0.98, 1.38), (0.36, 1.05, 1.3)], [0.014] * 4, (200, 200, 205), "Metal", sides=6)
    for x in (-0.55, 0.55):
        for y in (-0.5, 0.45):
            knobby_tire((x, y, 0.2), 0.2, 0.12, 1 if x > 0 else -1, tread=16)
    # Headlight "eyes" that glare, angled into a scowl.
    for side in (-1, 1):
        rounded_box("Glare", (side * 0.24, -0.63, 0.36), (0.22, 0.03, 0.07), (255, 70, 50), "Neon", bevel=0.45, rotation=(0, side * 0.3, 0))
    rounded_box("Grille", (0, -0.635, 0.24), (0.5, 0.02, 0.06), (25, 25, 28), bevel=0.4)


# --------------------------------------------------------------------- toy
def toy():
    """A painted tin wind-up drummer: seams, cross-belts, braided cuffs."""
    coat = "Tint"
    gold = (225, 185, 80)
    for side in (-1, 1):
        rounded_box("Boot", (side * 0.1, -0.02, 0.05), (0.12, 0.17, 0.1), (25, 25, 28), bevel=0.4)
        gloss("Boot", 0.25)
        cylinder("Trousers", (side * 0.1, 0, 0.22), 0.07, 0.26, (35, 45, 95), sides=20)
        tube("Stripe", [(side * 0.17, 0, 0.1), (side * 0.17, 0, 0.34)], [0.01, 0.01], gold, sides=5)
    cylinder("Coat", (0, 0, 0.5), 0.2, 0.36, coat, sides=32, bevel=0.03)
    gloss("Coat", 0.12)
    cylinder("Belt", (0, 0, 0.36), 0.206, 0.045, (245, 240, 230), sides=32)
    rounded_box("Buckle", (0, -0.205, 0.36), (0.06, 0.012, 0.045), gold, "Metal", bevel=0.3)
    for side in (-1, 1):
        tube("CrossBelt", [(side * 0.18, -0.08, 0.66), (0, -0.205, 0.5), (-side * 0.18, -0.08, 0.38)], [0.012] * 3, (245, 240, 230), sides=5)
    for z in (0.43, 0.5, 0.57, 0.64):
        ellipsoid("Button", (0, -0.205, z), (0.018, 0.01, 0.018), gold, "Metal")
    gloss("Button", 0.3)
    for side in (-1, 1):
        ellipsoid("Epaulette", (side * 0.2, 0, 0.67), (0.08, 0.08, 0.035), gold, "Metal")
        for k in range(7):
            a = k / 7 * math.pi - math.pi / 2
            tube("Fringe", [(side * (0.2 + math.cos(a) * 0.075), math.sin(a) * 0.075, 0.655), (side * (0.21 + math.cos(a) * 0.08), math.sin(a) * 0.08, 0.6)], [0.008, 0.006], gold, "Metal", sides=4)
        tube("Arm", [(side * 0.22, 0, 0.64), (side * 0.26, -0.06, 0.5), (side * 0.2, -0.16, 0.44)], [0.05, 0.045, 0.04], coat, sides=10)
        tube("Cuff", [(side * 0.21, -0.14, 0.45), (side * 0.2, -0.17, 0.44)], [0.045, 0.045], gold, sides=10)
        ellipsoid("Hand", (side * 0.19, -0.19, 0.43), (0.032,) * 3, (245, 245, 240))
        tube("Drumstick", [(side * 0.18, -0.19, 0.44), (side * 0.06, -0.31, 0.4)], [0.01, 0.01], (220, 190, 140), "Wood", sides=6)
        ellipsoid("Drumstick", (side * 0.06, -0.31, 0.4), (0.016,) * 3, (220, 190, 140), "Wood")
    cylinder("Drum", (0, -0.3, 0.32), 0.13, 0.12, (245, 240, 230), sides=32, bevel=0.01)
    for z in (0.26, 0.38):
        cylinder("DrumRim", (0, -0.3, z), 0.135, 0.02, (210, 40, 40), sides=32)
    for k in range(8):
        a0, a1 = k / 8 * math.tau, (k + 0.5) / 8 * math.tau
        tube("DrumRope", [(math.cos(a0) * 0.132, -0.3 + math.sin(a0) * 0.132, 0.27), (math.cos(a1) * 0.132, -0.3 + math.sin(a1) * 0.132, 0.37)], [0.005, 0.005], gold, sides=4)
    ellipsoid("Face", (0, 0, 0.79), (0.13, 0.13, 0.14), (245, 210, 180), segments=22)
    gloss("Face", 0.15)
    for side in (-1, 1):
        ellipsoid("Cheek", (side * 0.075, -0.105, 0.76), (0.03, 0.015, 0.022), (235, 120, 120))
        ellipsoid("Eye", (side * 0.045, -0.12, 0.81), (0.018, 0.01, 0.022), (25, 22, 28))
    tube("Mustache", [(-0.06, -0.12, 0.755), (0, -0.13, 0.765), (0.06, -0.12, 0.755)], [0.012, 0.016, 0.012], (60, 40, 30), sides=6)
    cylinder("Hat", (0, 0, 1.0), 0.125, 0.3, (25, 25, 28), sides=28, bevel=0.015)
    cylinder("HatBand", (0, 0, 0.88), 0.13, 0.035, gold, "Metal", sides=28)
    rounded_box("Visor", (0, -0.11, 0.86), (0.2, 0.08, 0.015), (25, 25, 28), bevel=0.4)
    ellipsoid("Badge", (0, -0.125, 1.0), (0.04, 0.01, 0.045), gold, "Metal")
    ellipsoid("Plume", (0, -0.02, 1.2), (0.045, 0.045, 0.1), (210, 40, 40), "Fabric")
    gloss("Hat", 0.3)
    # The wind-up key, with a seam line down the back of the tin.
    tube("Seam", [(0, 0.2, 0.34), (0, 0.205, 0.68)], [0.005, 0.005], "TintDark", sides=4)
    tube("Key", [(0, 0.2, 0.52), (0, 0.33, 0.52)], [0.018, 0.018], gold, "Metal", sides=8)
    for side in (-1, 1):
        ellipsoid("Key", (side * 0.07, 0.34, 0.52), (0.07, 0.014, 0.045), gold, "Metal")
    gloss("Key", 0.35)


# ------------------------------------------------------------------- robot
def robot():
    """A vintage tin toy robot: riveted panels, dials, accordion arms."""
    metal = "Tint"
    for side in (-1, 1):
        rounded_box("Tread", (side * 0.26, 0, 0.1), (0.15, 0.6, 0.2), (35, 35, 38), "Rubber", bevel=0.5)
        for y in (-0.2, 0.0, 0.2):
            cylinder("Wheel", (side * 0.34, y, 0.1), 0.07, 0.025, (170, 170, 175), "Metal", rotation=(0, math.pi / 2, 0), sides=16)
        for k in range(10):
            rounded_box("TreadBlock", (side * 0.26, -0.27 + k * 0.06, 0.205), (0.15, 0.025, 0.012), (25, 25, 28), "Rubber", bevel=0.3, segments=2)
    rounded_box("Body", (0, 0, 0.42), (0.5, 0.42, 0.46), metal, "Metal", bevel=0.12)
    gloss("Body", 0.2)
    rounded_box("ChestPanel", (0, -0.212, 0.44), (0.32, 0.015, 0.26), (45, 48, 56), bevel=0.2)
    for i, c in enumerate(((255, 80, 80), (255, 210, 60), (80, 220, 120))):
        cylinder("Light", (-0.09 + i * 0.09, -0.222, 0.5), 0.028, 0.015, c, "Neon", rotation=(math.pi / 2, 0, 0), sides=12)
    for side in (-1, 1):
        cylinder("Dial", (side * 0.08, -0.222, 0.38), 0.045, 0.012, (235, 230, 215), rotation=(math.pi / 2, 0, 0), sides=20)
        tube("Needle", [(side * 0.08, -0.23, 0.38), (side * 0.08 + 0.025, -0.23, 0.405)], [0.005, 0.003], (200, 40, 40), sides=4)
    rivets([(x * 0.23, -0.212, z) for x in (-1, 1) for z in (0.24, 0.42, 0.6)] + [(x * 0.08, -0.212, 0.64) for x in (-1, 0, 1)], 0.012)
    rounded_box("Neck", (0, 0, 0.67), (0.14, 0.12, 0.06), (60, 62, 68), "Metal", bevel=0.3)
    rounded_box("Head", (0, 0, 0.82), (0.38, 0.32, 0.26), metal, "Metal", bevel=0.18)
    gloss("Head", 0.2)
    rounded_box("Visor", (0, -0.16, 0.83), (0.28, 0.015, 0.09), (255, 60, 60), "Neon", bevel=0.4)
    rounded_box("Grille", (0, -0.16, 0.73), (0.16, 0.012, 0.04), (40, 42, 48), bevel=0.3)
    tube("Antenna", [(0, 0, 0.95), (0, 0, 1.1)], [0.014, 0.01], (60, 62, 68), "Metal", sides=6)
    ellipsoid("AntennaBall", (0, 0, 1.12), (0.035,) * 3, (255, 60, 60), "Neon")
    for side in (-1, 1):
        cylinder("Ear", (side * 0.2, 0, 0.82), 0.07, 0.04, (60, 62, 68), "Metal", rotation=(0, math.pi / 2, 0), sides=20, bevel=0.01)
        # Accordion arm of stacked rings, then a pincer.
        for k in range(6):
            p = lerp3((side * 0.27, 0, 0.55), (side * 0.35, -0.2, 0.38), k / 5)
            ellipsoid("ArmRing", p, (0.045, 0.045, 0.03), (90, 92, 98), "Metal", segments=10)
        cone("Claw", (side * 0.35, -0.22, 0.38), (side * 0.31, -0.34, 0.42), 0.035, (60, 62, 68), "Metal")
        cone("Claw", (side * 0.35, -0.22, 0.38), (side * 0.39, -0.34, 0.34), 0.035, (60, 62, 68), "Metal")


# ---------------------------------------------------------------- sentinel
def sentinel():
    """An armoured titan guard: layered plate, glowing visor and emblem,
    a bladed spear and a rimmed shield."""
    armour = "Tint"
    dark = "TintDark"
    under = (60, 64, 72)
    glow = (120, 220, 255)
    for side in (-1, 1):
        rounded_box("Sabaton", (side * 0.12, -0.04, 0.04), (0.13, 0.22, 0.08), armour, "Metal", bevel=0.4)
        tube("Leg", [(side * 0.12, 0, 0.08), (side * 0.12, 0, 0.3), (side * 0.11, 0, 0.47)], [0.06, 0.07, 0.075], under, "Metal", sides=12)
        rounded_box("Greave", (side * 0.12, -0.045, 0.22), (0.13, 0.08, 0.2), armour, "Metal", bevel=0.4)
        ellipsoid("Poleyn", (side * 0.12, -0.06, 0.34), (0.06, 0.04, 0.05), dark, "Metal")
        rounded_box("Cuisse", (side * 0.12, -0.04, 0.42), (0.13, 0.08, 0.12), armour, "Metal", bevel=0.4)
    for k in range(3):
        rounded_box("Fauld", (0, -0.01, 0.53 - k * 0.035), (0.34 - k * 0.02, 0.22, 0.04), dark, "Metal", bevel=0.4)
    rounded_box("Torso", (0, 0, 0.67), (0.4, 0.22, 0.24), under, "Metal", bevel=0.3)
    ellipsoid("Breastplate", (0, -0.06, 0.68), (0.2, 0.09, 0.14), armour, "Metal", segments=22)
    tube("Ridge", [(0, -0.15, 0.58), (0, -0.155, 0.78)], [0.012, 0.012], dark, "Metal", sides=6)
    ellipsoid("Emblem", (0, -0.155, 0.7), (0.035, 0.01, 0.045), glow, "Neon")
    gloss("Breastplate", 0.2)
    rounded_box("Gorget", (0, 0, 0.81), (0.2, 0.18, 0.05), dark, "Metal", bevel=0.4)
    for side in (-1, 1):
        for k in range(3):
            ellipsoid("Pauldron", (side * (0.25 + k * 0.012), 0, 0.8 - k * 0.04), (0.12 - k * 0.01, 0.13 - k * 0.01, 0.07), armour if k == 0 else dark, "Metal", segments=16)
        tube("Arm", [(side * 0.26, 0, 0.74), (side * 0.29, -0.04, 0.6), (side * 0.3, -0.12, 0.5)], [0.05, 0.048, 0.045], under, "Metal", sides=10)
        rounded_box("Vambrace", (side * 0.3, -0.09, 0.54), (0.08, 0.1, 0.08), armour, "Metal", bevel=0.4)
        ellipsoid("Gauntlet", (side * 0.3, -0.14, 0.47), (0.05,) * 3, dark, "Metal")
    gloss("Pauldron", 0.2)
    # Great helm with a T-slit visor and a crest.
    rounded_box("Helm", (0, 0, 0.93), (0.17, 0.19, 0.18), armour, "Metal", bevel=0.4)
    gloss("Helm", 0.2)
    rounded_box("Visor", (0, -0.096, 0.94), (0.13, 0.01, 0.025), glow, "Neon", bevel=0.4)
    rounded_box("Visor", (0, -0.096, 0.91), (0.025, 0.01, 0.05), glow, "Neon", bevel=0.4)
    tube("Crest", [(0, -0.06, 1.02), (0, 0.04, 1.06), (0, 0.12, 1.02)], [0.02, 0.03, 0.015], dark, "Metal", sides=6)
    # Spear with a leaf blade; shield with rim and emblem.
    tube("Spear", [(0.3, -0.14, 0.08), (0.3, -0.14, 1.04)], [0.016, 0.016], (95, 75, 55), "Wood", sides=6)
    tube("SpearBlade", [(0.3, -0.14, 1.04), (0.3, -0.14, 1.1), (0.3, -0.14, 1.2)], [0.012, 0.04, 0.002], (225, 228, 235), "Metal", sides=6)
    gloss("SpearBlade", 0.4)
    rounded_box("Shield", (-0.36, -0.13, 0.56), (0.035, 0.24, 0.34), armour, "Metal", bevel=0.4)
    tube("ShieldRim", [(-0.38, -0.13 + math.cos(t / 24 * math.tau) * 0.115, 0.56 + math.sin(t / 24 * math.tau) * 0.165) for t in range(25)], [0.012] * 25, dark, "Metal", sides=5)
    ellipsoid("ShieldEmblem", (-0.385, -0.13, 0.56), (0.012, 0.05, 0.07), glow, "Neon")


# -------------------------------------------------------------------- mech
def mech():
    """A titan-guard mech: armour panels with seams, hydraulic legs,
    cockpit glass, cannons with cooling rings, capped missile pods."""
    armour = "Tint"
    frame = (55, 56, 64)
    for side in (-1, 1):
        rounded_box("Foot", (side * 0.2, -0.05, 0.04), (0.18, 0.32, 0.08), frame, "Metal", bevel=0.35)
        for t in (-1, 1):
            cone("Toe", (side * 0.2 + t * 0.05, -0.2, 0.04), (side * 0.2 + t * 0.06, -0.26, 0.02), 0.035, frame, "Metal", sides=6)
        tube("Leg", [(side * 0.2, 0, 0.08), (side * 0.22, -0.08, 0.3), (side * 0.2, 0.02, 0.5)], [0.06, 0.07, 0.07], frame, "Metal", sides=12)
        tube("Piston", [(side * 0.27, 0.02, 0.12), (side * 0.27, -0.06, 0.3)], [0.022, 0.022], (190, 190, 195), "Metal", sides=8)
        tube("Piston", [(side * 0.27, -0.06, 0.32), (side * 0.25, 0.04, 0.48)], [0.022, 0.022], (190, 190, 195), "Metal", sides=8)
        rounded_box("Shin", (side * 0.22, -0.11, 0.24), (0.14, 0.07, 0.2), armour, "Metal", bevel=0.35)
        cylinder("Knee", (side * 0.22, -0.1, 0.36), 0.065, 0.13, frame, "Metal", rotation=(0, math.pi / 2, 0), sides=20)
        rivets([(side * 0.22 + dx, -0.15, z) for dx in (-0.05, 0.05) for z in (0.17, 0.31)], 0.01)
    rounded_box("Torso", (0, 0, 0.62), (0.52, 0.38, 0.26), armour, "Metal", bevel=0.2)
    gloss("Torso", 0.15)
    for z in (0.55, 0.69):
        rounded_box("Seam", (0, -0.192, z), (0.48, 0.006, 0.006), frame, "Metal", bevel=0.3)
    rounded_box("Cockpit", (0, -0.2, 0.66), (0.26, 0.04, 0.12), (110, 190, 245), "Glass", bevel=0.45)
    ellipsoid("Core", (0, -0.2, 0.55), (0.06, 0.025, 0.06), (80, 200, 255), "Neon")
    for k in range(4):
        rounded_box("Vent", (-0.15 + k * 0.1, 0.195, 0.62), (0.06, 0.01, 0.1), (25, 25, 28), bevel=0.4)
    for side in (-1, 1):
        rounded_box("Shoulder", (side * 0.33, 0, 0.74), (0.16, 0.24, 0.12), armour, "Metal", bevel=0.3)
        rivets([(side * 0.33, -0.12, 0.74 + dz) for dz in (-0.03, 0.03)], 0.01)
        tube("Arm", [(side * 0.36, 0, 0.66), (side * 0.38, -0.06, 0.5), (side * 0.38, -0.2, 0.44)], [0.06, 0.055, 0.05], frame, "Metal", sides=12)
        cylinder("Cannon", (side * 0.38, -0.32, 0.44), 0.05, 0.24, (40, 41, 46), "Metal", rotation=(math.pi / 2, 0, 0), sides=20, bevel=0.01)
        for k in range(3):
            cylinder("CoolingRing", (side * 0.38, -0.26 - k * 0.04, 0.44), 0.058, 0.012, (90, 92, 98), "Metal", rotation=(math.pi / 2, 0, 0), sides=20)
        cylinder("Muzzle", (side * 0.38, -0.445, 0.44), 0.035, 0.01, (80, 200, 255), "Neon", rotation=(math.pi / 2, 0, 0), sides=16)
        rounded_box("MissilePod", (side * 0.22, 0.12, 0.86), (0.16, 0.16, 0.12), frame, "Metal", bevel=0.2)
        for k in range(2):
            for j in range(2):
                cylinder("Missile", (side * 0.22 + (k - 0.5) * 0.06, 0.035, 0.84 + j * 0.05), 0.022, 0.02, (255, 90, 60), "Neon", rotation=(math.pi / 2, 0, 0), sides=12)
    tube("Antenna", [(0.18, 0.1, 0.75), (0.2, 0.15, 1.0)], [0.012, 0.006], frame, "Metal", sides=5)


# ------------------------------------------------------------------- golem
def golem():
    """A rock golem: faceted boulders bound by glowing cracks, moss, crystals."""
    import random

    rng = random.Random(11)
    rock = "Tint"
    dark = "TintDark"
    ember = (255, 140, 60)

    def boulder(role, centre, r, color=rock):
        obj = ellipsoid(role, centre, (r * rng.uniform(0.85, 1.15), r * rng.uniform(0.85, 1.1), r * rng.uniform(0.8, 1.0)), color, rotation=(rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3)), segments=7)
        # Faceted, like split stone.
        for poly in obj.data.polygons:
            poly.use_smooth = False

    for x, y, z, r in ((0, 0, 0.62, 0.26), (0.13, 0.05, 0.78, 0.17), (-0.13, -0.02, 0.76, 0.18), (0, 0.06, 0.47, 0.2), (0.08, -0.1, 0.6, 0.15), (-0.09, 0.1, 0.62, 0.16)):
        boulder("Body", (x, y, z), r)
    boulder("Head", (0, -0.05, 0.96), 0.12)
    for side in (-1, 1):
        ellipsoid("Eye", (side * 0.045, -0.155, 0.97), (0.028, 0.012, 0.016), ember, "Neon")
        boulder("Shoulder", (side * 0.3, 0, 0.8), 0.13, dark)
        boulder("Arm", (side * 0.36, -0.02, 0.6), 0.1)
        boulder("Arm", (side * 0.38, -0.04, 0.46), 0.09, dark)
        boulder("Fist", (side * 0.39, -0.07, 0.3), 0.14, dark)
        boulder("Leg", (side * 0.13, 0, 0.18), 0.14, dark)
        boulder("Leg", (side * 0.14, -0.04, 0.06), 0.1)
        ellipsoid("Moss", (side * 0.27, 0.03, 0.9), (0.09, 0.08, 0.025), (85, 125, 65), "Fabric", segments=10)
        cone("Crystal", (side * 0.3, 0.05, 0.88), (side * 0.38, 0.1, 1.02), 0.035, (140, 220, 255), "Neon", sides=5)
    ellipsoid("Moss", (0.05, 0.05, 0.85), (0.1, 0.08, 0.03), (85, 125, 65), "Fabric", segments=10)
    ellipsoid("Core", (0, -0.25, 0.62), (0.07, 0.035, 0.08), ember, "Neon")
    # Glowing seams between the boulders.
    for pts in (
        [(-0.12, -0.24, 0.72), (-0.05, -0.25, 0.66), (0.0, -0.26, 0.7)],
        [(0.05, -0.25, 0.55), (0.12, -0.24, 0.5), (0.16, -0.22, 0.44)],
        [(-0.04, -0.25, 0.52), (-0.1, -0.23, 0.45)],
    ):
        tube("Crack", pts, [0.008] * len(pts), ember, "Neon", sides=4)


# ---------------------------------------------------------------- colossus
def colossus():
    """The final titan: carved stone armour, violet crystal growths, glowing
    runes and a gold crown."""
    stone = (104, 98, 96)
    carved = (84, 78, 80)
    gold = (230, 195, 120)
    for side in (-1, 1):
        rounded_box("Foot", (side * 0.13, -0.04, 0.03), (0.13, 0.2, 0.06), carved, bevel=0.3)
        tube("Leg", [(side * 0.12, 0, 0.06), (side * 0.12, 0, 0.26), (side * 0.11, 0, 0.44)], [0.07, 0.075, 0.085], stone, sides=12)
        rounded_box("Greave", (side * 0.12, -0.05, 0.2), (0.12, 0.06, 0.16), carved, bevel=0.4)
        tube("Rune", [(side * 0.12, -0.082, 0.14), (side * 0.12, -0.082, 0.26)], [0.006, 0.006], "Tint", "Neon", sides=4)
        for k in range(2):
            cone("Crystal", (side * 0.17, 0.02, 0.28 + k * 0.08), (side * (0.25 + k * 0.03), 0.04, 0.38 + k * 0.08), 0.035, "Tint", "Neon", sides=6)
    rounded_box("Waist", (0, 0, 0.47), (0.3, 0.18, 0.08), carved, bevel=0.3)
    rounded_box("Belt", (0, 0, 0.5), (0.32, 0.2, 0.04), gold, "Metal", bevel=0.4)
    gloss("Belt", 0.3)
    ellipsoid("Torso", (0, 0, 0.65), (0.24, 0.15, 0.2), stone, segments=20)
    ellipsoid("Chestplate", (0, -0.07, 0.67), (0.18, 0.09, 0.14), carved, segments=18)
    ellipsoid("Heart", (0, -0.155, 0.67), (0.055, 0.02, 0.065), "Tint", "Neon")
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        tube("Rune", [(math.cos(a) * 0.08, -0.155, 0.67 + math.sin(a) * 0.09), (math.cos(a) * 0.12, -0.15, 0.67 + math.sin(a) * 0.12)], [0.006, 0.004], "Tint", "Neon", sides=4)
    for side in (-1, 1):
        ellipsoid("Shoulder", (side * 0.26, 0, 0.79), (0.1, 0.11, 0.09), carved)
        for k in range(4):
            cone("Crystal", (side * (0.24 + k * 0.025), 0.03 * (k - 1.5), 0.84), (side * (0.28 + k * 0.06), 0.04 * (k - 1.5), 1.0 - k * 0.03), 0.04 - k * 0.006, "Tint", "Neon", sides=6)
        tube("Arm", [(side * 0.28, 0, 0.74), (side * 0.32, -0.02, 0.56), (side * 0.32, -0.06, 0.4)], [0.065, 0.06, 0.055], stone, sides=12)
        rounded_box("Bracer", (side * 0.32, -0.05, 0.47), (0.09, 0.09, 0.08), gold, "Metal", bevel=0.4)
        ellipsoid("Fist", (side * 0.32, -0.07, 0.36), (0.07,) * 3, carved)
    ellipsoid("Head", (0, -0.02, 0.92), (0.1, 0.1, 0.11), stone, segments=18)
    rounded_box("Brow", (0, -0.1, 0.95), (0.14, 0.03, 0.025), carved, bevel=0.4)
    for side in (-1, 1):
        ellipsoid("Eye", (side * 0.04, -0.11, 0.925), (0.025, 0.01, 0.014), "Tint", "Neon")
    for k in range(5):
        a = math.radians(-60 + k * 30)
        cone("Crown", (math.sin(a) * 0.085, math.cos(a) * -0.02, 1.0), (math.sin(a) * 0.12, math.cos(a) * -0.03, 1.08 + (0.05 if k == 2 else 0)), 0.025, gold, "Metal", sides=6)
    tube("CrownBand", [(math.cos(t / 24 * math.tau) * 0.095, math.sin(t / 24 * math.tau) * 0.095, 0.99) for t in range(25)], [0.014] * 25, gold, "Metal", sides=5)
    gloss("Crown", 0.35)
