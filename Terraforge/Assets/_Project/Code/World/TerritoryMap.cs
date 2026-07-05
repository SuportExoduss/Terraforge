using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// A verdade sobre a posse do planeta: uma grade de células distribuídas
    /// uniformemente na esfera (espiral de Fibonacci), cada uma com um dono.
    /// Conquistar = marcar células; "estou em casa?" = "esta célula é minha?".
    /// É a fundação do SYS-001/SYS-002 e, no futuro, do multiplayer.
    /// </summary>
    public sealed class TerritoryMap : MonoBehaviour, ITerritoryOwnership
    {
        [SerializeField] private int _cellCount = 20000;

        // Espessura da "cerca" formada pelo rastro durante a inundação:
        // precisa ser maior que o espaçamento entre células para não vazar.
        [SerializeField] private float _boundaryThickness = 2.4f;

        private const byte NoOwner = 0;
        private const byte PlayerOwner = 1;

        // Tamanho angular dos baldes de busca (graus de latitude/longitude).
        private const float BucketSizeDegrees = 3f;

        private Vector3[] _cellDirections;
        private byte[] _cellOwners;
        private int _playerCellCount;
        private Dictionary<Vector2Int, List<int>> _buckets;
        private float _cellSpacing;
        private bool _built;

        private void Awake()
        {
            TerritoryOwnershipLocator.Register(this);
            EventBus.Subscribe<TerritoryLoopClosedEvent>(OnLoopClosed);
        }

        private void OnDestroy()
        {
            TerritoryOwnershipLocator.Unregister(this);
            EventBus.Unsubscribe<TerritoryLoopClosedEvent>(OnLoopClosed);
        }

        public bool IsOwnedByPlayer(Vector3 worldPosition)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return false;
            }

            EnsureBuilt(planet);
            Vector3 direction = (worldPosition - planet.Center).normalized;
            int cell = FindNearestCell(direction, _cellSpacing * 2f, planet);
            return cell >= 0 && _cellOwners[cell] == PlayerOwner;
        }

        /// <summary>Marca como do jogador todas as células de uma calota (a base inicial).</summary>
        public void ClaimCap(Vector3 capDirection, float capAngleDegrees)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            EnsureBuilt(planet);
            var newlyClaimed = new List<Vector3>();
            float minDot = Mathf.Cos(capAngleDegrees * Mathf.Deg2Rad);
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (Vector3.Dot(_cellDirections[i], capDirection) >= minDot)
                {
                    ClaimCell(i, planet, newlyClaimed);
                }
            }

            PublishClaims(newlyClaimed);
        }

        private void OnLoopClosed(TerritoryLoopClosedEvent loopEvent)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null || loopEvent.TrailPoints.Count < 3)
            {
                return;
            }

            EnsureBuilt(planet);
            ClaimLoopInterior(planet, loopEvent.TrailPoints);
        }

        // ------------------------------------------------------------------
        // Conquista pelo método do "lado de fora": marca a cerca do rastro,
        // inunda o exterior do domínio a partir do ponto livre mais distante
        // e conquista TUDO que não respirar o lado de fora. Nenhum bolsão
        // cercado escapa — se está fechado, é do jogador (regra do GDMD).
        // ------------------------------------------------------------------
        private void ClaimLoopInterior(IPlanet planet, IReadOnlyList<Vector3> trailPoints)
        {
            var newlyClaimed = new List<Vector3>();
            float sampleStep = _cellSpacing * 0.5f;

            // 1. A cerca: células próximas de cada trecho do rastro viram do
            //    jogador (amostrado ponto a ponto para não deixar frestas).
            Vector3 centroidSum = Vector3.zero;
            var fence = new HashSet<int>();
            for (int i = 0; i < trailPoints.Count; i++)
            {
                Vector3 from = trailPoints[i];
                Vector3 to = trailPoints[(i + 1) % trailPoints.Count];
                float segmentLength = Vector3.Distance(from, to);
                int samples = Mathf.Max(1, Mathf.CeilToInt(segmentLength / sampleStep));

                for (int s = 0; s <= samples; s++)
                {
                    Vector3 sample = Vector3.Lerp(from, to, (float)s / samples);
                    Vector3 direction = (sample - planet.Center).normalized;
                    CollectCellsWithin(direction, _boundaryThickness, planet, fence);
                }

                centroidSum += (trailPoints[i] - planet.Center).normalized;
            }

            foreach (int cell in fence)
            {
                ClaimCell(cell, planet, newlyClaimed);
            }

            // 2. Semente do lado de fora: a célula LIVRE mais distante do
            //    circuito (o ponto do planeta que com certeza não foi cercado).
            Vector3 centroid = centroidSum.normalized;
            int outsideSeed = -1;
            float lowestDot = 2f;
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (_cellOwners[i] != NoOwner)
                {
                    continue;
                }

                float dot = Vector3.Dot(_cellDirections[i], centroid);
                if (dot < lowestDot)
                {
                    lowestDot = dot;
                    outsideSeed = i;
                }
            }

            // 3. Inunda o exterior: tudo que é livre e alcançável a partir da
            //    semente, sem atravessar território do jogador, é "oceano".
            var exterior = new HashSet<int>();
            if (outsideSeed >= 0)
            {
                var frontier = new Queue<int>();
                var neighborBuffer = new List<int>();
                exterior.Add(outsideSeed);
                frontier.Enqueue(outsideSeed);

                while (frontier.Count > 0)
                {
                    int cell = frontier.Dequeue();
                    neighborBuffer.Clear();
                    CollectCellsWithin(_cellDirections[cell], _cellSpacing * 1.6f, planet, neighborBuffer);

                    foreach (int neighbor in neighborBuffer)
                    {
                        if (_cellOwners[neighbor] == NoOwner && exterior.Add(neighbor))
                        {
                            frontier.Enqueue(neighbor);
                        }
                    }
                }
            }

            // 4. O veredito: célula livre que não respira o oceano está
            //    cercada pelo domínio do jogador — conquistada.
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (_cellOwners[i] == NoOwner && !exterior.Contains(i))
                {
                    ClaimCell(i, planet, newlyClaimed);
                }
            }

            PublishClaims(newlyClaimed);
            Debug.Log($"[World] Território anexado ao domínio do jogador: {newlyClaimed.Count} células novas.");
        }

        private void ClaimCell(int cell, IPlanet planet, List<Vector3> newlyClaimed)
        {
            if (_cellOwners[cell] != PlayerOwner)
            {
                _cellOwners[cell] = PlayerOwner;
                _playerCellCount++;
                newlyClaimed.Add(GetCellSurfacePosition(cell, planet));
            }
        }

        private Vector3 GetCellSurfacePosition(int cell, IPlanet planet)
        {
            return planet.Center + _cellDirections[cell] * planet.Radius;
        }

        private void PublishClaims(List<Vector3> newlyClaimed)
        {
            if (newlyClaimed.Count > 0)
            {
                EventBus.Publish(new TerritoryCellsClaimedEvent(newlyClaimed, _cellSpacing));
                EventBus.Publish(new TerritoryScoreChangedEvent((float)_playerCellCount / _cellCount));
            }
        }

        // ------------------------------------------------------------------
        // Construção da grade (preguiçosa: acontece no primeiro uso).
        // ------------------------------------------------------------------
        private void EnsureBuilt(IPlanet planet)
        {
            if (_built)
            {
                return;
            }

            _cellDirections = new Vector3[_cellCount];
            _cellOwners = new byte[_cellCount];
            _buckets = new Dictionary<Vector2Int, List<int>>();

            // Espiral de Fibonacci: N pontos quase perfeitamente uniformes
            // sobre a esfera — o "papel quadriculado" do planeta.
            float goldenAngle = Mathf.PI * (3f - Mathf.Sqrt(5f));
            for (int i = 0; i < _cellCount; i++)
            {
                float y = 1f - (i + 0.5f) * 2f / _cellCount;
                float radiusAtY = Mathf.Sqrt(1f - y * y);
                float angle = goldenAngle * i;
                var direction = new Vector3(
                    Mathf.Cos(angle) * radiusAtY,
                    y,
                    Mathf.Sin(angle) * radiusAtY);

                _cellDirections[i] = direction;
                GetBucketList(GetBucketKey(direction), createIfMissing: true).Add(i);
            }

            // Distância média entre células vizinhas (na superfície real).
            float sphereArea = 4f * Mathf.PI * planet.Radius * planet.Radius;
            _cellSpacing = Mathf.Sqrt(sphereArea / _cellCount);
            _built = true;

            Debug.Log($"[World] Grade territorial criada: {_cellCount} células, " +
                      $"espaçamento ~{_cellSpacing:F2} unidades.");
        }

        // ------------------------------------------------------------------
        // Busca espacial por baldes de latitude/longitude.
        // ------------------------------------------------------------------
        private static Vector2Int GetBucketKey(Vector3 direction)
        {
            float latitude = Mathf.Asin(Mathf.Clamp(direction.y, -1f, 1f)) * Mathf.Rad2Deg;
            float longitude = Mathf.Atan2(direction.z, direction.x) * Mathf.Rad2Deg;
            return new Vector2Int(
                Mathf.FloorToInt((longitude + 180f) / BucketSizeDegrees),
                Mathf.FloorToInt((latitude + 90f) / BucketSizeDegrees));
        }

        private List<int> GetBucketList(Vector2Int key, bool createIfMissing)
        {
            if (!_buckets.TryGetValue(key, out List<int> list) && createIfMissing)
            {
                list = new List<int>();
                _buckets[key] = list;
            }

            return list;
        }

        private int FindNearestCell(Vector3 direction, float maxSurfaceDistance, IPlanet planet)
        {
            int best = -1;
            float bestDot = -2f;
            float minDot = Mathf.Cos(maxSurfaceDistance / planet.Radius);

            foreach (int candidate in EnumerateCandidates(direction, maxSurfaceDistance, planet))
            {
                float dot = Vector3.Dot(_cellDirections[candidate], direction);
                if (dot >= minDot && dot > bestDot)
                {
                    bestDot = dot;
                    best = candidate;
                }
            }

            return best;
        }

        private void CollectCellsWithin(
            Vector3 direction, float surfaceDistance, IPlanet planet, ICollection<int> results)
        {
            float minDot = Mathf.Cos(surfaceDistance / planet.Radius);
            foreach (int candidate in EnumerateCandidates(direction, surfaceDistance, planet))
            {
                if (Vector3.Dot(_cellDirections[candidate], direction) >= minDot)
                {
                    results.Add(candidate);
                }
            }
        }

        private IEnumerable<int> EnumerateCandidates(
            Vector3 direction, float surfaceDistance, IPlanet planet)
        {
            float radiusDegrees = surfaceDistance / planet.Radius * Mathf.Rad2Deg;
            int bucketRange = Mathf.CeilToInt(radiusDegrees / BucketSizeDegrees);
            Vector2Int center = GetBucketKey(direction);
            int longitudeBuckets = Mathf.CeilToInt(360f / BucketSizeDegrees);

            for (int dy = -bucketRange; dy <= bucketRange; dy++)
            {
                int latIndex = center.y + dy;

                // Perto dos polos os baldes de longitude ficam estreitos;
                // alarga a varredura conforme a latitude.
                float latitudeDegrees = latIndex * BucketSizeDegrees - 90f + BucketSizeDegrees * 0.5f;
                float cosLat = Mathf.Max(0.05f, Mathf.Cos(latitudeDegrees * Mathf.Deg2Rad));
                int lonRange = Mathf.Min(
                    longitudeBuckets / 2,
                    Mathf.CeilToInt(radiusDegrees / (BucketSizeDegrees * cosLat)));

                for (int dx = -lonRange; dx <= lonRange; dx++)
                {
                    int lonIndex = ((center.x + dx) % longitudeBuckets + longitudeBuckets) % longitudeBuckets;
                    List<int> bucket = GetBucketList(new Vector2Int(lonIndex, latIndex), createIfMissing: false);
                    if (bucket == null)
                    {
                        continue;
                    }

                    foreach (int cell in bucket)
                    {
                        yield return cell;
                    }
                }
            }
        }
    }
}
