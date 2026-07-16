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

            public PendingCell(Vector3 position, Color32 color, float worldRadius)
            {
                Position = position;
                Color = color;
                WorldRadius = worldRadius;
            }
        }

        private readonly Queue<PendingCell> _pendingCells = new();
        private Planet _planet;
        private Texture2D _territoryMap;
        private Color32[] _pixels;
        private int _mapHeight;
        private bool _dirty;
        private float _nextUploadTime;

        private void Awake()
        {
            _planet = GetComponent<Planet>();
            BuildTerritoryMap();
            EventBus.Subscribe<TerritoryCellsClaimedEvent>(OnCellsClaimed);
        }

        private void Start()
        {
            // Troca os materiais do modelo visual pelo shader da "pele"
            // (preservando a cor/textura original de cada parte).
            ConvertPlanetMaterials();
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<TerritoryCellsClaimedEvent>(OnCellsClaimed);
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
                _pendingCells.Enqueue(
                    new PendingCell(claimEvent.CellPositions[i], color, brushRadius));
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
                _dirty = false;
                _nextUploadTime = Time.unscaledTime + _uploadInterval;
            }
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
                    _pixels[y * _mapWidth + wrappedX] = cell.Color;
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

            _pixels = new Color32[_mapWidth * _mapHeight];
            var transparent = new Color32(0, 0, 0, 0);
            for (int i = 0; i < _pixels.Length; i++)
            {
                _pixels[i] = transparent;
            }

            _territoryMap.SetPixels32(_pixels);
            _territoryMap.Apply(updateMipmaps: false);

            Shader.SetGlobalTexture("_TerritoryMap", _territoryMap);
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
