"""World prop models, built in game studs at the exact layout of the block
version they dress (see the region file named in each docstring), so the
invisible collision blocks and the visible model line up.

Axes: Blender (x, y, z) = Roblox (x, z, y). The exported model is fitted to
the box passed to Kit.skin, so only its proportions matter."""

import math

from lib import cylinder, ellipsoid, loft, rounded_box, tube


def r2b(x, y, z):
    """Roblox position -> Blender position."""
    return (x, z, y)


def rbox(role, lo, hi, color, material="Fabric", bevel=0.2):
    """Rounded box from Roblox min/max corners."""
    centre = r2b(*((a + b) / 2 for a, b in zip(lo, hi)))
    size = r2b(*(b - a for a, b in zip(lo, hi)))
    return rounded_box(role, centre, size, color, material, bevel=bevel, segments=4)


def couch():
    """FloorWorld.couch: base x230..316 y8..20 z80..260, back x298..316 up to
    y52, arms (y20..32) at z80..94 and z246..260, three cushions, four legs."""
    fabric = (90, 110, 140)
    light = (108, 128, 158)
    rbox("Upholstery", (230, 8, 80), (316, 20, 260), fabric, bevel=0.3)
    rbox("Upholstery", (298, 20, 80), (316, 52, 260), fabric, bevel=0.35)
    for z0 in (80, 246):
        rbox("Upholstery", (230, 20, z0), (298, 32, z0 + 14), fabric, bevel=0.45)
        # Rolled arm top.
        cylinder("Upholstery", r2b(264, 31, z0 + 7), 7.4, 68, fabric, "Fabric", rotation=(0, math.pi / 2, 0), sides=24)
    # Back cushions: three puffy pillows leaning on the back.
    for i in range(3):
        z = 96 + i * 50 + 24
        rbox("Cushion", (288, 22, z - 23), (299, 48, z + 23), light, bevel=0.45)
        tube("Piping", [r2b(288.5, 48, z - 22), r2b(288.5, 48, z + 22)], [0.7, 0.7], (70, 88, 115), "Fabric", sides=6)
    # Seat cushions with piping along the front edge.
    for i in range(3):
        z0 = 96 + i * 50
        rbox("Cushion", (234, 20, z0), (294, 25, z0 + 48), light, bevel=0.45)
        tube("Piping", [r2b(234.6, 24.4, z0 + 2), r2b(234.6, 24.4, z0 + 46)], [0.7, 0.7], (70, 88, 115), "Fabric", sides=6)
        ellipsoid("Button", r2b(264, 25.1, z0 + 24), (1.2, 1.2, 0.4), (70, 88, 115))
    # A throw pillow tucked in the corner.
    ellipsoid("Pillow", r2b(280, 30, 104), (5, 7, 6), (235, 170, 80), "Fabric", rotation=(0.3, -0.5, 0.2))
    # Tapered wooden legs.
    for x, z in ((235, 85), (311, 85), (235, 255), (311, 255)):
        tube("Leg", [r2b(x, 0, z), r2b(x, 8.4, z)], [2.0, 3.0], (105, 70, 45), "Wood", sides=12)


