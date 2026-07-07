using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// Detecta quando este corredor encosta no rastro de OUTRA civilização
    /// e ordena o corte (DD-099). O invasor não é afetado — segue correndo.
    /// </summary>
    public sealed class TrailCutSensor : MonoBehaviour
    {
        // Raio de toque: precisa cobrir a distância vertical entre o centro
        // da cápsula (1 acima do chão) e a linha do rastro (0.15 acima).
        [SerializeField] private float _cutRadius = 1.5f;

        // Carência: rastros recém-nascidos (poucos pontos) ainda não podem
        // ser cortados — evita a cascata de cortes/teleportes no segundo em
        // que alguém sai da própria base.
        [SerializeField] private int _minPointsToCut = 5;

        private Civilization _civilization;

        private void Awake()
        {
            _civilization = GetComponent<Civilization>();
            if (_civilization == null)
            {
                Debug.LogError($"[TrailCutSensor] {name} precisa do crachá Civilization.");
                enabled = false;
            }
        }

        private void Update()
        {
            Vector3 position = transform.position;
            IReadOnlyList<ICuttableTrail> trails = TrailRegistry.All;

            for (int t = 0; t < trails.Count; t++)
            {
                ICuttableTrail trail = trails[t];
                if (trail.OwnerId == _civilization.Id || trail.Points.Count < _minPointsToCut)
                {
                    continue;
                }

                if (IsTouchingTrail(trail.Points, position))
                {
                    trail.Cut(_civilization.Id);
                }
            }
        }

        private bool IsTouchingTrail(IReadOnlyList<Vector3> points, Vector3 position)
        {
            float radiusSquared = _cutRadius * _cutRadius;
            for (int i = 0; i < points.Count - 1; i++)
            {
                Vector3 closest = ClosestPointOnSegment(points[i], points[i + 1], position);
                if ((closest - position).sqrMagnitude <= radiusSquared)
                {
                    return true;
                }
            }

            return false;
        }

        private static Vector3 ClosestPointOnSegment(Vector3 a, Vector3 b, Vector3 point)
        {
            Vector3 segment = b - a;
            float lengthSquared = segment.sqrMagnitude;
            if (lengthSquared < 0.0001f)
            {
                return a;
            }

            float projection = Mathf.Clamp01(Vector3.Dot(point - a, segment) / lengthSquared);
            return a + segment * projection;
        }
    }
}
