# Roadmap — Passos 49 a 58 (loop "faça mais 10 fases", 2026-11-09)

Derivado do GDMD Cap.03 Partes 01–03 (abertura, matchmaking, regras do 1º minuto), Cap.05 Parte 06 (UI-006 Configurações,
"boa acessibilidade") e do que os Passos 46–48 deixaram pendente (uso real da tela ONLINE).
Regra: 1 commit por passo, smoke novo + regressão verde antes de cada commit; nenhum sinal antigo do EventBus muda de assinatura.

| # | Passo | GDMD | Entrega |
|---|---|---|---|
| 49 | Música do menu | Cap.03 P01 MÚSICA, DD-006 | trilha suave no menu (hoje o menu é mudo); uma camada nova entra quando o jogador abre uma tela; some ao começar a partida |
| 50 | Lembrar a sala online | Cap.04 lobby | endereço e porta da última sala ficam salvos no perfil e voltam preenchidos na tela ONLINE |
| 51 | Latência na tela ONLINE | Cap.03 P02 "melhor latência possível" | o status mostra o ping (ms) até o servidor, atualizado durante a sala e a partida |
| 52 | Criar sala | Cap.04 lobby, Passo 38 | botão CRIAR SALA na tela ONLINE: abre um servidor dedicado local (2 vagas) e entra nele; outro PC entra pelo endereço |
| 53 | Nível de habilidade | Cap.03 P02 matchmaking ("habilidade semelhante") | rating simples no perfil (sobe/desce conforme a posição final) e mostrado na tela PERFIL |
| 54 | Bots no nível do jogador | DD-066 (bots simulam jogadores reais) | a ambição dos bots acompanha o rating do jogador (fraco = bots mais calmos, forte = bots mais agressivos) |
| 55 | Sensibilidade do giro | UI-006 Configurações | controle "GIRO" nas configurações (50%–150%), aplicado à direção do corredor |
| 56 | Reduzir movimento | UI-006, Cap.05 P06 "boa acessibilidade" | opção que desliga o brilho/tremida da HUD e meteoros/auroras do fundo do menu |
| 57 | Bônus raro só após 45 s | Cap.03 P03 REGRAS | nenhum bônus raro cai antes de 45 s de partida |
| 58 | Spawn justo | Cap.03 P02 CRITÉRIOS DE SPAWN | distância mínima entre as bases e nenhuma base perto de evento ativo, travado por smoke |

Pendente de decisão do André (não implementado): o GDMD Cap.03 P03 diz "nenhum evento global antes de 60 s", mas o código
usa 25 s de paz (DD-106). Balanceamento do item 6 (planeta enche em t≈375–465 s). Lista de modelos por civilização (txt/PDF).
Ordem dos nomes das civilizações (suposição). Cópia de segurança do disco D:.

Status:
- Passo 49 ✔ (música do menu: MenuMusic com base suave, camada de pulso entra ao abrir uma tela, some no mergulho; smoke_menu_music; regressão 58/58)
- Passo 50 ✔ (sala online lembrada: endereço e porta no perfil, tela ONLINE volta preenchida; smoke_online_saved; regressão 59/59)
- Passo 51 ✔ (ping na tela ONLINE: NetSession.ping_ms() mede a ida e volta pelo ENet; aparece no status da sala e no quadro da partida; smoke_online_ping; regressão 60/60)
- Passo 52 ✔ (CRIAR SALA na tela ONLINE: sobe um servidor dedicado de 2 vagas num processo à parte e entra nele; SAIR/CANCELAR/fechar a tela encerram o processo; smoke_online_host; regressão 61/61)
- Passo 53 ✔ (nível de habilidade: rating do perfil começa em 1000, sobe/desce pela colocação (+25/+10/0, -15 do 4º para baixo), gravado na apuração e mostrado em PERFIL; smoke_rating; regressão 62/62)
