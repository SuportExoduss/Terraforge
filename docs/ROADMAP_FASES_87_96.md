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
| 88 | Ferramentas de medida | sem número, só sensação | `tools/bench_load.gd` (carga, custo do `_ready` de cada nó, travadas) e `tools/profile_scripts.gd` (CPU de cada `_process`, quem causa o pior quadro) |
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
- Passo 88 ✔ (medidas, sem mudar o jogo: `tools/bench_load.gd` mede carga em thread, `add_child` com o ranking dos `_ready` mais caros e as travadas > 40 ms de 25 s de jogo, com o jogador como bot de conquista; `tools/profile_scripts.gd` (headless) assume o `_process` de cada nó e cronometra um por um. ACHADOS: o `_ready` restante da partida (1,85 s) = Territory 575 ms, música 450 ms, colisão do planeta 144 ms, pintor 107 ms, base 84 ms; os picos de CPU do jogo = `load()` do GLB do touro (**35 ms a cada sentinela**, porque nada segura a cena na memória; com referência viva cai para 0,03 ms), a gema do bônus e a boiada pelo mesmo motivo, e a síntese preguiçosa dos efeitos sonoros (6–24 ms no 1º uso de cada um, 142 ms no total). O custo médio dos scripts é só 3,3 ms/quadro: o problema são os picos, não o laço)
- Passo 89 ✔ (`ModelCache` segura o touro e a gema na memória: `scene()` devolve a mesma cena sem reler o arquivo; o menu chama `ModelCache.prefetch()` e pede a partida em thread já ao abrir (`load_threaded_request` no `_ready`), então no JOGAR ela vem andada. `DefenderSystem`, `BonusSystem` e `StampedeEvent` usam `ModelCache.scene()` no lugar de `load()` solto. MEDIDO (`profile_scripts`): o pior `_process` dos sentinelas **50,8 → 16,7 ms**. `smoke_model_cache`: 2º uso < 2 ms, mesma cena, touro com esqueleto. NOTA: a troca nesses 3 consumidores está no working tree, mas fica FORA do commit porque os arquivos misturam a integração do touro/gema do André ainda não commitada; entra junto com a arte dele)
