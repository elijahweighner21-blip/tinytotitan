"""Creature models. Each faces -Y; heights are rough (export normalises)."""

import math

from lib import cone, cylinder, ellipsoid, mirror_mesh_x, rounded_box, tube, wing

BLACK = (34, 30, 30)
SHINE = (255, 255, 255)


def cartoon_eyes(x, y, z, r, iris=(25, 22, 28)):
    """Big glossy eyes with a white catch-light: reads at any distance."""
    eye = ellipsoid("Eye", (x, y, z), (r, r * 0.9, r * 1.05), iris, "SmoothPlastic")
    mirror_mesh_x(eye)
    shine = ellipsoid("EyeShine", (x - r * 0.25, y - r * 0.75, z + r * 0.4), (r * 0.28,) * 3, SHINE, "Neon")
    mirror_mesh_x(shine)


def insect_leg(root, side, spread, length, thickness, color, lift=0.0):
    """Three-segment leg: up and out, then down to a pointed foot."""
    x, y, z = root
    knee = (x + side * length * 0.45, y + spread * length * 0.25, z + length * (0.28 + lift))
    ankle = (x + side * length * 0.85, y + spread * length * 0.5, z - length * 0.1)
    foot = (x + side * length * 0.98, y + spread * length * 0.62, z - length * 0.42)
    tube("Leg", [root, knee, ankle, foot], [thickness, thickness * 0.85, thickness * 0.6, thickness * 0.2], color, sides=8)


def wasp():
    yellow = "Tint"
    # Head, thorax, waist, segmented abdomen (alternating bands).
    ellipsoid("Head", (0, -0.62, 0.62), (0.2, 0.17, 0.19), yellow)
    ellipsoid("Mask", (0, -0.74, 0.56), (0.12, 0.08, 0.1), BLACK)
    cartoon_eyes(0.12, -0.7, 0.66, 0.085)
    for side in (-1, 1):
        tube(
            "Antenna",
            [(side * 0.05, -0.72, 0.75), (side * 0.12, -0.86, 0.95), (side * 0.2, -1.02, 0.98)],
            [0.018, 0.014, 0.01],
            BLACK,
            sides=6,
        )
        tube("Mandible", [(side * 0.05, -0.78, 0.47), (side * 0.02, -0.86, 0.42)], [0.025, 0.008], BLACK, sides=6)
    ellipsoid("Thorax", (0, -0.3, 0.6), (0.2, 0.22, 0.2), BLACK)
    ellipsoid("Fuzz", (0, -0.3, 0.72), (0.16, 0.17, 0.1), (120, 80, 30), "Fabric")
    tube("Waist", [(0, -0.12, 0.58), (0, 0.0, 0.55)], [0.05, 0.05], BLACK, sides=8)
    bands = [(0.06, 0.2), (0.22, 0.25), (0.4, 0.26), (0.58, 0.23), (0.74, 0.17), (0.87, 0.1)]
    for i, (y, r) in enumerate(bands):
        ellipsoid("Body" if i % 2 == 0 else "Stripe", (0, y + 0.06, 0.52 - y * 0.18), (r, 0.13, r * 0.92), yellow if i % 2 == 0 else BLACK)
    tube("Stinger", [(0, 1.0, 0.36), (0, 1.16, 0.3)], [0.03, 0.002], BLACK, sides=8)
    # Legs hang from the thorax; wings sweep back.
    # Legs dangle back under the body, as a flying wasp's do.
    for i, dy in enumerate((-0.4, -0.3, -0.2)):
        for side in (-1, 1):
            x0 = side * 0.1
            tube(
                "Leg",
                [
                    (x0, dy, 0.46),
                    (x0 + side * 0.12, dy + 0.06, 0.34),
                    (x0 + side * 0.1, dy + 0.2 + i * 0.06, 0.2 + i * 0.02),
                    (x0 + side * 0.08, dy + 0.4 + i * 0.08, 0.1 + i * 0.03),
                ],
                [0.03, 0.026, 0.02, 0.008],
                BLACK if i == 0 else (60, 50, 40),
                sides=8,
            )
    for side in (-1, 1):
        wing("Wing", (side * 0.08, -0.32, 0.8), (side * 0.9, 0.55, 0.38), 0.78, 0.2, (232, 244, 255))
        wing("Wing", (side * 0.07, -0.24, 0.78), (side * 0.75, 0.9, 0.22), 0.56, 0.14, (232, 244, 255))
        # Dark vein along each forewing's leading edge.
        tube("Vein", [(side * 0.08, -0.32, 0.81), (side * 0.6, -0.0, 1.03)], [0.012, 0.006], (90, 80, 70), sides=5)


def beetle():
    shell = "Tint"
    ellipsoid("Shell", (0, 0.1, 0.45), (0.5, 0.68, 0.36), shell, "SmoothPlastic", segments=28)
    # Seam down the middle of the wing cases + a sheen band.
    tube("Seam", [(0, -0.48, 0.74), (0, 0.1, 0.82), (0, 0.72, 0.56)], [0.018, 0.02, 0.012], (25, 60, 40), sides=6)
    ellipsoid("Pronotum", (0, -0.55, 0.42), (0.36, 0.2, 0.25), "TintDark")
    ellipsoid("Head", (0, -0.78, 0.36), (0.22, 0.16, 0.17), "TintDark")
    cartoon_eyes(0.15, -0.88, 0.42, 0.06)
    tube("Horn", [(0, -0.88, 0.45), (0, -1.08, 0.6), (0, -1.16, 0.82)], [0.07, 0.045, 0.012], (30, 40, 35), sides=10)
    for side in (-1, 1):
        tube("Antenna", [(side * 0.12, -0.92, 0.42), (side * 0.28, -1.08, 0.5)], [0.02, 0.012], (30, 40, 35), sides=6)
    for i, (dy, spread) in enumerate(((-0.5, -0.5), (-0.15, 0.1), (0.25, 0.7))):
        for side in (-1, 1):
            insect_leg((side * 0.3, dy, 0.25), side, spread, 0.5, 0.04, (35, 45, 40))


