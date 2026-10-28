#!/usr/bin/env python3
"""Draw the app icon: a desktop monitor whose screen shows a jump to
hyperspace, in front of a night sky with fixed stars.

Writes Design/AppIcon.svg, the whole drawing clipped to the icon's rounded
rectangle for preview, and the layers that Resources/AppIcon.icon (Icon
Composer) uses, in Resources/AppIcon.icon/Assets:

    1-screen.svg    the screen's glow and streaks
    2-monitor.svg   bezel and stand
    3-stars.svg     the fixed stars

The sky is the icon's fill, set in icon.json. The drawing uses the old icon
grid (the rounded rectangle spans 100-924); the layers scale it to the full
1024 x 1024 canvas, which Icon Composer masks. The random numbers come from
fixed seeds, so every run draws the same icon. Run from the repository root:
Design/make-icon.py
"""
import math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "Resources", "AppIcon.icon", "Assets")
CX, CY = 512, 430  # the vanishing point: the screen's centre
DY = 40            # moves the monitor down to the middle of the icon
SCALE = 1024 / 824 # from the old grid's rounded rectangle to the full canvas

DEFS = f'''<defs>
 <clipPath id="screen"><rect x="236" y="254" width="552" height="352" rx="18"/></clipPath>
 <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#151a46"/><stop offset="1" stop-color="#060818"/></linearGradient>
 <radialGradient id="halo"><stop offset="0" stop-color="#cfe0ff" stop-opacity=".7"/><stop offset="1" stop-color="#cfe0ff" stop-opacity="0"/></radialGradient>
 <radialGradient id="glow" cx="{CX}" cy="{CY}" r="300" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#ffffff"/><stop offset=".12" stop-color="#bcd7ff"/><stop offset=".45" stop-color="#3550c8"/><stop offset="1" stop-color="#0d1240"/></radialGradient>
 <linearGradient id="metal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f2f4f8"/><stop offset="1" stop-color="#a9b0bd"/></linearGradient>
</defs>'''

def streaks(n=44):
    stars()  # the streaks continue the random sequence after the stars, as in the first draft
    out = []
    for i in range(n):
        a = 2*math.pi*i/n + random.uniform(-0.04, 0.04)
        r0 = random.uniform(30, 60); r1 = random.uniform(300, 340)
        w = random.uniform(4, 8)
        c = random.choice(["#cfe3ff", "#9fc4ff", "#ffffff", "#b9a8ff"])
        out.append(f'<line x1="{CX+r0*math.cos(a):.0f}" y1="{CY+r0*math.sin(a):.0f}" x2="{CX+r1*math.cos(a):.0f}" '
                   f'y2="{CY+r1*math.sin(a):.0f}" stroke="{c}" stroke-width="{w:.1f}" stroke-linecap="round" '
                   f'opacity="{random.uniform(.6,.95):.2f}" clip-path="url(#screen)"/>')
    return "\n".join(out)

def behind_monitor(x, y, m=24):
    return (216-m < x < 808+m and 234+DY-m < y < 626+DY+m) or (370 < x < 654 and 600+DY < y < 740+DY)

def stars():
    random.seed(3)
    out = []
    while len(out) < 70:
        x, y = random.uniform(100, 924), random.uniform(100, 924)
        if not (130 < x < 894 and 130 < y < 894) or behind_monitor(x, y): continue
        r = random.choice([2, 2, 2.5, 3, 3, 4, 5])
        opacity = random.uniform(.35, .9)
        # The larger stars are about one pixel at 128 px, so they still show there.
        if r >= 4: r, opacity = {4: 6, 5: 7.5}[r], max(opacity, .85)
        out.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="#ffffff" opacity="{opacity:.2f}"/>')
    # three bright stars with a four-pointed sparkle, placed so that they do not
    # line up with the screen's corners (at small sizes only these show)
    for x, y, s in [(700, 168, 20), (160, 480, 15), (330, 852, 18)]:
        out.append(f'<circle cx="{x}" cy="{y}" r="{s*0.9}" fill="url(#halo)"/>')
        out.append(f'<path d="M{x} {y-s} Q{x} {y} {x+s} {y} Q{x} {y} {x} {y+s} Q{x} {y} {x-s} {y} Q{x} {y} {x} {y-s} Z" fill="#ffffff"/>')
    return "\n".join(out)

def monitor():
    return f'''<g transform="translate(0 {DY})">
<path d="M462 620 L562 620 L578 712 L446 712 Z" fill="url(#metal)"/>
<rect x="380" y="708" width="264" height="22" rx="11" fill="#c3c9d4"/>
<rect x="216" y="234" width="592" height="392" rx="34" fill="url(#metal)"/>
</g>'''

def screen():
    return f'''<g transform="translate(0 {DY})">
<rect x="236" y="254" width="552" height="352" rx="18" fill="url(#glow)"/>
{streaks()}
</g>'''

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">\n{DEFS}\n{body}\n</svg>\n'

def write(path, text):
    with open(path, "w") as f:
        f.write(text)
    print(os.path.relpath(path, os.path.join(HERE, "..")))

write(os.path.join(HERE, "AppIcon.svg"), svg(
    '<rect x="100" y="100" width="824" height="824" rx="185" fill="url(#sky)"/>\n'
    + stars() + "\n" + monitor() + "\n" + screen()))

full = f'matrix({SCALE:.6f} 0 0 {SCALE:.6f} {512 - 512*SCALE:.4f} {512 - 512*SCALE:.4f})'
os.makedirs(ASSETS, exist_ok=True)
for name, body in [("1-screen.svg", screen()), ("2-monitor.svg", monitor()), ("3-stars.svg", stars())]:
    write(os.path.join(ASSETS, name), svg(f'<g transform="{full}">\n{body}\n</g>'))
