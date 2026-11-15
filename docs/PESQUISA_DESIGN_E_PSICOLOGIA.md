# Pesquisa: como se faz um jogo assim — e a psicologia por trás (2026-11-14)

Notas de André-dono-do-jogo (Claude). Fontes marcadas **[boa]** (autor identificado / pesquisa) ou **[opinião]** (blog de prática). Sites-espelho e páginas geradas por IA foram descartados.

## 1. Por que as pessoas jogam (e voltam)
- **Teoria da Autodeterminação** — o jogo motiva "por dentro" quando satisfaz 3 necessidades: **autonomia** (escolho), **competência** (fico melhor, "fácil de aprender, difícil de dominar"), **relação** (ligação com outros). [Frontiers, estudo de caso SDT em jogos](https://www.frontiersin.org/articles/10.3389/frvir.2022.847120/pdf) **[boa]**; [Liftoff](https://liftoff.io/?p=18729) **[opinião]**.
- **12 motivações da Quantic Foundry** (400 mil+ jogadores): Destruição, Excitação, Competição, Comunidade, Desafio, Estratégia, Completar, Poder, Fantasia, História, Design (criar/personalizar), Descoberta. [Quantic Foundry](https://quanticfoundry.com/) **[boa]**.
- **Terraforge hoje cobre:** Competição, Estratégia, Desafio, Excitação (cercar e fechar), Completar (conquistas), Design (cosméticos). **Falta:** Comunidade (clã/amigos), Descoberta (planetas diferentes), Fantasia/História (civilizações com identidade).

## 2. Fluxo e dificuldade
- Dificuldade logo acima da habilidade = fluxo; abaixo = tédio; muito acima = frustração. Se a retenção cai num ponto, a dificuldade ali está errada. [Game Developer](https://www.gamedeveloper.com/design/difficulty-curves-how-to-get-the-right-balance-) **[boa]**; [Pocketgamer.biz](https://www.pocketgamer.biz/difficulty-curves-find-the-right-balance-and-boost-retention-and-revenue) **[opinião]**.
- **Paper.io 2** (o parente mais próximo do Terraforge): a dificuldade sobe sozinha porque o território cresce e a arena enche; o risco é "sair longe demais de casa"; a parede é zona segura; logo depois de matar um bot o território dele fica vazio (janela de oportunidade); visão limitada é fonte de tensão; porcentagem de território vira a "barra de missão" da vida toda; morte em 3 tempos (rastro some, explosão, território some) dá fechamento; **bug de território que some faz o jogador desistir**. [Game Developer — Paper.io 2](https://gamedeveloper.com/design/paper-io-2-a-natural-difficulty-curve) **[opinião, 1 autor]**.

## 3. Loops, economia, retenção (como analisar um jogo)
- Analisar = mapear **ação → recompensa → progresso** (loop central, minutos), depois **o que o meta-loop gasta do que o loop central ganha** (meses), e se a economia tem **ralos** (coisas para gastar) que mantêm a moeda importante. [Deconstructor of Fun — Core Loops](https://www.deconstructoroffun.com/blog//2013/10/mid-core-success-part-1-core-loops.html) **[boa]**.
- **Clash Royale:** baú grátis a cada 4 h (abrir o app já premia); meta de sessão (10 coroas → baú); 4 vagas de baú = limite **"macio"** (continua jogando, só não progride); partidas curtas; clã dá motivo para ficar. [Deconstructing Clash Royale](https://mobilefreetoplay.com/deconstructing-clash-royale/) **[opinião, 2016]**.
- **Brawl Stars:** passe só por dinheiro real, com 2–3 **conjuntos de cosméticos** como isca (e não mais um personagem); missões diárias; **ralos de moeda** (5.000 moedas por Hipercarga); ofertas em degraus; sequência de vitórias; removeu caixa paga e substituiu por sorteio grátis; recorde de receita e D30 em jan/2024. [Deconstructor of Fun — Brawl Stars to the Moon](https://deconstructoroffun.com/blog/2024/2/11/brawl-stars-to-the-moon) **[opinião, estimativas de terceiros]**.

## 4. Loja, cor e menu
- **Uma cor de ação só**, a de maior contraste, sempre no mesmo lugar do fluxo; o resto neutro. O que importa é o **contraste**, não o matiz. Texto ≥ 4,5:1. [UXmatters](https://uxmatters.com/mt/archives/2020/02/capture-attention-through-color-psychology.php), [Tubik](https://tubikstudio.com/blog/call-for-attention-powerful-cta-button-design/) **[opinião]**.
- **Carga cognitiva:** poucas escolhas por tela; ordenar loja por **categoria**, não por preço; oferta em destaque no centro com o jogo visível atrás. [Rookies — UX do Clash Royale](https://discover.therookies.co/2020/02/24/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/), [Game Developer — 5 padrões de monetização](https://www.gamedeveloper.com/business/5-incredibly-powerful-f2p-monetisation-patterns-using-behavioural-economics-in-ux-design-) **[opinião]**.
- **Por que se compra skin:** (1) ser único, (2) marcar presença, (3) estética, (4) status, (5) identidade de comunidade; o motivo nº 1 é "gosto de como fica". Cosmético > poder (3× mais gente aceita gastar com aparência). [Power in Skin (NJIT, Fortnite)](https://digitalcommons.njit.edu/fac_pubs/4853) **[boa]**; [Univ. Illinois](https://www.ideals.illinois.edu/items/114139) **[boa]**. Alerta de justiça: quem quer se ver representado não pode pagar mais caro por isso.

## 5. "Juice" (sensação de jogo) e acessibilidade
- Cada ação precisa de resposta imediata: flash, tremor, número flutuando, som, partícula, "pulo" de escala e volta (tween). Deixe o **efeito opcional** nas configurações (movimento reduzido). [Juice it or lose it (Jonasson & Purho, GDC 2012)](https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/) **[resumo]**; [Godot — tweens e feedback](https://bjamba.github.io/teach-me-engineering/learn-godot/module-06-juice-polish/lesson-01-tweens-feedback.html) **[opinião]**.

## 6. Como se cria (processo)
- **Protótipo valida** ("é divertido? controla bem no celular?"); **fatia vertical apresenta** (uma pequena parte, completa e polida). Observar jogador novo **calado, sem explicar nada**. Fatia vertical mobile também testa picos de quadro (abrir menu). [Wayline](https://www.wayline.io/blog/vertical-slice-vs-full-prototype), [HacknPlan](https://hacknplan.com/blog/understanding-vertical-slicing) **[opinião]**.
- Níveis: definir início, sucesso, falha e retry **antes** de multiplicar conteúdo.

## 7. O que isso muda no Terraforge (decisões)
1. **Beleza primeiro (Passo 109, DD-149):** uma cor de ação (âmbar) só em JOGAR/equipado/foco; o resto vidro azul-escuro; JOGAR maior que tudo; coluna à esquerda com o planeta grande à direita (menos itens por tela, centro livre para o mundo).
2. **Loja:** abas por categoria (já), cartões com raridade, destaque âmbar só no equipado e no COMPRAR que dá para pagar; prévia antes de comprar (já).
3. **Território é a "barra de missão"** (Paper.io): mostrar % no HUD e na tela de resultado; **nunca** perder território por bug → smokes de território já existem, manter.
4. **Retorno diário macio** (Clash/Brawl): missões diárias + sequência → fonte de gemas (hoje só conquistas dão); sem energia, sem bloqueio.
5. **Passe de temporada cosmético** (Brawl): trilha na mesma tabela de cosméticos (DD-148), conjuntos temáticos como isca, **nunca** poder.
6. **Juice com opção "reduzir movimento"** em Configurações.
7. **Comunidade** é a motivação que mais falta: amigos/clã/placar entram quando o online 3D existir (depende de conta de loja, só André).
