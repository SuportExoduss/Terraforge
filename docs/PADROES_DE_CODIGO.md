# Project Terraforge — Padrões de Código

Regras que todo código C# do projeto segue. Curtas de propósito: padrão bom é padrão
que se consegue lembrar.

## 1. Nomes

| O quê | Padrão | Exemplo |
|---|---|---|
| Classe, struct, enum | PascalCase, substantivo | `TerritoryClaimer`, `PlanetGrid` |
| Interface | PascalCase com prefixo `I` | `ITerritoryOwner` |
| Método | PascalCase, verbo | `ClaimTerritory()`, `CalculateScore()` |
| Propriedade pública | PascalCase | `CurrentLives` |
| Campo privado | camelCase com `_` | `_moveSpeed` |
| Constante | PascalCase | `MaxPlayers` |
| Evento | PascalCase, prefixo `On` | `OnTerritoryClaimed` |

- Nomes em **inglês** (padrão da indústria; a Unity e todas as bibliotecas são em inglês).
- Nomes dizem **o que a coisa é/faz**, nunca abreviações (`territoryCount`, não `tCnt`).

## 2. Organização

- **Um arquivo = uma classe**, e o arquivo tem o nome da classe (`PlanetGrid.cs`).
- **Namespace segue a pasta:** código em `Code/World/` vive em `namespace Terraforge.World`.
- Módulos oficiais (Capítulo 5 do GDMD): `Core`, `Gameplay`, `World`, `AI`, `Network`, `UI`, `Audio`.

## 3. Regras de dependência (DD-053/DD-054 — arquitetura modular)

- Um módulo **nunca** acessa a implementação interna de outro; comunicação por
  **eventos e interfaces**.
- `Gameplay` nunca acessa `UI` diretamente. `UI` apenas exibe estados.
- `World` nunca decide pontuação. `Network` é dona da sincronização.

## 4. Estilo C# / Unity

- Campos expostos no Inspector: `[SerializeField] private float _moveSpeed;`
  — **nunca** campos públicos.
- Comentários apenas quando o código não consegue se explicar sozinho — e explicam
  o **porquê**, não o "o quê".
- Sem números mágicos: valores de design viram constantes nomeadas ou campos
  serializados.
- `Update()` enxuto: nada de busca (`Find`, `GetComponent`) dentro de loops de frame;
  referências são resolvidas uma vez (`Awake`/`Start`) e guardadas.

## 5. Estrutura de pastas do Assets

```
Assets/
└── _Project/            ← TUDO que é nosso vive aqui (o _ mantém no topo da lista;
    │                       pacotes de terceiros importados ficam fora, em Assets/)
    ├── Code/            ← C#, uma subpasta por módulo do GDMD
    ├── Art/             ← Models, Materials, Textures, Shaders, Animations
    ├── Audio/           ← Music, SFX, Ambience
    ├── Prefabs/         ← objetos prontos reutilizáveis
    ├── Scenes/          ← cenas do jogo
    └── Settings/        ← configurações (URP, Input, etc.)
```

## 6. Git

- Commits pequenos e frequentes; mensagem explica **o que** e **por quê**.
- Nunca commitar com o Console da Unity mostrando erro de compilação.
