# REVISÃO GERAL — GDMD × JOGO (Godot), 2026-11-14

Escopo: o que o GDMD (D:\JOGO (TERRAFORGE)) manda ter × o que o port Godot (D:\Terraforge_Godot, commit a5d1436, Passo 101; correções no Passo 102) tem de fato × o que o port tem e NÃO deveria ter.
Regra de desempate usada: DD mais recente vence; empate → o código é o juiz. O GDMD só ganhou o Adendo 08 (aditivo); nenhum texto antigo foi alterado.
Marcas: ✅ confere · ⚠ diverge/falta em parte · ❌ falta · ➕ extra (não está no GDMD) · ❓ precisa de decisão do André.

---

## 0. STATUS APÓS "corrija tudo" (Passo 102, 2026-11-14)

| Item do relatório | Situação |
|---|---|
| §2.1 eventos 2 por vez | ✅ corrigido: `limit()` = 1 (DD-128); `smoke_event_limit` reescrito |
| §2.1 dano do guardião 1 → 2 e perseguição sem teto | ✅ corrigido: dano 2/16, teto de 4 s (DD-109); `smoke_defenders` 3b prova o teto |
| §3 comentário velho "DD-113 (retrato)" | ✅ corrigido em `runner_camera.gd` |
| §3 DD-131..134 sem registro / §5 contradições 1–10 | ✅ registrados no **Adendo 08** (DD-131..137) e índice (próximo livre = DD-138). Texto antigo do GDMD não foi alterado |
| §3 Manada, botões ONLINE/SAIR | ✅ oficializados no Adendo 08 (DD-137, DD-136) |
| §3 mudanças não commitadas | ✅ meu trabalho (areia, rolagem, correções, docs) commitado; ficam fora, de propósito, a arte do André, o Touro (G06) em `defender_system.gd`, `minimap_markers.gd` e `project.godot` |
| Bicho pequeno 1/16; "5 de 8 elementos"; Passe; menu em ícones; cliente online 3D; E01m–E12m; teste no celular; G06 por civ.; território de eliminada; balanceamento item 6; DD-009 | ❌ **continuam pendentes** (arte, aparelho ou decisão do Diretor) — lista em Adendo 08, parte E |

---

## 1. DEVERIA TER E TEM (confere com o GDMD)

| Tema | GDMD | No jogo |
|---|---|---|
| Planeta e partida | DD-111: raio 100, partida 600 s | ✅ |
| Vida | DD-105: 16 pontos; corte = 2; regeneração 1 pt/1,5 s; 0 pt = ELIMINADO + espectador | ✅ |
| Abertura | DD-096: 7 s (5 s de descida + 2 s no chão, contagem 5..1, GO) | ✅ (`home_territory.gd`: 5,0 + 2,0) |
| Campo de força | DD-097: escala 15 (raio 7,5); DD-100: decolagem em 0,2 s | ✅ |
| Civilizações | DD-095: 6 civs nas faces do cubo | ✅ |
| Rastro / corte / base cai / território amputado / ruína / recall | DD-099/100/102/122/123 | ✅ (smokes de laço 97–99) |
| Conquista | DD-127: onda de domínio, auto-toque fecha área, ≥12 células, desempate, contagem sem repetir | ✅ |
| Bots | DD-101 humanos; DD-130 ambição 0,6–1,6 | ✅ |
| Minimapa | DD-104: expande a 75 %, arrasta, toque | ✅ |
| Ciclo de eventos | DD-106/128: janelas calmas de 25 s, folga de 25 s, fila aleatória 0–8 s | ✅ (mas "um por vez" não vale com 6 corredores — ver §2.1) |
| Os 7 eventos | DD-107: furacão, vulcão, meteoro, tsunami, terremoto, chuva ácida, verme | ✅ (+ manada, ver §3) |
| Cicatrizes | DD-108 | ✅ |
| Obstáculos somem no vulcão/tsunami | SYS-007 | ✅ (Passos 100–101) |
| Bônus | DD-106 (cristais), vida extra com teto 20 (DD-129) | ✅ |
| Guardião | DD-109: 6 estados, nunca sai do território | ✅ parcial (ver §2) |
| Slots de ambiente | DD-110 | ✅ 720 slots (ver §5) |
| Clima / dia-noite | Cap 03 | ✅ |
| HUD | Cap 03 P03.. | ✅ |
| Multiplayer | Cap 05: validação no servidor, reconexão 20 s, hash de dessincronia, predição, interpolação, servidor dedicado | ✅ |
| Disciplina de módulos | Cap 05: módulos só falam por EventBus/Services | ✅ (nenhum gameplay → UI direto) |
| Tela deitada | DD-126: paisagem 960×540 | ✅ |
| Perfil, civilizações, loja (cercas), lobby, tela ONLINE, configurações | Cap 03 P01 | ✅ (loja só com cores de cerca) |

