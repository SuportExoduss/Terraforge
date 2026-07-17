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
        private const string NormalAtlasPath = ThemeFolder + "/GroundNormalAtlas.asset";
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

            Texture2DArray atlas = BakeColorAtlas(themes);
            Texture2DArray normalAtlas = BakeNormalAtlas(themes);
            AttachRegistry(baseTheme, themes, atlas, normalAtlas);

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

            // Ambiente: piso (E00) — o material COMPLETO da areia
            // (cor + relevo + sombreamento de cavidades).
            cowboy.GroundTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(
                $"{GroundFolder}/Ground_VelhoOeste.jpg");
            cowboy.GroundNormalTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(
                $"{GroundFolder}/Ground_VelhoOeste_Normal.png");
            cowboy.GroundAOTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(
                $"{GroundFolder}/Ground_VelhoOeste_AO.jpg");
            cowboy.GroundRelief = 1f;
            cowboy.GroundHeight = 0.6f;
            cowboy.GroundTiling = 16f;

            // Paleta extraída das referências de deserto do Diretor: a foto
            // aérea de praia é areia MOLHADA acinzentada — esta correção a
            // aquece para areia de deserto (dourado/alaranjado).
            cowboy.GroundTint = new Color(0.77f, 0.56f, 0.38f);
            cowboy.SoilBase = new Color(0.87f, 0.65f, 0.42f);
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

        // Assa o atlas de pisos: fatia N = cor E00 da civilização N+1 já
        // MULTIPLICADA pelo AO (sombreamento de cavidades vira parte da
        // cor — efeito de material completo sem custo em jogo).
        private static Texture2DArray BakeColorAtlas(PlanetTheme[] themes)
        {
            var atlas = NewAtlas("GroundAtlas", themes.Length, linear: false);

            for (int i = 0; i < themes.Length; i++)
            {
                PlanetTheme theme = themes[i];
                Texture color = theme != null && theme.GroundTexture != null
                    ? theme.GroundTexture
                    : Texture2D.whiteTexture;

                Color32[] pixels = ReadPixels(color, linear: false);

                if (theme != null && theme.GroundAOTexture != null)
                {
                    // AO a 50%: sombreia as cavidades sem SUJAR a cor
                    // (a 100% a areia ficava acinzentada e escura).
                    Color32[] ao = ReadPixels(theme.GroundAOTexture, linear: false);
                    for (int p = 0; p < pixels.Length; p++)
                    {
                        int soft = 255 + ao[p].r;
                        pixels[p].r = (byte)(pixels[p].r * soft / 510);
                        pixels[p].g = (byte)(pixels[p].g * soft / 510);
                        pixels[p].b = (byte)(pixels[p].b * soft / 510);
                    }
                }

                atlas.SetPixels32(pixels, i, 0);
            }

            atlas.Apply(updateMipmaps: true);
            return SaveAtlas(atlas, AtlasPath);
        }

        // Assa o atlas de relevos: fatia N = mapa normal E00. Normal é
        // DADO (0,5 = plano): tudo em espaço LINEAR, sem correção de gama.
        private static Texture2DArray BakeNormalAtlas(PlanetTheme[] themes)
        {
            var atlas = NewAtlas("GroundNormalAtlas", themes.Length, linear: true);
            var flat = new Color32(128, 128, 255, 255); // normal "plana"

            for (int i = 0; i < themes.Length; i++)
            {
                PlanetTheme theme = themes[i];
                if (theme != null && theme.GroundNormalTexture != null)
                {
                    EnsureLinearImport(theme.GroundNormalTexture);
                    atlas.SetPixels32(
                        ReadPixels(theme.GroundNormalTexture, linear: true), i, 0);
                }
                else
                {
                    var pixels = new Color32[AtlasSize * AtlasSize];
                    for (int p = 0; p < pixels.Length; p++)
                    {
                        pixels[p] = flat;
                    }

                    atlas.SetPixels32(pixels, i, 0);
                }
            }

            atlas.Apply(updateMipmaps: true);
            return SaveAtlas(atlas, NormalAtlasPath);
        }

        private static Texture2DArray NewAtlas(string name, int slices, bool linear)
        {
            return new Texture2DArray(
                AtlasSize, AtlasSize, Mathf.Max(1, slices),
                TextureFormat.RGBA32, mipChain: true, linear: linear)
            {
                name = name,
                wrapMode = TextureWrapMode.Repeat
            };
        }

        // Blit+ReadPixels redimensiona para 512 mesmo com textura não
        // legível; o modo linear evita o desvio de gama em mapas de dado.
        private static Color32[] ReadPixels(Texture source, bool linear)
        {
            RenderTexture target = RenderTexture.GetTemporary(
                AtlasSize, AtlasSize, 0, RenderTextureFormat.ARGB32,
                linear ? RenderTextureReadWrite.Linear : RenderTextureReadWrite.Default);
            RenderTexture previous = RenderTexture.active;

            Graphics.Blit(source, target);
            RenderTexture.active = target;
            var reader = new Texture2D(AtlasSize, AtlasSize, TextureFormat.RGBA32, false, linear);
            reader.ReadPixels(new Rect(0, 0, AtlasSize, AtlasSize), 0, 0);
            reader.Apply(false);

            Color32[] pixels = reader.GetPixels32();
            RenderTexture.active = previous;
            RenderTexture.ReleaseTemporary(target);
            Object.DestroyImmediate(reader);
            return pixels;
        }

        // Mapa normal importado como sRGB distorce o relevo (0,5 deixa de
        // ser "plano"). Garante a importação em espaço linear.
        private static void EnsureLinearImport(Texture2D texture)
        {
            string path = AssetDatabase.GetAssetPath(texture);
            if (AssetImporter.GetAtPath(path) is TextureImporter importer && importer.sRGBTexture)
            {
                importer.sRGBTexture = false;
                importer.SaveAndReimport();
            }
        }

        private static Texture2DArray SaveAtlas(Texture2DArray atlas, string path)
        {
            AssetDatabase.DeleteAsset(path);
            AssetDatabase.CreateAsset(atlas, path);
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
            PlanetTheme baseTheme, PlanetTheme[] themes,
            Texture2DArray atlas, Texture2DArray normalAtlas)
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
            serialized.FindProperty("_groundNormals").objectReferenceValue = normalAtlas;

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
