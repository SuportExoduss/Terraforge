# Terraforge — visão de criador e lista de desenvolvedor (2026-11-14)

Pedido do André: "observe o jogo agora; lista de desenvolvedor de quem quer lançar online como Clash Royale / Brawl Stars / Call of Duty; reidealize para ser bonito, criativo, divertido, intuitivo, forte, duradouro; compras no app, skins, planetas de tamanhos diferentes".
**Isto é PROPOSTA.** O GDMD só muda quando cada parte for construída e virar DD (decisões já registradas: Adendo 09, DD-138..145).

---

## 1. Observação honesta do jogo hoje

Vi (capturas reais): menu, loja, perfil, partida do ponto de vista do corredor e planetas vistos de cima.

| Área | Hoje | Nota |
|---|---|---|
| Regra central | Cercar terra com um rastro de luz e fechar o laço (estilo Paper.io/Qix) numa **esfera** viva, com eventos globais, guardiões, bônus, bots, eliminação | **Forte e original.** É o diferencial; o resto precisa estar à altura |
| Partida | 10 min, 6 civilizações, 1 planeta fixo (raio 100); 105 testes automáticos | Longa demais para celular; sem variedade |
| Visual | Planeta de areia lisa, território em cor chapada, HUD mínimo ("Domínio 0,1 %", relógio, corações) | **Protótipo.** Falta atmosfera, brilho, "tesão" visual |
| Menu | Botões de texto sobre um planeta girando | Funcional, sem identidade |
| Loja | 5 cores de cerca, por moedas do jogo | Só um molde de loja |
| Progressão | Nível, XP, moedas, 8 conquistas, perfil | Existe, mas sem objetivo diário nem temporada |
| Online | Servidor dedicado, sala, reconexão, detecção de dessincronia — mas **cliente online ainda é tabuleiro 2D** | O coração técnico está pronto; falta o jogo 3D em rede |
| Celular | Último APK de 5/nov (e o de hoje) **sem teste no aparelho** | Maior risco aberto |

## 2. A visão (o jogo que eu construiria)

**Uma frase:** *você tem 3 minutos para pintar um mundo vivo com a sua cor — e o mundo reage.*

Pilares (tudo se mede contra eles):
1. **Legível em 3 segundos.** Um dedo, um objetivo (fechar o laço), um placar que é o próprio planeta. Quem nunca jogou entende olhando.
2. **O planeta é o placar e o espetáculo.** A onda de domínio, os eventos, o dia e a noite são o "show". Todo o dinheiro de arte vai primeiro no planeta.
3. **Tensão curta, vontade de mais uma.** Partida rápida, derrota que ensina, recompensa a cada partida.
4. **Justo.** Nada que se compra dá vantagem (DD-144). Habilidade e leitura do mapa vencem.
5. **Vivo para sempre.** Temporadas, planetas novos, eventos do mês: o jogo muda sem o jogador reinstalar.

### O ciclo (três relógios, como os grandes)
- **30 segundos:** sair da base, esticar o rastro, arriscar, fechar o laço, ver a onda de domínio.
- **3 a 10 minutos:** uma partida. **Modo Rápido (planeta pequeno, ~3–4 min) é o principal no celular**; o Clássico de 10 min vira modo "épico".
- **Dias e semanas:** missões diárias, troféus/liga, temporada de ~6 semanas com passe cosmético e um planeta/evento temático.

### O que torna a Terraforge diferente (e divulgável)
- **Replay em time-lapse do planeta sendo conquistado** (`match_replay.gd` já existe): 15 s compartilháveis. É o anúncio que cada jogador faz de graça.
- **Planeta que reage** (furacão, vulcão, tsunami… hoje 8 eventos): ninguém joga igual duas vezes.
- **Espectador do espaço** (`contemplation_camera.gd`): eliminado não sai — assiste de cima.

### Planetas = conteúdo (DD-143)
| Planeta | Para quê | Ideia de identidade |
|---|---|---|
| Pequeno | Modo Rápido, treino, estreia | Lua/asteroide, ~3–4 min, 3–4 civs |
| Médio (atual) | Clássico | Deserto (Velho Oeste já existe), 6 civs |
| Grande | Partida épica, clãs | Mundo oceânico/floresta, mais civs, 15 min |
| Temáticos de temporada | Reter | Gelo, vulcânico, noite eterna; mudam **aparência e ritmo**, nunca o poder |

