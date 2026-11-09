# Roadmap — Passos 44 a 48 (loop "mais 5 passos", 2026-11-09)

Derivado do GDMD Cap.03 Parte 03 ("Os primeiros 60 segundos", DD-012..014) contra o que a partida ainda não tem, e do que o
Passo 38 deixou pendente (cliente visual do lobby).
Regra: 1 commit por passo, smoke novo + regressão verde antes de cada commit; nenhum sinal antigo do EventBus muda de assinatura.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 44 | Primeira conquista espetacular | Cap.03 P03 20–30 s, DD-013, DD-014 | anel de luz + faíscas no centro da primeira área que o jogador fecha, uma vez por partida, sem texto |
| 45 | Começo calmo | Cap.03 P03 30–45 s, DD-012 | bots cautelosos no começo: a ambição sobe de forma gradual até o pleno em ~45 s (poucos confrontos no 1º minuto) |
| 46 | Tela ONLINE | Cap.04 lobby (Passo 38) | tela no menu para entrar na sala de um servidor dedicado, com o status do lobby (jogadores/capacidade, tempo) |
| 47 | Partida online no cliente | Cap.04 lobby, Adendo 06 | quando a sala fecha, a tela ONLINE mostra o quadro da partida (corredores, tempo, ranking) e envia a direção ao servidor |
| 48 | A definir após o 47 | — | — |

Pendente de decisão do André (não implementado): Cap.03 P03 diz "nenhum evento global antes de 60 s" e "bônus raro só após 45 s",
mas o DD-106 (Adendo 02, já no código) usa paz de 25 s. Os dois valores se contradizem.

Status:
- Passo 44 ✔ (Primeira conquista: anel de luz + faíscas na primeira área fechada pelo jogador, DD-013; smoke_first_conquest; regressão 53/53)
- Passo 45 ✔ (Começo calmo: bots só caçam rastro inimigo depois de 15 s, alcance sobe até o pleno aos 45 s, DD-012; smoke_calm_start; regressão 54/54)
- Passo 46 ✔ (Tela ONLINE: entra na sala de um servidor dedicado e mostra jogadores/capacidade e o tempo; só ENTRAR, hospedar = servidor dedicado; smoke_online_screen; regressão 55/55)
- Passo 47 ✔ (Partida online no cliente: ao fechar a sala, a tela ONLINE abre o quadro 2D (OnlineBoard) com corredores, tempo e ranking do snapshot e manda ← →; smoke_online_board; regressão 56/56, replay passou sozinho após falha de carga)
