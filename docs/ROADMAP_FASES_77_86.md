# Roadmap — Passos 77 a 86 (pedido "rode mais 10 fases", 2026-11-11)

Vêm do GDMD Cap.03: P07 (SYS-004 Eventos globais — a MANADA ainda não existia e o BALANCEAMENTO pede "intensidade aumenta conforme a
partida avança" e "eventos simultâneos dependem do tamanho do planeta e da quantidade de jogadores"), P08 (SYS-005 Bônus — INTERFACE:
"ícone exclusivo, contador, indicador de duração, animação de ativação"; DD-028 "forte feedback visual"), P09 (SYS-006 Defensores —
"identidade visual única para cada civilização") e P11 (Encerramento — o replay mostra "grandes eventos" e "mudanças climáticas").
Regra: 1 commit local por passo (nunca `push`), smoke novo + regressão do trecho verde antes de cada commit; nenhum sinal do EventBus
muda de assinatura (só nasce sinal novo). O trabalho de arte do André (modelos, `.import`, cenas, touro) não entra nos commits.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 77 | Evento MANADA | SYS-004 (lista de eventos), DD-107 | 5 touros em V cruzam uma faixa avisada no chão, atropelam (3 pts + volta à base) e deixam pegadas + cristais |
| 78 | Intensidade crescente | SYS-004 BALANCEAMENTO | os eventos ficam mais frequentes (intervalo menor) conforme a partida avança |
| 79 | Simultâneos por civilização | SYS-004 BALANCEAMENTO | o limite de eventos ao mesmo tempo cresce com o número de civilizações em jogo |
| 80 | Ícone exclusivo do bônus | SYS-005 INTERFACE, DD-028 | cada bônus ativo na coluna da HUD tem ícone/cor próprios |
| 81 | Indicador de duração | SYS-005 INTERFACE | barra que esvazia sob cada bônus temporário |
| 82 | Animação de ativação | SYS-005 INTERFACE, DD-028 | o ícone "pula" ao ativar; respeita "Reduzir movimento" |
| 83 | Marca da civilização no defensor | SYS-006 identidade visual | cada defensor leva a cor da civilização dona do território |
| 84 | Tela EVENTOS | SYS-004 ACEITAÇÃO "facilmente compreendidos" | tela no menu explica cada evento (aviso, efeito, cicatriz) |
| 85 | Clima no replay | P11 REPLAY "mudanças climáticas" | a legenda do replay anota chuva/neblina/tempestade (sinal novo no EventBus) |
| 86 | Eventos vividos nos resultados | P11 RESULTADO | a tela de resultado conta quantos eventos o jogador enfrentou/escapou |

Status:
- Passo 77 ✔ (evento MANADA: `StampedeEvent` (`scripts/world/stampede_event.gd`, nó `Stampede` em `match.tscn`) herda `GlobalEvent`; AVISO: a faixa por onde a manada vai passar acende no chão (14 caixas planas âmbar, 20 u de largura) e o minimapa aponta o meio dela; EXECUÇÃO: 5 touros do defensor (esqueleto, animação Trot, 1,5× o tamanho) em V correm 22 u/s por 6 s pelo círculo máximo; quem fica a 3 u de algum touro leva 3 pts "MANADA" e volta ao campo de força (2 s de folga por corredor, como o Furacão); CICATRIZ: 20 pegadas que somem aos poucos + 2 a 3 cristais onde a manada parou; nunca mexe no território (DD-024); smoke_stampede; smoke_event_gate agora cobre 8 eventos; smoke_approach passa a esperar por tempo real (os 12 modelos E01–E12 levaram a carga da partida de ~17 s para ~46 s em modo sem janela))
- Passo 78 ✔ (intensidade crescente: `GlobalEvent.pace()` encolhe o intervalo sorteado entre dois eventos de 100 % no começo da partida para 50 % no fim, linear pelo relógio da partida; vale para os eventos da base e para o Meteoro (ciclo próprio); a paz inicial e a paz final continuam como eram; smoke_event_pace)
- Passo 79 ✔ (simultâneos por jogadores: `GlobalEvent.limit()` = 1 + 1 a cada 3 corredores além do primeiro (1–3 corredores → 1, 4–6 → 2); o portão (`gate_open`) passa a usar esse limite — DD-128 segue valendo para quem joga sozinho: 1 corredor = nunca 2 eventos juntos; o planeta tem um tamanho só, então só a quantidade de jogadores conta; smoke_event_limit: com 6 corredores chegam a 2 eventos juntos e nunca a 3)
- Passo 80 ✔ (ícone exclusivo: cada bônus ativo na coluna da HUD vira uma linha `Row_<nome>` com ficha `Chip` (quadrado arredondado na cor do cristal + símbolo `»` velocidade, `R` recuperação, `+` vida extra, `*` congelamento, `O` escudo, `!` congelado) e o contador ao lado; o tamanho da ficha segue o ajuste TEXTO; smoke_bonus_hud confere que as 6 fichas têm cor e símbolo diferentes e que o bônus de outro dono não aparece)
- Passo 81 ✔ (indicador de duração: sob a ficha de cada bônus temporário há uma barra `Bar` na cor do cristal que começa cheia e esvazia até acabar o efeito; o bônus instantâneo (Vida Extra pega na hora, etc.) não tem barra; smoke_bonus_hud confere cheia no começo, esvaziando com o tempo e escondida no instantâneo)