def spider():
    fur = "Tint"
    ellipsoid("Abdomen", (0, 0.42, 0.55), (0.42, 0.5, 0.4), fur, "Fabric", segments=24)
    ellipsoid("Marking", (0, 0.42, 0.93), (0.14, 0.24, 0.04), (230, 120, 60), "SmoothPlastic")
    ellipsoid("Body", (0, -0.2, 0.42), (0.28, 0.3, 0.22), fur, "Fabric")
    for x, z, r in ((0.09, 0.56, 0.07), (0.2, 0.5, 0.045)):
        cartoon_eyes(x, -0.45, z, r, (120, 20, 25))
    for side in (-1, 1):
        tube("Fang", [(side * 0.07, -0.48, 0.3), (side * 0.05, -0.55, 0.18)], [0.035, 0.01], (40, 30, 30), sides=6)
    for i in range(4):
        a = math.radians(-55 + i * 35)
        for side in (-1, 1):
            base = (side * 0.2, -0.2 + i * 0.07, 0.42)
            reach = 1.05
            dx, dy = math.cos(a) * side, math.sin(a)
            tube(
                "Leg",
                [
                    base,
                    (base[0] + dx * reach * 0.42, base[1] + dy * reach * 0.42, 0.95),
                    (base[0] + dx * reach * 0.8, base[1] + dy * reach * 0.8, 0.5),
                    (base[0] + dx * reach, base[1] + dy * reach, 0.0),
                ],
                [0.045, 0.04, 0.03, 0.012],
                fur,
                "Fabric",
                sides=8,
            )


def mower():
    red = "Tint"

    rounded_box("Deck", (0, 0, 0.32), (1.1, 1.5, 0.3), red, bevel=0.3)
    rounded_box("Hood", (0, -0.1, 0.55), (0.75, 0.9, 0.28), red, bevel=0.4)
    cylinder("Engine", (0, -0.1, 0.8), 0.24, 0.28, (60, 60, 64), "Metal", bevel=0.03)
    cylinder("Cap", (0.1, -0.2, 0.97), 0.06, 0.06, (240, 200, 40), bevel=0.01)
    for x in (-0.6, 0.6):
        for y in (-0.55, 0.55):
            cylinder("Tire", (x, y, 0.2), 0.2, 0.14, (30, 30, 32), "Rubber", rotation=(0, math.pi / 2, 0), bevel=0.04)
            cylinder("Hub", (x * 1.08, y, 0.2), 0.09, 0.04, (200, 200, 205), "Metal", rotation=(0, math.pi / 2, 0))
    # Handle: two bars meeting a grip.
    for side in (-1, 1):
        tube("Handle", [(side * 0.38, 0.6, 0.5), (side * 0.38, 1.05, 1.15), (side * 0.38, 1.25, 1.45)], [0.03, 0.03, 0.03], (60, 60, 64), "Metal", sides=8)
    tube("Grip", [(-0.42, 1.25, 1.45), (0.42, 1.25, 1.45)], [0.045, 0.045], (30, 30, 32), "Rubber", sides=10)
    # Grumpy face on the front: eyes + angry brows.
    cartoon_eyes(0.22, -0.78, 0.4, 0.09)
    for side in (-1, 1):
        tube("Brow", [(side * 0.08, -0.8, 0.55), (side * 0.32, -0.78, 0.5)], [0.03, 0.03], (30, 30, 32), sides=6)
    tube("Grille", [(-0.3, -0.76, 0.22), (0.3, -0.76, 0.22)], [0.03, 0.03], (30, 30, 32), sides=6)


def legs8(attach_y, attach_z, spread_x, reach, thick, color, material="SmoothPlastic", knee=0.5, rows=4):
    """Spider/mite style legs radiating from the body sides."""
    for i in range(rows):
        a = math.radians(-50 + i * (100 / max(rows - 1, 1)))
        for side in (-1, 1):
            base = (side * spread_x, attach_y + (i - (rows - 1) / 2) * 0.12, attach_z)
            dx, dy = math.cos(a) * side, math.sin(a)
            tube(
                "Leg",
                [
                    base,
                    (base[0] + dx * reach * 0.45, base[1] + dy * reach * 0.45, attach_z + knee * reach),
                    (base[0] + dx * reach, base[1] + dy * reach, 0.0),
                ],
                [thick, thick * 0.8, thick * 0.3],
                color,
                material,
                sides=8,
            )


