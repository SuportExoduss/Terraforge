# Roadmap — Passos 29 a 38 (loop "mais 10 fases", 2026-11-09)

Derivado do GDMD (Cap. 04 consolidação, Cap. 05 módulos AUDIO/UI/EVENTOS, Cap. 06 partes 05–07) contra o que o código ainda não tem.
Regra: 1 commit por passo, smoke novo + regressão verde antes de cada commit; nenhum sinal antigo do EventBus muda de assinatura.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 29 | Áudio base | Cap.05 AUDIO, UI-004 | `AudioDirector`: sons sintetizados por código (sem arquivos) reagindo ao EventBus: captura, corte, dano, bônus, aviso de evento, fim de partida; barramentos Master/SFX/Música |
| 30 | Música e som ambiente | BD-007, CL-007 | música procedural em loop + ambiente que muda com o bioma dominante/evento |
| 31 | Ciclo dia/noite | CL-001, CL-006 | `DayNightCycle` guiado pelo cronômetro: Sol + ambiente, transição gradual, legibilidade garantida |
| 32 | Clima | CL-002..005, DD-086..088 | gerenciador de clima (chuva, neblina, aurora), transições suaves, eventos globais sobrepõem |
| 33 | Minimapa estratégico | MP-003..007 | zoom (pinça/roda), eventos ativos e direção dos grandes, bônus destacados |
| 34 | Configurações | UI-006 | tela de opções (volumes, qualidade) gravada no perfil, ligada ao áudio |
| 35 | Otimização | OP-001..006, DD-092..094 | LOD/culling dos objetos distantes, atualização incremental, medidor de quadros no smoke |
| 36 | Registro de eventos + ordem de atualização | Cap.05 P07, DD-071..073 | log de depuração do EventBus (anel) e ordem determinística dos módulos |
| 37 | Rede: dessincronia + interpolação | Cap.04 (auditoria/correção) | detector automático por hash de checkpoint e interpolação dos jogadores remotos |
| 38 | Rede: lobby/matchmaking + servidor dedicado | Cap.04 fluxo, Adendo 06 | estados Matchmaking→Lobby e entrada `--headless --server` |

Status:
- Passo 29 ✔ (AudioDirector, smoke_audio; regressão 38/38)
- Passo 30 ✔ (MusicDirector: música em 2 camadas + ambiente por civilização líder; smoke_music; regressão 39/39)
- Passo 31 ✔ (DayNightCycle: Sol e ambiente seguem o relógio, pisos de luz; smoke_daynight; regressão 41/41)
- Passo 32 ✔ (WeatherManager: chuva/neblina/tempestade/aurora por semente, evento global sobrepõe; smoke_weather; regressão 41/41)
- Passo 33 ✔ (minimapa estratégico: zoom, marcas de evento/rumo, bônus; smoke_minimap_strategy; regressão 42/42)
