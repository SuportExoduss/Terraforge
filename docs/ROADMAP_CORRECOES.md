# Roadmap de correções (2026-11-14)

Origem: o que sobrou do Passo 102 (`REVISAO_GDMD_vs_JOGO.md` e Adendo 08, parte E).
**As decisões abaixo foram tomadas pelo Claude a pedido do André ("você decide por mim")**. Ele pode trocar qualquer uma; as decisões foram registradas na Fase 0 (Adendo 09, DD-138..145).
Ordem = risco primeiro: o que pode invalidar o resto vem antes do que só acrescenta.

## Decisões (no lugar do Diretor)

| Pendência | Decisão | Por quê |
|---|---|---|
| Teste no celular (DD-124 a/c) | **Fazer já, é a Fase 1.** No celular mais fraco que o André tiver | Maior risco do projeto: a migração inteira só está aceita se rodar ≥ 45 FPS no aparelho. O resultado diz quanto "orçamento" sobra para o resto |
| Passe, anúncios, compras no app | **REVISADO (DD-144): entram, só cosméticos; cobrança real liga com conta de loja** | O André pediu skins e compras no app. Antes valia "fora da v1"; o pedido novo é mais recente. Ver `PRODUTO_VISAO_CRIADOR.md` |
| G06 (defensor por civilização) | **Touro Blindado para todas na v1** | Já é o que o jogo faz; modelo novo por civilização é arte, depois da v1 |
| Território de civilização eliminada | **Vira ruína (piso morto do DD-122) e continua podendo ser conquistado** | Mostra a eliminação sem criar regra nova; continua dando presa para os outros |
| Balanceamento item 6 (planeta enche ~480 s) | **Não mexer agora; decidir depois de um playtest com gente de verdade** | Cada civilização que perde território devolve terra à briga, então "cheio" não é "parado". Só um humano diz se os últimos 2 min ficam chatos |
| DD-009 ("PREPARANDO A PARTIDA" ~1,1 s) | **Manter** | Esconde a carga; reavaliar só se no celular passar de ~2 s |
| Menu em ícones (Cap 03) | **Menu de texto na v1** (DD-136) | Depende da arte do menu |
| IDs do Cap 04 sem marca no código | **Não fazer agora** | Só anotar quando eu mexer no arquivo; sem valor para o jogo |

## Fases

| Fase | O que | Tamanho | Depende de |
|---|---|---|---|
| **0** | Registrar as decisões acima no GDMD (Adendo 09, DD-138 em diante) e no índice | pequeno | só do OK do André |
| **1** | **Celular**: exportar o APK Android, instalar, medir FPS e tempo de carga, testar giro/toque/paisagem. Consertar o que o aparelho mostrar. Passo a passo com o André (instalar SDK/JDK em D:, o C: está cheio) | grande | um celular |
| **2** | **Fechar o Touro (G06)**: o trabalho do André em `defender_system.gd`, `home_base.tscn`, `planet_runner.gd` etc. está sem commit. Revisar, rodar os smokes e commitar | pequeno | André terminar a arte |
| **3** | **Online jogável**: hoje o cliente online é um tabuleiro 2D. Levar a partida 3D para a rede (planeta e corredores remotos com interpolação), liberar as civs 2–6, hospedar pela tela ONLINE | grande, em vários passos | Fase 1 (para saber o custo no celular) |
| **4** | **Regras que faltam do DD-109**: bicho pequeno (1/16) e "cada território ativa 5 dos 8 elementos" | médio | Fase 1 (cada ator novo custa FPS) |
| **5** | **Acabamento do jogo**: ruína da eliminada; 8 % de "circuitos vazios" e 6 avisos "cerca sem área" (laços de 3–6 células); pico de 44 ms na virada do fim de partida (pintura pendente 92 → 3694) | pequeno cada | Fase 1 (o pico só importa se aparecer no aparelho) |
| **6** | **Playtest com gente** e decisão do balanceamento (item 6) | médio | Fases 1 e 3 |
| **Arte (André)** | Modelos E01m–E12m (hoje cai no fallback escuro), cosméticos da cerca, menu "dentro do planeta" em ícones, defensor por civilização | — | André |
| **Produto** | Backlog completo e ordem de construção (passos 103+): `docs/PRODUTO_VISAO_CRIADOR.md` | — | — |

Regra de trabalho: um passo por vez, com smoke novo para cada correção e regressão completa antes de cada commit.