### Skins e cosméticos (tudo só visual)
Corredor (por civilização, 3 raridades), cerca/rastro (cor, brilho, partículas), cúpula da base, efeito de conquista, pose no pódio, moldura e título de perfil, fundo do menu, "assinatura" do replay.

### Modos
Rápido (FFA, planeta pequeno) · Clássico (10 min) · **Duplas** (2 equipes de 3? — a calibrar) · Privado com código (amigos) · **Guerra de clãs** (pós-lançamento).

---

## 3. Lista de desenvolvedor (backlog)

Prioridade: **P0** = sem isso não lança · **P1** = primeiros 90 dias · **P2** = longo prazo.
Quem: **EU** = faço no código sozinho · **AND** = precisa do André (arte, conta, decisão, aparelho) · **EXT** = serviço de fora.

### Épico A — Aparelho e desempenho
| P | Item | Quem |
|---|---|---|
| P0 | Teste no celular mais fraco: FPS ≥ 45, tempo de carga, temperatura, bateria (DD-124 a/c, DD-138) | AND + EU |
| P0 | Orçamento de desempenho por qualidade (BAIXA/MÉDIA/ALTA) e teto de memória; reduzir o APK de 314 MB (compressão de textura, LOD dos modelos) | EU |
| P0 | Pico de 44 ms no fim da partida (pintura pendente 92 → 3694) | EU |
| P1 | Telemetria de FPS/crash por modelo de aparelho | EXT |

### Épico B — Beleza e "juice" (o que o jogador vê em 5 segundos)
| P | Item | Quem |
|---|---|---|
| P0 | Direção de arte do planeta: atmosfera/halo, luz rasante, nuvens, sombra da noite, cor por civilização com contraste forte | EU + AND |
| P0 | HUD redesenhado (placar vivo por civilização, barra de domínio, aviso de evento com ícone, vida legível) | EU (skill `impeccable`) |
| P0 | Sensação de toque: vibração, tremor de tela, partículas ao fechar laço, som por ação | EU |
| P0 | Menu com identidade (planeta vivo + atalhos grandes + próximo objetivo à vista) | EU + AND |
| P1 | Modelos de "morto" E01m–E12m; defensor próprio por civilização (arte) | AND |
| P1 | Pódio e tela de resultado "para postar" | EU |

### Épico C — Entendimento imediato (intuitivo)
| P | Item | Quem |
|---|---|---|
| P0 | **Tutorial como primeira partida**: planeta pequeno, 1 bot manso, dicas de 1 frase na hora certa | EU |
| P0 | Controle: giro com um polegar (sensibilidade já existe), teste de alcance do polegar em paisagem | EU + AND |
| P1 | Dicas contextuais ("sua cerca está exposta") e modo daltônico | EU |
| P1 | Localização (pt-BR, en, es) | EU |

### Épico D — Conteúdo duradouro
| P | Item | Quem |
|---|---|---|
| P0 | **Planetas por dados** (`PlanetDef`: tamanho, jogadores, duração, eventos, aparência) — fundação do DD-143 | EU |
| P0 | Planeta Pequeno + modo Rápido | EU |
| P0 | Ruína da civilização eliminada (DD-140) | EU |
| P1 | Planeta Grande + 2 planetas temáticos | EU + AND |
| P1 | Bicho pequeno (1/16) e "5 de 8 elementos" (DD-109) | EU |
| P1 | Modo Duplas e partida privada com código | EU |
| P2 | Guerra de clãs; eventos sazonais; editor de mutadores | EU |

### Épico E — Progressão e retenção
| P | Item | Quem |
|---|---|---|
| P0 | Missões diárias (3/dia) + sequência de dias | EU |
| P0 | Troféus e ligas (ranqueado) com pareamento por troféus | EU + EXT |
| P1 | **Passe de temporada** (trilha grátis + trilha paga, só cosméticos) | EU |
| P1 | Conquistas ampliadas e títulos | EU |
| P2 | Clãs, amigos, convite por link | EU + EXT |

