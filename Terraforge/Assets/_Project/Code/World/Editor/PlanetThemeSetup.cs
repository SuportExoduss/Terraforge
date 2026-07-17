using System.IO;
using UnityEditor;
using UnityEngine;

namespace Terraforge.World.EditorTools
{
    /// <summary>
    /// Gera/atualiza as fichas de civilização (Planet Themes, DD-115/DD-120)
    /// e assa o atlas de pisos (E00). Pode rodar quantas vezes quiser: cria
    /// o que falta, preenche o Velho Oeste com os assets já produzidos e
    /// reassa o atlas com as texturas atuais das fichas.
    /// </summary>
    public static class PlanetThemeSetup
    {
        private const string ThemeFolder = "Assets/_Project/Art/PlanetThemes";
        private const string CowboyFolder = "Assets/_Project/Art/Models/Civilizations/Cowboy";
        private const string GroundFolder = "Assets/_Project/Art/Textures/Ground";
        private const string AtlasPath = ThemeFolder + "/GroundAtlas.asset";
        private const int AtlasSize = 512;

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
                string preferred = civId == 1 ? "PlanetTheme_VelhoOeste" : $"PlanetTheme_Civ{civId}";
                themes[i] = CreateOrLoad(preferred, $"PlanetTheme_Civ{civId}");
                Paint(themes[i], $"Civilização {civId}", colors[i]);
            }

            // Civilização 1 = Velho Oeste: a ficha completa (18 slots).
            if (themes.Length > 0)
            {
                FillCowboy(themes[0]);
            }

            // O planeta neutro: o que aparece onde ninguém domina.
            PlanetTheme baseTheme = CreateOrLoad("PlanetTheme_Base", "PlanetTheme_Base");
            baseTheme.CivilizationName = "Neutro";
            baseTheme.VegetationDensity = 0.15f;
            baseTheme.RockDensity = 0.35f;
            baseTheme.Dust = 0.2f;
            baseTheme.Humidity = 0.4f;
            EditorUtility.SetDirty(baseTheme);

