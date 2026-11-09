# Roadmap — Passos 39 a 43 (loop "mais 5 passos", 2026-11-09)

Derivado do GDMD Cap.03 Parte 01 (Abertura do jogo, Menu principal, Primeiro clique em "Jogar", DD-006..008) contra o que o menu ainda não tem.
Regra: 1 commit por passo, smoke novo + regressão verde antes de cada commit; nenhum sinal antigo do EventBus muda de assinatura.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 39 | Abertura viva | Cap.03 P01 ABERTURA, DD-006 | `PlanetBackdrop` no fundo do menu: planeta girando, nuvens, atmosfera, estrelas, auroras ocasionais e meteoros |
| 40 | Primeiro clique em JOGAR | Cap.03 P01, DD-007 | a câmera do menu aproxima e atravessa a atmosfera enquanto a partida carrega em segundo plano; sem tela estática |
| 41 | Civilizações | Menu principal, Adendo 03 | galeria das 6 civilizações e escolha da civilização do jogador (gravada no Profile, vale na partida) |
| 42 | Perfil | Menu principal | tela com nível, XP, moedas, partidas, totais acumulados e conquistas |
| 43 | Loja cosmética | Menu principal, Cap.01 "monetização apenas cosmética" | catálogo de cores de rastro/cerca comprado com moedas do perfil; equipado vale na partida; sem vantagem de jogo |

Status:
- Passo 39 ✔ (Abertura viva: PlanetBackdrop no fundo do menu — planeta girando, nuvens, atmosfera, estrelas, aurora e meteoros; DD-006; smoke_backdrop; regressão 48/48)
