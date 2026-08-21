"""Builds the Maps tab terrain texture from Natural Earth's hypsometric raster.

Crops the India region, reprojects it from equirectangular to Web Mercator so
it lines up with the app's MapProjection, and darkens it for the app's
dark-terrain look. Only land is kept — the app paints its own ocean and clips
this texture to the vector coastline, which keeps coastlines crisp at any zoom.
"""
import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None

SRC = 'hyp/HYP_50M_SR_W.tif'
DST = 'terrain.jpg'

# Must match region.json's region and the Dart TerrainTexture bounds.
WEST, EAST, SOUTH, NORTH = 55.0, 105.0, -6.0, 44.0
OUT_W = 2200


def merc_y(lat):
    return np.degrees(np.log(np.tan(np.pi / 4 + np.radians(lat) / 2)))


def inv_merc_y(y):
    return np.degrees(2 * np.arctan(np.exp(np.radians(y))) - np.pi / 2)


img = Image.open(SRC)
sw, sh = img.size
print(f'source {sw}x{sh}')

# Pixel bounds of the crop in the global equirectangular grid.
px_per_deg_x = sw / 360.0
px_per_deg_y = sh / 180.0
left = int((WEST + 180) * px_per_deg_x)
right = int((EAST + 180) * px_per_deg_x)
top = int((90 - NORTH) * px_per_deg_y)
bottom = int((90 - SOUTH) * px_per_deg_y)

crop = np.asarray(img.crop((left, top, right, bottom)).convert('RGB'))
img.close()
ch, cw = crop.shape[:2]
print(f'crop {cw}x{ch}')

# Target height keeps the Mercator aspect ratio honest.
span_x = EAST - WEST
span_y = merc_y(NORTH) - merc_y(SOUTH)
out_h = int(round(OUT_W * span_y / span_x))

# Row remap: each output row is a Mercator y, converted back to a latitude and
# then to the source row that holds it.
ys = merc_y(NORTH) - (np.arange(out_h) + 0.5) * span_y / out_h
lats = inv_merc_y(ys)
src_rows = np.clip(((NORTH - lats) / (NORTH - SOUTH) * ch).astype(int), 0, ch - 1)

cols = np.clip(((np.arange(OUT_W) + 0.5) / OUT_W * cw).astype(int), 0, cw - 1)
out = crop[src_rows][:, cols].astype(np.float32)
print(f'reprojected {OUT_W}x{out_h}')

# The app clips this texture to the vector coastline, which is simplified and
# so does not follow the raster's coast exactly. Where the polygon sits a little
# seaward, raw ocean pixels would show as a blue fringe on land. Bleeding land
# colours a few pixels out to sea removes that failure mode entirely.
ocean = (out[..., 2] > out[..., 0] + 12) & (out[..., 2] > out[..., 1] + 4) & (out[..., 2] > 110)
print('ocean fraction %.2f' % ocean.mean())

filled = out.copy()
mask = ocean.copy()
for _ in range(8):
    if not mask.any():
        break
    src = np.where(mask[..., None], np.nan, filled)
    acc = np.zeros_like(filled)
    cnt = np.zeros(filled.shape[:2], dtype=np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = np.roll(np.roll(src, dy, axis=0), dx, axis=1)
        ok = ~np.isnan(n[..., 0])
        acc[ok] += n[ok]
        cnt += ok
    grew = mask & (cnt > 0)
    filled[grew] = acc[grew] / cnt[grew, None]
    mask &= ~grew
out = filled

# Dark-terrain treatment: deepen and saturate so the hypsometric bands stay
# legible against the app's dark ocean instead of washing out to grey.
grey = out @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
out = grey[..., None] + (out - grey[..., None]) * 1.45      # saturation
out = 128 + (out - 128) * 1.12                              # contrast
out *= 0.70                                                 # overall level
out = 10 + out * (255 - 10) / 255                           # lift the blacks

Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(
    DST, 'JPEG', quality=86, optimize=True, progressive=True)
print('written', DST)