---

## 2. DEVERIA TER E FALTA OU DIVERGE

### 2.1 Divergências de regra (código ≠ DD)
- ⚠ **Eventos simultâneos (DD-128 manda 1 por vez)**: `global_event.gd` `limit()` = 1 + (corredores−1)/3 → **2 eventos juntos com 6 corredores**. Confirmado no playtest: em 9 ciclos dois eventos avisaram com ≤ 1,5 s de diferença (em 7 deles os dois ficaram ativos ao mesmo tempo) (ex.: manada + furacão aos 96–97 s; verme + chuva ácida aos 142–143 s). A regra "cresce com jogadores" vem do Cap 03 Parte 07 (anterior ao DD-128); pelo critério "DD mais recente vence", o código diverge. ❓ Decisão sua: manter 2 (Cap 03) ou travar em 1 (DD-128).
- ⚠ **Dano do guardião**: DD-109 manda 2/16 (guardião) e 1/16 (bicho pequeno). O jogo: `damage := 1` fixo, e **não existe o bicho pequeno**.
- ⚠ **Perseguição do guardião**: DD-109 manda no máximo 4 s. O jogo desiste por distância (`give_up_radius := 26`), sem limite de tempo.
- ⚠ **"5 de 8 elementos ativos por território"** (DD-109): não encontrei no código.
- ⚠ **G06 – defensor por civilização**: a LISTA_DE_MODELOS marca "DECISÃO PENDENTE DO DIRETOR". O jogo usa o Touro para todas (interpretação provisória).

### 2.2 Telas e produto
- ❌ **Passe** (menu + progresso na tela de resultados): não existe. Cosméticos = só 5 cores de cerca.
- ⚠ **Menu**: Cap 03 P01 pede "menu faz parte do planeta, pouco texto, ícones grandes". O jogo tem botões de texto + dock; os botões ONLINE e SAIR não estão na lista do GDMD.
- ⚠ **"Jogar" sem tela estática** (DD-009): existe uma tela "PREPARANDO A PARTIDA…" de ~1,1 s sobre o quadro escuro.
- ❌ **Anúncios e compras no app**: nada.
- ⚠ **Tela EVENTOS**: é só uma lista de ajuda dos 8 eventos; o GDMD não define o que "Eventos" deveria ser no menu.

### 2.3 Online
- ⚠ **Cliente online ainda é tabuleiro 2D**, sem o planeta 3D; civs 2–6 não jogáveis online; hospedar a partir da tela e interpolação visual dos remotos pendentes.

### 2.4 Critérios do DD-124 (aceite da migração)
- ❌ **Teste no celular**: o APK é de 5/nov, sem registro de teste no aparelho nem de FPS ≥ 45 (critérios a/c).

### 2.5 Arte
- ⚠ **Modelos de "morto" E01m–E12m** não existem; o jogo usa fallback (cor dessaturada/escura no shader).
- ⚠ Cosméticos da cerca e demais modelos da LISTA_DE_MODELOS dependem da arte do André.

### 2.6 IDs do Cap 04 sem anotação no código
STATE-004..008/012, UI-001..005, CL-003..005, OP-003..006, MP-001/002/004..006, PL-001..007: provavelmente implementados, mas **sem marcação no código** — não dá para provar cobertura. (Só confirmo se você quiser.)

---

## 3. TEM E NÃO DEVERIA (ou não está no GDMD)

- ➕ **DD-131..134 usados no código/docs, mas o índice do GDMD diz que o próximo livre é DD-131** → conflito de numeração. Cobrem: minimapa estratégico (MP-003..005), configurações (UI-006), detecção de dessincronia, servidor dedicado. Precisa de **Adendo 08** registrando — ou renumerar no código.
- ➕ **Comentário velho** `scripts/gameplay/runner_camera.gd:4` cita "DD-113 (retrato)" — o DD-126 trocou para paisagem.
- ➕ **MANADA** (8º evento na tela EVENTOS): fora dos 7 oficiais do DD-107.
- ➕ **Botões ONLINE e SAIR** no menu (razoáveis, mas não estão no Cap 03 P01).
- ➕ **Classificação "bônus raro/guardado"** e **Touro como guardião G06**: interpretações, não regra escrita.
- ➕ **Mudanças ainda não commitadas** na árvore: arte do André (cowboy/domo/nave, modelos de eventos) + shader da areia granulada + scroll do menu/configurações + `project.godot` reserializado pelo editor.

