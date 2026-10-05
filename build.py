#!/usr/bin/env python3
# HyperLED plugin "Klipper Status Display": builds klipper-status.json.
#
# Copyright (c) 2026 Dennis Guse
# Licensed under the EUPL, Version 1.2 (see the LICENSE file of this repository).
"""A plugin file is plain JSON, and JSON has no multi-line strings, so the Lua script cannot be written
in it comfortably. The script lives in src/klipper-status.lua and the rest of the plugin in
src/klipper-status.template.json; this puts the script into the template's "script" field and writes
the finished plugin file klipper-status.json next to this script. Run it after every change:

    python build.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MAX_SCRIPT = 8 * 1024   # the limit of the plugin format
MAX_FILE = 16 * 1024


def compact_lua(text, keep=4):
    """The shipped script without its comments and indentation, to fit the 16 KB of a plugin file.
    Every line stays a line (comment lines become empty ones), so the line numbers in an error message
    are those of src/klipper-status.lua. The first `keep` lines (the licence) stay as they are. This
    script has no string that contains '--' or spans lines, which is all this has to understand."""
    out = []
    for number, line in enumerate(text.split("\n")):
        if number < keep:
            out.append(line)
            continue
        quote = None
        cut = len(line)
        for i, c in enumerate(line):
            if quote:
                if c == quote:
                    quote = None
            elif c in "'\"":
                quote = c
            elif c == "-" and line[i:i + 2] == "--":
                cut = i
                break
        out.append(line[:cut].strip())
    return "\n".join(out)


def main():
    with open(os.path.join(HERE, "src", "klipper-status.template.json"), encoding="utf-8") as f:
        plugin = json.load(f)
    with open(os.path.join(HERE, "src", "klipper-status.lua"), encoding="utf-8", newline="") as f:
        script = compact_lua(f.read().replace("\r\n", "\n"))
    if len(script.encode("utf-8")) > MAX_SCRIPT:
        sys.exit("The script is longer than 8 KB")
    plugin["script"] = script
    # Compact: the plugin file may be at most 16 KB, and the script and the texts in three languages
    # make this one big. The readable form is the template.
    text = json.dumps(plugin, ensure_ascii=False, separators=(",", ":")) + "\n"
    if len(text.encode("utf-8")) > MAX_FILE:
        sys.exit("The plugin file is longer than 16 KB")
    out = os.path.join(HERE, "klipper-status.json")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("%s: %d bytes, script %d bytes" % (out, len(text.encode("utf-8")), len(script.encode("utf-8"))))


if __name__ == "__main__":
    main()