def mite():
    body = "Tint"
    # Lumpy, chubby body made of overlapping blobs.
    ellipsoid("Body", (0, 0.05, 0.42), (0.42, 0.55, 0.36), body, "Fabric", segments=24)
    for x, y, z, r in ((0.2, 0.2, 0.62, 0.18), (-0.22, 0.3, 0.58, 0.17), (0.0, 0.42, 0.55, 0.2), (0.0, -0.1, 0.7, 0.18)):
        ellipsoid("Body", (x, y, z), (r, r, r * 0.9), body, "Fabric")
    ellipsoid("Head", (0, -0.52, 0.36), (0.18, 0.16, 0.15), "TintDark", "Fabric")
    cartoon_eyes(0.08, -0.64, 0.42, 0.055)
    for side in (-1, 1):
        tube("Mouth", [(side * 0.04, -0.66, 0.3), (side * 0.03, -0.74, 0.26)], [0.03, 0.012], "TintDark", sides=6)
    # Bristles along the back.
    for i in range(7):
        y = -0.3 + i * 0.13
        for side in (-1, 1):
            tube("Bristle", [(side * 0.12, y, 0.72), (side * 0.2, y + 0.05, 0.92)], [0.012, 0.004], (120, 110, 100), sides=4)
    legs8(0.05, 0.3, 0.32, 0.34, 0.06, "TintDark", "Fabric", knee=0.3)


def insect():
    """An ant (the Queen boss uses this too, at a bigger scale)."""
    shell = "Tint"
    ellipsoid("Head", (0, -0.7, 0.55), (0.2, 0.18, 0.17), shell)
    cartoon_eyes(0.13, -0.76, 0.6, 0.06)
    for side in (-1, 1):
        tube("Mandible", [(side * 0.08, -0.84, 0.48), (side * 0.03, -0.96, 0.44)], [0.035, 0.01], "TintDark", sides=6)
        tube(
            "Antenna",
            [(side * 0.06, -0.8, 0.68), (side * 0.12, -0.84, 0.92), (side * 0.22, -1.08, 0.98)],
            [0.02, 0.016, 0.012],
            "TintDark",
            sides=6,
        )
    ellipsoid("Thorax", (0, -0.36, 0.5), (0.13, 0.22, 0.12), shell)
    ellipsoid("Petiole", (0, -0.1, 0.48), (0.07, 0.07, 0.09), "TintDark")
    ellipsoid("Gaster", (0, 0.35, 0.52), (0.3, 0.42, 0.28), shell, segments=24)
    ellipsoid("Shine", (0.08, 0.28, 0.74), (0.1, 0.16, 0.04), (255, 255, 255), "Glass")
    for i, (dy, spread) in enumerate(((-0.45, -0.5), (-0.36, 0.1), (-0.27, 0.7))):
        for side in (-1, 1):
            insect_leg((side * 0.1, dy, 0.44), side, spread, 0.62, 0.03, "TintDark")


def moth():
    fur = "Tint"
    ellipsoid("Body", (0, 0.05, 0.4), (0.16, 0.45, 0.15), fur, "Fabric")
    ellipsoid("Ruff", (0, -0.32, 0.43), (0.19, 0.14, 0.17), "TintLight", "Fabric")
    ellipsoid("Head", (0, -0.48, 0.42), (0.13, 0.11, 0.12), fur, "Fabric")
    cartoon_eyes(0.08, -0.56, 0.46, 0.05)
    for side in (-1, 1):
        # Feathery antennae: a stem with little side barbs.
        stem = [(side * 0.04, -0.56, 0.52), (side * 0.14, -0.7, 0.7), (side * 0.26, -0.78, 0.82)]
        tube("Antenna", stem, [0.012, 0.01, 0.006], "TintDark", sides=5)
        for k in range(5):
            t = k / 5
            px = side * (0.06 + 0.18 * t)
            py = -0.6 - 0.16 * t
            pz = 0.56 + 0.24 * t
            tube("Antenna", [(px, py, pz), (px + side * 0.05, py + 0.04, pz - 0.02)], [0.006, 0.003], "TintDark", sides=4)
        wing("Wing", (side * 0.1, -0.2, 0.48), (side * 1.0, -0.25, 0.25), 0.9, 0.42, "TintLight", "Fabric")
        wing("Wing", (side * 0.1, 0.05, 0.46), (side * 0.85, 0.55, 0.1), 0.62, 0.28, "TintLight", "Fabric")
        # Eye-spots on the forewings scare birds (and players).
        ellipsoid("Spot", (side * 0.55, -0.32, 0.6), (0.11, 0.09, 0.02), (60, 40, 30), rotation=(0.0, side * -0.25, 0))
        ellipsoid("SpotRing", (side * 0.55, -0.32, 0.596), (0.16, 0.13, 0.02), (240, 200, 120), rotation=(0.0, side * -0.25, 0))
    for side in (-1, 1):
        for dy in (-0.35, -0.25, -0.15):
            tube("Leg", [(side * 0.08, dy, 0.32), (side * 0.18, dy + 0.05, 0.16), (side * 0.2, dy + 0.12, 0.0)], [0.02, 0.016, 0.006], "TintDark", sides=6)


def fly():
    body = "Tint"
    ellipsoid("Thorax", (0, -0.15, 0.5), (0.26, 0.26, 0.24), body, "Fabric")
    ellipsoid("Abdomen", (0, 0.28, 0.45), (0.26, 0.32, 0.22), body)
    ellipsoid("Sheen", (0, 0.28, 0.6), (0.18, 0.24, 0.08), (90, 140, 110), "Foil")
    ellipsoid("Head", (0, -0.48, 0.5), (0.2, 0.14, 0.17), body)
    for side in (-1, 1):
        # Huge red compound eyes.
        ellipsoid("CompoundEye", (side * 0.14, -0.5, 0.54), (0.13, 0.12, 0.15), (190, 40, 40))
        ellipsoid("EyeShine", (side * 0.16, -0.6, 0.62), (0.035,) * 3, SHINE, "Neon")
        wing("Wing", (side * 0.08, -0.15, 0.72), (side * 0.7, 0.75, 0.25), 0.62, 0.17, (225, 238, 250))
        tube("Vein", [(side * 0.08, -0.15, 0.73), (side * 0.38, 0.28, 0.87)], [0.01, 0.005], (60, 60, 60), sides=5)
    tube("Proboscis", [(0, -0.58, 0.42), (0, -0.62, 0.3)], [0.03, 0.05], "TintDark", sides=8)
    for i, dy in enumerate((-0.28, -0.16, -0.04)):
        for side in (-1, 1):
            insect_leg((side * 0.15, dy, 0.38), side, -0.3 + i * 0.6, 0.42, 0.028, "TintDark")
    # Bristly hairs.
    for i in range(6):
        y = -0.3 + i * 0.07
        tube("Bristle", [(0.06 - (i % 2) * 0.12, y, 0.72), (0.08 - (i % 2) * 0.16, y + 0.05, 0.84)], [0.01, 0.003], (20, 20, 20), sides=4)


