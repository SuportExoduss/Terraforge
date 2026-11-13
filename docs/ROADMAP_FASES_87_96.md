# Roadmap — Passos 87 a 96 (pedido "mais 10 passos, resolva os travamentos e o início após o mergulho", 2026-11-13)

Não vêm do GDMD: é desempenho (critério DD-124: 45+ FPS no notebook i5-8365U + UHD 620). Medida de partida (`tools/bench_load.gd`, janela,
com outro Godot aberto ao lado): a partida levava **88 s** para carregar em segundo plano, o `add_child` dela **congelava 7,8 s** (é o "início lento
depois do mergulho") e o jogo tinha 19 travadas > 40 ms em 25 s; o processo chegava a **7,7 GB** porque 65 texturas de 4096 px estavam em WebP
sem perdas (85 MB cada na memória).
Regra: 1 commit local por passo (nunca `push`), smoke novo + regressão do trecho verde antes de cada commit; nenhum sinal do EventBus muda.
O trabalho de arte do André (modelos, `.import`, cenas, touro) não entra nos commits — só o script que o reescreve e os padrões do projeto.

| # | Passo | Causa | Entrega |
|---|---|---|---|
| 87 | Texturas leves | 65 texturas 4096 px sem compressão (~5 GB) | `tools/optimize_textures.py` + padrões de importação: VRAM comprimida, máx. 2048 px |
| 88 | Ferramenta de medida | sem número, só sensação | `tools/bench_load.gd` (carga, `add_child`, travadas) e quadros lentos no `PerfMeter` |
| 89 | Modelos em segundo plano | `load()` de .glb no meio do jogo trava o quadro | o menu pede os .glb da partida em thread; `load()` depois é instantâneo |
| 90 | Som pré-gerado | a música/efeitos são sintetizados em GDScript na hora | a síntese roda em thread enquanto o jogador está no menu |
| 91 | Grupos do cenário prontos | `EnvironmentSlotSystem` monta um MultiMesh na 1ª conquista | os grupos nascem na carga, não no meio da corrida |
| 92 | Mergulho sem engasgo | a troca de cena instancia tudo num quadro só | a partida entra na árvore em fatias, atrás da tela de mergulho |
| 93 | Sem `print` no jogo | `print()` custa 10–30 ms no console do Windows | logs de jogo só em depuração e por arquivo |
| 94 | Pré-aquecimento de sombreadores | 1º uso de cada material compila no meio do jogo | um quadro invisível desenha cada material antes do "valendo" |
| 95 | Custo por quadro | alocações a cada quadro nos laços quentes | os laços medidos como piores ficam sem alocar |
| 96 | Fecha o ciclo | — | `bench_load` de novo, regressão completa, memória e roteiro atualizados |

Status:
- Passo 87 ✔ (texturas leves: `tools/optimize_textures.py` reescreve os `.import` de `art/models` — `compress/mode=2` (VRAM comprimida: S3TC no PC, ETC2/ASTC no celular), `process/size_limit=2048`, relevo com `compress/normal_map=1`; 65 arquivos; cada textura de 4096 px passou de ~85 MB para ~5,6 MB na memória. MEDIDO (`bench_load`, mesma máquina, com outro Godot aberto): carga em segundo plano **88,6 s → 7,2 s**; `add_child` da partida **7,8 s → 2,3 s**; o visual não mudou (foto do cacto/arbusto conferida). `smoke_textures` falha se um modelo novo entrar em 4096 px/sem compressão e diz o comando para corrigir. O `.import` de arte do André segue fora dos commits: só o script e o smoke entram)
