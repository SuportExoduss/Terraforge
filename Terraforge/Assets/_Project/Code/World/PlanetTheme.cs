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
        [Header("Ambiente — E00 Terreno (textura do piso)")]
        [Tooltip("E00: textura tileável do chão (areia, grama, neve, lava...).")]
        public Texture2D GroundTexture;

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
