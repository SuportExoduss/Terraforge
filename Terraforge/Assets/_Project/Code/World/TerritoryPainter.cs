using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// O visual do território: azulejos hexagonais por civilização, gerados
    /// dos MESMOS dados do TerritoryMap — visual e posse nunca divergem.
    /// A malha de cada civilização é fatiada em BLOCOS (~1000 azulejos):
    /// blocos cheios são selados e nunca mais reenviados à placa de vídeo,
    /// mantendo os envios pequenos e constantes (sem picos nem alarmes de
    /// memória do motor).
    /// </summary>
    public sealed class TerritoryPainter : MonoBehaviour
    {
        // Elemento 0 = civilização 1 (jogador), elemento 1 = civilização 2...
        [SerializeField] private Material[] _civilizationMaterials;

        // Abaixo do rastro (0.15) para a linha continuar visível por cima.
        [SerializeField] private float _surfaceOffset = 0.1f;

        // Raio do azulejo relativo ao espaçamento da grade: acima de 0.5,
        // vizinhos se sobrepõem e a mancha fica contínua, sem frestas.
        [SerializeField] private float _tileRadiusFactor = 0.95f;

        // Azulejos por bloco: 1000 × 7 vértices fica bem abaixo do limite
        // de 65 mil do formato compacto de malha.
        [SerializeField] private int _tilesPerChunk = 1000;

        private const int TileSides = 6;
        private const int VerticesPerTile = TileSides + 1;

        // Conversões de território: cada leva de pintura sobe um fio de
        // cabelo acima da anterior, para a cor nova cobrir a antiga.
        // (Dívida conhecida do protótipo; o definitivo removerá azulejos.)
        private const float ElevationStep = 0.0005f;

        private sealed class MeshChunk
        {
            public readonly List<Vector3> Vertices = new();
            public readonly List<Vector3> Normals = new();
            public readonly List<int> Triangles = new();
            public Mesh Mesh;
            public int TileCount;
        }

        private sealed class CivilizationLayer
        {
            public readonly List<MeshChunk> Chunks = new();
            public Transform Root;
            public Material Material;
        }

        private readonly Dictionary<byte, CivilizationLayer> _layers = new();
        private readonly HashSet<MeshChunk> _dirtyChunks = new();
        private float _paintElevation;

        private void Awake()
        {
            EventBus.Subscribe<TerritoryCellsClaimedEvent>(OnCellsClaimed);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<TerritoryCellsClaimedEvent>(OnCellsClaimed);
        }

        private void OnCellsClaimed(TerritoryCellsClaimedEvent claimEvent)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null || claimEvent.CellPositions.Count == 0)
            {
                return;
            }

            CivilizationLayer layer = GetOrCreateLayer(claimEvent.OwnerId, planet);
            if (layer == null)
            {
                return;
            }

            _paintElevation += ElevationStep;
            float tileRadius = claimEvent.CellSpacing * _tileRadiusFactor;
            for (int i = 0; i < claimEvent.CellPositions.Count; i++)
            {
                MeshChunk chunk = GetWritableChunk(layer, planet);
                AppendTile(chunk, claimEvent.CellPositions[i], tileRadius, planet);
                _dirtyChunks.Add(chunk);
            }
        }

        // Envio único por frame, e apenas dos blocos que mudaram.
        private void LateUpdate()
        {
            if (_dirtyChunks.Count == 0)
            {
                return;
            }

            foreach (MeshChunk chunk in _dirtyChunks)
            {
                chunk.Mesh.SetVertices(chunk.Vertices);
                chunk.Mesh.SetNormals(chunk.Normals);
                chunk.Mesh.SetTriangles(chunk.Triangles, 0);
            }

            _dirtyChunks.Clear();
        }

        private CivilizationLayer GetOrCreateLayer(byte ownerId, IPlanet planet)
        {
            if (_layers.TryGetValue(ownerId, out CivilizationLayer existing))
            {
                return existing;
            }

            int materialIndex = ownerId - 1;
            if (materialIndex < 0 || materialIndex >= _civilizationMaterials.Length)
            {
                Debug.LogError(
                    $"[World] TerritoryPainter sem material para a civilização {ownerId} " +
                    "(configure a lista Civilization Materials).");
                return null;
            }

            var rootObject = new GameObject($"TerritoryLayer_Civ{ownerId}");
            rootObject.transform.position = planet.Center;

            var layer = new CivilizationLayer
            {
                Root = rootObject.transform,
                Material = _civilizationMaterials[materialIndex]
            };

            _layers[ownerId] = layer;
            return layer;
        }

        // Bloco atual da civilização; cheio = sela e abre um novo.
        private MeshChunk GetWritableChunk(CivilizationLayer layer, IPlanet planet)
        {
            if (layer.Chunks.Count > 0)
            {
                MeshChunk last = layer.Chunks[^1];
                if (last.TileCount < _tilesPerChunk)
                {
                    return last;
                }
            }

            var chunk = new MeshChunk
            {
                Mesh = new Mesh { name = $"TerritoryChunk_{layer.Chunks.Count}" }
            };
            chunk.Mesh.MarkDynamic();

            var chunkObject = new GameObject($"Chunk_{layer.Chunks.Count}");
            chunkObject.transform.SetParent(layer.Root, worldPositionStays: false);
            chunkObject.transform.position = planet.Center;
            chunkObject.AddComponent<MeshFilter>().mesh = chunk.Mesh;
            chunkObject.AddComponent<MeshRenderer>().material = layer.Material;

            layer.Chunks.Add(chunk);
            return chunk;
        }

        private void AppendTile(MeshChunk chunk, Vector3 cellPosition, float tileRadius, IPlanet planet)
        {
            Vector3 up = (cellPosition - planet.Center).normalized;

            // Base tangente à superfície para desenhar o hexágono deitado.
            Vector3 reference = Mathf.Abs(up.y) < 0.99f ? Vector3.up : Vector3.right;
            Vector3 tangent = Vector3.Cross(up, reference).normalized;
            Vector3 bitangent = Vector3.Cross(up, tangent);

            float surfaceRadius = planet.Radius + _surfaceOffset + _paintElevation;
            int centerIndex = chunk.Vertices.Count;

            chunk.Vertices.Add(planet.Center + up * surfaceRadius);
            chunk.Normals.Add(up);

            for (int i = 0; i < TileSides; i++)
            {
                float angle = i * (2f * Mathf.PI / TileSides);
                Vector3 rim =
                    cellPosition + (tangent * Mathf.Cos(angle) + bitangent * Mathf.Sin(angle)) * tileRadius;

                // Projeta a ponta do azulejo de volta à casca da esfera.
                Vector3 rimUp = (rim - planet.Center).normalized;
                chunk.Vertices.Add(planet.Center + rimUp * surfaceRadius);
                chunk.Normals.Add(rimUp);
            }

            for (int i = 0; i < TileSides; i++)
            {
                chunk.Triangles.Add(centerIndex);
                chunk.Triangles.Add(centerIndex + 1 + i);
                chunk.Triangles.Add(centerIndex + 1 + (i + 1) % TileSides);
            }

            chunk.TileCount++;
        }
    }
}
