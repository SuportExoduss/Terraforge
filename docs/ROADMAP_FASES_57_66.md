# Roadmap — Passos 57 a 66 (pedido "faça os restantes e dê continuidade em mais 10 passos", 2026-11-10)

57 e 58 vêm do `ROADMAP_FASES_49_58.md` (André pediu para parar no 56). 59–66 foram derivados do GDMD contra o que o código
ainda não faz: Cap.03 P08 (bônus guardados), Cap.05 P05 (IA responde a eventos, comportamento distinto por civilização),
Cap.03 P06 (respawn longe de confrontos), Cap.03 P11 (planeta final: aproximar a câmera, observar cada civilização) e
Cap.05 P06 (UI-006, "boa acessibilidade").
Regra: 1 commit por passo, smoke novo + regressão verde antes de cada commit; nenhum sinal antigo do EventBus muda de assinatura.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 57 | Bônus raro só após 45 s | Cap.03 P03 REGRAS | Vida Extra e Escudo Temporal ("raros": interpretação, o GDMD não lista quais) ficam fora do sorteio até 45 s de partida |
| 58 | Spawn justo | Cap.03 P02 CRITÉRIOS DE SPAWN | o pouso da nave (base nova) fica a ≥ 0,5 rad de outra base e ≥ 0,4 rad de evento em aviso/execução; as 6 bases da abertura já ficam a ≥ 90° (faces do cubo); obstáculo já é tratado pelo ObstacleSystem |
| 59 | Bônus guardados | Cap.03 P08 USO, DD-029 | Recuperação e Vida Extra seguem automáticos; Velocidade, Congelamento e Escudo Temporal vão para o estoque (limite 3); estoque cheio = cristal fica no chão; bots usam o que guardam depois de uns segundos |
| 60 | Usar o estoque | Cap.03 P08 INTERFACE, Cap.05 P06 HUD | tecla ESPAÇO (e toque na coluna da direita) usa o próximo bônus guardado; a coluna mostra o estoque (nome + contador) |
| 61 | Bots fogem de evento | Cap.05 P05 "Resposta aos eventos" | bot não sai em surtida para perto de evento em aviso/execução e, se já estiver perto, volta para a base |
| 62 | Personalidade por civilização | Cap.05 P05 DD-065 / critério "comportamentos distintos" | cada bot tem um perfil fixo pelo id da civilização (caçador, cauteloso, ousado, oportunista, paciente) que ajusta alcance de caça, surtida, exposição e cobiça por bônus |
| 63 | Pouso longe de confrontos | Cap.03 P06 RESPAWN | o pouso também evita corredores adversários em campo (≥ 0,3 rad) |
| 64 | Zoom na contemplação | Cap.03 P11 PLANETA FINAL | roda do mouse / +- aproximam e afastam a câmera do planeta final (com limites) |
| 65 | Observar cada civilização | Cap.03 P11 "observar cada civilização" | na contemplação, TAB gira a câmera para a base da próxima civilização |
| 66 | Texto grande | UI-006, Cap.05 P06 "boa acessibilidade" | ajuste TEXTO (100%–150%) nas configurações, aplicado aos textos da HUD |

Pendente de decisão do André (não implementado): GDMD Cap.03 P03 "nenhum evento global antes de 60 s" vs 25 s de paz do código
(DD-106); balanceamento item 6 (planeta enche em t≈375–465 s); quais bônus são "raros" (57) e quais ficam guardados (59) — as duas
listas são minha interpretação; ordem dos nomes das civilizações (perfis do 62 usam só o id).

Status:
- Passo 57 ✔ (bônus raro só após 45 s: `BonusSystem.RARE` = Vida Extra + Escudo, `pick_kind(elapsed)`; smoke_rare_bonus)
- Passo 58 ✔ (pouso justo em `HomeTerritory.is_fair_spot`; smoke_fair_spawn)
- Passo 59 ✔ (estoque de bônus: `BonusSystem.STORED`/`STOCK_LIMIT`/`use_next`/`stock_of`, sinal `bonus_stock_changed`; bots usam sozinhos após `bot_use_delay`; smoke_bonus_stock; o estoque NÃO é salvo na reconexão — ponytail)
- Passo 60 ✔ (usar o estoque: HUD botão "Stock" + ESPAÇO → `EventBus.bonus_use_requested` → `BonusSystem.use_next`; toque no botão não vira direção; smoke_bonus_use)
