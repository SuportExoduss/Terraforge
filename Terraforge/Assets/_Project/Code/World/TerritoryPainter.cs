using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;
using UnityEngine.Rendering;

namespace Terraforge.World
{
    /// <summary>
    /// O visual do território: uma camada de azulejos hexagonais por
    /// civilização, cada uma com seu material, todas geradas dos MESMOS
    /// dados do TerritoryMap — visual e posse nunca divergem.
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

        private const int TileSides = 6;

        // Conversões de território: cada leva de pintura sobe um fio de
        // cabelo acima da anterior, para a cor nova cobrir a antiga.
        // (Dívida conhecida do protótipo; o definitivo removerá azulejos.)
        private const float ElevationStep = 0.0005f;

        private sealed class CivilizationLayer
        {
            public readonly List<Vector3> Vertices = new();
            public readonly List<Vector3> Normals = new();
            public readonly List<int> Triangles = new();
            public Mesh Mesh;
        }

        private readonly Dictionary<byte, CivilizationLayer> _layers = new();
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
            foreach (Vector3 cellPosition in claimEvent.CellPositions)
            {
                AppendTile(layer, cellPosition, tileRadius, planet);
            }

            layer.Mesh.SetVertices(layer.Vertices);
            layer.Mesh.SetNormals(layer.Normals);
            layer.Mesh.SetTriangles(layer.Triangles, 0);
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

            var layer = new CivilizationLayer
            {
                // UInt32: a malha crescerá além do limite de 65 mil vértices
                // do formato padrão conforme o domínio se expande.
                Mesh = new Mesh
                {
                    name = $"TerritoryLayer_Civ{ownerId}",
                    indexFormat = IndexFormat.UInt32
                }
            };

            var layerObject = new GameObject($"TerritoryLayer_Civ{ownerId}");
            layerObject.transform.position = planet.Center;
            layerObject.AddComponent<MeshFilter>().mesh = layer.Mesh;
            layerObject.AddComponent<MeshRenderer>().material = _civilizationMaterials[materialIndex];

            _layers[ownerId] = layer;
            return layer;
        }

        private void AppendTile(
            CivilizationLayer layer, Vector3 cellPosition, float tileRadius, IPlanet planet)
        {
            Vector3 up = (cellPosition - planet.Center).normalized;

            // Base tangente à superfície para desenhar o hexágono deitado.
            Vector3 reference = Mathf.Abs(up.y) < 0.99f ? Vector3.up : Vector3.right;
            Vector3 tangent = Vector3.Cross(up, reference).normalized;
            Vector3 bitangent = Vector3.Cross(up, tangent);

            float surfaceRadius = planet.Radius + _surfaceOffset + _paintElevation;
            int centerIndex = layer.Vertices.Count;

            layer.Vertices.Add(planet.Center + up * surfaceRadius);
            layer.Normals.Add(up);

            for (int i = 0; i < TileSides; i++)
            {
                float angle = i * (2f * Mathf.PI / TileSides);
                Vector3 rim =
                    cellPosition + (tangent * Mathf.Cos(angle) + bitangent * Mathf.Sin(angle)) * tileRadius;

                // Projeta a ponta do azulejo de volta à casca da esfera.
                Vector3 rimUp = (rim - planet.Center).normalized;
                layer.Vertices.Add(planet.Center + rimUp * surfaceRadius);
                layer.Normals.Add(rimUp);
            }

            for (int i = 0; i < TileSides; i++)
            {
                layer.Triangles.Add(centerIndex);
                layer.Triangles.Add(centerIndex + 1 + i);
                layer.Triangles.Add(centerIndex + 1 + (i + 1) % TileSides);
            }
        }
    }
}