def sneaker():
    """FloorWorld.shoe: x112..126 (toe at -X), z288..294, sole 0.8 tall;
    toe ramp up to 2.5, laces 2.5, tongue 3.6, collar 4.4."""
    white = (240, 240, 240)
    blue = (60, 110, 200)
    # Sole: a rounded slab with a darker tread band.
    rbox("Sole", (112, 0.25, 288), (126, 0.8, 294), white, "Rubber", bevel=0.45)
    rbox("Tread", (112.2, 0, 288.2), (125.8, 0.3, 293.8), (180, 180, 185), "Rubber", bevel=0.45)
    # Upper: one lofted body following the climb profile (toe low, collar
    # high), slightly narrower than the sole.
    sections = [
        (112.25, 1.05, 0.0),
        (112.6, 2.1, 0.75),
        (114.0, 2.65, 1.25),
        (116.0, 2.75, 1.65),
        (118.0, 2.75, 1.85),
        (120.5, 2.75, 2.0),
        (122.5, 2.7, 2.75),
        (124.5, 2.6, 3.35),
        (125.7, 2.3, 3.2),
        (125.95, 1.3, 2.6),
    ]
    loft("Upper", [(x, 291, 0.8, hw, max(h, 0.05)) for x, hw, h in sections], blue, "Fabric")
    # Toe cap and heel counter in white rubber/leather.
    ellipsoid("ToeCap", r2b(113.4, 1.05, 291), (1.3, 2.45, 0.42), white, "Leather")
    rbox("Heel", (124.6, 0.8, 288.6), (126, 3.4, 293.4), white, "Leather", bevel=0.45)
    # Tongue sticking up, padded collar, laces across the top.
    rbox("Tongue", (121, 2.2, 289.2), (123.2, 3.9, 292.8), (80, 130, 215), "Fabric", bevel=0.5)
    # The foot opening with a padded white rim.
    ellipsoid("Opening", r2b(124.4, 4.05, 291), (1.15, 1.7, 0.18), (40, 50, 80), "Fabric")
    ellipsoid("Collar", r2b(124.4, 3.98, 291), (1.45, 2.0, 0.2), white, "Fabric")
    for i in range(4):
        x = 117.6 + i * 1.0
        y = 2.65 + i * 0.12
        tube("Lace", [r2b(x, y, 289.4), r2b(x + 0.15, y + 0.12, 291), r2b(x, y, 292.6)], [0.14, 0.14, 0.14], white, "Fabric", sides=6)
    # Side swoosh.
    for side in (288.35, 293.65):
        tube("Swoosh", [r2b(116, 1.3, side), r2b(119.5, 1.15, side), r2b(123.5, 2.4, side)], [0.12, 0.22, 0.05], white, "Leather", sides=6)


def bed():
    """Bedroom.bed: head at -X. Frame x-280..-170 y10..16 z180..300, mattress
    to y27, quilt from x-250, pillows, headboard x-282..-278 up to y60."""
    wood = (160, 110, 70)
    dark = (105, 70, 45)
    for x, z in ((-275, 185), (-175, 185), (-275, 295), (-175, 295)):
        tube("Leg", [r2b(x, 0, z), r2b(x, 10.2, z)], [2.4, 3.0], dark, "Wood", sides=12)
    rbox("Frame", (-280, 10, 180), (-170, 16, 300), wood, "Wood", bevel=0.3)
    rbox("Mattress", (-278, 16, 182), (-172, 27, 298), (235, 235, 245), "Fabric", bevel=0.4)
    # Quilt: covers the top and drapes over the sides, folded back at the head.
    rbox("Quilt", (-250, 19, 181), (-171, 28.5, 299), (80, 120, 190), "Fabric", bevel=0.25)
    tube("QuiltFold", [r2b(-250, 28, 181.5), r2b(-250, 28, 298.5)], [1.6, 1.6], (110, 150, 215), "Fabric", sides=12)
    for z in (190, 220, 250, 280):
        tube("Stitch", [r2b(-248, 28.6, z), r2b(-173, 28.6, z)], [0.3, 0.3], (60, 95, 160), "Fabric", sides=5)
    for z0 in (195, 245):
        rbox("Pillow", (-276, 27, z0), (-254, 33, z0 + 40), (250, 250, 250), "Fabric", bevel=0.48)
    # Headboard: rounded top, inset panel, posts.
    rbox("Headboard", (-282, 10, 182), (-278, 56, 298), wood, "Wood", bevel=0.4)
    cylinder("Headboard", r2b(-280, 54, 240), 4, 116, wood, "Wood", rotation=(math.pi / 2, 0, 0), sides=20)
    rbox("Panel", (-278.3, 22, 192), (-277.9, 50, 288), dark, "Wood", bevel=0.3)
    for z in (182, 298):
        tube("Post", [r2b(-280, 0, z), r2b(-280, 58, z)], [2.2, 2.2], dark, "Wood", sides=12)
        ellipsoid("Finial", r2b(-280, 58.5, z), (2.2, 2.2, 1.5), dark, "Wood")


