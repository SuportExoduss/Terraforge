# Roadmap — Passos 72 a 76 (pedido "rode mais 5 fases", 2026-11-11)

Todos vêm do GDMD Cap.03 P05 (SYS-002 Conversão) e P06 (SYS-003 Vidas), que ainda tinham lacunas: o critério de aceitação
"o jogador entende imediatamente por que perdeu uma vida", a proteção curta de retorno ("respawn" = voltar ao campo de força),
o "evitar sequência de eliminações sem chance de reação", o "perder uma vida deve causar tensão e impacto" (DD-021) e os
"sons exclusivos" de cada civilização na conversão.
Regra: 1 commit por passo, smoke novo + regressão do trecho verde antes de cada commit; nenhum sinal do EventBus muda de assinatura
(só nasce sinal novo). O trabalho de arte do André (modelos, `.import`, cenas) não entra nos commits.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 72 | Motivo da perda de vida | SYS-003 ACEITAÇÃO, DD-021 | `Health.take_damage(n, causa)` publica o sinal novo `damage_taken`; a HUD escreve "-N CAUSA" (rastro cortado, vulcão, defensor...) sob os corações |
| 73 | Proteção ao voltar ao campo | SYS-003 RESPAWN/BALANCEAMENTO | depois de ser devolvido ao campo de força (corte, anel interno de evento) o jogador fica 2 s imune a dano direto, sem perder movimento nem conquista |
| 74 | Flash de dano | SYS-003 FILOSOFIA, DD-021 | a tela pisca vermelha ao perder vida (mais forte quanto mais pontos); respeita "Reduzir movimento" |
| 75 | Som de conversão por civilização | SYS-002 "sons exclusivos" | o som da conversão muda de timbre conforme a civilização do jogador |
| 76 | Último coração | SYS-003 FILOSOFIA "tensão" | com 4 pontos ou menos a HUD pulsa o coração final e toca um batimento; respeita "Reduzir movimento" |

Status:
- Passo 72 ✔ (motivo da perda: `EventBus.damage_taken(victim_id, points, cause)` só quando o dano de fato desconta (escudo não conta); causas: RASTRO CORTADO, IMPACTO (meteoro/verme), FURACÃO, VULCÃO, TSUNAMI, TERREMOTO, CHUVA ÁCIDA, DEFENSOR; `Hud._on_damage` mostra "-N  CAUSA" por 2 s no `CauseLabel`; smoke_damage_cause)
