import math, random
random.seed(7)

def lerp(a, b, t): return a + (b - a) * t


ALLPTS = []

def feather(gid, base, angle, length, width, curve, colors, notches):
    ang = math.radians(angle)
    dx, dy = math.sin(ang), -math.cos(ang)
    px, py = -dy, dx
    n = 140
    center, left, right = [], [], []
    phase = random.random()
    teeth = random.uniform(20, 26)
    for i in range(n + 1):
        t = i / n
        cx = base[0] + dx * t * length + px * curve * length * t * t
        cy = base[1] + dy * t * length + py * curve * length * t * t
        tx = dx + px * curve * 2 * t
        ty = dy + py * curve * 2 * t
        tl = math.hypot(tx, ty); tx /= tl; ty /= tl
        nx, ny = -ty, tx
        sv = t ** 0.7
        w = width * math.sqrt(max(0.0, math.sin(math.pi * sv)))
        w *= 0.35 + 0.65 * min(1, t / 0.25)
        center.append((cx, cy, nx, ny, w, tx, ty))
        for side, arr in ((-1, left), (1, right)):
            saw = ((t * teeth + phase + (0.5 if side > 0 else 0)) % 1.0)
            f = 1 - 0.22 * (1 - saw) ** 2.5
            for (nt, ns, depth) in notches:
                dd = abs(t - nt)
                if ns == side and dd < 0.04:
                    f *= 1 - depth * (1 - dd / 0.04)
            ww = w * f
            fwd = ww * 0.3
            ex = cx + side * nx * ww + tx * fwd
            ey = cy + side * ny * ww + ty * fwd
            arr.append((ex, ey))
    pts = left + right[::-1]
    ALLPTS.extend(pts)
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"
    tip = center[-1]
    out = [f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" '
           f'x1="{base[0]:.1f}" y1="{base[1]:.1f}" x2="{tip[0]:.1f}" y2="{tip[1]:.1f}">'
           f'<stop offset="0" stop-color="{colors[0]}"/>'
           f'<stop offset="0.5" stop-color="{colors[1]}"/>'
           f'<stop offset="1" stop-color="{colors[2]}"/></linearGradient>']
    out.append(f'<path d="{d}" fill="url(#{gid})" stroke="{colors[3]}" stroke-opacity="0.18" '
               f'stroke-width="1.5" stroke-linejoin="round"/>')
    barbs = []
    for i in range(6, n - 4, 3):
        cx, cy, nx, ny, w, tx, ty = center[i]
        for side in (-1, 1):
            ex, ey = (left if side < 0 else right)[min(n, i + 4)]
            mx = lerp(cx, ex, 0.5) - tx * w * 0.08
            my = lerp(cy, ey, 0.5) - ty * w * 0.08
            barbs.append(f"M{cx:.1f},{cy:.1f} Q{mx:.1f},{my:.1f} {lerp(cx, ex, .9):.1f},{lerp(cy, ey, .9):.1f}")
    out.append(f'<path d="{" ".join(barbs)}" fill="none" stroke="{colors[3]}" '
               f'stroke-opacity="0.13" stroke-width="1.4" stroke-linecap="round"/>')
    m = int(n * 0.9)
    shaft = "M" + " L".join(f"{c[0]:.1f},{c[1]:.1f}" for c in center[:m])
    out.append(f'<path d="{shaft}" fill="none" stroke="{colors[4]}" stroke-width="3.5" '
               f'stroke-linecap="round" stroke-opacity="0.55"/>')
    return "\n".join(out)

layers = [
    # (angles, length range, width, palette: base, mid, tip, barb, shaft)
    (list(range(-72, 73, 12)), (320, 360), 92,
     ("#5a3a22", "#7a5034", "#9b6a45", "#2e1b0e", "#d9c2a0")),
    (list(range(-60, 61, 12)), (370, 405), 98,
     ("#8a5a34", "#b07a4a", "#d1a06c", "#4a2c16", "#f0dfc4")),
    ([a + 6 for a in range(-48, 43, 12)], (395, 425), 100,
     ("#b98b5a", "#dcb98a", "#f1dcb8", "#7a5432", "#fff6e6")),
    (list(range(-30, 31, 15)), (405, 435), 96,
     ("#e1c49a", "#f6e6c8", "#fffaf0", "#a07a52", "#ffffff")),
]