def dresser():
    """Bedroom.dresser: body x-270..-215 y0..47 z20..60; drawers pulled out
    as steps (tops at y6, 17, 28, 39), jewelry box on top."""
    wood = (160, 110, 70)
    light = (200, 160, 110)
    rbox("Body", (-270, 2, 20), (-215.5, 46, 60), wood, "Wood", bevel=0.05)
    rbox("Top", (-270, 45, 20), (-215, 47, 60), (140, 95, 60), "Wood", bevel=0.3)
    rbox("Plinth", (-269, 0, 21), (-216, 2.5, 59), (105, 70, 45), "Wood", bevel=0.3)
    for i in range(4):
        y = 4 + i * 11
        out = 4 + (3 - i) * 4
        # The pulled-out drawer: bottom at the step, low sides, front panel.
        rbox("Drawer", (-215, y, 22), (-215 + out, y + 2, 58), light, "Wood", bevel=0.2)
        rbox("Drawer", (-215, y + 2, 22), (-215 + out, y + 4.5, 23.2), light, "Wood", bevel=0.3)
        rbox("Drawer", (-215, y + 2, 56.8), (-215 + out, y + 4.5, 58), light, "Wood", bevel=0.3)
        rbox("DrawerFront", (-215 + out - 1.2, y, 21), (-215 + out, y + 9, 59), light, "Wood", bevel=0.3)
        for z in (32, 48):
            ellipsoid("Knob", r2b(-215 + out + 0.3, y + 5, z), (0.7, 1.1, 1.1), (220, 190, 90), "Metal")
    # Jewelry box with a gold clasp.
    rbox("JewelryBox", (-262, 47, 28), (-248, 53, 38), (120, 40, 80), "Fabric", bevel=0.3)
    rbox("JewelryLid", (-262.3, 52, 27.7), (-247.7, 54, 38.3), (140, 50, 95), "Fabric", bevel=0.4)
    ellipsoid("Clasp", r2b(-255, 52.5, 27.6), (1, 0.4, 0.8), (230, 195, 90), "Metal")


def toy_chest():
    """Bedroom.toyChest: open box x-110..-70 z270..310 (front wall lower),
    lid propped open at the front (40x2x40 at (-90,34,312), -70° about X)."""
    wood = (160, 110, 70)
    band = (60, 60, 66)
    rbox("Chest", (-110, 0, 270), (-70, 2, 310), wood, "Wood", bevel=0.2)
    rbox("Chest", (-110, 2, 270), (-108, 20, 310), wood, "Wood", bevel=0.25)
    rbox("Chest", (-72, 2, 270), (-70, 20, 310), wood, "Wood", bevel=0.25)
    rbox("Chest", (-110, 2, 270), (-70, 20, 272), wood, "Wood", bevel=0.25)
    rbox("Chest", (-110, 2, 308), (-70, 12, 310), wood, "Wood", bevel=0.25)
    # Painted stripes and metal corner straps.
    for y in (6, 15):
        rbox("Stripe", (-110.3, y, 270.5), (-109.7, y + 2, 309.5), (230, 80, 80), "SmoothPlastic", bevel=0.3)
        rbox("Stripe", (-70.3, y, 270.5), (-69.7, y + 2, 309.5), (230, 80, 80), "SmoothPlastic", bevel=0.3)
    for x, z in ((-110, 270), (-70, 270), (-110, 310), (-70, 310)):
        top = 12 if z == 310 else 20
        rbox("Strap", (x - 0.4, 0, z - 0.4), (x + 0.4, top, z + 0.4), band, "Metal", bevel=0.4)
    lid = rounded_box("Lid", (-90, 312, 34), (40, 40, 2), wood, "Wood", bevel=0.3, rotation=(math.radians(70), 0, 0))
    lid["role"] = "Lid"
    star = ellipsoid("Star", (-90, 311.3, 36), (5, 0.8, 5), (250, 210, 70), rotation=(math.radians(70), 0, 0))
    star["role"] = "Star"


