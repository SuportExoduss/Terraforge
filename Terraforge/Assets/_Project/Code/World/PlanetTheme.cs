using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// DD-115: a "ficha" completa de uma civilização — o ÚNICO contrato que
    /// o planeta conhece. Uma civilização nova é um Planet Theme novo:
    /// nenhuma linha de código muda (DD-114, PLS).
    ///
    /// O planeta não cria nada; ele REVELA o theme dono de cada região.
    /// </summary>
    [CreateAssetMenu(fileName = "PlanetTheme_", menuName = "Terraforge/Planet Theme")]
    public sealed class PlanetTheme : ScriptableObject
    {
        [Header("Identidade")]
        public string CivilizationName = "Neutro";

        [Header("Kit de Terreno (DD-116) — o shader compõe o solo com estas cores")]
        [Tooltip("Cor dominante do solo da região.")]
        public Color SoilBase = new(0.55f, 0.42f, 0.28f);

        [Tooltip("Segunda cor do solo: manchas que quebram a monotonia.")]
        public Color SoilSecondary = new(0.62f, 0.33f, 0.2f);

        [Tooltip("Detalhes: rachaduras, pedrinhas, veios.")]
        public Color Detail = new(0.35f, 0.28f, 0.22f);

        [Tooltip("Vegetação rasteira que o terreno mostra sozinho.")]
        public Color Vegetation = new(0.45f, 0.5f, 0.25f);

        [Header("Slot Assets (DD-110/DD-115) — equivalente por categoria")]
        public GameObject VegetationTall;
        public GameObject VegetationLow;
        public GameObject RockLarge;
        public GameObject RockSmall;
        public GameObject Construction;
        public GameObject Decoration;
        public GameObject FaunaSmall;
        public GameObject Guardian;

        [Header("Biome DNA (DD-118) — a personalidade ambiental")]
        [Range(0f, 1f)] public float VegetationDensity = 0.3f;
        [Range(0f, 1f)] public float RockDensity = 0.5f;
        [Range(0f, 1f)] public float Dust = 0.8f;
        [Range(0f, 1f)] public float Humidity = 0.1f;
        [Range(0f, 1f)] public float Saturation = 0.5f;
        [Range(0f, 1f)] public float Contrast = 0.8f;

        /// <summary>O equivalente desta civilização para uma categoria de slot.</summary>
        public GameObject GetSlotAsset(SlotCategory category)
        {
            return category switch
            {
                SlotCategory.VegetationTall => VegetationTall,
                SlotCategory.VegetationLow => VegetationLow,
                SlotCategory.RockLarge => RockLarge,
                SlotCategory.RockSmall => RockSmall,
                SlotCategory.Construction => Construction,
                SlotCategory.Decoration => Decoration,
                SlotCategory.FaunaSmall => FaunaSmall,
                SlotCategory.Guardian => Guardian,
                _ => null,
            };
        }
    }

    /// <summary>
    /// DD-110: as oito categorias oficiais de slot. Um slot NUNCA muda de
    /// categoria — apenas troca qual theme está revelando.
    /// </summary>
    public enum SlotCategory
    {
        VegetationTall,
        VegetationLow,
        RockLarge,
        RockSmall,
        Construction,
        Decoration,
        FaunaSmall,
        Guardian,
    }
}
