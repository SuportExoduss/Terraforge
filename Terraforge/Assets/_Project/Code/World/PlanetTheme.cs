using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// DD-115/DD-120: a FICHA COMPLETA de uma civilização — o único
    /// contrato que o jogo conhece. São 18 slots fixos (5 de Gameplay +
    /// 13 de Ambiente): criar uma civilização nova é preencher esta ficha
    /// com modelos, materiais e texturas. Nenhuma linha de código muda
    /// (DD-114, Planet Layer System).
    ///
    /// O planeta não cria nada; ele REVELA o conteúdo do theme dono de
    /// cada região.
    /// </summary>
    [CreateAssetMenu(fileName = "PlanetTheme_", menuName = "Terraforge/Planet Theme")]
    public sealed class PlanetTheme : ScriptableObject
    {
        [Header("Identidade")]
        public string CivilizationName = "Neutro";

        // ------------------------------------------------------------------
        // GAMEPLAY (G01–G05) — os 5 assets que existem em toda civilização.
        // ------------------------------------------------------------------
        [Header("Gameplay — G01 a G05")]
        [Tooltip("G01: o personagem corredor desta civilização.")]
        public GameObject Character;

        [Tooltip("G02: a nave/base que pousa e decola.")]
        public GameObject Ship;

        [Tooltip("G03: o domo de energia (pode ser o Domo Universal).")]
        public GameObject Dome;

        [Tooltip("G04: o meteoro do evento global (modelo ou variação).")]
        public GameObject Meteor;

        [Tooltip("G05: o segmento do rastro (cerca, cristal, muro...).")]
        public GameObject TrailSegment;

        // ------------------------------------------------------------------
        // AMBIENTE (E00) — o piso: material com TEXTURA aplicado ao planeta
        // conforme o território é conquistado. Não é um modelo 3D.
        // ------------------------------------------------------------------
        [Header("Ambiente — E00 Terreno (material completo do piso)")]
        [Tooltip("E00: a COR do chão (areia, grama, neve, lava...). Mapa _diff.")]
        public Texture2D GroundTexture;

        [Tooltip("E00: o RELEVO do chão (mapa normal, _nor). O terreno ganha " +
                 "ondulações e volume iluminados de verdade.")]
        public Texture2D GroundNormalTexture;

        [Tooltip("E00: sombreamento de cavidades (mapa _ao). Assado na cor.")]
        public Texture2D GroundAOTexture;

        [Tooltip("Correção de cor do material (cinza 50% = neutra): ajusta " +
                 "a paleta do piso ao bioma sem perder as ondulações. " +
                 "Ex.: aquecer areia de praia para virar deserto.")]
        public Color GroundTint = new(0.5f, 0.5f, 0.5f);

        [Tooltip("Força do relevo (0 = liso, 1 = natural, 2 = exagerado).")]
        [Range(0f, 2f)] public float GroundRelief = 1f;

        [Tooltip("Altura da CAMADA do bioma (unidades): o terreno dominado " +
                 "SOBE sobre o planeta e afina até acabar na borda.")]
        [Range(0f, 3f)] public float GroundHeight = 0.6f;

        [Tooltip("Repetições da textura ao redor do planeta (maior = mais miúda).")]
        [Range(1f, 64f)] public float GroundTiling = 16f;

        [Header("Kit de Terreno (DD-116) — variação procedural sobre o piso")]
        [Tooltip("Cor dominante do solo; também colore o mapa/minimapa.")]
        public Color SoilBase = new(0.55f, 0.42f, 0.28f);

        [Tooltip("Manchas que quebram a monotonia (misturadas por ruído+seed).")]
        public Color SoilSecondary = new(0.62f, 0.33f, 0.2f);

        [Tooltip("Detalhes finos: rachaduras, pedrinhas, veios.")]
        public Color Detail = new(0.35f, 0.28f, 0.22f);

        [Tooltip("Vegetação rasteira que o próprio solo mostra.")]
        public Color Vegetation = new(0.45f, 0.5f, 0.25f);

        // ------------------------------------------------------------------
        // AMBIENTE (E01–E12) — os 12 modelos que os Slots revelam.
        // ------------------------------------------------------------------
        [Header("Ambiente — E01 a E12 (modelos dos Slots)")]
        [Tooltip("E01: vegetação alta (cacto gigante, árvore mágica...).")]
        public GameObject VegetationTall;

        [Tooltip("E02: vegetação média (arbusto seco, arbusto encantado...).")]
        public GameObject VegetationMedium;

        [Tooltip("E03: vegetação baixa (tufo de capim, cogumelos...).")]
        public GameObject VegetationLow;

        [Tooltip("E04: rocha grande.")]
        public GameObject RockLarge;

        [Tooltip("E05: rocha pequena.")]
        public GameObject RockSmall;

        [Tooltip("E06: estrutura pequena (barril...).")]
        public GameObject StructureSmall;

        [Tooltip("E07: estrutura média (poste, obelisco...).")]
        public GameObject StructureMedium;

        [Tooltip("E08: estrutura grande (cabana, torre mágica...).")]
        public GameObject StructureLarge;

        [Tooltip("E09: decorativo natural (crânio de boi, cristal...).")]
        public GameObject DecorationNatural;

        [Tooltip("E10: decorativo artificial (roda de carroça, portal...).")]
        public GameObject DecorationArtificial;

        [Tooltip("E11: container (caixa de madeira, baú arcano...).")]
        public GameObject Container;

        [Tooltip("E12: landmark — o objeto icônico de grande porte.")]
        public GameObject Landmark;

        // ------------------------------------------------------------------
        // DEATH BIOME (DD-122) — a versão MORTA do bioma, exibida quando a
        // civilização é eliminada, até a ruína ser conquistada. Enquanto os
        // campos estiverem vazios, o jogo escurece a temática viva sozinho.
        // ------------------------------------------------------------------
        [Header("Death Biome (DD-122) — a versão morta do bioma")]
        [Tooltip("D00: a COR do chão morto (areia cinza, terra queimada...). " +
                 "Vazio = escurecimento automático da temática viva.")]
        public Texture2D DeadGroundTexture;

        [Tooltip("D00: o RELEVO do chão morto. Vazio = usa o relevo vivo.")]
        public Texture2D DeadGroundNormalTexture;

        [Tooltip("Correção de cor do material morto (cinza 50% = neutra).")]
        public Color DeadGroundTint = new(0.4f, 0.38f, 0.36f);

        [Tooltip("D01: a nave DESTRUÍDA, exibida na ruína (arte futura).")]
        public GameObject DeadShip;

        [Tooltip("D02: o domo QUEBRADO, exibido na ruína (arte futura).")]
        public GameObject DeadDome;

        // O espelho morto dos 12 slots ambientais (pedido do Diretor: tudo
        // que existe vivo existe morto). Slot morto vazio = a Fase 3 exibe
        // a versão viva escurecida automaticamente.
        [Header("Death Biome — E01 a E12 mortos (espelho dos slots)")]
        [Tooltip("E01 morto: vegetação alta morta (cacto seco/quebrado...).")]
        public GameObject DeadVegetationTall;

        [Tooltip("E02 morto: vegetação média morta (arbusto ressecado...).")]
        public GameObject DeadVegetationMedium;

        [Tooltip("E03 morto: vegetação baixa morta (capim queimado...).")]
        public GameObject DeadVegetationLow;

        [Tooltip("E04 morto: rocha grande rachada/escurecida.")]
        public GameObject DeadRockLarge;

        [Tooltip("E05 morto: rocha pequena morta.")]
        public GameObject DeadRockSmall;

        [Tooltip("E06 morto: estrutura pequena destruída (barril quebrado...).")]
        public GameObject DeadStructureSmall;

        [Tooltip("E07 morto: estrutura média destruída (poste caído...).")]
        public GameObject DeadStructureMedium;

        [Tooltip("E08 morto: estrutura grande destruída (cabana em ruínas...).")]
        public GameObject DeadStructureLarge;

        [Tooltip("E09 morto: decorativo natural morto.")]
        public GameObject DeadDecorationNatural;

        [Tooltip("E10 morto: decorativo artificial morto.")]
        public GameObject DeadDecorationArtificial;

        [Tooltip("E11 morto: container destruído (caixa quebrada...).")]
        public GameObject DeadContainer;

        [Tooltip("E12 morto: o landmark em ruínas.")]
        public GameObject DeadLandmark;

        // ------------------------------------------------------------------
        // BIOME DNA (DD-118) — a personalidade ambiental.
        // ------------------------------------------------------------------
        [Header("Biome DNA (DD-118) — a personalidade ambiental")]
        [Range(0f, 1f)] public float VegetationDensity = 0.3f;
        [Range(0f, 1f)] public float RockDensity = 0.5f;
        [Range(0f, 1f)] public float Dust = 0.8f;
        [Range(0f, 1f)] public float Humidity = 0.1f;
        [Range(0f, 1f)] public float Saturation = 0.5f;
        [Range(0f, 1f)] public float Contrast = 0.8f;

        /// <summary>
        /// O sistema nunca pergunta "qual é o objeto?" — apenas
        /// "qual asset ocupa este slot neste bioma?" (DD-120).
        /// </summary>
        public GameObject GetSlotAsset(SlotCategory category)
        {
            return category switch
            {
                SlotCategory.VegetationTall => VegetationTall,
                SlotCategory.VegetationMedium => VegetationMedium,
                SlotCategory.VegetationLow => VegetationLow,
                SlotCategory.RockLarge => RockLarge,
                SlotCategory.RockSmall => RockSmall,
                SlotCategory.StructureSmall => StructureSmall,
                SlotCategory.StructureMedium => StructureMedium,
                SlotCategory.StructureLarge => StructureLarge,
                SlotCategory.DecorationNatural => DecorationNatural,
                SlotCategory.DecorationArtificial => DecorationArtificial,
                SlotCategory.Container => Container,
                SlotCategory.Landmark => Landmark,
                _ => null,
            };
        }

        /// <summary>
        /// DD-122: o equivalente MORTO de um slot. Sem versão morta na
        /// ficha, devolve null — quem exibe usa a versão viva escurecida.
        /// </summary>
        public GameObject GetDeadSlotAsset(SlotCategory category)
        {
            return category switch
            {
                SlotCategory.VegetationTall => DeadVegetationTall,
                SlotCategory.VegetationMedium => DeadVegetationMedium,
                SlotCategory.VegetationLow => DeadVegetationLow,
                SlotCategory.RockLarge => DeadRockLarge,
                SlotCategory.RockSmall => DeadRockSmall,
                SlotCategory.StructureSmall => DeadStructureSmall,
                SlotCategory.StructureMedium => DeadStructureMedium,
                SlotCategory.StructureLarge => DeadStructureLarge,
                SlotCategory.DecorationNatural => DeadDecorationNatural,
                SlotCategory.DecorationArtificial => DeadDecorationArtificial,
                SlotCategory.Container => DeadContainer,
                SlotCategory.Landmark => DeadLandmark,
                _ => null,
            };
        }
    }

    /// <summary>
    /// DD-120: as 12 categorias ambientais oficiais (E01–E12). Um slot
    /// NUNCA muda de categoria — apenas troca qual theme está revelando.
    /// (E00, o material do terreno, não é um slot: é a pele do planeta.)
    /// </summary>
    public enum SlotCategory
    {
        VegetationTall = 1,        // E01
        VegetationMedium = 2,      // E02
        VegetationLow = 3,         // E03
        RockLarge = 4,             // E04
        RockSmall = 5,             // E05
        StructureSmall = 6,        // E06
        StructureMedium = 7,       // E07
        StructureLarge = 8,        // E08
        DecorationNatural = 9,     // E09
        DecorationArtificial = 10, // E10
        Container = 11,            // E11
        Landmark = 12,             // E12
    }
}
