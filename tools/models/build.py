"""Build models: .tools/blender-venv/bin/python tools/models/build.py [names...]

Writes build/models/<Name>.fbx, <Name>.json (manifest) and <Name>.png
(preview). With no names, builds everything in MODELS."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import props  # noqa: E402
import realistic  # noqa: E402
from lib import export, reset  # noqa: E402

# Name -> (builder, preview tint). Creature names match CreatureBuilder shapes;
# the tint previews the colour of one enemy that uses the shape.
MODELS = {
    "Mite": (realistic.mite, (210, 200, 190)),
    "Insect": (realistic.ant, (110, 45, 30)),
    "Beetle": (realistic.beetle, (60, 130, 90)),
    "Moth": (realistic.moth, (190, 170, 140)),
    "Spider": (realistic.spider, (70, 55, 50)),
    "Toy": (realistic.toy, (200, 40, 40)),
    "Fly": (realistic.fly, (50, 50, 62)),
    "Roach": (realistic.roach, (110, 60, 30)),
    "Robot": (realistic.robot, (150, 160, 180)),
    "Wasp": (realistic.wasp, (250, 196, 40)),
    "Frog": (realistic.frog, (90, 150, 60)),
    "Crow": (realistic.crow, (40, 40, 48)),
    "Car": (realistic.car, (220, 60, 60)),
    "Drone": (realistic.drone, (120, 130, 140)),
    "Sentinel": (realistic.sentinel, (80, 170, 255)),
    "Golem": (realistic.golem, (130, 120, 108)),
    "Vacuum": (realistic.vacuum, (70, 70, 82)),
    "Mower": (realistic.mower, (210, 50, 40)),
    "Mech": (realistic.mech, (80, 160, 255)),
    "Colossus": (realistic.colossus, (170, 120, 255)),
    # World props (dress the block versions via Kit.skin).
    "Couch": (props.couch, (90, 110, 140)),
    "Sneaker": (props.sneaker, (60, 110, 200)),
    "Bed": (props.bed, (80, 120, 190)),
    "Dresser": (props.dresser, (160, 110, 70)),
    "ToyChest": (props.toy_chest, (160, 110, 70)),
    "Fridge": (props.fridge, (235, 238, 240)),
    "Tree": (props.tree, (86, 150, 72)),
    "Pine": (props.pine, (52, 108, 70)),
}

names = [a for a in sys.argv[1:] if not a.startswith("-")] or list(MODELS)
for name in names:
    build, tint = MODELS[name]
    reset(tint)
    build()
    export(name, preview="--no-preview" not in sys.argv)