def roach():
    shell = "Tint"
    ellipsoid("Body", (0, 0.1, 0.28), (0.38, 0.68, 0.17), shell, segments=28)
    tube("Seam", [(0, -0.3, 0.44), (0, 0.2, 0.45), (0, 0.72, 0.32)], [0.012, 0.012, 0.008], "TintDark", sides=6)
    ellipsoid("Shine", (0.1, 0.0, 0.43), (0.12, 0.35, 0.03), (255, 240, 220), "Glass")
    ellipsoid("Pronotum", (0, -0.55, 0.3), (0.3, 0.18, 0.12), (200, 160, 110))
    ellipsoid("Head", (0, -0.7, 0.24), (0.14, 0.1, 0.1), "TintDark")
    cartoon_eyes(0.08, -0.78, 0.28, 0.04)
    for side in (-1, 1):
        tube(
            "Antenna",
            [(side * 0.05, -0.78, 0.3), (side * 0.25, -1.1, 0.5), (side * 0.55, -1.35, 0.45), (side * 0.75, -1.45, 0.3)],
            [0.014, 0.011, 0.008, 0.004],
            "TintDark",
            sides=5,
        )
        tube("Cercus", [(side * 0.05, 0.75, 0.25), (side * 0.12, 0.92, 0.28)], [0.02, 0.005], "TintDark", sides=5)
    for i, (dy, spread) in enumerate(((-0.4, -0.7), (-0.1, 0.0), (0.2, 0.9))):
        for side in (-1, 1):
            insect_leg((side * 0.25, dy, 0.18), side, spread, 0.62 + i * 0.08, 0.03, "TintDark")


def toy():
    """A wind-up tin drummer."""
    coat = "Tint"
    for side in (-1, 1):
        cylinder("Boot", (side * 0.1, 0, 0.05), 0.08, 0.1, (30, 30, 34), bevel=0.02)
        cylinder("Trousers", (side * 0.1, 0, 0.2), 0.075, 0.24, (35, 45, 90))
    cylinder("Coat", (0, 0, 0.48), 0.2, 0.36, coat, bevel=0.03)
    cylinder("Belt", (0, 0, 0.36), 0.205, 0.04, (245, 240, 230))
    for z in (0.44, 0.52, 0.6):
        ellipsoid("Button", (0, -0.2, z), (0.022, 0.012, 0.022), (240, 200, 60), "Metal")
    ellipsoid("Epaulette", (0.2, 0, 0.64), (0.07, 0.07, 0.04), (240, 200, 60), "Metal")
    ellipsoid("Epaulette", (-0.2, 0, 0.64), (0.07, 0.07, 0.04), (240, 200, 60), "Metal")
    for side in (-1, 1):
        tube("Arm", [(side * 0.22, 0, 0.62), (side * 0.26, -0.06, 0.48), (side * 0.2, -0.16, 0.42)], [0.05, 0.045, 0.04], coat, sides=8)
        tube("Drumstick", [(side * 0.18, -0.18, 0.42), (side * 0.06, -0.3, 0.38)], [0.012, 0.012], (220, 190, 140), "Wood", sides=6)
    cylinder("Drum", (0, -0.28, 0.32), 0.13, 0.12, (245, 240, 230), bevel=0.01)
    cylinder("DrumRim", (0, -0.28, 0.385), 0.135, 0.02, (220, 40, 40))
    ellipsoid("Face", (0, 0, 0.78), (0.14, 0.14, 0.15), (245, 210, 180))
    for side in (-1, 1):
        ellipsoid("Cheek", (side * 0.08, -0.11, 0.75), (0.035, 0.02, 0.025), (240, 120, 120))
        ellipsoid("Eye", (side * 0.05, -0.13, 0.8), (0.022, 0.012, 0.026), (25, 22, 28))
    rounded_box("Mustache", (0, -0.135, 0.76), (0.1, 0.02, 0.025), (60, 40, 30), bevel=0.4)
    cylinder("Hat", (0, 0, 1.0), 0.13, 0.3, (30, 30, 34), bevel=0.02)
    cylinder("HatBand", (0, 0, 0.88), 0.135, 0.04, (240, 200, 60), "Metal")
    ellipsoid("Plume", (0, -0.04, 1.2), (0.05, 0.05, 0.1), (220, 40, 40), "Fabric")
    # The wind-up key on the back.
    tube("Key", [(0, 0.2, 0.5), (0, 0.32, 0.5)], [0.02, 0.02], (240, 200, 60), "Metal", sides=8)
    for side in (-1, 1):
        ellipsoid("Key", (side * 0.07, 0.33, 0.5), (0.07, 0.015, 0.045), (240, 200, 60), "Metal")


