import numpy as np, heapq, math, sys
from PIL import Image
W = "D:/Terraforge_Godotrt/work_g01/"
TEX = 2048; PAD = 4
ANG = float(sys.argv[1]) if len(sys.argv) > 1 else 52.0
d = np.load(W + "mesh2.npz")
V, T, part = d["V"], d["T"], d["part"]
n = len(T)
P = V[T]                                   # (n,3,3)
cr = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
area = np.linalg.norm(cr, axis=1) / 2
nrm = cr / np.maximum(np.linalg.norm(cr, axis=1, keepdims=True), 1e-12)
# vizinhos por aresta (mesmos indices de vertice)
edge = {}
for f in range(n):
    for k in range(3):
        a, b = T[f][k], T[f][(k + 1) % 3]
        edge.setdefault((min(a, b), max(a, b)), []).append(f)
adj = [[] for _ in range(n)]
for fs in edge.values():
    for i in fs:
        for j in fs:
            if i != j: adj[i].append(j)
CMIN = math.cos(math.radians(ANG)); CSEED = math.cos(math.radians(ANG * 1.25))
chart = -np.ones(n, int); charts = []
order = np.argsort(-area)
for s in order:
    if chart[s] >= 0: continue
    cid = len(charts); members = [s]; chart[s] = cid
    N = nrm[s].copy() * area[s]; heap = []
    def push(f):
        for g in adj[f]:
            if chart[g] < 0:
                dn = nrm[g] @ (N / np.linalg.norm(N))
                heapq.heappush(heap, (-dn, g))
    push(s)
    while heap:
        dn, g = heapq.heappop(heap)
        if chart[g] >= 0: continue
        Nn = N / np.linalg.norm(N)
        if nrm[g] @ Nn < CMIN or nrm[g] @ nrm[s] < CSEED: continue
        chart[g] = cid; members.append(g); N += nrm[g] * area[g]; push(g)
    charts.append(members)
print("charts iniciais", len(charts))

def cnormal(ms):
    v = (nrm[ms] * area[ms][:, None]).sum(0); return v / np.linalg.norm(v)
# funde charts pequenos no vizinho de normal parecida
changed = True
while changed:
    changed = False
    sizes = sorted(range(len(charts)), key=lambda c: len(charts[c]))
    for c in sizes:
        ms = charts[c]
        if not ms or len(ms) >= 8: continue
        Nc = cnormal(ms); cand = {}
        for f in ms:
            for g in adj[f]:
                if chart[g] != c and chart[g] >= 0: cand[chart[g]] = cand.get(chart[g], 0) + 1
        best = None
        for c2, cnt in cand.items():
            dn = cnormal(charts[c2]) @ Nc
            # checa que todos os triangulos do chart pequeno cabem no chart destino
            merged = charts[c2] + ms; Nm = cnormal(merged)
            if (nrm[merged] @ Nm).min() >= math.cos(math.radians(ANG * 1.35)) and (best is None or dn > best[0]): best = (dn, c2)
        if best:
            c2 = best[1]
            for f in ms: chart[f] = c2
            charts[c2] = charts[c2] + ms; charts[c] = []; changed = True
charts = [c for c in charts if c]
for i, ms in enumerate(charts):
    for f in ms: chart[f] = i
print("charts apos fusao", len(charts), "tamanho medio", n / len(charts))

# projecao planar de cada chart, em unidades do mundo, escalada p/ densidade media = 1
isl = []
up = np.array([0, 0, 1.0])
for ms in charts:
    ms = np.array(ms); N = cnormal(ms)
    u = np.cross(up, N)
    if np.linalg.norm(u) < 0.2: u = np.cross(np.array([1.0, 0, 0]), N)
    u /= np.linalg.norm(u); v = np.cross(N, u)
    pts = P[ms].reshape(-1, 3)
    uv = np.stack([pts @ u, pts @ v], axis=1).reshape(len(ms), 3, 2)
    a2 = 0.5 * np.abs((uv[:, 1, 0] - uv[:, 0, 0]) * (uv[:, 2, 1] - uv[:, 0, 1]) - (uv[:, 1, 1] - uv[:, 0, 1]) * (uv[:, 2, 0] - uv[:, 0, 0]))
    a3 = area[ms].sum(); s = math.sqrt(a3 / max(a2.sum(), 1e-12))
    uv = uv * s
    # rotacao de caixa minima
    flat = uv.reshape(-1, 2); best = None
    for deg in range(0, 90, 3):
        c, sn = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        r = flat @ np.array([[c, -sn], [sn, c]]).T; bb = r.max(0) - r.min(0)
        if best is None or bb[0] * bb[1] < best[0]: best = (bb[0] * bb[1], deg, r.min(0), bb)
    _, deg, mn, bb = best
    c, sn = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    uv = (uv @ np.array([[c, -sn], [sn, c]]).T) - mn
    if bb[1] > bb[0]:   # deixa a caixa mais larga do que alta (prateleiras)
        uv = np.stack([uv[..., 1], bb[0] - uv[..., 0]], axis=-1); bb = bb[::-1]
    isl.append(dict(ms=ms, uv=uv, w=bb[0], h=bb[1], s=s))

def shelf(k):
    items = sorted(range(len(isl)), key=lambda i: -isl[i]["h"])
    x = y = rowh = 0; pos = {}
    for i in items:
        w = isl[i]["w"] * k + 2 * PAD; h = isl[i]["h"] * k + 2 * PAD
        if w > TEX: return None
        if x + w > TEX: x = 0; y += rowh; rowh = 0
        if y + h > TEX: return None
        pos[i] = (x, y); x += w; rowh = max(rowh, h)
    return pos
lo, hi = 100.0, 6000.0
for _ in range(30):
    mid = (lo + hi) / 2
    if shelf(mid): lo = mid
    else: hi = mid
k = lo; pos = shelf(k)
print("px por unidade", round(k, 1), "(modelo de altura 1.0 -> %d px)" % k)
UV3 = np.zeros((n, 3, 2)); prev = np.zeros((TEX, TEX, 3), np.uint8)
rng = np.random.default_rng(1); used = 0
for i, it in enumerate(isl):
    x0, y0 = pos[i]
    px = it["uv"] * k + np.array([x0 + PAD, y0 + PAD])
    UV3[it["ms"], :, 0] = px[..., 0] / TEX
    UV3[it["ms"], :, 1] = 1.0 - px[..., 1] / TEX
    used += it["w"] * it["h"] * k * k
    col = rng.integers(60, 255, 3)
    xa, xb = int(x0 + PAD), int(x0 + PAD + it["w"] * k); ya, yb = int(y0 + PAD), int(y0 + PAD + it["h"] * k)
    prev[ya:yb, xa:xb] = col
print("preenchimento (caixas)", round(used / TEX / TEX * 100, 1), "%")
np.savez(W + "mesh3.npz", V=V, T=T, UV=UV3, part=part, chart=chart)
Image.fromarray(prev).resize((1024, 1024)).save(W + "pack_preview.png")
# distorcao interna: razao de densidade por triangulo / media
a2 = 0.5 * np.abs((UV3[:, 1, 0] - UV3[:, 0, 0]) * (UV3[:, 2, 1] - UV3[:, 0, 1]) - (UV3[:, 1, 1] - UV3[:, 0, 1]) * (UV3[:, 2, 0] - UV3[:, 0, 0])) * TEX * TEX
dens = a2 / area
print("densidade px/unid2: min %.0f p5 %.0f med %.0f p95 %.0f max %.0f" % (dens.min(), np.percentile(dens, 5), np.median(dens), np.percentile(dens, 95), dens.max()))
