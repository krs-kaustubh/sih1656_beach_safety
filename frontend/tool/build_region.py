# File: tool/build_region.py
# Description: Preprocessing script that parses Natural Earth GeoJSON vector boundaries and simplifies country polygon rings for map rendering.

# Regenerates assets/geo/region.json — country outlines, labels and cities.
# Run from the frontend/ directory:
#   curl -o /tmp/ind_pov.json https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_countries_ind.geojson
#   python3 tool/build_region.py /tmp/ind_pov.json assets/geo/region.json
# Note: Uses India point-of-view GeoJSON edition.

import json, math, sys

# Region shown on the map: India plus enough of its neighbours for context.

WEST, EAST, SOUTH, NORTH = 55.0, 105.0, -6.0, 44.0

def rdp(pts, eps):
    if len(pts) < 3:
        return pts[:]
    keep = [False]*len(pts); keep[0] = keep[-1] = True
    stack = [(0, len(pts)-1)]
    while stack:
        i, j = stack.pop()
        if j <= i+1: continue
        ax, ay = pts[i]; bx, by = pts[j]
        dx, dy = bx-ax, by-ay
        den = math.hypot(dx, dy)
        best, bi = -1.0, -1
        for k in range(i+1, j):
            px, py = pts[k]
            d = math.hypot(px-ax, py-ay) if den == 0 else abs(dy*px - dx*py + bx*ay - by*ax)/den
            if d > best: best, bi = d, k
        if best > eps:
            keep[bi] = True; stack.append((i, bi)); stack.append((bi, j))
    return [p for p, k in zip(pts, keep) if k]

def area(r):
    a = 0.0
    for i in range(len(r)-1):
        a += r[i][0]*r[i+1][1] - r[i+1][0]*r[i][1]
    return abs(a)/2

def intersects(ring):
    xs = [p[0] for p in ring]; ys = [p[1] for p in ring]
    return not (max(xs) < WEST or min(xs) > EAST or max(ys) < SOUTH or min(ys) > NORTH)

src = sys.argv[1]
dst = sys.argv[2]
d = json.load(open(src))

EPS, MIN_AREA = 0.012, 0.004
countries = []
for f in d['features']:
    p = f['properties']
    name = p.get('NAME') or p.get('ADMIN') or ''
    g = f['geometry']
    if not g: continue
    polys = g['coordinates'] if g['type'] == 'MultiPolygon' else [g['coordinates']]

    rings = []
    for poly in polys:
        outer = [tuple(c[:2]) for c in poly[0]]
        if not intersects(outer):
            continue
        if area(outer) < MIN_AREA:
            continue
        s = rdp(outer, EPS)
        if len(s) >= 4:
            rings.append([[round(x, 3), round(y, 3)] for x, y in s])

    if not rings:
        continue

    # Natural Earth ships a cartographer-placed label anchor, but for a country
    # only partly in frame (China, Iran) it sits far outside the map. Fall back
    # to the centroid of the vertices that ARE in frame, which puts the name
    # over the visible territory, then inset it so it cannot hug the edge.
    lx, ly = p.get('LABEL_X'), p.get('LABEL_Y')
    if lx is None or ly is None or not (WEST <= lx <= EAST and SOUTH <= ly <= NORTH):
        inside = [q for r in rings for q in r
                  if WEST <= q[0] <= EAST and SOUTH <= q[1] <= NORTH]
        if not inside:
            continue
        lx = sum(q[0] for q in inside)/len(inside)
        ly = sum(q[1] for q in inside)/len(inside)

    pad_x = (EAST - WEST) * 0.04
    pad_y = (NORTH - SOUTH) * 0.04
    lx = min(max(lx, WEST + pad_x), EAST - pad_x)
    ly = min(max(ly, SOUTH + pad_y), NORTH - pad_y)

    countries.append({
        "name": name,
        "iso": p.get('ISO_A3') or p.get('ADM0_A3') or '',
        "isIndia": name == 'India',
        "label": [round(lx, 3), round(ly, 3)],
        "rings": rings,
    })

countries.sort(key=lambda c: (not c['isIndia'], -sum(area(r) for r in c['rings'])))
doc = {
    "source": "Natural Earth 1:10m admin-0 countries, India point-of-view "
              "(ne_10m_admin_0_countries_ind). Public domain.",
    "region": [WEST, SOUTH, EAST, NORTH],
    "countries": countries,
}
json.dump(doc, open(dst, 'w'), separators=(',', ':'))
pts = sum(len(r) for c in countries for r in c['rings'])
print(f"countries: {len(countries)}  rings: {sum(len(c['rings']) for c in countries)}  points: {pts}")
print("names:", ', '.join(c['name'] for c in countries[:14]))