def robot():
    metal = "Tint"
    for side in (-1, 1):
        rounded_box("Tread", (side * 0.26, 0, 0.1), (0.16, 0.6, 0.2), (40, 40, 44), "Rubber", bevel=0.5)
        for y in (-0.2, 0, 0.2):
            cylinder("Wheel", (side * 0.35, y, 0.1), 0.07, 0.03, (150, 150, 155), "Metal", rotation=(0, math.pi / 2, 0))
    rounded_box("Body", (0, 0, 0.42), (0.5, 0.42, 0.46), metal, "Metal", bevel=0.15)
    rounded_box("ChestPanel", (0, -0.21, 0.42), (0.3, 0.02, 0.22), (40, 44, 52), bevel=0.2)
    for i, c in enumerate(((255, 80, 80), (255, 210, 60), (80, 220, 120))):
        cylinder("Light", (-0.08 + i * 0.08, -0.225, 0.47), 0.025, 0.02, c, "Neon", rotation=(math.pi / 2, 0, 0))
    rounded_box("Head", (0, 0, 0.8), (0.38, 0.32, 0.28), metal, "Metal", bevel=0.2)
    rounded_box("Visor", (0, -0.16, 0.8), (0.28, 0.02, 0.1), (255, 60, 60), "Neon", bevel=0.4)
    tube("Antenna", [(0, 0, 0.94), (0, 0, 1.1)], [0.015, 0.012], (60, 60, 64), "Metal", sides=6)
    ellipsoid("AntennaBall", (0, 0, 1.12), (0.04,) * 3, (255, 60, 60), "Neon")
    for side in (-1, 1):
        cylinder("Ear", (side * 0.2, 0, 0.8), 0.07, 0.04, (60, 60, 64), "Metal", rotation=(0, math.pi / 2, 0))
        tube("Arm", [(side * 0.27, 0, 0.55), (side * 0.36, -0.08, 0.42), (side * 0.36, -0.22, 0.38)], [0.045, 0.04, 0.04], (60, 60, 64), "Metal", sides=8)
        cone("Claw", (side * 0.36, -0.22, 0.38), (side * 0.32, -0.34, 0.42), 0.04, (60, 60, 64), "Metal")
        cone("Claw", (side * 0.36, -0.22, 0.38), (side * 0.4, -0.34, 0.34), 0.04, (60, 60, 64), "Metal")


def frog():
    skin = "Tint"
    ellipsoid("Body", (0, 0.05, 0.32), (0.4, 0.48, 0.3), skin, segments=28)
    ellipsoid("Belly", (0, -0.1, 0.24), (0.32, 0.36, 0.2), (235, 225, 170))
    ellipsoid("Head", (0, -0.32, 0.46), (0.34, 0.28, 0.2), skin)
    for side in (-1, 1):
        ellipsoid("EyeBulge", (side * 0.18, -0.36, 0.62), (0.12, 0.12, 0.11), skin)
        ellipsoid("Eye", (side * 0.2, -0.44, 0.66), (0.075, 0.06, 0.075), (245, 220, 80))
        ellipsoid("Pupil", (side * 0.2, -0.5, 0.66), (0.055, 0.02, 0.03), (20, 20, 20))
        ellipsoid("Spot", (side * 0.22, 0.15, 0.5), (0.08, 0.1, 0.05), "TintDark")
        # Folded back legs and front feet.
        ellipsoid("Thigh", (side * 0.34, 0.25, 0.18), (0.16, 0.26, 0.15), skin)
        ellipsoid("Foot", (side * 0.4, -0.05, 0.03), (0.12, 0.22, 0.03), skin)
        tube("Arm", [(side * 0.24, -0.3, 0.22), (side * 0.27, -0.4, 0.04)], [0.075, 0.06], skin, sides=10)
        ellipsoid("Foot", (side * 0.28, -0.45, 0.02), (0.08, 0.08, 0.02), skin)
    ellipsoid("Spot", (0, 0.3, 0.6), (0.1, 0.12, 0.05), "TintDark")
    tube("Mouth", [(-0.2, -0.5, 0.41), (-0.08, -0.585, 0.39), (0.08, -0.585, 0.39), (0.2, -0.5, 0.41)], [0.012] * 4, (60, 40, 40), sides=5)


def crow():
    feather = "Tint"
    ellipsoid("Body", (0, 0.05, 0.5), (0.24, 0.42, 0.26), feather, "Fabric", rotation=(math.radians(-15), 0, 0))
    ellipsoid("Chest", (0, -0.2, 0.46), (0.2, 0.18, 0.22), "TintLight", "Fabric")
    ellipsoid("Head", (0, -0.36, 0.78), (0.17, 0.18, 0.16), feather, "Fabric")
    cone("Beak", (0, -0.48, 0.77), (0, -0.74, 0.72), 0.07, (70, 70, 74), sides=10)
    cartoon_eyes(0.1, -0.47, 0.82, 0.045)
    for side in (-1, 1):
        # Folded wing along each flank, feather tips fanning back.
        ellipsoid("Wing", (side * 0.2, 0.15, 0.55), (0.08, 0.42, 0.18), "TintDark", "Fabric", rotation=(math.radians(-15), 0, 0))
        for k in range(3):
            ellipsoid("Wing", (side * 0.2, 0.55 + k * 0.05, 0.42 - k * 0.04), (0.05, 0.16, 0.04), "TintDark", "Fabric")
        tube("Leg", [(side * 0.08, 0.0, 0.26), (side * 0.09, -0.02, 0.02)], [0.025, 0.02], (60, 50, 40), sides=6)
        for a in (-0.4, 0, 0.4):
            tube("Toe", [(side * 0.09, -0.02, 0.02), (side * 0.09 + math.sin(a) * 0.1, -0.02 - math.cos(a) * 0.1, 0.0)], [0.018, 0.008], (60, 50, 40), sides=5)
    for k in range(3):
        ellipsoid("Tail", ((k - 1) * 0.06, 0.6, 0.36), (0.06, 0.24, 0.03), "TintDark", "Fabric", rotation=(math.radians(20), 0, (k - 1) * 0.15))


