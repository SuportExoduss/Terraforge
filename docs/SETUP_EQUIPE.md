# Project Terraforge — Setup para Desenvolvedores

Guia para um novo desenvolvedor entrar no projeto e trabalhar de outro
computador. Siga na ordem.

---

## 1. Ferramentas (instale antes de tudo)

| Ferramenta | Versão | Onde |
|---|---|---|
| **Unity Hub** | qualquer | unity.com/download |
| **Unity Editor** | **6000.3.19f1 (Unity 6.3 LTS)** — a MESMA, sem exceção | pelo Hub → Instalações → Instalar Editor → aba "Versões oficiais" |
| **Git** | 2.x | git-scm.com |
| **Git LFS** | 3.x | git-lfs.com (ou já vem com o Git) |
| **VS Code** (opcional) | — | code.visualstudio.com |

> ⚠️ **A versão do Unity precisa ser idêntica.** Versões diferentes reescrevem
> arquivos do projeto e geram conflitos e bugs difíceis de achar.

Ao instalar o Editor pelo Hub, marque o módulo **Android Build Support**
(com Android SDK & NDK Tools + OpenJDK) se for gerar APK.

---

## 2. Acesso ao repositório

O repositório é **privado**. O dono (André) precisa te adicionar:
GitHub → repositório **Terraforge** → **Settings** → **Collaborators** →
**Add people** → seu usuário do GitHub → você aceita o convite por e-mail.

---

## 3. Baixar o projeto (uma vez)

```bash
git lfs install
git clone https://github.com/SuportExoduss/Terraforge.git
cd Terraforge
git lfs pull
```

> O `git lfs pull` é obrigatório: modelos 3D e texturas ficam no Git LFS.
> Sem ele, os arquivos vêm como "ponteiros" e o projeto abre quebrado.

Depois: **Unity Hub → Projetos → Adicionar → escolha a pasta `Terraforge/Terraforge`**
(a subpasta interna, que é o projeto Unity). A primeira abertura demora
(vários minutos importando).

---

## 4. Registrar o merge inteligente da Unity (uma vez, obrigatório)

Sem isto, mexer na mesma cena que outra pessoa gera conflito ilegível.

```bash
git config --global merge.unityyamlmerge.name "Unity Smart Merge"
git config --global merge.unityyamlmerge.driver "'<CAMINHO_DO_UNITY>/Editor/Data/Tools/UnityYAMLMerge.exe' merge -p %O %B %A %A"
git config --global merge.unityyamlmerge.recursive binary
```

Troque `<CAMINHO_DO_UNITY>` pela pasta da sua instalação, por exemplo:
`C:/Program Files/Unity/Hub/Editor/6000.3.19f1`

---

## 5. O ritual de todo dia (o mais importante)

**SEMPRE antes de começar a trabalhar:**
```bash
git pull
```

**SEMPRE ao terminar (com a Unity FECHADA ou a cena salva):**
```bash
git add -A
git commit -m "descreva o que fez e por quê"
git push
```

> Commits pequenos e frequentes. Nunca fique dias sem dar `push` —
> quanto mais tempo separado, pior o conflito.

---

## 6. Regras de convivência (evitam 90% das dores)

1. **Avise antes de mexer na cena.** `SampleScene.unity` é o ponto mais
   conflituoso. Combinem por mensagem: "vou mexer na cena agora".
2. **Dividam frentes.** Ex.: um em código (`Assets/_Project/Code`), outro em
   arte/cena. Arquivos diferentes = zero conflito.
3. **Puxe antes de mexer na cena**, sempre.
4. **Nunca commite com erro vermelho no Console.**
5. **Modelos 3D do Tripo** passam pela dieta antes de entrar
   (ver `docs/PADROES_DE_CODIGO.md` e o Adendo 03 do GDMD: orçamento de
   polígonos DD-114, texturas 2K).

---

## 7. Onde está o quê

| Pasta | Conteúdo |
|---|---|
| `Terraforge/Assets/_Project/Code` | Código C#, um módulo por pasta (Core, Gameplay, World, AI, UI, Audio, Network) |
| `Terraforge/Assets/_Project/Art` | Modelos, materiais, shaders |
| `Terraforge/Assets/_Project/Scenes` | Cenas |
| `docs/` | Padrões de código e este guia |

**A regra de ouro da arquitetura:** cada módulo só conhece o `Core`.
Módulos conversam por **eventos** (EventBus), nunca se referenciando
diretamente. O compilador impede violações (Assembly Definitions).

A fonte da verdade de design é o **GDMD** (documentação do jogo, mantida
pelo André) — nenhum sistema muda sem passar por lá.
