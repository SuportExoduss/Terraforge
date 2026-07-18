# PROJECT TERRAFORGE — Visão Geral do Projeto

> Documento de embarque para novos desenvolvedores. Leia isto primeiro;
> depois o [SETUP_EQUIPE.md](SETUP_EQUIPE.md) (ambiente) e o
> [PADROES_DE_CODIGO.md](PADROES_DE_CODIGO.md) (código).

---

## 1. O que é o jogo

**Terraforge** é um jogo **multiplayer competitivo de conquista
territorial em um planeta esférico 3D vivo** — pense em paper.io, mas
numa esfera, com arte cartoon premium e um mundo que se transforma.

- Cada jogador é uma **civilização** (Cowboy, Alien, Mago...) que corre
  pela superfície deixando um **rastro**; fechar um circuito **conquista
  a área cercada**;
- **Cortar o rastro** de um inimigo causa dano e destrói a expansão dele;
- Conquistar a **base** inimiga = herdar TODO o império dele;
- **Eventos globais** (meteoros...) sacodem a partida;
- Partidas de **10 minutos**, tela **vertical** (mobile-first);
- O planeta **se transforma**: cada região conquistada REVELA o bioma
  da civilização dona (deserto do cowboy, cristais do alien...).

**Estado atual: partida completa jogável** — 6 civilizações (jogador +
5 bots), cerimônia de abertura com naves, conquista pintando a pele do
planeta, corte/vida/eliminação, herança de império, evento meteoro,
minimapa-bússola, joystick de toque, pódio final. Roda a ~45 FPS em
notebook modesto.

## 2. As pessoas e os papéis

- **André** — Diretor do projeto e dono do design. NÃO programa: dirige
  visão, testa, aprova e produz os assets 3D (Tripo AI). **Toda decisão
  de design passa por ele.**
- **Paulo** — desenvolvedor (você!).
- **Claude** (IA, no computador do André) — CTO/arquiteto técnico;
  escreveu o código existente sob direção do André.

## 3. A lei do projeto: o GDMD

O **Game Design Master Document** (pasta `D:\JOGO (TERRAFORGE)` no PC
do André; peça os arquivos a ele) é a **verdade absoluta** do design.
Toda regra tem um número (**DD-xxx** = Design Decision). No código você
verá comentários citando `DD-102`, `DD-110` etc. — são referências a
esse documento.

Regras de ouro:
1. **Não altere um comportamento de design sem aprovação do André**;
2. Se dois documentos/códigos discordarem: vale o DD mais recente; em
   empate, **o que o código implementa**;
3. Números de DD nunca são reutilizados (índice mestre no GDMD).

## 4. Arquitetura do código (o mapa)

Projeto Unity **6.3 LTS (6000.3.19f1)**, URP, **Input System novo**,
retrato. Projeto em `Terraforge/`, código em
`Assets/_Project/Code/`, organizado em **7 módulos** (Assembly
Definitions) que o compilador OBRIGA a ficarem desacoplados:

```
Core      ← todos os outros referenciam SÓ ele
Gameplay  (corredor, rastro, vida, câmeras)
World     (planeta, território, pintura, temas, base)
AI        (bots)
UI        (HUD por código: corações, placar, minimapa...)
Audio     (vazio ainda)
Network   (vazio — multiplayer é a FASE FINAL, DD-103)
```

**Comunicação entre módulos: só por eventos.** O `EventBus` (Core) é o
correio: `EventBus.Publish(new TrailCutEvent(...))` e quem quiser ouve
com `Subscribe`. Módulos NUNCA se referenciam diretamente; serviços
compartilhados usam localizadores (`PlanetLocator`,
`TerritoryOwnershipLocator`...) definidos no Core.

### Os sistemas principais