def car():
    paint = "Tint"
    rounded_box("Chassis", (0, 0, 0.3), (0.62, 1.2, 0.14), (40, 40, 44), bevel=0.3)
    rounded_box("Body", (0, 0.02, 0.44), (0.56, 0.9, 0.2), paint, bevel=0.35)
    rounded_box("Nose", (0, -0.5, 0.36), (0.5, 0.25, 0.14), paint, bevel=0.45)
    rounded_box("Cabin", (0, 0.08, 0.6), (0.42, 0.42, 0.18), (60, 90, 120), "Glass", bevel=0.4)
    for side in (-1, 1):
        tube("Cage", [(side * 0.22, -0.14, 0.52), (side * 0.2, 0.0, 0.76), (side * 0.2, 0.3, 0.74), (side * 0.22, 0.4, 0.52)], [0.022] * 4, (30, 30, 34), "Metal", sides=6)
        for y in (-0.42, 0.42):
            cylinder("Tire", (side * 0.38, y, 0.2), 0.2, 0.16, (28, 28, 30), "Rubber", rotation=(0, math.pi / 2, 0), bevel=0.05)
            cylinder("Rim", (side * 0.465, y, 0.2), 0.1, 0.02, (220, 220, 225), "Metal", rotation=(0, math.pi / 2, 0))
        ellipsoid("Headlight", (side * 0.17, -0.62, 0.38), (0.06, 0.03, 0.04), (255, 240, 180), "Neon")
    rounded_box("Spoiler", (0, 0.58, 0.68), (0.6, 0.12, 0.03), paint, bevel=0.4)
    for side in (-1, 1):
        tube("Strut", [(side * 0.2, 0.55, 0.5), (side * 0.2, 0.58, 0.67)], [0.02, 0.02], (30, 30, 34), sides=6)
    tube("Antenna", [(0.2, 0.45, 0.5), (0.22, 0.5, 1.0)], [0.01, 0.005], (30, 30, 34), sides=5)
    ellipsoid("AntennaTip", (0.22, 0.5, 1.0), (0.025,) * 3, (255, 60, 60), "Neon")
    rounded_box("Stripe", (0, 0.02, 0.545), (0.12, 0.92, 0.012), (245, 245, 245), bevel=0.3)


def drone():
    shell = "Tint"
    ellipsoid("Body", (0, 0, 0.5), (0.3, 0.3, 0.14), shell, "Metal", segments=28)
    ellipsoid("Dome", (0, 0, 0.6), (0.18, 0.18, 0.1), (40, 44, 52), "Glass")
    ellipsoid("Eye", (0, -0.26, 0.47), (0.08, 0.06, 0.07), (30, 30, 34))
    ellipsoid("EyeGlow", (0, -0.31, 0.47), (0.045, 0.02, 0.045), (255, 60, 60), "Neon")
    for k in range(4):
        a = math.radians(45 + k * 90)
        dx, dy = math.cos(a), math.sin(a)
        tube("Arm", [(dx * 0.22, dy * 0.22, 0.5), (dx * 0.62, dy * 0.62, 0.52)], [0.035, 0.03], (50, 52, 58), "Metal", sides=8)
        cylinder("Motor", (dx * 0.62, dy * 0.62, 0.55), 0.06, 0.08, (50, 52, 58), "Metal", bevel=0.01)
        cylinder("Guard", (dx * 0.62, dy * 0.62, 0.58), 0.26, 0.03, shell, "Metal", sides=32)
        cylinder("Rotor", (dx * 0.62, dy * 0.62, 0.6), 0.23, 0.01, (200, 210, 220), "Glass", sides=32)
    for side in (-1, 1):
        tube("Skid", [(side * 0.15, -0.25, 0.42), (side * 0.18, -0.2, 0.05)], [0.02, 0.02], (50, 52, 58), "Metal", sides=6)
        tube("Skid", [(side * 0.15, 0.25, 0.42), (side * 0.18, 0.2, 0.05)], [0.02, 0.02], (50, 52, 58), "Metal", sides=6)
        tube("Skid", [(side * 0.18, -0.32, 0.03), (side * 0.18, 0.32, 0.03)], [0.022, 0.022], (50, 52, 58), "Metal", sides=6)


