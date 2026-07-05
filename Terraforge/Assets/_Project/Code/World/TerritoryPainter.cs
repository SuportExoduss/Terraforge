using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;
using UnityEngine.Rendering;

namespace Terraforge.World
{
    /// <summary>
    /// O visual do território: um "azulejo" hexagonal sobre cada célula
    /// conquistada, todos numa única malha que cresce a cada conquista.
    /// Pinta a partir dos MESMOS dados do TerritoryMap — visual e posse
    /// nunca divergem.
    /// </summary>
    public sealed class TerritoryPainter : MonoBehaviour
    {
        [SerializeField] private Material _territoryMaterial;

        // Abaixo do rastro (0.15) para a linha continuar visível por cima.
        [SerializeField] private float _surfaceOffset = 0.1f;

        // Raio do azulejo relativo ao espaçamento da grade: acima de 0.5,
        // vizinhos se sobrepõem e a mancha fica contínua, sem frestas.
        [SerializeField] private float _tileRadiusFactor = 0.95f;

        private const int TileSides = 6;

        private readonly List<Vector3> _vertices = new();
        private readonly List<Vector3> _normals = new();
        private readonly List<int> _triangles = new();
        private Mesh _mesh;

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

            EnsureMeshExists(planet);

            float tileRadius = claimEvent.CellSpacing * _tileRadiusFactor;
            foreach (Vector3 cellPosition in claimEvent.CellPositions)
            {
                AppendTile(cellPosition, tileRadius, planet);
            }

            _mesh.SetVertices(_vertices);
            _mesh.SetNormals(_normals);
            _mesh.SetTriangles(_triangles, 0);
        }

        private void EnsureMeshExists(IPlanet planet)
        {
            if (_mesh != null)
            {
                return;
            }

            // UInt32: a malha crescerá além do limite de 65 mil vértices
            // do formato padrão conforme o império se expande.
            _mesh = new Mesh { name = "TerritoryLayer" };
            _mesh.indexFormat = IndexFormat.UInt32;

            var layer = new GameObject("TerritoryLayer");
            layer.transform.position = planet.Center;
            layer.AddComponent<MeshFilter>().mesh = _mesh;
            layer.AddComponent<MeshRenderer>().material = _territoryMaterial;
        }

        private void AppendTile(Vector3 cellPosition, float tileRadius, IPlanet planet)
        {
            Vector3 up = (cellPosition - planet.Center).normalized;

            // Base tangente à superfície para desenhar o hexágono deitado.
            Vector3 reference = Mathf.Abs(up.y) < 0.99f ? Vector3.up : Vector3.right;
            Vector3 tangent = Vector3.Cross(up, reference).normalized;
            Vector3 bitangent = Vector3.Cross(up, tangent);

            float surfaceRadius = planet.Radius + _surfaceOffset;
            int centerIndex = _vertices.Count;

            _vertices.Add(planet.Center + up * surfaceRadius);
            _normals.Add(up);

            for (int i = 0; i < TileSides; i++)
            {
                float angle = i * (2f * Mathf.PI / TileSides);
                Vector3 rim =
                    cellPosition + (tangent * Mathf.Cos(angle) + bitangent * Mathf.Sin(angle)) * tileRadius;

                // Projeta a ponta do azulejo de volta à casca da esfera.
                Vector3 rimUp = (rim - planet.Center).normalized;
                _vertices.Add(planet.Center + rimUp * surfaceRadius);
                _normals.Add(rimUp);
            }

            for (int i = 0; i < TileSides; i++)
            {
                _triangles.Add(centerIndex);
                _triangles.Add(centerIndex + 1 + i);
                _triangles.Add(centerIndex + 1 + (i + 1) % TileSides);
            }
        }
    }
}