| Sistema | Onde | Como funciona |
|---|---|---|
| Gravidade esférica | `Gameplay/PlanetRunner` | posição = centro + direção×raio; `IPlanet.GetSurfaceRadius` sonda o relevo real via raycast |
| Território | `World/TerritoryMap` | 20.000 células (esfera de Fibonacci), dono por célula (byte), conquista por inundação do exterior, ZERO alocações em jogo |
| Pintura | `World/TerritoryPainter` + shader `Terraforge/PlanetSurface` | mapa equiretangular global; o shader troca a cor/textura DO PRÓPRIO planeta (nada é criado por cima) |
| Vida | `Gameplay/Health` | 16 pontos (4 corações × 4); corte = 2; regen no campo de força; zerou = eliminado (espectador) |
| Cerimônia | `World/MatchSetup` + `HomeTerritory` | naves descem, contagem 5..1 GO, relógio de 600s só então dispara |
| Eventos globais | `World/MeteorEventSystem` | máquina de estados aviso→impacto→cicatriz; 7 eventos planejados (1 pronto) |
| Bots | `AI/BotSteering` | caçam rastros, avaliam risco, recuam; meta: parecer humano (DD-101) |
| PLS / Biomas | `World/PlanetTheme*` | veja a seção 5 — é o sistema em construção AGORA |

## 5. O que está sendo construído: o PLS

O **Planet Layer System** (Adendo 04, DD-114, regra IMUTÁVEL): o
planeta **nunca cria nem destrói nada** — ele **REVELA**. Vários
"planetas temáticos" ocupam o mesmo espaço; conquista = trocar qual
tema é visível naquela região.

Cada civilização é definida por **uma ficha** (`PlanetTheme`,
ScriptableObject em `Assets/_Project/Art/PlanetThemes/`) com **18
slots** (DD-120): 5 de gameplay (personagem, nave, domo, meteoro,
rastro) + 13 de ambiente (E00 = textura do chão; E01–E12 = vegetação,
rochas, estruturas, decoração, landmark). **Criar civilização nova =
preencher uma ficha. Zero código.**

Progresso das fases:
- ✅ **Fase 1** — o contrato (ficha + registro + gerador no menu
  `Terraforge > Gerar Planet Themes`);
- ✅ **Fase 2** — terreno: textura E00 por civilização (atlas
  Texture2DArray, projeção triplanar) + variação procedural por
  ruído/seed (nenhuma partida é igual);
- ✅ **Fase 3** — slots ambientais (`EnvironmentSlotSystem`,
  auto-instalado): centenas de posições sorteadas por seed, invisíveis
  no planeta neutro; conquista revela o equivalente do tema dono
  (densidade via Biome DNA), morte revela o gêmeo morto (DD-122),
  troca de dono troca o conteúdo via pooling;
- 🔜 **Fase 4** — a transformação orgânica completa de 0,8–1,2s
  (DD-117; o crescimento básico de ~0,9s já existe);
- 🔜 **Fase 5** — Biome DNA vivo (partículas, luz, clima por tema).

## 6. Como trabalhamos

- **Fluxo git:** `git pull` SEMPRE antes de começar; commits pequenos e
  descritivos; `git push` ao terminar. LFS para binários (já
  configurado). Merge inteligente de cenas Unity via UnityYAMLMerge
  (veja SETUP_EQUIPE.md).
- **A cena é zona sensível:** `SampleScene.unity` é única — **avise no
  grupo antes de mexer nela** para evitar conflitos de merge.
- **Performance é requisito**, não luxo: o jogo tem que rodar liso em
  celular. Nada de alocações por frame, nada de Instantiate em jogo
  (pooling), texturas 2K, orçamento de polígonos (DD-119).
- **Assets 3D:** o André produz (Tripo AI) e processa (pipeline
  Blender). Nunca decimar arte pronta — pede-se versão low-poly nativa.
- **Comentários e nomes** em português, estilo dos arquivos existentes.

## 7. Roadmap resumido

1. **PLS Fases 3–5** (biomas completos) ← estamos aqui
2. Conteúdo do Velho Oeste (18 slots — checklist no GDMD)
3. Demais eventos globais (6 restantes), bônus (SYS-005), defensores
   (SYS-006)
4. Áudio
5. Polimento mobile + builds Android (menu `Terraforge > Build Android
   APK`)
6. **Multiplayer** (fase final — o jogo comercial é SÓ multiplayer;
   bots viram preenchimento)

## 8. Onde pedir ajuda

- Dúvida de design → André (e o GDMD);
- Dúvida de código → leia o módulo Core primeiro (é pequeno e é a
  espinha de tudo); os comentários dos arquivos explicam o porquê das
  decisões;
- Console vermelho após pull → `git lfs pull` e reimporte; persiste?
  Avise no grupo.

Bem-vindo a bordo! 🚀🌍
