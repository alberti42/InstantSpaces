#!/usr/bin/env python3
"""
mark_informational_for_old_builds.py  APPCAST_PATH  RELEASE_URL

Marks the FIRST <item> in APPCAST_PATH (the newest release) as an
informational update for builds below FIRST_SPACEJUMPER_BUILD, and gives it a
<link> to RELEASE_URL.

Builds 2 and 3 are InstantSpaces 0.1.0 and 0.1.1, with the bundle identifier
io.alberti42.InstantSpaces. Sparkle refuses to install an update with another
bundle identifier ("Failed to match host bundle identifiers"), so those
installs are shown the update with a link to its release page instead of an
install button. SpaceJumper builds update as usual.
"""

import re
import sys

FIRST_SPACEJUMPER_BUILD = 4

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} APPCAST_PATH RELEASE_URL", file=sys.stderr)
    sys.exit(1)

appcast_path, release_url = sys.argv[1], sys.argv[2]

with open(appcast_path, encoding="utf-8") as f:
    content = f.read()

item_re = re.compile(r"<item>.*?</item>", re.DOTALL)
first = item_re.search(content)
if not first:
    print("ERROR: no <item> found in appcast", file=sys.stderr)
    sys.exit(1)

item = first.group(0)
if "<sparkle:informationalUpdate>" not in item:
    marker = (f"<link>{release_url}</link>\n"
              f"            <sparkle:informationalUpdate>\n"
              f"                <sparkle:belowVersion>{FIRST_SPACEJUMPER_BUILD}</sparkle:belowVersion>\n"
              f"            </sparkle:informationalUpdate>\n"
              f"            ")
    item = item.replace("<enclosure ", marker + "<enclosure ", 1)
    content = content[:first.start()] + item + content[first.end():]

with open(appcast_path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Marked the newest item informational below build {FIRST_SPACEJUMPER_BUILD}.")
