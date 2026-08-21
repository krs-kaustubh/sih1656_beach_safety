"""Regenerates assets/geo/india.json from Natural Earth.

Run from the frontend/ directory:

    curl -o /tmp/ind_pov.json \
      https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_countries_ind.geojson
    python3 tool/build_india_outline.py /tmp/ind_pov.json assets/geo/india.json

The _ind suffix is the India point-of-view edition. The default Natural Earth
release draws Jammu & Kashmir on de-facto control lines rather than India's
official boundary, so it is the wrong file to use here.

Natural Earth is public domain.
"""
import sys
import json, math

def rdp(pts, eps):
    """Ramer-Douglas-Peucker, iterative to avoid recursion limits."""
    if len(pts) < 3:
        return pts[:]
    keep = [False]*len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts)-1)]
    while stack:
        i, j = stack.pop()
        if j <= i+1:
            continue
        ax, ay = pts[i]; bx, by = pts[j]
        dx, dy = bx-ax, by-ay
        denom = math.hypot(dx, dy)
        best, bi = -1.0, -1
        for k in range(i+1, j):
            px, py = pts[k]
            if denom == 0:
                d = math.hypot(px-ax, py-ay)
            else:
                d = abs(dy*px - dx*py + bx*ay - by*ax)/denom
            if d > best:
                best, bi = d, k
        if best > eps:
            keep[bi] = True
            stack.append((i, bi)); stack.append((bi, j))
    return [p for p, k in zip(pts, keep) if k]

def ring_area(r):
    a = 0.0
    for i in range(len(r)-1):
        a += r[i][0]*r[i+1][1] - r[i+1][0]*r[i][1]
    return abs(a)/2

src = sys.argv[1] if len(sys.argv) > 1 else 'ind_pov.json'
dst = sys.argv[2] if len(sys.argv) > 2 else 'india.json'
d = json.load(open(src))
india = next(f for f in d['features'] if f['properties'].get('NAME') == 'India')
g = india['geometry']
polys = g['coordinates'] if g['type'] == 'MultiPolygon' else [g['coordinates']]

EPS = 0.008          # ~0.9 km
MIN_AREA = 0.0008    # drop specks too small to see at any usable zoom

out, dropped = [], 0
for poly in polys:
    outer = poly[0]
    if ring_area(outer) < MIN_AREA:
        dropped += 1
        continue
    simplified = rdp([tuple(c[:2]) for c in outer], EPS)
    if len(simplified) >= 4:
        out.append([[round(x, 4), round(y, 4)] for x, y in simplified])

out.sort(key=ring_area, reverse=True)
total = sum(len(r) for r in out)
xs = [c[0] for r in out for c in r]
ys = [c[1] for r in out for c in r]

doc = {
    "source": "Natural Earth 1:10m admin-0 countries, India point-of-view "
              "(ne_10m_admin_0_countries_ind). Public domain.",
    "bbox": [round(min(xs),4), round(min(ys),4), round(max(xs),4), round(max(ys),4)],
    "rings": out,
}
json.dump(doc, open(dst,'w'), separators=(',',':'))
print(f"rings kept: {len(out)}  dropped specks: {dropped}  points: {total}")
print("bbox:", doc['bbox'])