---

## 4. COMPORTAMENTO OBSERVADO

### 4.1 Regressão automática
**105/105 smokes OK** (`tools/run_smokes.sh`), sem falha. Cobrem: laços nos polos e de 4–100° (97–98), rastro de terceiros (99), tsunami e vulcão queimando obstáculos (100–101), eventos, clima, rede, servidor dedicado, minimapa, configurações etc.

### 4.2 Playtest completo (`tools/playtest_match.gd`, 600 s de jogo, você = civ 1 + 5 bots, headless)
Log: `D:\Terraforge_Godot\.playtest_revisao.log` (não versionado).

| Item | Resultado |
|---|---|
| Abertura | 7,0 s exatos (descida + contagem 5..1 + GO), naves realocadas ✅ |
| Fluxo de estados | abertura → jogo ↔ evento (~10 ciclos) → fim → pódio → resultado, sem travar ✅ |
| Eventos | 9 ciclos com 2 avisos quase juntos, 7 com os dois ativos ao mesmo tempo (ver §2.1); folga de ~25 s entre ciclos ✅; todos os 7 + manada apareceram ✅ |
| Primeiro evento | aviso aos 64 s de jogo (57 s depois do GO) — fica entre os 25 s do DD-106 e os 60 s do Cap 03 |
| Vida / eliminação | pontos descem e regeneram 1/1,5 s ✅; civ 4 (t=360) e civ 2 (t=532) ELIMINADAS e vão para o fim do placar ✅ |
| Cortes de rastro | 4 cortes + 1 toque mútuo, 0 "não cortou" ✅; auto-toque sem fechar: 0 ✅ |
| Circuitos | 388 fechados; 411 anexos; 32 "circuitos vazios" (~8 %) e 6 avisos "cerca sem área" (laços de 3–6 células). Menor, já visto antes; não afeta o placar |
| Domínio | pico por civ 19–26 %; planeta ~99,5 % tomado já aos ~480 s (livre 0,5 %) → confirma o item 6 do balanceamento (planeta enche antes do fim) |
| Placar final | 1º civ 5 (25,1 %), 2º civ 3 (23,6 %), 3º civ 6 (17,0 %), 4º VOCÊ (16,2 %), 5º/6º eliminadas (por "máx") |
| Território de eliminada | continua no mapa (civ 4 com 4,8 %, civ 2 com 13,1 %) e vira presa dos outros. GDMD não diz o destino — ❓ |
| Desempenho (headless, sem GPU) | quadro médio 3–9 ms, p99 ≤ 11 ms, 0 quadros > 60 ms; picos de 44 ms só na virada do fim de partida (pintura pendente 92 → 3694) |
| Memória / vazamento | nós 2843→4094 estável, 0 órfãos, 261→279 MB ✅ |

⚠ O número de quadros é do computador **sem placa de vídeo**: não prova FPS no celular (ver §2.4).

---

## 5. CONTRADIÇÕES DENTRO DO PRÓPRIO GDMD (precisam de decisão sua → virar DD)

| # | Texto A | Texto B | O jogo segue |
|---|---|---|---|
| 1 | Janela sem eventos 60 s (Cap 03/05) | 25 s (DD-106) | 25 s (mais recente) |
| 2 | 5 vidas (Cap 03) | 16 pontos (DD-105) | 16 pontos |
| 3 | Partida 5 min (Cap 01/03) | 10 min (DD-111) | 600 s |
| 4 | Contagem 3 s | DD-096 (7 s) | DD-096 |
| 5 | Respawn | Eliminação/espectador (DD-105 R1) | Eliminação |
| 6 | DD-110 "milhares de slots" | 720 slots | 720 |
| 7 | `ROADMAP_CONTEUDO_POR_CIVILIZACAO.txt` desatualizado | LISTA_DE_MODELOS atual | LISTA_DE_MODELOS |
| 8 | Balanceamento item 6 (planeta enche em t≈375–465 s) | aguarda o Diretor (reconfirmado: ~480 s no playtest) | — |
| 9 | Eventos simultâneos "dependem de planeta e jogadores" (Cap 03 P07) | "1 por vez" (DD-128) | 2 com 6 corredores (Cap 03) |
| 10 | "Nos primeiros 60 s não há eventos" (Cap 03 P07) | janela de paz de 25 s (DD-106) | 1º aviso aos ~57 s |

Nota: a anotação de memória "paisagem aguarda sim" está velha — o DD-126 já existe.