def fridge():
    """Kitchen.fridge: body x275..311 y0..80 z-40..-4 (front faces -X), door
    split at y30, handle x273..274.5 y36..66 near z-10."""
    white = (235, 238, 240)
    grey = (150, 150, 155)
    rbox("Body", (275.2, 0, -40), (311, 80, -4), white, "Metal", bevel=0.08)
    rbox("Door", (274.6, 31.2, -39.6), (276, 79.4, -4.4), (245, 247, 250), "Metal", bevel=0.25)
    rbox("Door", (274.6, 1.4, -39.6), (276, 29.6, -4.4), (245, 247, 250), "Metal", bevel=0.25)
    rbox("Seal", (275, 0.5, -39.8), (275.6, 80, -4.2), grey, "Rubber", bevel=0.3)
    tube("Handle", [r2b(274.5, 36, -9), r2b(273.2, 37.5, -9), r2b(273.2, 64.5, -9), r2b(274.5, 66, -9)], [0.75] * 4, grey, "Metal", sides=10)
    tube("Handle", [r2b(274.5, 22, -9), r2b(273.2, 23.5, -9), r2b(273.2, 27.5, -9), r2b(274.5, 29, -9)], [0.75] * 4, grey, "Metal", sides=10)
    rbox("Kick", (275, 0, -39), (276.5, 1.2, -5), (60, 60, 66), "Metal", bevel=0.3)
    rbox("Display", (274.5, 50, -30), (274.9, 54, -24), (40, 60, 80), "Glass", bevel=0.3)


def tree():
    """Props.tree: a rounded broadleaf tree (fitted to each tree's box)."""
    bark = (100, 74, 52)
    leaf = (86, 150, 72)
    tube("Trunk", [(0, 0, 0), (0.1, 0, 2.2), (-0.05, 0.05, 4.2), (0, 0, 5.6)], [0.75, 0.5, 0.42, 0.3], bark, "Wood", sides=12)
    for a in (0, 2.1, 4.2):
        tube("Root", [(0, 0, 0.5), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.0)], [0.35, 0.12], bark, "Wood", sides=8)
    for a, z in ((0.6, 4.0), (2.9, 4.5), (4.8, 3.7)):
        tube("Branch", [(0, 0, z), (math.cos(a) * 1.8, math.sin(a) * 1.8, z + 1.3)], [0.22, 0.1], bark, "Wood", sides=8)
    clusters = [(0, 0, 7.0, 2.6), (1.7, 0.6, 6.2, 1.9), (-1.6, 0.8, 6.4, 1.9), (0.4, -1.7, 6.1, 1.8), (-0.6, 1.6, 7.4, 1.7), (0.9, 1.4, 7.8, 1.5), (-1.2, -1.0, 7.3, 1.6)]
    for i, (x, y, z, r) in enumerate(clusters):
        ellipsoid("Leaves" if i % 3 else "LeavesLight", (x, y, z), (r, r, r * 0.85), leaf if i % 3 else (120, 175, 90), "SmoothPlastic", segments=14)


def pine():
    """Props.pine: trunk plus drooping needle tiers (fitted to each pine)."""
    bark = (96, 66, 46)
    green = (52, 108, 70)
    tube("Trunk", [(0, 0, 0), (0, 0, 3.0)], [0.36, 0.26], bark, "Wood", sides=10)
    tiers = [(1.6, 2.6, 2.2), (3.2, 2.1, 2.0), (4.6, 1.6, 1.8), (5.9, 1.0, 1.5)]
    for i, (z, radius, height) in enumerate(tiers):
        tube(
            "Needles" if i % 2 == 0 else "NeedlesLight",
            [(0, 0, z - 0.25), (0, 0, z), (0, 0, z + height * 0.55), (0, 0, z + height)],
            [radius * 0.85, radius, radius * 0.45, 0.02],
            green if i % 2 == 0 else (66, 126, 80),
            "SmoothPlastic",
            sides=14,
        )