def sentinel():
    """An armoured titan guard: broad shoulders, glowing visor, spear arm."""
    armour = "Tint"
    for side in (-1, 1):
        rounded_box("Boot", (side * 0.13, -0.03, 0.05), (0.14, 0.22, 0.1), "TintDark", "Metal", bevel=0.3)
        tube("Leg", [(side * 0.12, 0, 0.1), (side * 0.12, 0, 0.3), (side * 0.11, 0, 0.46)], [0.065, 0.075, 0.08], (70, 74, 82), "Metal", sides=10)
        rounded_box("Greave", (side * 0.12, -0.05, 0.26), (0.14, 0.08, 0.18), armour, "Metal", bevel=0.3)
    rounded_box("Hips", (0, 0, 0.5), (0.36, 0.2, 0.1), "TintDark", "Metal", bevel=0.3)
    rounded_box("Torso", (0, 0, 0.66), (0.42, 0.24, 0.26), armour, "Metal", bevel=0.25)
    rounded_box("Chest", (0, -0.11, 0.7), (0.22, 0.04, 0.12), (120, 220, 255), "Neon", bevel=0.4)
    for side in (-1, 1):
        ellipsoid("Pauldron", (side * 0.27, 0, 0.8), (0.12, 0.14, 0.09), armour, "Metal")
        tube("Arm", [(side * 0.27, 0, 0.74), (side * 0.3, -0.04, 0.6), (side * 0.3, -0.12, 0.5)], [0.055, 0.05, 0.05], (70, 74, 82), "Metal", sides=10)
        ellipsoid("Fist", (side * 0.3, -0.14, 0.47), (0.055,) * 3, "TintDark", "Metal")
    rounded_box("Head", (0, 0, 0.9), (0.18, 0.18, 0.16), armour, "Metal", bevel=0.3)
    rounded_box("Visor", (0, -0.09, 0.91), (0.14, 0.02, 0.035), (120, 220, 255), "Neon", bevel=0.4)
    cone("Crest", (0, 0.02, 0.98), (0, 0.08, 1.06), 0.04, "TintDark", "Metal")
    # A spear in the right hand, a shield on the left arm.
    tube("Spear", [(0.3, -0.14, 0.12), (0.3, -0.14, 1.05)], [0.018, 0.018], (90, 70, 50), "Wood", sides=6)
    cone("SpearTip", (0.3, -0.14, 1.05), (0.3, -0.14, 1.18), 0.04, (230, 230, 235), "Metal", sides=8)
    rounded_box("Shield", (-0.36, -0.12, 0.56), (0.04, 0.24, 0.32), armour, "Metal", bevel=0.4)
    ellipsoid("ShieldBoss", (-0.385, -0.12, 0.56), (0.02, 0.06, 0.06), (120, 220, 255), "Neon")


def golem():
    rock = "Tint"
    seeds = [(0, 0, 0.6, 0.3, 0.24, 0.26), (0.12, 0.05, 0.75, 0.2, 0.18, 0.16), (-0.12, -0.03, 0.72, 0.2, 0.18, 0.18), (0, 0.06, 0.45, 0.26, 0.2, 0.18)]
    for i, (x, y, z, rx, ry, rz) in enumerate(seeds):
        ellipsoid("Body", (x, y, z), (rx, ry, rz), rock, "SmoothPlastic", rotation=(0.2 * i, 0.3 * i, 0.1 * i), segments=10)
    ellipsoid("Head", (0, -0.06, 0.95), (0.13, 0.12, 0.11), rock, rotation=(0.3, 0.2, 0.5), segments=8)
    for side in (-1, 1):
        ellipsoid("Eye", (side * 0.05, -0.17, 0.97), (0.03, 0.015, 0.02), (255, 140, 60), "Neon")
        ellipsoid("Shoulder", (side * 0.3, 0, 0.78), (0.14, 0.13, 0.12), "TintDark", rotation=(0.4, 0.2, side * 0.3), segments=8)
        ellipsoid("Arm", (side * 0.36, -0.02, 0.56), (0.09, 0.09, 0.16), rock, rotation=(0.1, side * 0.15, 0), segments=8)
        ellipsoid("Fist", (side * 0.38, -0.06, 0.32), (0.15, 0.14, 0.13), "TintDark", rotation=(0.5, 0.3, 0.2), segments=8)
        ellipsoid("Leg", (side * 0.13, 0, 0.17), (0.12, 0.13, 0.17), "TintDark", rotation=(0.1, 0.4, 0), segments=8)
        ellipsoid("Moss", (side * 0.26, 0.04, 0.88), (0.08, 0.08, 0.03), (90, 130, 70), "Fabric")
    ellipsoid("Core", (0, -0.24, 0.62), (0.07, 0.04, 0.08), (255, 140, 60), "Neon")


def vacuum():
    shell = "Tint"
    cylinder("Shell", (0, 0, 0.28), 0.9, 0.36, shell, "Metal", sides=48, bevel=0.08)
    cylinder("Bumper", (0, 0, 0.18), 0.92, 0.16, (30, 30, 34), "Rubber", sides=48, bevel=0.04)
    cylinder("TopPlate", (0, 0, 0.47), 0.6, 0.03, (40, 44, 52), "Glass", sides=48)
    cylinder("TopLight", (0, 0.1, 0.5), 0.1, 0.05, (255, 60, 60), "Neon", sides=24)
    # Angry face on the front: visor eyes and a grille mouth.
    for side in (-1, 1):
        rounded_box("Eye", (side * 0.26, -0.82, 0.36), (0.3, 0.1, 0.1), (255, 60, 60), "Neon", bevel=0.4, rotation=(0, side * 0.25, side * 0.3))
        cylinder("Brush", (side * 0.6, -0.55, 0.04), 0.18, 0.02, (60, 60, 64), sides=12)
        for k in range(6):
            a = k / 6 * math.tau
            tube("Bristle", [(side * 0.6, -0.55, 0.03), (side * 0.6 + math.cos(a) * 0.32, -0.55 + math.sin(a) * 0.32, 0.01)], [0.02, 0.01], (200, 200, 205), sides=4)
    rounded_box("Intake", (0, -0.6, 0.06), (0.8, 0.2, 0.06), (20, 20, 22), bevel=0.4)
    for k in range(5):
        rounded_box("Grille", (-0.24 + k * 0.12, -0.9, 0.2), (0.06, 0.04, 0.04), (30, 30, 34), bevel=0.4)


