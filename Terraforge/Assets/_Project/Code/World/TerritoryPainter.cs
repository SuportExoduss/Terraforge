using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// O pintor definitivo (DD-110): a dominação muda a cor dos PIXELS da
    /// própria superfície do planeta — nada é criado por cima. Mantém um
    /// "mapa de posse" (textura equiretangular global) pintado célula a
    /// célula em ondas por quadro; o shader Terraforge/PlanetSurface
    /// mistura esse mapa com a cor original do modelo do planeta.
    /// Vive no mesmo objeto do Planet.
    /// </summary>
    public sealed class TerritoryPainter : MonoBehaviour
    {
        // Elemento 0 = civilização 1 (jogador)... — as CORES das civilizações
        // são lidas destes materiais (mesma paleta do rastro e das bases).
        [SerializeField] private Material[] _civilizationMaterials;

        // Resolução do mapa de posse (largura; altura = metade).
        [SerializeField] private int _mapWidth = 1024;

        // Raio do pincel relativo ao espaçamento das células: >0.5 garante
        // mancha contínua entre células vizinhas.
        [SerializeField] private float _brushRadiusFactor = 1.05f;

        // Células pintadas por quadro: conquistas gigantes viram uma onda
        // de transformação que se espalha (DD-110), não um soluço.
        [SerializeField] private int _cellsPerFrame = 300;

        // Enviar uma textura inteira para a GPU é caro. A pintura continua
        // incremental, mas a textura é submetida no máximo 20 vezes por
        // segundo: a onda permanece fluida e os frames deixam de carregar
        // repetidamente o upload completo de 2 MiB.
        [SerializeField, Min(0.016f)] private float _uploadInterval = 0.05f;

        private readonly struct PendingCell
        {
            public readonly Vector3 Position;
            public readonly Color32 Color;
            public readonly float WorldRadius;
            public readonly byte OwnerId;

            public PendingCell(Vector3 position, Color32 color, float worldRadius, byte ownerId)
            {
                Position = position;
                Color = color;
                WorldRadius = worldRadius;
                OwnerId = ownerId;
            }
        }

        // DD-116: até 16 civilizações; cada uma entrega um Kit de Terreno
        // (4 cores) que o shader compõe com ruído.
        private const int MaxThemes = 16;

        private readonly Queue<PendingCell> _pendingCells = new();
        private readonly float[] _themeHeights = new float[MaxThemes + 1];
        private readonly bool[] _deadCivilizations = new bool[MaxThemes + 1];
        private Planet _planet;
        private Texture2D _territoryMap;
        private Texture2D _territoryIdMap;
        private Color32[] _pixels;
        private Color32[] _idPixels;
        private int _mapHeight;
        private bool _dirty;
        private float _nextUploadTime;

        private void Awake()
        {
            _planet = GetComponent<Planet>();
            BuildTerritoryMap();
            EventBus.Subscribe<TerritoryCellsClaimedEvent>(OnCellsClaimed);
            EventBus.Subscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        // DD-122: o império do morto escurece — mesma temática, versão
        // "morta" — até a ruína ser conquistada.
        private void OnEliminated(CivilizationEliminatedEvent eliminatedEvent)
        {
            if (eliminatedEvent.OwnerId <= MaxThemes)
            {
                _deadCivilizations[eliminatedEvent.OwnerId] = true;
                UploadThemeKits();
            }
        }

        private void Start()
        {
            // Troca os materiais do modelo visual pelo shader da "pele"
            // (preservando a cor/textura original de cada parte).
            ConvertPlanetMaterials();

            // DD-116: entrega os Kits de Terreno ao shader e sorteia a seed
            // da partida (nenhum planeta Cowboy é igual a outro). A seed sai
            // UMA vez — reenvios de kit (ex.: morte, DD-122) não a mudam.
            UploadThemeKits();
            Shader.SetGlobalFloat("_TerraSeed", Random.Range(0f, 1000f));
        }

        // DD-115/DD-120: cada civilização entrega o piso E00 (material com
        // cor original + relevo + altura da camada). Sem manchas de cor
        // procedurais — direção do Diretor: só as ondulações naturais do
        // material. Enviado uma vez, no início da partida.
        private void UploadThemeKits()
        {
            var ground = new Vector4[MaxThemes]; // x=tiling y=tem? z=relevo w=altura
            var tint = new Vector4[MaxThemes];
            var deadTint = new Vector4[MaxThemes];

            PlanetThemeRegistry registry = PlanetThemeRegistry.Current;
            for (int i = 0; i < MaxThemes; i++)
            {
                PlanetTheme theme = registry != null
                    ? registry.Get((byte)(i + 1))
                    : null;

                if (theme == null)
                {
                    continue;
                }

                ground[i] = new Vector4(
                    theme.GroundTiling,
                    theme.GroundTexture != null ? 1f : 0f,
                    theme.GroundNormalTexture != null ? theme.GroundRelief : 0f,
                    theme.GroundHeight);
                // O alfa do tint carrega o estado de vida: 1 = viva,
                // 0 = morta (o shader troca para o Death Biome, DD-122).
                Vector4 tintValue = theme.GroundTint;
                tintValue.w = _deadCivilizations[i + 1] ? 0f : 1f;
                tint[i] = tintValue;

                // Death Biome: correção de cor do material morto; o alfa
                // diz se existe material morto (senão, escurece o vivo).
                Vector4 deadValue = theme.DeadGroundTint;
                deadValue.w = theme.DeadGroundTexture != null ? 1f : 0f;
                deadTint[i] = deadValue;
                _themeHeights[i + 1] = theme.GroundHeight;
            }

            Shader.SetGlobalVectorArray("_ThemeGroundParams", ground);
            Shader.SetGlobalVectorArray("_ThemeGroundTint", tint);
            Shader.SetGlobalVectorArray("_ThemeDeadGroundTint", deadTint);

            // Os atlas dos pisos (E00): cor+AO e relevo. As fatias vêm em
            // dobro (vivas + mortas, DD-122): a contagem útil é a metade.
            if (registry != null && registry.GroundTextures != null)
            {
                Shader.SetGlobalTexture("_ThemeGroundArray", registry.GroundTextures);
                Shader.SetGlobalFloat("_ThemeGroundCount", registry.GroundTextures.depth / 2);

                if (registry.GroundNormals != null)
                {
                    Shader.SetGlobalTexture("_ThemeGroundNormalArray", registry.GroundNormals);
                }
            }
            else
            {
                Shader.SetGlobalFloat("_ThemeGroundCount", 0f);
            }
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<TerritoryCellsClaimedEvent>(OnCellsClaimed);
            EventBus.Unsubscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        private void OnCellsClaimed(TerritoryCellsClaimedEvent claimEvent)
        {
            if (!TryGetCivilizationColor(claimEvent.OwnerId, out Color32 color))
            {
                return;
            }

            float brushRadius = claimEvent.CellSpacing * _brushRadiusFactor;

            for (int i = 0; i < claimEvent.CellPositions.Count; i++)
            {
                _pendingCells.Enqueue(new PendingCell(
                    claimEvent.CellPositions[i], color, brushRadius, claimEvent.OwnerId));
            }
        }

        // DD-115: a cor do território vem do PLANET THEME da civilização
        // (o solo do bioma). Enquanto um theme não existir, cai no material
        // antigo — migração sem quebrar nada.
        private bool TryGetCivilizationColor(byte ownerId, out Color32 color)
        {
            color = default;

            PlanetTheme theme = PlanetThemeRegistry.Current != null
                ? PlanetThemeRegistry.Current.Get(ownerId)
                : null;

            if (theme != null)
            {
                color = theme.SoilBase;
                color.a = byte.MaxValue;
                return true;
            }

            int materialIndex = ownerId - 1;
            if (_civilizationMaterials == null ||
                materialIndex < 0 ||
                materialIndex >= _civilizationMaterials.Length ||
                _civilizationMaterials[materialIndex] == null)
            {
                Debug.LogError(
                    $"[World] Civilização {ownerId} não tem Planet Theme nem material. " +
                    "Configure um PlanetTheme no PlanetThemeRegistry.");
                return false;
            }

            color = _civilizationMaterials[materialIndex].color;
            color.a = byte.MaxValue;
            return true;
        }

        private void LateUpdate()
        {
            if (_pendingCells.Count > 0)
            {
                int budget = Mathf.Min(_cellsPerFrame, _pendingCells.Count);
                for (int i = 0; i < budget; i++)
                {
                    PaintCell(_pendingCells.Dequeue());
                }
            }

            if (_dirty && Time.unscaledTime >= _nextUploadTime)
            {
                _territoryMap.SetPixels32(_pixels);
                _territoryMap.Apply(updateMipmaps: false);
                _territoryIdMap.SetPixels32(_idPixels);
                _territoryIdMap.Apply(updateMipmaps: false);
                _dirty = false;
                _nextUploadTime = Time.unscaledTime + _uploadInterval;
            }
        }

        /// <summary>
        /// A ALTURA da camada de bioma numa direção do planeta (0 = terra
        /// neutra). Espelha o esfumado do shader: média em cruz larga da
        /// posse + curva suave × altura do theme dono. É o que faz
        /// corredores, cercas e bases andarem POR CIMA da areia, não
        /// afundados nela.
        /// </summary>
        public float GetElevationAt(Vector3 surfaceDirection)
        {
            if (_pixels == null)
            {
                return 0f;
            }

            Vector3 dir = surfaceDirection.normalized;
            float longitude = Mathf.Atan2(dir.z, dir.x);
            float latitude = Mathf.Asin(Mathf.Clamp(dir.y, -1f, 1f));
            int x = Mathf.RoundToInt((longitude / (2f * Mathf.PI) + 0.5f) * _mapWidth);
            int y = Mathf.Clamp(
                Mathf.RoundToInt((latitude / Mathf.PI + 0.5f) * _mapHeight), 0, _mapHeight - 1);

            // Mesma leitura larga do shader (cruz de 5 texels).
            int alpha = AlphaAt(x, y) * 2 + AlphaAt(x + 5, y) + AlphaAt(x - 5, y) +
                        AlphaAt(x, y + 5) + AlphaAt(x, y - 5);
            float fill = SmoothFill(alpha / (6f * 255f));
            if (fill <= 0f)
            {
                return 0f;
            }

            // Altura do dono: o maior theme presente na vizinhança (para a
            // rampa continuar existindo logo fora do último pixel possuído).
            float height = Mathf.Max(
                Mathf.Max(HeightAt(x, y), HeightAt(x + 5, y)),
                Mathf.Max(HeightAt(x - 5, y),
                    Mathf.Max(HeightAt(x, y + 5), HeightAt(x, y - 5))));

            return fill * height;
        }

        private int AlphaAt(int x, int y)
        {
            if (y < 0 || y >= _mapHeight)
            {
                return 0;
            }

            int wrappedX = ((x % _mapWidth) + _mapWidth) % _mapWidth;
            return _pixels[y * _mapWidth + wrappedX].a;
        }

        private float HeightAt(int x, int y)
        {
            if (y < 0 || y >= _mapHeight)
            {
                return 0f;
            }

            int wrappedX = ((x % _mapWidth) + _mapWidth) % _mapWidth;
            byte owner = _idPixels[y * _mapWidth + wrappedX].r;
            return owner <= MaxThemes ? _themeHeights[owner] : 0f;
        }

        // smoothstep(0.06, 0.9, x) — os mesmos limiares do shader.
        private static float SmoothFill(float value)
        {
            float t = Mathf.Clamp01((value - 0.06f) / (0.9f - 0.06f));
            return t * t * (3f - 2f * t);
        }

        // ------------------------------------------------------------------
        // O pincel: converte a posição da célula em latitude/longitude e
        // pinta um disco de pixels (alargado perto dos polos, onde o mapa
        // equiretangular "estica").
        // ------------------------------------------------------------------
        private void PaintCell(PendingCell cell)
        {
            Vector3 direction = (cell.Position - _planet.Center).normalized;

            float longitude = Mathf.Atan2(direction.z, direction.x);
            float latitude = Mathf.Asin(Mathf.Clamp(direction.y, -1f, 1f));

            float centerX = (longitude / (2f * Mathf.PI) + 0.5f) * _mapWidth;
            float centerY = (latitude / Mathf.PI + 0.5f) * _mapHeight;

            // Raio do pincel em pixels (ângulo → pixels do mapa).
            float angularRadius = cell.WorldRadius / _planet.Radius;
            float radiusY = angularRadius / Mathf.PI * _mapHeight;
            float cosLatitude = Mathf.Max(0.05f, Mathf.Cos(latitude));
            float radiusX = angularRadius / (2f * Mathf.PI) * _mapWidth / cosLatitude;

            int minY = Mathf.FloorToInt(centerY - radiusY);
            int maxY = Mathf.CeilToInt(centerY + radiusY);
            int minX = Mathf.FloorToInt(centerX - radiusX);
            int maxX = Mathf.CeilToInt(centerX + radiusX);

            for (int y = minY; y <= maxY; y++)
            {
                if (y < 0 || y >= _mapHeight)
                {
                    continue;
                }

                float dy = (y - centerY) / radiusY;
                for (int x = minX; x <= maxX; x++)
                {
                    float dx = (x - centerX) / radiusX;
                    if (dx * dx + dy * dy > 1f)
                    {
                        continue;
                    }

                    // Longitude dá a volta no mundo (o mapa emenda nas bordas).
                    int wrappedX = ((x % _mapWidth) + _mapWidth) % _mapWidth;
                    int index = y * _mapWidth + wrappedX;
                    _pixels[index] = cell.Color;

                    // DD-116: o ID identifica QUAL Kit de Terreno o shader usa
                    // neste pixel. Nunca é interpolado (ler ID médio não faz
                    // sentido) — por isso vive num mapa próprio, sem filtro.
                    _idPixels[index] = new Color32(cell.OwnerId, 0, 0, 255);
                }
            }

            _dirty = true;
        }

        // ------------------------------------------------------------------
        // Infraestrutura: o mapa de posse e a troca de pele do modelo.
        // ------------------------------------------------------------------
        private void BuildTerritoryMap()
        {
            _mapHeight = _mapWidth / 2;
            _territoryMap = new Texture2D(_mapWidth, _mapHeight, TextureFormat.RGBA32, mipChain: false)
            {
                name = "TerritoryOwnershipMap",
                wrapModeU = TextureWrapMode.Repeat,
                wrapModeV = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear
            };

            // Mapa de IDs: qual civilização (e portanto qual Kit de Terreno)
            // domina cada pixel. Point = nunca interpola IDs.
            // LINEAR é obrigatório: id é DADO, não cor. Em sRGB a Unity
            // aplica gama ao ler e o id 1 chega ao shader como 0,077 —
            // vira índice inválido e o bioma nunca aparece.
            _territoryIdMap = new Texture2D(
                _mapWidth, _mapHeight, TextureFormat.RGBA32, mipChain: false, linear: true)
            {
                name = "TerritoryIdMap",
                wrapModeU = TextureWrapMode.Repeat,
                wrapModeV = TextureWrapMode.Clamp,
                filterMode = FilterMode.Point
            };

            _pixels = new Color32[_mapWidth * _mapHeight];
            _idPixels = new Color32[_mapWidth * _mapHeight];
            var transparent = new Color32(0, 0, 0, 0);
            for (int i = 0; i < _pixels.Length; i++)
            {
                _pixels[i] = transparent;
                _idPixels[i] = transparent;
            }

            _territoryMap.SetPixels32(_pixels);
            _territoryMap.Apply(updateMipmaps: false);
            _territoryIdMap.SetPixels32(_idPixels);
            _territoryIdMap.Apply(updateMipmaps: false);

            Shader.SetGlobalTexture("_TerritoryMap", _territoryMap);
            Shader.SetGlobalTexture("_TerritoryIdMap", _territoryIdMap);
            Shader.SetGlobalVector("_PlanetCenter", transform.position);
            Shader.SetGlobalVector("_TerritoryMapTexel",
                new Vector4(1f / _mapWidth, 1f / _mapHeight, _mapWidth, _mapHeight));
        }

        private void ConvertPlanetMaterials()
        {
            Shader surfaceShader = Shader.Find("Terraforge/PlanetSurface");
            if (surfaceShader == null)
            {
                Debug.LogError("[World] Shader Terraforge/PlanetSurface não encontrado.");
                return;
            }

            foreach (Renderer childRenderer in GetComponentsInChildren<Renderer>())
            {
                if (childRenderer.gameObject == gameObject)
                {
                    continue; // a esfera matemática (invisível) fica como está
                }

                Material[] materials = childRenderer.materials;
                for (int i = 0; i < materials.Length; i++)
                {
                    Material original = materials[i];
                    var skinned = new Material(surfaceShader);

                    if (original.HasProperty("_BaseColor"))
                    {
                        skinned.SetColor("_BaseColor", original.GetColor("_BaseColor"));
                    }
                    else
                    {
                        skinned.SetColor("_BaseColor", original.color);
                    }

                    if (original.mainTexture != null)
                    {
                        skinned.SetTexture("_BaseMap", original.mainTexture);
                    }

                    materials[i] = skinned;
                }

                childRenderer.materials = materials;
            }
        }
    }
}
