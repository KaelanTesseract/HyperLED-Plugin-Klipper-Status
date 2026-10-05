#!/usr/bin/env python3
# HyperLED plugin "Klipper-Statusanzeige": draws pictures of what the script shows.
#
# Copyright (c) 2026 Dennis Guse
# Licensed under the EUPL, Version 1.2 (see the LICENSE file of this repository).
"""Runs the plugin's Lua script (src/klipper-status.lua) on a simulated strip for a set of printer states and
draws the LEDs it would light into docs/images/states.png and docs/images/directions.png. The pictures
are therefore the script's own output, not hand-made drawings. Needs Pillow and lupa:

    pip install pillow lupa
    python tools/render_states.py
"""
import os

from lupa import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LEDS = 48

DEFAULTS = {
    "direction": "ltr", "heat_margin": 10, "brightness": 100, "head_pulse": False,
    "c_idle": 0x001A33, "c_heat": 0xFF7A00, "c_print": 0x00D060, "c_pause": 0xFFC800,
    "c_done": 0x00C8FF, "c_error": 0xFF0000, "show_done": True, "offline_color": 0x000000,
    "_layout": "grid", "_leds": LEDS, "_first": 0,
}


def run(values, settings=None, t=0):
    """The pixels (r, g, b) of a strip of LEDS LEDs after the script has seen `values`."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    pixels = [(0, 0, 0)] * LEDS

    def clamp(x):
        return max(0, min(255, int(x)))

    def px(x, y, r, g, b):
        x = int(x)
        if 0 <= x < LEDS and int(y) == 0:
            pixels[x] = (clamp(r), clamp(g), clamp(b))

    def fill(r, g, b):
        for i in range(LEDS):
            pixels[i] = (clamp(r), clamp(g), clamp(b))

    def clear():
        fill(0, 0, 0)

    g = lua.globals()
    g.W, g.H, g.N = LEDS, 1, LEDS
    g.px, g.fill, g.clear = px, fill, clear
    g.log = lambda text: None
    s = dict(DEFAULTS)
    s.update(settings or {})
    g.settings = lua.table_from(s)
    g.v = lua.table_from(values)
    with open(os.path.join(ROOT, "src", "klipper-status.lua"), encoding="utf-8") as f:
        lua.execute(f.read())
    g.update()
    g.frame(t)
    return list(pixels)


COLD = {"e0": 32, "e1": 32, "e2": 33, "e3": 33, "bed": 35, "g0": -32, "g1": -32, "g2": -33, "g3": -33, "bed_gap": -35}


def printing(progress, **extra):
    v = dict(COLD, state="printing", duration=900, progress=progress, idle="Printing",
             e1=210, g1=0, bed=65, bed_gap=0)
    v.update(extra)
    return v


STATES = [
    ("Idle", "printer is standing by", dict(COLD, state="standby", idle="Idle"), 0),
    ("Preheating", "nozzle 110/210 °C, bed 40/60 °C",
     dict(COLD, state="standby", idle="Idle", e1=110, g1=100, bed=40, bed_gap=20), 1000),
    ("Printing 25 %", "", printing(25), 0),
    ("Printing 50 %", "", printing(50), 0),
    ("Printing 75 %", "", printing(75), 0),
    ("Printing 100 %", "", printing(100), 0),
    ("Paused", "breathes", printing(50, state="paused"), 1000),
    ("Finished", "until the printer goes idle", printing(100, state="complete", idle="Ready"), 0),
    ("Error", "flashes", printing(50, state="error"), 0),
]

DIRECTIONS = [
    ("Left to right", "ltr"),
    ("Right to left", "rtl"),
    ("From both ends to the middle", "both"),
    ("From the middle outwards", "center"),
]

BG = (21, 23, 28)
OFF = (42, 46, 54)
TEXT = (230, 233, 238)
MUTED = (150, 156, 166)


def font(size, bold=False):
    for name in ("segoeuib.ttf" if bold else "segoeui.ttf", "arialbd.ttf" if bold else "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_strip(d, x0, y0, pixels, size=15, gap=3):
    for i, (r, g, b) in enumerate(pixels):
        x = x0 + i * (size + gap)
        lit = r or g or b
        d.rounded_rectangle([x, y0, x + size, y0 + size + 6], radius=3, fill=(r, g, b) if lit else OFF)


def board(rows, path, label_w=250, title=None):
    row_h = 54
    width = label_w + LEDS * 18 + 30
    top = 56 if title else 16
    img = Image.new("RGB", (width, top + len(rows) * row_h + 14), BG)
    d = ImageDraw.Draw(img)
    if title:
        d.text((16, 14), title, fill=TEXT, font=font(20, True))
    for n, (name, note, pixels) in enumerate(rows):
        y = top + n * row_h
        d.text((16, y + 2), name, fill=TEXT, font=font(16, True))
        if note:
            d.text((16, y + 24), note, fill=MUTED, font=font(11))
        draw_strip(d, label_w, y + 6, pixels)
    img.save(path)
    print("wrote", path)


def main():
    out = os.path.join(ROOT, "docs", "images")
    os.makedirs(out, exist_ok=True)
    rows = []
    for name, note, values, t in STATES:
        rows.append((name, note if len(note) < 38 else note[:36] + "…", run(values, t=t)))
    # a too long note would run into the strip: keep them short, explain in the README instead
    board(rows, os.path.join(out, "states.png"), title="What the status display shows (48 LEDs, default colours)")
    rows = [(name, "", run(printing(50), {"direction": d})) for name, d in DIRECTIONS]
    board(rows, os.path.join(out, "directions.png"), title="Direction of the bar (print at 50 %)")


if __name__ == "__main__":
    main()
