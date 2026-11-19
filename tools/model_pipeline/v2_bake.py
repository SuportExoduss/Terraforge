import sys, json, time
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from v2lib import *

POW = float(sys.argv[1]) if len(sys.argv) > 1 else 6.0
TEX = 2048
t0 = time.time()
V, T, UV, part, chart = load_mesh()
Vm = V * np.array([-1.0, 1, 1])          # quadro das imagens
P = Vm[T]                                 # (n,3,3)
cr = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]); nrm = cr / np.maximum(np.linalg.norm(cr, axis=1, keepdims=True), 1e-12)
cen = P.mean(1); c0 = cen.mean(0)
if (nrm * (cen - c0)).sum() < 0: nrm = -nrm
cams = json.load(open(W + "cams.json"))
views = [np.array(Image.open(G + "multiview_%d_ae4d1b2a-ea36-4862-b342-9753ab4801dc.webp" % i).convert("RGB")) for i in range(4)]

# ---- atlas: id do triangulo e baricentro de cada texel
UVpx = np.stack([UV[..., 0] * TEX, (1.0 - UV[..., 1]) * TEX], axis=-1)
aid, _, abar = raster(UVpx, np.zeros((len(T), 3)), TEX, TEX)
cover = aid >= 0
print("atlas rasterizado", round(time.time() - t0), "s; cobertura", round(cover.mean() * 100, 1), "%")
ys, xs = np.nonzero(cover); tid = aid[ys, xs]; bc = abar[ys, xs]
pos = (P[tid] * bc[..., None]).sum(1); nt = nrm[tid]     # (N,3)
N = len(tid)
EYE = np.isin(part[tid], [33, 34, 54, 55])
BOOT = np.isin(part[tid], [5, 6, 47, 48, 56, 57, 38, 40, 64, 65, 71, 72])

