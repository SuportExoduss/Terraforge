using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// A verdade sobre a posse do planeta: uma grade de células distribuídas
    /// uniformemente na esfera (espiral de Fibonacci), cada uma com o id da
    /// civilização dona. Conquistar = marcar células; cercar território
    /// inimigo o converte; fragmentos sem conexão com a base do dono são
    /// amputados (DD-102); dominar a base herda o império (DD-100).
    /// Todas as buscas reutilizam buffers — zero lixo de memória por frame.
    /// </summary>
    public sealed class TerritoryMap : MonoBehaviour, ITerritoryOwnership
    {
        [SerializeField] private int _cellCount = 20000;

        // Espessura da "cerca" formada pelo rastro durante a inundação:
        // precisa ser maior que o espaçamento entre células para não vazar.
        [SerializeField] private float _boundaryThickness = 2.4f;

        private const byte NoOwner = 0;
        private const int MaxOwners = 16;

        // Tamanho angular dos baldes de busca (graus de latitude/longitude).
        private const float BucketSizeDegrees = 3f;

        private Vector3[] _cellDirections;
        private byte[] _cellOwners;
        private int[][] _neighbors;
        private readonly int[] _cellCountsByOwner = new int[MaxOwners];
        private Dictionary<Vector2Int, List<int>> _buckets;
        private float _cellSpacing;
        private bool _built;

        // Buffers reutilizados pelas buscas e inundações (evitam o coletor
        // de lixo — causa clássica de engasgos em jogos).
        private readonly List<int> _candidateBuffer = new(64);
        private readonly List<int> _neighborBuffer = new(32);
        private readonly HashSet<int> _fence = new();
        private readonly HashSet<int> _searchSet = new();
        private readonly Queue<int> _searchFrontier = new();
        private readonly List<Vector3> _claimBuffer = new(256);
        private readonly HashSet<byte> _dispossessedBuffer = new();
        private readonly HashSet<int> _pocketVisited = new();
        private readonly List<int> _pocketBuffer = new(256);
        private readonly int[] _pocketBorderCounts = new int[MaxOwners];

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

        public bool IsOwnedBy(byte civilizationId, Vector3 worldPosition)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return false;
            }

            EnsureBuilt(planet);
            Vector3 direction = (worldPosition - planet.Center).normalized;
            int cell = FindNearestCell(direction, _cellSpacing * 2f, planet);
            return cell >= 0 && _cellOwners[cell] == civilizationId;
        }

        /// <summary>Quem é o dono do chão neste ponto (0 = ninguém).</summary>
        public byte GetOwnerAt(Vector3 worldPosition)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return NoOwner;
            }

            EnsureBuilt(planet);
            Vector3 direction = (worldPosition - planet.Center).normalized;
            int cell = FindNearestCell(direction, _cellSpacing * 2f, planet);
            return cell >= 0 ? _cellOwners[cell] : NoOwner;
        }

        /// <summary>
        /// DD-100: dominar a base = herdar o império. Converte TODAS as
        /// células da vítima para o conquistador, com placares atualizados.
        /// </summary>
        public void ConvertAllCellsOf(byte victimId, byte conquerorId)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null || victimId == conquerorId || conquerorId == NoOwner)
            {
                return;
            }

            EnsureBuilt(planet);
            _claimBuffer.Clear();
            _dispossessedBuffer.Clear();
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (_cellOwners[i] == victimId)
                {
                    ClaimCell(conquerorId, i, planet);
                }
            }

            PublishClaims(conquerorId);

            // A herança pode ter emendado territórios ao redor de vãos
            // livres — era a origem dos "buracos" no fim da partida.
            SealEnclosedFreePockets(planet);
        }

        public Vector3 GetRandomUnownedPosition()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return Vector3.zero;
            }

            EnsureBuilt(planet);

            // Sorteia até achar célula livre; num planeta quase todo dominado,
            // devolve qualquer uma após 128 tentativas (fim de partida raro).
            for (int attempt = 0; attempt < 128; attempt++)
            {
                int cell = Random.Range(0, _cellCount);
                if (_cellOwners[cell] == NoOwner)
                {
                    return GetCellSurfacePosition(cell, planet);
                }
            }

            return GetCellSurfacePosition(Random.Range(0, _cellCount), planet);
        }

        /// <summary>Entrega uma calota à civilização (a base inicial de cada uma).</summary>
        public void ClaimCap(byte ownerId, Vector3 capDirection, float capAngleDegrees)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            EnsureBuilt(planet);
            _claimBuffer.Clear();
            _dispossessedBuffer.Clear();
            float minDot = Mathf.Cos(capAngleDegrees * Mathf.Deg2Rad);
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (Vector3.Dot(_cellDirections[i], capDirection) >= minDot)
                {
                    ClaimCell(ownerId, i, planet);
                }
            }

            PublishClaims(ownerId);
        }

        private void OnLoopClosed(TerritoryLoopClosedEvent loopEvent)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null || loopEvent.TrailPoints.Count < 3)
            {
                return;
            }

            EnsureBuilt(planet);
            ClaimLoopInterior(loopEvent.OwnerId, planet, loopEvent.TrailPoints);
        }

        // ------------------------------------------------------------------
        // Conquista pelo método do "lado de fora": marca a cerca do rastro,
        // inunda o exterior do domínio e converte TUDO que ficou cercado.
        // ------------------------------------------------------------------
        private void ClaimLoopInterior(byte ownerId, IPlanet planet, IReadOnlyList<Vector3> trailPoints)
        {
            _claimBuffer.Clear();
            _dispossessedBuffer.Clear();
            float sampleStep = _cellSpacing * 0.5f;

            // A cerca precisa ser sempre mais grossa que o vão entre células,
            // senão a inundação vaza — em qualquer tamanho de planeta.
            float fenceThickness = Mathf.Max(_boundaryThickness, _cellSpacing * 1.3f);

            // 1. A cerca: células próximas de cada trecho do rastro viram do
            //    conquistador (amostrado ponto a ponto para não deixar frestas).
            Vector3 centroidSum = Vector3.zero;
            _fence.Clear();
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
                    CollectCellsWithin(direction, fenceThickness, planet, _fence);
                }

                centroidSum += (trailPoints[i] - planet.Center).normalized;
            }

            foreach (int cell in _fence)
            {
                ClaimCell(ownerId, cell, planet);
            }

            // 2. Semente do lado de fora: a célula mais distante do circuito
            //    que NÃO pertence ao conquistador.
            Vector3 centroid = centroidSum.normalized;
            int outsideSeed = -1;
            float lowestDot = 2f;
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (_cellOwners[i] == ownerId)
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

            // 3. Inunda o exterior: tudo que não é do conquistador e é
            //    alcançável a partir da semente respira o "oceano".
            _searchSet.Clear();
            if (outsideSeed >= 0)
            {
                _searchFrontier.Clear();
                _searchSet.Add(outsideSeed);
                _searchFrontier.Enqueue(outsideSeed);

                while (_searchFrontier.Count > 0)
                {
                    int cell = _searchFrontier.Dequeue();
                    int[] neighbors = _neighbors[cell];
                    for (int n = 0; n < neighbors.Length; n++)
                    {
                        int neighbor = neighbors[n];
                        if (_cellOwners[neighbor] != ownerId && _searchSet.Add(neighbor))
                        {
                            _searchFrontier.Enqueue(neighbor);
                        }
                    }
                }
            }

            // 4. O veredito: quem não é do conquistador e não respira o
            //    oceano está cercado — convertido, seja livre ou inimigo.
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (_cellOwners[i] != ownerId && !_searchSet.Contains(i))
                {
                    ClaimCell(ownerId, i, planet);
                }
            }

            // DD-102: fragmentos inimigos que perderam a conexão com a
            // própria base são amputados — viram do conquistador.
            ConvertDisconnectedEnemyRegions(ownerId, planet);

            PublishClaims(ownerId);
            Debug.Log(
                $"[World] Civilização {ownerId} anexou {_claimBuffer.Count} células" +
                (_dispossessedBuffer.Count > 0 ? " (convertendo território inimigo!)." : "."));

            // Nenhum vão preso: bolsões livres cercados são selados.
            SealEnclosedFreePockets(planet);
        }

        // ------------------------------------------------------------------
        // Nenhum buraco fica para trás: após qualquer conversão em massa,
        // regiões LIVRES que perderam contato com o "oceano" (a maior região
        // livre do planeta) estão cercadas — e são entregues ao dono que
        // mais as cerca. Pedido do Diretor: sem espaços abertos presos.
        // ------------------------------------------------------------------
        private void SealEnclosedFreePockets(IPlanet planet)
        {
            // 1. Acha a maior região livre (o oceano respirável).
            _pocketVisited.Clear();
            int largestSeed = -1;
            int largestSize = 0;
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (_cellOwners[i] != NoOwner || _pocketVisited.Contains(i))
                {
                    continue;
                }

                int size = FloodFreeRegion(i, collectCells: false);
                if (size > largestSize)
                {
                    largestSize = size;
                    largestSeed = i;
                }
            }

            if (largestSeed < 0)
            {
                return; // não há terra livre nenhuma
            }

            // 2. Marca o oceano em _searchSet.
            _searchSet.Clear();
            _searchFrontier.Clear();
            _searchSet.Add(largestSeed);
            _searchFrontier.Enqueue(largestSeed);
            while (_searchFrontier.Count > 0)
            {
                int cell = _searchFrontier.Dequeue();
                int[] neighbors = _neighbors[cell];
                for (int n = 0; n < neighbors.Length; n++)
                {
                    int neighbor = neighbors[n];
                    if (_cellOwners[neighbor] == NoOwner && _searchSet.Add(neighbor))
                    {
                        _searchFrontier.Enqueue(neighbor);
                    }
                }
            }

            // 3. Toda célula livre fora do oceano pertence a um bolsão:
            //    entrega cada bolsão a quem mais o cerca.
            _pocketVisited.Clear();
            for (int i = 0; i < _cellDirections.Length; i++)
            {
                if (_cellOwners[i] != NoOwner || _searchSet.Contains(i) ||
                    _pocketVisited.Contains(i))
                {
                    continue;
                }

                FloodFreeRegion(i, collectCells: true);

                byte bestOwner = NoOwner;
                int bestCount = 0;
                for (int owner = 1; owner < MaxOwners; owner++)
                {
                    if (_pocketBorderCounts[owner] > bestCount)
                    {
                        bestCount = _pocketBorderCounts[owner];
                        bestOwner = (byte)owner;
                    }
                }

                if (bestOwner == NoOwner)
                {
                    continue;
                }

                _claimBuffer.Clear();
                _dispossessedBuffer.Clear();
                for (int p = 0; p < _pocketBuffer.Count; p++)
                {
                    ClaimCell(bestOwner, _pocketBuffer[p], planet);
                }

                PublishClaims(bestOwner);
                Debug.Log(
                    $"[World] Bolsão cercado de {_pocketBuffer.Count} células " +
                    $"selado para a civilização {bestOwner}.");
            }
        }

        // Inunda uma região livre a partir da semente. Com collectCells,
        // guarda as células em _pocketBuffer e conta os donos vizinhos em
        // _pocketBorderCounts. Sempre marca _pocketVisited. Devolve o tamanho.
        private int FloodFreeRegion(int seed, bool collectCells)
        {
            if (collectCells)
            {
                _pocketBuffer.Clear();
                System.Array.Clear(_pocketBorderCounts, 0, _pocketBorderCounts.Length);
            }

            int size = 0;
            _searchFrontier.Clear();
            _pocketVisited.Add(seed);
            _searchFrontier.Enqueue(seed);

            while (_searchFrontier.Count > 0)
            {
                int cell = _searchFrontier.Dequeue();
                size++;
                if (collectCells)
                {
                    _pocketBuffer.Add(cell);
                }

                int[] neighbors = _neighbors[cell];
                for (int n = 0; n < neighbors.Length; n++)
                {
                    int neighbor = neighbors[n];
                    byte owner = _cellOwners[neighbor];
                    if (owner == NoOwner)
                    {
                        if (_pocketVisited.Add(neighbor))
                        {
                            _searchFrontier.Enqueue(neighbor);
                        }
                    }
                    else if (collectCells)
                    {
                        _pocketBorderCounts[owner]++;
                    }
                }
            }

            return size;
        }

        // ------------------------------------------------------------------
        // DD-102: para cada civilização inimiga, inunda o território dela a
        // partir da célula da base; o que o "sangue" da base não alcançar
        // está amputado e é convertido para o conquistador.
        // ------------------------------------------------------------------
        private void ConvertDisconnectedEnemyRegions(byte conquerorId, IPlanet planet)
        {
            // Só quem acabou de perder células pode ter ficado separado da
            // própria base. Evita flood fills inúteis para todas as demais
            // civilizações a cada circuito fechado.
            foreach (byte enemy in _dispossessedBuffer)
            {
                if (enemy == conquerorId || _cellCountsByOwner[enemy] <= 0)
                {
                    continue;
                }

                if (!HomeBaseRegistry.TryGet(enemy, out HomeBaseRegistry.BaseInfo baseInfo))
                {
                    continue;
                }

                Vector3 baseDirection = (baseInfo.Position - planet.Center).normalized;
                int baseCell = FindNearestCell(baseDirection, _cellSpacing * 3f, planet);
                if (baseCell < 0 || _cellOwners[baseCell] != enemy)
                {
                    // A própria base já não é do dono: cenário do DD-100,
                    // resolvido pela realocação da nave.
                    continue;
                }

                _searchSet.Clear();
                _searchFrontier.Clear();
                _searchSet.Add(baseCell);
                _searchFrontier.Enqueue(baseCell);

                while (_searchFrontier.Count > 0)
                {
                    int cell = _searchFrontier.Dequeue();
                    int[] neighbors = _neighbors[cell];
                    for (int n = 0; n < neighbors.Length; n++)
                    {
                        int neighbor = neighbors[n];
                        if (_cellOwners[neighbor] == enemy && _searchSet.Add(neighbor))
                        {
                            _searchFrontier.Enqueue(neighbor);
                        }
                    }
                }

                if (_searchSet.Count >= _cellCountsByOwner[enemy])
                {
                    continue; // território inteiro conectado — nada a amputar
                }

                for (int i = 0; i < _cellDirections.Length; i++)
                {
                    if (_cellOwners[i] == enemy && !_searchSet.Contains(i))
                    {
                        ClaimCell(conquerorId, i, planet);
                    }
                }

                Debug.Log($"[World] Território amputado da civilização {enemy} (DD-102).");
            }
        }

        private void ClaimCell(byte ownerId, int cell, IPlanet planet)
        {
            byte previousOwner = _cellOwners[cell];
            if (previousOwner == ownerId)
            {
                return;
            }

            if (previousOwner != NoOwner)
            {
                _cellCountsByOwner[previousOwner]--;
                _dispossessedBuffer.Add(previousOwner);
            }

            _cellOwners[cell] = ownerId;
            _cellCountsByOwner[ownerId]++;
            _claimBuffer.Add(GetCellSurfacePosition(cell, planet));
        }

        private Vector3 GetCellSurfacePosition(int cell, IPlanet planet)
        {
            return planet.Center + _cellDirections[cell] * planet.Radius;
        }

        // Os eventos carregam o buffer reutilizado: os assinantes (síncronos)
        // devem consumi-lo durante o anúncio, nunca guardá-lo.
        private void PublishClaims(byte ownerId)
        {
            if (_claimBuffer.Count == 0)
            {
                return;
            }

            EventBus.Publish(new TerritoryCellsClaimedEvent(ownerId, _claimBuffer, _cellSpacing));
            EventBus.Publish(new TerritoryScoreChangedEvent(
                ownerId, (float)_cellCountsByOwner[ownerId] / _cellCount));

            // Quem perdeu terreno também tem placar novo.
            foreach (byte loser in _dispossessedBuffer)
            {
                EventBus.Publish(new TerritoryScoreChangedEvent(
                    loser, (float)_cellCountsByOwner[loser] / _cellCount));
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
            BuildNeighborGraph(planet);
            _built = true;

            Debug.Log($"[World] Grade territorial criada: {_cellCount} células, " +
                      $"espaçamento ~{_cellSpacing:F2} unidades.");
        }

        // A vizinhança da grade nunca muda durante uma partida. Calculá-la
        // uma vez na criação elimina milhares de buscas por baldes durante
        // cada flood fill de conquista ou amputação territorial.
        private void BuildNeighborGraph(IPlanet planet)
        {
            _neighbors = new int[_cellCount][];
            float neighborDistance = _cellSpacing * 1.6f;

            for (int cell = 0; cell < _cellCount; cell++)
            {
                _neighborBuffer.Clear();
                CollectCellsWithin(_cellDirections[cell], neighborDistance, planet, _neighborBuffer);
                _neighbors[cell] = _neighborBuffer.ToArray();
            }
        }

        // ------------------------------------------------------------------
        // Busca espacial por baldes de latitude/longitude (sem alocações).
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
            CollectCandidates(direction, maxSurfaceDistance, planet);

            int best = -1;
            float bestDot = -2f;
            float minDot = Mathf.Cos(maxSurfaceDistance / planet.Radius);
            for (int c = 0; c < _candidateBuffer.Count; c++)
            {
                int candidate = _candidateBuffer[c];
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
            CollectCandidates(direction, surfaceDistance, planet);

            float minDot = Mathf.Cos(surfaceDistance / planet.Radius);
            for (int c = 0; c < _candidateBuffer.Count; c++)
            {
                int candidate = _candidateBuffer[c];
                if (Vector3.Dot(_cellDirections[candidate], direction) >= minDot)
                {
                    results.Add(candidate);
                }
            }
        }

        // Preenche _candidateBuffer com as células dos baldes ao redor da
        // direção — laços diretos, sem iteradores (sem lixo de memória).
        private void CollectCandidates(Vector3 direction, float surfaceDistance, IPlanet planet)
        {
            _candidateBuffer.Clear();

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

                    for (int b = 0; b < bucket.Count; b++)
                    {
                        _candidateBuffer.Add(bucket[b]);
                    }
                }
            }
        }
    }
}
