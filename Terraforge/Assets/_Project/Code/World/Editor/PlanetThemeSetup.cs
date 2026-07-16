using System.IO;
using UnityEditor;
using UnityEngine;

namespace Terraforge.World.EditorTools
{
    /// <summary>
    /// Gera os Planet Themes (DD-115) da partida a partir do que já existe
    /// na cena: aproveita as cores das civilizações e conecta os assets do
    /// bioma Cowboy. Roda uma vez; depois os themes são editáveis à mão.
    /// </summary>
    public static class PlanetThemeSetup
    {
        private const string ThemeFolder = "Assets/_Project/Art/PlanetThemes";
        private const string CowboyFolder = "Assets/_Project/Art/Models/Civilizations/Cowboy";

        [MenuItem("Terraforge/Gerar Planet Themes (PLS)")]
        public static void Generate()
        {
            Directory.CreateDirectory(ThemeFolder);

            var painter = Object.FindAnyObjectByType<TerritoryPainter>();
            if (painter == null)
            {
                Debug.LogError("[PLS] TerritoryPainter não encontrado na cena.");
                return;
            }

            // Cores já escolhidas pelo Diretor, lidas dos materiais atuais.
            Color[] colors = ReadCivilizationColors(painter);

            var themes = new PlanetTheme[colors.Length];
            for (int i = 0; i < colors.Length; i++)
            {
                byte civId = (byte)(i + 1);
                themes[i] = CreateOrLoad($"PlanetTheme_Civ{civId}");
                Paint(themes[i], $"Civilização {civId}", colors[i]);
            }

            // Civilização 1 = Velho Oeste: recebe os assets já produzidos.
            if (themes.Length > 0)
            {
                PlanetTheme cowboy = themes[0];
                cowboy.CivilizationName = "Velho Oeste";
                cowboy.VegetationTall = Load($"{CowboyFolder}/Environment/CowboyCactus.glb");
                cowboy.VegetationLow = Load($"{CowboyFolder}/Environment/CowboyArbusto.glb");
                cowboy.Decoration = Load($"{CowboyFolder}/CowboyTrail.glb");
                cowboy.Construction = Load($"{CowboyFolder}/NaveCowboy.glb");

                // Biome DNA do Velho Oeste (DD-118).
                cowboy.VegetationDensity = 0.2f;
                cowboy.RockDensity = 0.5f;
                cowboy.Dust = 0.9f;
                cowboy.Humidity = 0.05f;
                cowboy.Saturation = 0.5f;
                cowboy.Contrast = 0.85f;
                EditorUtility.SetDirty(cowboy);
            }

            // O planeta neutro: o que aparece onde ninguém domina.
            PlanetTheme baseTheme = CreateOrLoad("PlanetTheme_Base");
            baseTheme.CivilizationName = "Neutro";
            baseTheme.VegetationDensity = 0.15f;
            baseTheme.RockDensity = 0.35f;
            baseTheme.Dust = 0.2f;
            baseTheme.Humidity = 0.4f;
            EditorUtility.SetDirty(baseTheme);

            AttachRegistry(baseTheme, themes);

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log($"[PLS] {themes.Length} Planet Themes + base gerados em {ThemeFolder} " +
                      "e conectados ao PlanetThemeRegistry do planeta.");
        }

        private static Color[] ReadCivilizationColors(TerritoryPainter painter)
        {
            var serialized = new SerializedObject(painter);
            SerializedProperty materials = serialized.FindProperty("_civilizationMaterials");
            var colors = new Color[Mathf.Max(1, materials.arraySize)];

            for (int i = 0; i < materials.arraySize; i++)
            {
                var material = materials.GetArrayElementAtIndex(i).objectReferenceValue as Material;
                colors[i] = material != null ? material.color : Color.gray;
            }

            return colors;
        }

        // Coloca o registro no planeta e entrega os themes prontos.
        private static void AttachRegistry(PlanetTheme baseTheme, PlanetTheme[] themes)
        {
            var planet = Object.FindAnyObjectByType<Planet>();
            if (planet == null)
            {
                Debug.LogError("[PLS] Planet não encontrado na cena.");
                return;
            }

            var registry = planet.GetComponent<PlanetThemeRegistry>();
            if (registry == null)
            {
                registry = planet.gameObject.AddComponent<PlanetThemeRegistry>();
            }

            var serialized = new SerializedObject(registry);
            serialized.FindProperty("_baseTheme").objectReferenceValue = baseTheme;

            SerializedProperty list = serialized.FindProperty("_civilizationThemes");
            list.arraySize = themes.Length;
            for (int i = 0; i < themes.Length; i++)
            {
                list.GetArrayElementAtIndex(i).objectReferenceValue = themes[i];
            }

            serialized.ApplyModifiedProperties();
            EditorUtility.SetDirty(planet.gameObject);

            // Sem SALVAR a cena, o registro recém-criado evapora ao fechar —
            // e o shader fica sem Kit nenhum (planeta sem temática).
            UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(planet.gameObject.scene);
            UnityEditor.SceneManagement.EditorSceneManager.SaveScene(planet.gameObject.scene);
        }

        private static PlanetTheme CreateOrLoad(string assetName)
        {
            string path = $"{ThemeFolder}/{assetName}.asset";
            var existing = AssetDatabase.LoadAssetAtPath<PlanetTheme>(path);
            if (existing != null)
            {
                return existing;
            }

            var theme = ScriptableObject.CreateInstance<PlanetTheme>();
            AssetDatabase.CreateAsset(theme, path);
            return theme;
        }

        // Deriva um kit de terreno plausível a partir da cor da civilização:
        // ponto de partida editável, não uma camisa de força.
        private static void Paint(PlanetTheme theme, string civName, Color color)
        {
            Color.RGBToHSV(color, out float h, out float s, out float v);
            theme.CivilizationName = civName;
            theme.SoilBase = color;
            theme.SoilSecondary = Color.HSVToRGB(Mathf.Repeat(h + 0.04f, 1f), s * 0.85f, v * 0.8f);
            theme.Detail = Color.HSVToRGB(h, s * 0.6f, v * 0.5f);
            theme.Vegetation = Color.HSVToRGB(Mathf.Repeat(h - 0.06f, 1f), s * 0.7f, v * 0.9f);
            EditorUtility.SetDirty(theme);
        }

        private static GameObject Load(string path)
        {
            return AssetDatabase.LoadAssetAtPath<GameObject>(path);
        }
    }
}
