# Pipeline de modelos (Passo 138, DD-177): malha do Tripo + 4 vistas -> GLB pintado e rigado

Feito para o G01 da Floresta (`art/models/floresta/FlorestaG01_Guardiao.glb`). Roda FORA do jogo (Blender 4.2 + Python com PIL/numpy);
`tools/*` não entra no APK. Os caminhos `W` (pasta de trabalho) e `G` (pasta com as 4 vistas) ficam no topo de `v2lib.py`,
`v2_charts.py`, `v2_apply.py` e `rig_v2.py` — troque para o G01 de outra civilização.

Ordem (cada script imprime o que fez):
1. `build_g01.py`  (Blender -b -P) limpa a malha do Tripo (`.glb`) e salva o `.blend` base.
2. `v2_charts.py` desdobra a UV em "peças" (charts, ângulo 45°) e empacota em 2048² -> `mesh3.npz`.
3. `v2_cam.py` ajusta a câmera de cada vista pela silhueta (IoU) -> `cams.json` (malha espelhada em X SÓ na projeção).
4. `v2_bake.py [POW=6]` pinta cada texel pela vista que o enxerga melhor (peso cos^POW, rejeita fundo/sombra), preenche o que
   nenhuma vista vê e confere em Lab (ΔE) -> `atlas_v2.png` + `bake_check.png`.
5. `v2_apply.py` (Blender) põe UV + atlas na malha. 6. `rig_v2.py` (Blender) esqueleto de 12 ossos + animação "Correr" -> `.glb`.
7. `rend_v2.py` renders de conferência. Constantes de peça (olhos, botas) em `v2_bake.py` são do G01 élfico.
Depois: copiar o `.glb` para `art/models/<civ>/`, reimportar, e deixar a textura extraída com `compress/mode=2` e `size_limit=2048`.
