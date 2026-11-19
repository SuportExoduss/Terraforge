import numpy as np
from PIL import Image
W = "D:/Terraforge_Godotrt/work_g01/"
G = "C:/Users/andre/Desktop/modelos/03_Floresta/G01/"


def load_mesh(name="mesh3.npz"):
    d = np.load(W + name)
    return d["V"], d["T"], d["UV"], d["part"], d["chart"]


def raster(P2, depth, w, h, want_bary=True):
    """z-buffer de triangulos. P2 (n,3,2) em pixels (x dir, y baixo); depth (n,3), menor = mais perto.
    Devolve id (h,w) int32 (-1 vazio), zbuf (h,w), bary (h,w,3)."""
    ids = -np.ones((h, w), np.int32); zb = np.full((h, w), np.inf, np.float32)
    bary = np.zeros((h, w, 3), np.float32) if want_bary else None
    n = len(P2)
    for f in range(n):
        p = P2[f]
        x0 = max(int(np.floor(p[:, 0].min() - 0.5)), 0); x1 = min(int(np.ceil(p[:, 0].max() + 0.5)), w - 1)
        y0 = max(int(np.floor(p[:, 1].min() - 0.5)), 0); y1 = min(int(np.ceil(p[:, 1].max() + 0.5)), h - 1)
        if x1 < x0 or y1 < y0: continue
        den = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(den) < 1e-12: continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        l0 = ((p[1, 1] - p[2, 1]) * (gx - p[2, 0]) + (p[2, 0] - p[1, 0]) * (gy - p[2, 1])) / den
        l1 = ((p[2, 1] - p[0, 1]) * (gx - p[2, 0]) + (p[0, 0] - p[2, 0]) * (gy - p[2, 1])) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not inside.any(): continue
        z = l0 * depth[f, 0] + l1 * depth[f, 1] + l2 * depth[f, 2]
        sub_z = zb[y0:y1 + 1, x0:x1 + 1]
        upd = inside & (z < sub_z)
        if not upd.any(): continue
        sub_z[upd] = z[upd]; ids[y0:y1 + 1, x0:x1 + 1][upd] = f
        if want_bary:
            b = bary[y0:y1 + 1, x0:x1 + 1]
            b[upd, 0] = l0[upd]; b[upd, 1] = l1[upd]; b[upd, 2] = l2[upd]
    return ids, zb, bary


def erode_dist(mask, maxd=8):
    """distancia (em passos de 4 vizinhos) de cada pixel True ate a borda da mascara, saturando em maxd"""
    d = np.zeros(mask.shape, np.int16); cur = mask.copy()
    for i in range(1, maxd + 1):
        n = cur.copy()
        n[1:] &= cur[:-1]; n[:-1] &= cur[1:]; n[:, 1:] &= cur[:, :-1]; n[:, :-1] &= cur[:, 1:]
        n[0, :] = False; n[-1, :] = False; n[:, 0] = False; n[:, -1] = False
        d[n] = i; cur = n
    return d


def ref_mask(img):
    r = img.astype(int); mx = r.max(2); mn = r.min(2)
    m = ((255 - r).max(2) > 40) & (((mx - mn) > 22) | (mx < 170))
    # abertura simples p/ tirar a sombra fina
    return m


def srgb_to_lab(rgb):
    c = np.asarray(rgb, np.float64) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    M = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = c @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)