### Épico F — Loja, skins e compras no app (DD-144)
| P | Item | Quem |
|---|---|---|
| P0 | **Inventário e catálogo de cosméticos por dados** (`cosmetics.gd` hoje só tem 5 cores de cerca) + equipar por categoria | EU |
| P0 | Loja com abas (Corredor, Cerca, Base, Efeitos), prévia 3D, raridades | EU |
| P0 | Duas moedas: Moedas (jogando) e Gemas (compradas) | EU |
| P0 | Conta Google Play Console + Google Play Billing; produtos e preços | **AND** |
| P0 | **Validação de compra no servidor** e restauração de compras | EU + EXT |
| P1 | Pacotes de gemas, "primeira compra", ofertas semanais (sem enganar o jogador) | EU |
| P1 | Anúncio opcional recompensado (só ganhar moedas) | EXT |
| P2 | iOS (exige Mac e conta Apple) | AND |

### Épico G — Online sério
| P | Item | Quem |
|---|---|---|
| P0 | **Cliente online 3D** (hoje tabuleiro 2D): partida real em rede, civs 2–6, hospedar pela tela ONLINE, interpolação visual | EU |
| P0 | Contas (convidado + Google), nuvem do perfil, inventário no servidor | EU + EXT |
| P0 | Pareamento: fila por troféus, completar com bots, tempo de espera máximo (DD-134) | EU |
| P0 | Servidores: orquestrador que sobe 1 processo por sala, em 1–2 regiões | EXT + AND |
| P1 | Anti-trapaça (servidor autoritativo já é o princípio), denúncia e silenciar jogador | EU |
| P1 | Reconexão e "voltar à partida" já têm base (20 s); testar em rede ruim | EU |
| P2 | Espectador ao vivo; replays na nuvem | EU + EXT |

### Épico H — Lançamento e operação
| P | Item | Quem |
|---|---|---|
| P0 | Política de privacidade, termos, LGPD e classificação etária (`/codelgpd`) | EU + AND |
| P0 | Assinatura de lançamento (keystore de release), AAB para a Play Store, ícone e imagens de loja | AND + EU |
| P0 | Teste fechado (20 pessoas) → aberto → lançamento gradual | AND |
| P0 | Crash reporting e analytics de funil (tutorial concluído, partida 1, D1/D7) | EXT |
| P1 | Configuração remota (balanceamento sem atualizar o app) e calendário de eventos | EU + EXT |
| P1 | Suporte, página do jogo, canal de comunidade | AND |

---

## 4. Ordem de construção (o que eu faço, um passo por vez)

Cada passo: smoke novo → regressão → commit local (nunca push) → sem tocar na arte não commitada do André.

| Passo | Entrega | Por que nesta ordem |
|---|---|---|
| 103 | `PlanetDef` por dados + o planeta atual como "Médio" (sem mudar o jogo) | Fundação de planetas, modos e skins de planeta |
| 104 | Planeta Pequeno + Modo Rápido (3–4 min) | O modo principal do celular |
| 105 | Ruína da eliminada (DD-140) | Fecha pendência do Adendo 09 |
| 106 | Tutorial como primeira partida | Intuitivo |
| 107 | Catálogo de cosméticos por dados + inventário + equipar | Base de skins |
| 108 | Loja com abas, prévia, raridades, duas moedas | Base das compras |
| 109 | Missões diárias + sequência + troféus/liga local | Retenção |
| 110 | Passe de temporada (cosmético, com moedas do jogo) | Duração |
| 111 | Passada de beleza: HUD, atmosfera do planeta, juice | O que o jogador vê |
| 112+ | Cliente online 3D, em vários passos (partida em rede, civs 2–6, hospedar) | Maior bloco; depende de medir o celular |

Em paralelo, **o que só o André faz**: testar o APK no celular mais fraco que tiver (e me dizer o modelo), abrir a conta Google Play Console, decidir nome/identidade visual, a arte (menu em ícones, modelos E01m–E12m, defensores).

## 5. Riscos principais
1. **Desempenho no celular** — ainda não medido; 314 MB de APK. Mitigação: Épico A primeiro.
2. **Partida longa demais (10 min)** — mitigada pelo Modo Rápido.
3. **Online 3D é o maior bloco** — por isso planetas/modos/skins (que funcionam offline) vêm antes e já geram valor.
4. **Monetização depende de conta e de servidor** — a loja funciona offline com moedas do jogo; a cobrança real só liga com conta de loja e validação no servidor (DD-144).
5. **Escopo** — a lista é grande de propósito; só os P0 bloqueiam o lançamento.