def mech():
    armour = "Tint"
    for side in (-1, 1):
        rounded_box("Foot", (side * 0.2, -0.05, 0.04), (0.18, 0.32, 0.08), (60, 60, 70), "Metal", bevel=0.3)
        tube("Leg", [(side * 0.2, 0, 0.08), (side * 0.22, -0.08, 0.3), (side * 0.2, 0.02, 0.5)], [0.06, 0.07, 0.07], (60, 60, 70), "Metal", sides=10)
        rounded_box("Shin", (side * 0.22, -0.1, 0.28), (0.14, 0.08, 0.2), armour, "Metal", bevel=0.3)
        cylinder("Knee", (side * 0.22, -0.1, 0.38), 0.06, 0.12, (60, 60, 70), "Metal", rotation=(0, math.pi / 2, 0))
    rounded_box("Torso", (0, 0, 0.62), (0.52, 0.38, 0.26), armour, "Metal", bevel=0.2)
    rounded_box("Cockpit", (0, -0.2, 0.66), (0.24, 0.04, 0.12), (120, 200, 255), "Glass", bevel=0.4)
    ellipsoid("Core", (0, -0.19, 0.54), (0.06, 0.03, 0.06), (80, 200, 255), "Neon")
    for side in (-1, 1):
        rounded_box("Shoulder", (side * 0.33, 0, 0.74), (0.16, 0.24, 0.12), armour, "Metal", bevel=0.3)
        tube("Arm", [(side * 0.36, 0, 0.66), (side * 0.38, -0.06, 0.5), (side * 0.38, -0.2, 0.44)], [0.06, 0.055, 0.05], (60, 60, 70), "Metal", sides=10)
        cylinder("Cannon", (side * 0.38, -0.3, 0.44), 0.05, 0.22, (40, 40, 46), "Metal", rotation=(math.pi / 2, 0, 0), bevel=0.01)
        cylinder("Muzzle", (side * 0.38, -0.42, 0.44), 0.035, 0.02, (80, 200, 255), "Neon", rotation=(math.pi / 2, 0, 0))
        rounded_box("MissilePod", (side * 0.22, 0.12, 0.86), (0.16, 0.16, 0.12), (60, 60, 70), "Metal", bevel=0.2)
        for k in range(2):
            for j in range(2):
                cylinder("Missile", (side * 0.22 + (k - 0.5) * 0.06, 0.04, 0.84 + j * 0.05), 0.02, 0.02, (255, 90, 60), "Neon", rotation=(math.pi / 2, 0, 0))
    tube("Antenna", [(0.18, 0.1, 0.75), (0.2, 0.15, 1.0)], [0.012, 0.006], (60, 60, 70), "Metal", sides=5)


def colossus():
    """The final titan: stone body veined with violet crystal."""
    stone = (104, 98, 96)
    for side in (-1, 1):
        rounded_box("Foot", (side * 0.13, -0.04, 0.03), (0.13, 0.2, 0.06), stone, bevel=0.3)
        tube("Leg", [(side * 0.12, 0, 0.06), (side * 0.12, 0, 0.26), (side * 0.11, 0, 0.44)], [0.07, 0.075, 0.085], stone, sides=10)
        cone("Crystal", (side * 0.17, 0.02, 0.3), (side * 0.25, 0.04, 0.4), 0.04, "Tint", "Neon", sides=6)
    rounded_box("Waist", (0, 0, 0.47), (0.3, 0.18, 0.08), (90, 82, 100), bevel=0.3)
    ellipsoid("Torso", (0, 0, 0.64), (0.24, 0.15, 0.2), stone, segments=16)
    rounded_box("Belt", (0, 0, 0.5), (0.32, 0.2, 0.04), (230, 195, 120), "Metal", bevel=0.4)
    ellipsoid("Heart", (0, -0.14, 0.66), (0.06, 0.03, 0.07), "Tint", "Neon")
    for side in (-1, 1):
        ellipsoid("Shoulder", (side * 0.26, 0, 0.78), (0.1, 0.11, 0.09), stone)
        for k in range(3):
            cone("Crystal", (side * (0.26 + k * 0.03), 0.02 * k, 0.84), (side * (0.3 + k * 0.06), 0.03 * k - 0.02, 0.98 - k * 0.03), 0.04 - k * 0.008, "Tint", "Neon", sides=6)
        tube("Arm", [(side * 0.28, 0, 0.74), (side * 0.32, -0.02, 0.56), (side * 0.32, -0.06, 0.4)], [0.065, 0.06, 0.055], stone, sides=10)
        ellipsoid("Fist", (side * 0.32, -0.07, 0.36), (0.07, 0.07, 0.07), (90, 82, 100))
    ellipsoid("Head", (0, -0.02, 0.92), (0.1, 0.1, 0.11), stone)
    for side in (-1, 1):
        ellipsoid("Eye", (side * 0.04, -0.11, 0.93), (0.025, 0.01, 0.015), "Tint", "Neon")
    for k in range(5):
        a = math.radians(-60 + k * 30)
        cone("Crown", (math.sin(a) * 0.08, math.cos(a) * 0.02, 1.0), (math.sin(a) * 0.12, math.cos(a) * 0.03, 1.08 + (0.04 if k == 2 else 0)), 0.025, (230, 195, 120), "Metal", sides=6)