            Texture2DArray atlas = BakeGroundAtlas(themes);
            AttachRegistry(baseTheme, themes, atlas);

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log($"[PLS] {themes.Length} fichas + base atualizadas em {ThemeFolder}; " +
                      "atlas de pisos assado e registro conectado ao planeta.");
        }

        // A ficha do Velho Oeste (DD-120): Gameplay G01–G05 + Ambiente
        // E00–E12 com tudo que já foi produzido. Campos ainda sem modelo
        // ficam vazios esperando os próximos assets do Diretor.
        private static void FillCowboy(PlanetTheme cowboy)
        {
            cowboy.CivilizationName = "Velho Oeste";

            // Gameplay.
            cowboy.Character = Load($"{CowboyFolder}/CowboyRunner.glb");
            cowboy.Ship = Load($"{CowboyFolder}/NaveCowboy.glb");
            cowboy.Dome = Load($"{CowboyFolder}/DomoEnergia.glb");
            cowboy.Meteor = Load("Assets/_Project/Art/Models/Events/meteoroevent3D.glb");
            cowboy.TrailSegment = Load($"{CowboyFolder}/CowboyTrail.glb");

            // Ambiente: piso (E00) + modelos existentes.
            cowboy.GroundTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(
                $"{GroundFolder}/Ground_VelhoOeste.jpg");
            cowboy.GroundTiling = 16f;
            cowboy.VegetationTall = Load($"{CowboyFolder}/Environment/CowboyCactus.glb");   // E01
            cowboy.VegetationMedium = Load($"{CowboyFolder}/Environment/CowboyArbusto.glb"); // E02

            // Fichas antigas guardaram o arbusto no campo que hoje é o E03:
            // limpa para os slots vazios esperarem os assets certos.
            cowboy.VegetationLow = null;

            // Biome DNA do Velho Oeste (DD-118).
            cowboy.VegetationDensity = 0.2f;
            cowboy.RockDensity = 0.5f;
            cowboy.Dust = 0.9f;
            cowboy.Humidity = 0.05f;
            cowboy.Saturation = 0.5f;
            cowboy.Contrast = 0.85f;
            EditorUtility.SetDirty(cowboy);
        }

        // Assa o atlas de pisos: fatia N = textura E00 da civilização N+1,
        // redimensionada para 512 (o shader indexa a fatia pelo dono do
        // pixel). Blit+ReadPixels funciona mesmo com textura não legível.
        private static Texture2DArray BakeGroundAtlas(PlanetTheme[] themes)
        {
            var atlas = new Texture2DArray(
                AtlasSize, AtlasSize, Mathf.Max(1, themes.Length),
                TextureFormat.RGBA32, mipChain: true)
            {
                name = "GroundAtlas",
                wrapMode = TextureWrapMode.Repeat
            };

            RenderTexture target = RenderTexture.GetTemporary(
                AtlasSize, AtlasSize, 0, RenderTextureFormat.ARGB32);
            var reader = new Texture2D(AtlasSize, AtlasSize, TextureFormat.RGBA32, false);
            RenderTexture previous = RenderTexture.active;

            for (int i = 0; i < themes.Length; i++)
            {
                Texture source = themes[i] != null && themes[i].GroundTexture != null
                    ? themes[i].GroundTexture
                    : Texture2D.whiteTexture;

                Graphics.Blit(source, target);
                RenderTexture.active = target;
                reader.ReadPixels(new Rect(0, 0, AtlasSize, AtlasSize), 0, 0);
                reader.Apply(false);
                atlas.SetPixels32(reader.GetPixels32(), i, 0);
            }

            RenderTexture.active = previous;
            RenderTexture.ReleaseTemporary(target);
            Object.DestroyImmediate(reader);
            atlas.Apply(updateMipmaps: true);

            AssetDatabase.DeleteAsset(AtlasPath);
            AssetDatabase.CreateAsset(atlas, AtlasPath);
            return atlas;
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

        // Coloca o registro no planeta e entrega fichas + atlas prontos.
        private static void AttachRegistry(
            PlanetTheme baseTheme, PlanetTheme[] themes, Texture2DArray atlas)
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
            serialized.FindProperty("_groundTextures").objectReferenceValue = atlas;

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

        // Carrega a ficha pelo nome preferido; se só existir com o nome
        // antigo, RENOMEIA (a ficha leva o nome da civilização, DD-120).
        private static PlanetTheme CreateOrLoad(string preferredName, string legacyName)
        {
            string preferredPath = $"{ThemeFolder}/{preferredName}.asset";
            var existing = AssetDatabase.LoadAssetAtPath<PlanetTheme>(preferredPath);
            if (existing != null)
            {
                return existing;
            }

            string legacyPath = $"{ThemeFolder}/{legacyName}.asset";
            var legacy = AssetDatabase.LoadAssetAtPath<PlanetTheme>(legacyPath);
            if (legacy != null)
            {
                AssetDatabase.RenameAsset(legacyPath, preferredName);
                return legacy;
            }

            var theme = ScriptableObject.CreateInstance<PlanetTheme>();
            AssetDatabase.CreateAsset(theme, preferredPath);
            return theme;
        }

        // Deriva um kit de terreno plausível a partir da cor da civilização:
        // ponto de partida editável, não uma camisa de força.
        private static void Paint(PlanetTheme theme, string civName, Color color)
        {
            Color.RGBToHSV(color, out float h, out float s, out float v);
            if (string.IsNullOrEmpty(theme.CivilizationName) ||
                theme.CivilizationName.StartsWith("Civilização") ||
                theme.CivilizationName == "Neutro")
            {
                theme.CivilizationName = civName;
            }

            theme.SoilBase = color;

            // As três cores de apoio precisam DESTOAR da base — se forem
            // quase iguais, o terreno composto parece chapado.
            theme.SoilSecondary = Color.HSVToRGB(
                Mathf.Repeat(h + 0.07f, 1f), Mathf.Clamp01(s * 1.1f), Mathf.Clamp01(v * 0.62f));
            theme.Detail = Color.HSVToRGB(
                Mathf.Repeat(h - 0.02f, 1f), Mathf.Clamp01(s * 0.7f), Mathf.Clamp01(v * 0.3f));
            theme.Vegetation = Color.HSVToRGB(
                Mathf.Repeat(h - 0.12f, 1f), Mathf.Clamp01(s * 0.8f), Mathf.Clamp01(v * 1.15f));
            EditorUtility.SetDirty(theme);
        }

        private static GameObject Load(string path)
        {
            return AssetDatabase.LoadAssetAtPath<GameObject>(path);
        }
    }
}
