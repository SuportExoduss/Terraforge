# Passo 102 — "corrija tudo" (2026-11-14)

Origem: `docs/REVISAO_GDMD_vs_JOGO.md`. Regra de desempate: DD mais recente vence; empate, o código.

| Item | O que mudou |
|---|---|
| Eventos simultâneos | `GlobalEvent.limit()` = 1 sempre (DD-128 vence o Cap 03 P07 e o Passo 79); `smoke_event_limit` reescrito: 6 corredores, nunca 2 juntos, ≥ 2 eventos diferentes chegam à execução |
| Guardião | dano 2/16 por golpe e perseguição de no máximo 4 s (DD-109); `smoke_defenders` passo 3b prova o teto (sem o teto: "perseguição contínua de 9.0 s") |
| Comentário velho | `runner_camera.gd`: "DD-126 (paisagem)" |
| Areia granulada | shader da superfície com borda de grãos, relevo arredondado e granulado fino (`planet_surface.gdshader`) |
| Menu/Configurações | rolagem quando a tela não cabe (`menu_screen.gd`, `settings_panel.gd`) |
| GDMD | **Adendo 08** (`07_ADENDOS`): registra DD-131..134 (já no código), reconcilia os 10 conflitos do GDMD (DD-135), botões ONLINE/SAIR (DD-136), Manada como 8º evento (DD-137); índice atualizado, próximo livre = DD-138 |

Fica para depois (arte, aparelho ou decisão do Diretor — ver Adendo 08, parte E): bicho pequeno 1/16, "5 de 8 elementos", Passe, menu em ícones, cliente online 3D, modelos E01m–E12m, teste no celular, G06 por civilização, destino do território de eliminada, balanceamento item 6, tela estática do DD-009.
