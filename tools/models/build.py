"""Build models: .tools/blender-venv/bin/python tools/models/build.py [names...]

Writes build/models/<Name>.fbx, <Name>.json (manifest) and <Name>.png
(preview). With no names, builds everything in MODELS."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import creatures  # noqa: E402
from lib import export, reset  # noqa: E402

# Name -> (builder, preview tint). Creature names match CreatureBuilder shapes;
# the tint previews the colour of one enemy that uses the shape.
MODELS = {
    "Mite": (creatures.mite, (210, 200, 190)),
    "Insect": (creatures.insect, (110, 45, 30)),
    "Beetle": (creatures.beetle, (60, 130, 90)),
    "Moth": (creatures.moth, (190, 170, 140)),
    "Spider": (creatures.spider, (70, 55, 50)),
    "Toy": (creatures.toy, (200, 40, 40)),
    "Fly": (creatures.fly, (50, 50, 62)),
    "Roach": (creatures.roach, (110, 60, 30)),
    "Robot": (creatures.robot, (150, 160, 180)),
    "Wasp": (creatures.wasp, (250, 196, 40)),
    "Frog": (creatures.frog, (90, 150, 60)),
    "Crow": (creatures.crow, (40, 40, 48)),
    "Car": (creatures.car, (220, 60, 60)),
    "Drone": (creatures.drone, (120, 130, 140)),
    "Sentinel": (creatures.sentinel, (80, 170, 255)),
    "Golem": (creatures.golem, (130, 120, 108)),
    "Vacuum": (creatures.vacuum, (70, 70, 82)),
    "Mower": (creatures.mower, (210, 50, 40)),
    "Mech": (creatures.mech, (80, 160, 255)),
    "Colossus": (creatures.colossus, (170, 120, 255)),
}

names = [a for a in sys.argv[1:] if not a.startswith("-")] or list(MODELS)
for name in names:
    build, tint = MODELS[name]
    reset(tint)
    build()
    export(name, preview="--no-preview" not in sys.argv)
