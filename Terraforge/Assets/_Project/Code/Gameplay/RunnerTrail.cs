using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// O rastro do corredor (SYS-001): existe apenas FORA do território do
    /// jogador (base inicial + tudo que já foi conquistado). Sair do domínio
    /// inicia a gravação; retornar a qualquer parte dele fecha o circuito,
    /// anuncia TerritoryLoopClosedEvent no EventBus e limpa a trilha.
    /// A LISTA é o dado de jogo; a linha é apenas a projeção visual dela.
    /// </summary>
    [RequireComponent(typeof(LineRenderer))]
    public sealed class RunnerTrail : MonoBehaviour, ICuttableTrail
    {
        [SerializeField] private Material _trailMaterial;

        // Espaçamento entre pontos gravados: menor = curva mais fiel, porém
        // mais pontos para processar. 1.5 equilibra bem no raio atual.
        [SerializeField] private float _pointSpacing = 1.5f;
        [SerializeField] private float _width = 0.8f;

        // Levanta a linha um tiquinho do chão para não "brigar" com a
        // superfície da esfera (efeito zebrado chamado z-fighting).
        [SerializeField] private float _surfaceOffset = 0.15f;

        [Header("Visual do rastro (por civilização)")]
        // Modelo plantado ao longo do rastro (ex.: cerca do Velho Oeste).
        // Sem modelo, o rastro usa a linha simples.
        [SerializeField] private GameObject _segmentModel;
        [SerializeField] private float _segmentScale = 1f;
        [SerializeField, Min(0)] private int _prewarmSegments = 64;

        private readonly List<Transform> _segmentPool = new();
        private Transform _segmentContainer;
        private int _activeSegments;

        // Um circuito precisa de pelo menos um triângulo para cercar área.
        private const int MinPointsForLoop = 3;

        private readonly List<Vector3> _points = new();
        private LineRenderer _line;
        private Civilization _civilization;
        private PlanetRunner _runner;
        private bool _wasInsideOwnedTerritory = true;

        /// <summary>Os pontos do rastro, para os sistemas de circuito e corte.</summary>
        public IReadOnlyList<Vector3> Points => _points;

        public byte OwnerId => _civilization != null ? _civilization.Id : (byte)0;

        /// <summary>
        /// Corte por adversário (DD-099): a expansão quebra na hora e o
        /// acontecimento é anunciado — vida, efeitos e som reagem sozinhos.
        /// </summary>
        public void Cut(byte attackerId)
        {
            if (_points.Count == 0)
            {
                return;
            }

            ClearTrail();
            EventBus.Publish(new TrailCutEvent(OwnerId, attackerId));
        }

        private void OnDestroy()
        {
            TrailRegistry.Unregister(this);
            EventBus.Unsubscribe<BaseFallenEvent>(OnBaseFallen);
            EventBus.Unsubscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        private void OnEliminated(CivilizationEliminatedEvent eliminatedEvent)
        {
            if (_civilization != null && eliminatedEvent.OwnerId == _civilization.Id)
            {
                ClearTrail();
                TrailRegistry.Unregister(this);
                enabled = false;
            }
        }

        private void OnBaseFallen(BaseFallenEvent fallenEvent)
        {
            if (_civilization != null && fallenEvent.OwnerId == _civilization.Id && _points.Count > 0)
            {
                ClearTrail();
            }
        }

        private void Awake()
        {
            _civilization = GetComponent<Civilization>();
            if (_civilization == null)
            {
                Debug.LogError($"[RunnerTrail] {name} precisa do crachá Civilization.");
                enabled = false;
            }
            else
            {
                TrailRegistry.Register(this);
            }

            _runner = GetComponent<PlanetRunner>();

            // Embarcou no foguete (DD-100) ou foi eliminado (R1):
            // a expansão pendente evapora.
            EventBus.Subscribe<BaseFallenEvent>(OnBaseFallen);
            EventBus.Subscribe<CivilizationEliminatedEvent>(OnEliminated);

            _line = GetComponent<LineRenderer>();
            _line.useWorldSpace = true;
            _line.startWidth = _width;
            _line.endWidth = _width;
            _line.material = _trailMaterial;
            _line.positionCount = 0;

            // Com modelo de segmento, a linha se aposenta: o rastro vira
            // uma fileira de objetos plantados (cercas, cristais...).
            if (_segmentModel != null)
            {
                _line.enabled = false;
                _segmentContainer = new GameObject($"TrailSegments_{name}").transform;
                PrewarmSegments();
            }
        }

        private void Update()
        {
            // Fora de campo (pré-GO, embarcado, eliminado): nada de gravar
            // pontos no vazio. O rastro pendente já foi limpo pelos eventos.
            if (_runner != null && !_runner.IsActiveInField)
            {
                return;
            }

            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            ITerritoryOwnership territory = TerritoryOwnershipLocator.Current;
            bool insideOwned =
                territory != null && territory.IsOwnedBy(_civilization.Id, transform.position);

            if (insideOwned)
            {
                bool closedLoop = !_wasInsideOwnedTerritory && _points.Count >= MinPointsForLoop;
                if (closedLoop)
                {
                    // Cópia da lista: o rastro é limpo em seguida, mas quem
                    // recebeu o evento precisa dos pontos intactos.
                    EventBus.Publish(
                        new TerritoryLoopClosedEvent(_civilization.Id, new List<Vector3>(_points)));
                }

                if (_points.Count > 0)
                {
                    ClearTrail();
                }
            }
            else
            {
                RecordPointIfFarEnough(GetFootPointOnSurface(planet));
            }

            _wasInsideOwnedTerritory = insideOwned;
        }

        private void RecordPointIfFarEnough(Vector3 surfacePoint)
        {
            bool farEnoughFromLast =
                _points.Count == 0 ||
                Vector3.Distance(_points[^1], surfacePoint) >= _pointSpacing;

            if (farEnoughFromLast)
            {
                _points.Add(surfacePoint);
                _line.positionCount = _points.Count;
                _line.SetPosition(_points.Count - 1, surfacePoint);

                if (_segmentModel != null && _points.Count >= 2)
                {
                    PlaceSegment(_points[^2], _points[^1]);
                }
            }
        }

        // Planta um segmento (cerca) entre os dois últimos pontos do rastro,
        // deitado na superfície e apontando na direção da corrida. Os
        // segmentos são reciclados de um bolso (nunca criados em jogo após
        // a primeira vez — filosofia dos Slots).
        private void PlaceSegment(Vector3 from, Vector3 to)
        {
            // A linha lógica continua completa; se um jogador exceder o
            // estoque visual, ela segue legível sem provocar uma instanciação
            // tardia e um hitch no meio da partida.
            if (_activeSegments >= _segmentPool.Count)
            {
                return;
            }

            Transform segment = _segmentPool[_activeSegments];
            _activeSegments++;

            Vector3 middle = (from + to) * 0.5f;
            IPlanet planet = PlanetLocator.Current;
            Vector3 up = planet != null ? (middle - planet.Center).normalized : Vector3.up;
            Vector3 forward = Vector3.ProjectOnPlane(to - from, up).normalized;
            if (forward.sqrMagnitude < 0.001f)
            {
                forward = transform.forward;
            }

            segment.SetPositionAndRotation(middle, Quaternion.LookRotation(forward, up));
            segment.localScale = Vector3.one * _segmentScale;
            segment.gameObject.SetActive(true);
        }

        private Transform CreateSegment()
        {
            GameObject instance = Instantiate(_segmentModel.gameObject, _segmentContainer);
            foreach (Collider collider in instance.GetComponentsInChildren<Collider>())
            {
                Destroy(collider);
            }

            _segmentPool.Add(instance.transform);
            return instance.transform;
        }

        // Todo o estoque visual é preparado antes do GO. Assim a primeira
        // grande incursão não precisa instanciar cercas/modelos em gameplay.
        private void PrewarmSegments()
        {
            for (int i = 0; i < _prewarmSegments; i++)
            {
                Transform segment = CreateSegment();
                segment.gameObject.SetActive(false);
            }
        }

        private void ClearTrail()
        {
            _points.Clear();
            _line.positionCount = 0;

            // As cercas voltam para o bolso (recicladas para o próximo rastro).
            for (int i = 0; i < _activeSegments; i++)
            {
                _segmentPool[i].gameObject.SetActive(false);
            }

            _activeSegments = 0;
        }

        private Vector3 GetFootPointOnSurface(IPlanet planet)
        {
            // O rastro deita no TERRENO real (vales e morros), como os pés.
            Vector3 up = (transform.position - planet.Center).normalized;
            return planet.Center + up * (planet.GetSurfaceRadius(up) + _surfaceOffset);
        }
    }
}