def bilinear(img, gx, gy):
    h, w = img.shape[:2]; x = np.clip(gx - 0.5, 0, w - 1.001); y = np.clip(gy - 0.5, 0, h - 1.001)
    x0 = x.astype(int); y0 = y.astype(int); fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    a = img[y0, x0].astype(np.float32); b = img[y0, x0 + 1]; c = img[y0 + 1, x0]; d = img[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

def view_data(i):
    c = cams[i]; s = c["s"]; ax = c["axis"]
    toc = np.array((0, -s, 0)) if ax == "x" else np.array((s, 0, 0))
    def proj(p):
        h = p[..., 0] if ax == "x" else p[..., 1]
        return c["bx"] + c["ax"] * s * h, c["by"] - c["ay"] * p[..., 2], -(p @ toc)
    return c, toc, proj

acc = np.zeros((N, 3), np.float64); wsum = np.zeros(N); acc2 = np.zeros((N, 3), np.float64); wsum2 = np.zeros(N)
per_view = []
for i in range(4):
    c, toc, proj = view_data(i)
    gx, gy, dz = proj(P)                       # (n,3)
    ids, zb, _ = raster(np.stack([gx, gy], axis=-1), dz, 1024, 1024, want_bary=False)
    sil = ids >= 0; m = ref_mask(views[i])
    d_ref = erode_dist(m, 8); d_mod = erode_dist(sil, 8)
    zf = np.where(np.isfinite(zb), zb, 10.0)
    edge = np.zeros(zf.shape, bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        edge |= np.abs(zf - np.roll(zf, (dy, dx), (0, 1))) > 0.012
    edge &= sil
    d_edge = 8 - erode_dist(~edge, 8)          # 0 longe da borda de profundidade, 8 em cima
    dist = np.minimum(np.minimum(d_ref, d_mod), 8 - d_edge).astype(np.float32)   # px ate o "perigo"
    edgew = np.clip((dist - 1.0) / 4.0, 0, 1); edgew = edgew * edgew * (3 - 2 * edgew)
    # texels -> imagem
    px, py, pz = proj(pos)
    ix = np.clip(px.astype(int), 0, 1023); iy = np.clip(py.astype(int), 0, 1023)
    z3 = np.full(N, np.inf, np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            z3 = np.minimum(z3, zf[np.clip(iy + dy, 0, 1023), np.clip(ix + dx, 0, 1023)])
    vis = (pz <= z3 + 0.010) & (px > 1) & (px < 1022) & (py > 1) & (py < 1022)
    cosv = np.abs(nt @ toc)
    w = np.where(vis & (cosv > 0.2), cosv ** POW * edgew[iy, ix], 0.0)
    col = bilinear(views[i], px, py)
    pale = ((col.min(1) > 100) & ((col.max(1) - col.min(1)) < 60) & ~EYE) | (BOOT & (col.min(1) > 75) & ((col.max(1) - col.min(1)) < 42))
    w = np.where(pale, 0.0, w)
    w2 = np.where(vis & (cosv > 0.03) & (d_ref[iy, ix] >= 3) & ~pale, cosv, 0.0)
    acc2 += col * w2[:, None]; wsum2 += w2
    acc += col * w[:, None]; wsum += w
    print("vista", c["name"], "visivel", round(vis.mean() * 100, 1), "% ", round(time.time() - t0), "s")
good = wsum > 1e-3
colors = np.zeros((N, 3)); colors[good] = acc[good] / wsum[good, None]
g2 = ~good & (wsum2 > 1e-3)
colors[g2] = acc2[g2] / wsum2[g2, None]; good = good | g2
print('rasante:', int(g2.sum()))
print("texels com cor:", round(good.mean() * 100, 1), "%")

# ---- atlas e preenchimento do que nenhuma vista ve
atlas = np.zeros((TEX, TEX, 3), np.float32); valid = np.zeros((TEX, TEX), bool)
atlas[ys, xs] = colors; valid[ys, xs] = good
cid = -np.ones((TEX, TEX), np.int32); cid[ys, xs] = chart[tid]
fill = valid.copy()
ty, tx = np.nonzero(cover & ~fill)
for it in range(700):
    if len(ty) == 0: break
    s_acc = np.zeros((len(ty), 3), np.float32); s_cnt = np.zeros(len(ty), np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        yy = np.clip(ty + dy, 0, TEX - 1); xx = np.clip(tx + dx, 0, TEX - 1)
        ok = fill[yy, xx] & (cid[yy, xx] == cid[ty, tx])
        s_acc += atlas[yy, xx] * ok[:, None]; s_cnt += ok
    upd = s_cnt > 0
    if not upd.any(): break
    atlas[ty[upd], tx[upd]] = s_acc[upd] / s_cnt[upd, None]; fill[ty[upd], tx[upd]] = True
    ty, tx = ty[~upd], tx[~upd]
hid = cover & ~valid & fill
for it in range(12):   # suaviza so o que foi inventado
    nb = np.zeros_like(atlas); cn = np.zeros((TEX, TEX), np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ok = np.roll(fill, (dy, dx), (0, 1)) & (np.roll(cid, (dy, dx), (0, 1)) == cid)
        nb += np.roll(atlas, (dy, dx), (0, 1)) * ok[..., None]; cn += ok
    sel = hid & (cn > 0)
    atlas[sel] = 0.5 * atlas[sel] + 0.5 * nb[sel] / cn[sel, None]
left = cover & ~fill
print("texels de dentro sem cor apos difusao:", int(left.sum()))
if left.any():
    # cor media da peca (ou da peca mais proxima)
    pid = np.zeros((TEX, TEX), np.int32); pid[ys, xs] = part[tid]
    pm = {}
    for p in np.unique(part):
        sel = fill & (pid == p) & cover
        if sel.any(): pm[p] = atlas[sel].mean(0)
    pc = {p: cen[part == p].mean(0) for p in np.unique(part)}
    for p in np.unique(pid[left]):
        use = pm.get(p)
        if use is None:
            near = sorted(pm, key=lambda q: np.linalg.norm(pc[q] - pc[p])); use = pm[near[0]]
        atlas[left & (pid == p)] = use
    fill |= left
# ---- gutter: dilata a cor para fora das ilhas (8 px)
full = fill.copy()
for it in range(8):
    s_acc = np.zeros_like(atlas); s_cnt = np.zeros((TEX, TEX), np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0: continue
            nb_f = np.roll(full, (dy, dx), (0, 1)); nb_a = np.roll(atlas, (dy, dx), (0, 1))
            s_acc += nb_a * nb_f[..., None]; s_cnt += nb_f
    upd = ~full & (s_cnt > 0)
    atlas[upd] = s_acc[upd] / s_cnt[upd, None]; full |= upd
atlas[~full] = (110, 120, 90)
out = np.clip(atlas, 0, 255).astype(np.uint8)
Image.fromarray(out).save(W + "atlas_v2.png")
np.save(W + "atlas_v2_cover.npy", cover)
print("atlas salvo", round(time.time() - t0), "s")

# ---- verificacao: renderiza o modelo texturizado de cada vista e compara com a referencia
rows = []; stats = []
for i in range(4):
    c, toc, proj = view_data(i)
    gx, gy, dz = proj(P)
    ids, zb, bary = raster(np.stack([gx, gy], axis=-1), dz, 1024, 1024)
    sil = ids >= 0; yy, xx = np.nonzero(sil); f = ids[yy, xx]; b = bary[yy, xx]
    uv = (UV[f] * b[..., None]).sum(1)
    col = bilinear(out, uv[:, 0] * TEX, (1 - uv[:, 1]) * TEX)
    rend = np.full((1024, 1024, 3), 255, np.uint8); rend[yy, xx] = np.clip(col, 0, 255).astype(np.uint8)
    ref = views[i]; m = ref_mask(ref)
    d_ref = erode_dist(m, 8); inner = sil & m & (d_ref >= 4)
    lab_r = srgb_to_lab(rend[inner]); lab_g = srgb_to_lab(ref[inner]); de = np.linalg.norm(lab_r - lab_g, axis=1)
    stats.append((cams[i]["name"], de.mean(), np.percentile(de, 90), (de > 15).mean()))
    heat = np.zeros((1024, 1024, 3), np.uint8); hv = np.zeros((1024, 1024)); hv[inner] = np.clip(de / 30, 0, 1)
    heat[..., 0] = (hv * 255).astype(np.uint8); heat[..., 1] = ((1 - hv) * 90 * inner).astype(np.uint8)
    rows.append(np.concatenate([ref[100:920, 250:780], rend[100:920, 250:780], heat[100:920, 250:780]], axis=1)[::2, ::2])
for s in stats: print("dE %s: media %.1f  p90 %.1f  >15: %.1f%%" % (s[0], s[1], s[2], s[3] * 100))
Image.fromarray(np.concatenate(rows, axis=0)).save(W + "bake_check.png")
print("pronto", round(time.time() - t0), "s")