parts = []
gi = 0
for li, (angles, lr, width, pal) in enumerate(layers):
    order = sorted(angles, key=lambda a: abs(a), reverse=True)
    for a in order:
        a2 = a + random.uniform(-3, 3)
        length = random.uniform(*lr) * (1 - abs(a) / 420)
        curve = a / 520 + random.uniform(-0.02, 0.02)
        notches = [(random.uniform(0.35, 0.85), random.choice((-1, 1)), random.uniform(.4, .8))
                   for _ in range(random.randint(1, 3))]
        bx = math.sin(math.radians(a)) * 14
        parts.append(feather(f"g{gi}", (bx, 10), a2, length, width * random.uniform(.9, 1.1),
                             curve, pal, notches))
        gi += 1

plume = "\n".join(parts)

handle = '''
<defs>
 <linearGradient id="wood" x1="-30" y1="0" x2="30" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#5b2f14"/><stop offset="0.35" stop-color="#a65e2c"/>
  <stop offset="0.55" stop-color="#c47a3e"/><stop offset="1" stop-color="#5b2f14"/>
 </linearGradient>
 <linearGradient id="brass" x1="-48" y1="0" x2="48" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#6e4a12"/><stop offset="0.3" stop-color="#e9c46a"/>
  <stop offset="0.45" stop-color="#fff1b8"/><stop offset="0.7" stop-color="#c9962e"/>
  <stop offset="1" stop-color="#5e3d0c"/>
 </linearGradient>
</defs>
<path d="M-28,40 L-23,384 Q-23,414 0,416 Q23,414 23,384 L28,40 Z" fill="url(#wood)"/>
<path d="M-6,60 Q-3,200 -8,380" stroke="#3d1e0b" stroke-opacity="0.35" stroke-width="2.5" fill="none"/>
<path d="M9,70 Q6,220 10,370" stroke="#3d1e0b" stroke-opacity="0.25" stroke-width="2" fill="none"/>
<path d="M-11,50 L-8,385" stroke="#ffd9a8" stroke-opacity="0.35" stroke-width="5" stroke-linecap="round"/>
<circle cx="0" cy="378" r="7.5" fill="#2a1408" fill-opacity="0.75"/>
<path d="M-46,-6 Q0,-18 46,-6 L40,62 Q0,72 -40,62 Z" fill="url(#brass)"/>
<path d="M-44,14 Q0,4 44,14" stroke="#5e3d0c" stroke-opacity="0.55" stroke-width="3" fill="none"/>
<path d="M-42,40 Q0,32 42,40" stroke="#5e3d0c" stroke-opacity="0.55" stroke-width="3" fill="none"/>
<path d="M-44,17 Q0,7 44,17" stroke="#fff6d0" stroke-opacity="0.5" stroke-width="1.5" fill="none"/>
<path d="M-42,43 Q0,35 42,43" stroke="#fff6d0" stroke-opacity="0.5" stroke-width="1.5" fill="none"/>
'''


ROT = 38
ALLPTS.extend([(-28, 40), (28, 40), (-23, 416), (23, 416), (-46, -10), (46, -10)])
cr, sr = math.cos(math.radians(ROT)), math.sin(math.radians(ROT))
rp = [(x * cr - y * sr, x * sr + y * cr) for x, y in ALLPTS]
xs, ys = [p[0] for p in rp], [p[1] for p in rp]
bw, bh = max(xs) - min(xs), max(ys) - min(ys)
SC = 860 / max(bw, bh)
TX = 512 - SC * (max(xs) + min(xs)) / 2
TY = 500 - SC * (max(ys) + min(ys)) / 2
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
 <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
  <feGaussianBlur in="SourceAlpha" stdDeviation="12"/>
  <feOffset dx="0" dy="14" result="b"/>
  <feComponentTransfer><feFuncA type="linear" slope="0.35"/></feComponentTransfer>
  <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
 </filter>
</defs>
<g filter="url(#shadow)">
<g transform="translate({TX:.1f},{TY:.1f}) scale({SC:.4f}) rotate({ROT})">
{handle}
<g>{plume}</g>
</g>
</g>
</svg>'''
open("duster.svg", "w").write(svg)
