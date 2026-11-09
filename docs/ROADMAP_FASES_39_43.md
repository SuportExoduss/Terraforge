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
- Passo 40 ✔ (Primeiro clique: câmera do menu mergulha no planeta enquanto a partida carrega em segundo plano; DD-007; smoke_approach; regressão 49/49)
- Passo 41 ✔ (Civilizações: galeria no menu com as 6 do GDMD, só as com arte são escolhíveis, escolha no perfil e valendo na partida via PlanetThemeRegistry; smoke_civilizations; regressão 50/50)
- Passo 42 ✔ (Perfil: tela PERFIL no menu com nível, barra de XP, totais e conquistas feitas/pendentes; smoke_profile_screen; regressão 51/51)
- Passo 43 ✔ (Loja cosmética: cores de cerca compradas com moedas do perfil, só aparência; smoke_shop; regressão 51/52 + replay OK isolado 3x — flaky sob carga)
