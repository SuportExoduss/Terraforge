import sys, json
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from v2lib import *

V, T, UV, part, chart = load_mesh()
V = V * np.array([-1.0, 1, 1])   # a malha esta espelhada em X em relacao as imagens
P = V[T]
CS = 1000.0
# silhuetas canonicas do modelo: eixo x (frente/costas) projeta (x,z); eixo y (lados) projeta (y,z)
def canon(axis):
    h = P[..., 0] if axis == "x" else P[..., 1]
    px = (h + 0.6) * CS; py = (1.05 - P[..., 2]) * CS
    P2 = np.stack([px, py], axis=-1)
    ids, zb, _ = raster(P2, np.zeros((len(T), 3)), int(1.2 * CS), int(1.1 * CS), want_bary=False)
    return ids >= 0
canv = {"x": canon("x"), "y": canon("y")}
print("canonicas ok", {k: v.sum() for k, v in canv.items()})

views = []
for i in range(4):
    im = np.array(Image.open(G + "multiview_%d_ae4d1b2a-ea36-4862-b342-9753ab4801dc.webp" % i).convert("RGB"))
    views.append(im)
names = ["F", "L", "B", "R"]
cands = {0: [("x", 1), ("x", -1)], 1: [("y", 1), ("y", -1)], 2: [("x", 1), ("x", -1)], 3: [("y", 1), ("y", -1)]}
Dd = {("x", 1): (0, 1, 0), ("x", -1): (0, -1, 0), ("y", 1): (1, 0, 0), ("y", -1): (-1, 0, 0)}  # direcao em que a camera olha, a partir do sinal

def fit(sil, ref, s, init):
    Hh, Ww = ref.shape; gy, gx = np.mgrid[0:Hh:3, 0:Ww:3]; rr = ref[gy, gx]
    def iou(p):
        ax, bx, ay, by = p
        h = s * (gx - bx) / ax; z = (by - gy) / ay
        cx = np.round((h + 0.6) * CS).astype(int); cy = np.round((1.05 - z) * CS).astype(int)
        ok = (cx >= 0) & (cx < sil.shape[1]) & (cy >= 0) & (cy < sil.shape[0])
        m = np.zeros(ok.shape, bool); m[ok] = sil[cy[ok], cx[ok]]
        return (m & rr).sum() / max((m | rr).sum(), 1)
    cur = list(init); bi = iou(cur); steps = [8.0, 8.0, 8.0, 8.0]
    for rnd in range(40):
        moved = False
        for i in range(4):
            for d in (-1, 1):
                t = cur.copy(); t[i] += d * steps[i]; v = iou(t)
                if v > bi + 1e-6: bi = v; cur = t; moved = True
        if not moved: steps = [x * 0.6 for x in steps]
        if steps[0] < 0.05: break
    return cur, bi

out = []
for i, im in enumerate(views):
    m = ref_mask(im); ys, xs = np.where(m)
    y1 = ys.max()
    # remove sombra do chao: linhas finais so com pouca saturacao ja filtradas; usa bbox robusto
    ys_p = np.percentile(ys, [0.2, 99.8]); xs_p = np.percentile(xs, [0.2, 99.8])
    Href = ys_p[1] - ys_p[0]
    best = None
    for key in cands[i]:
        axis, s = key
        sil = canv[axis]
        hs = np.where(sil.any(axis=0))[0]; hc = (hs.min() + hs.max()) / 2 / CS - 0.6   # centro da silhueta em h
        init = [Href / 1.0, (xs_p[0] + xs_p[1]) / 2 - Href * s * hc, Href / 1.0, ys_p[1]]
        p, v = fit(sil, m, s, init)
        print(names[i], key, "IoU", round(v, 4), [round(c, 1) for c in p])
        if best is None or v > best[0]: best = (v, key, p)
    v, key, p = best
    out.append(dict(name=names[i], axis=key[0], s=key[1], D=Dd[key], ax=p[0], bx=p[1], ay=p[2], by=p[3], iou=float(v)))
json.dump(out, open(W + "cams.json", "w"), indent=1)

# overlay: contorno da referencia (vermelho) x silhueta do modelo projetada (verde)
tiles = []
for i, c in enumerate(out):
    m = ref_mask(views[i])
    s = c["s"]; sil = canv[c["axis"]]
    gy, gx = np.mgrid[0:1024, 0:1024]
    h = s * (gx - c["bx"]) / c["ax"]; z = (c["by"] - gy) / c["ay"]
    cx = np.round((h + 0.6) * CS).astype(int); cy = np.round((1.05 - z) * CS).astype(int)
    ok = (cx >= 0) & (cx < sil.shape[1]) & (cy >= 0) & (cy < sil.shape[0])
    ms = np.zeros((1024, 1024), bool); ms[ok] = sil[cy[ok], cx[ok]]
    img = np.zeros((1024, 1024, 3), np.uint8); img[..., 0] = m * 255; img[..., 1] = ms * 255
    tiles.append(img[100:920, 250:780][::2, ::2])
Image.fromarray(np.concatenate(tiles, axis=1)).save(W + "cam_overlay.png")
