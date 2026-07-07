using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.AI
{
    /// <summary>
    /// Cérebro v2 de bot (DD-101): joga como um humano com tática —
    /// escolhe alvos de expansão em terra livre, caça rastros expostos de
    /// inimigos para cortá-los e volta para casa antes de se expor demais.
    /// Só conhece contratos do Core.
    /// </summary>
    public sealed class BotSteering : MonoBehaviour, ISteeringSource
    {
        // Alcance das incursões de expansão (distância do alvo sorteado).
        [SerializeField] private float _minSortieDistance = 20f;
        [SerializeField] private float _maxSortieDistance = 45f;

        // Tempo máximo exposto antes de abortar e voltar (avaliação de risco).
        [SerializeField] private float _maxExposureSeconds = 12f;

        // Distância em que um rastro inimigo desperta o instinto de caça.
        [SerializeField] private float _huntRange = 35f;

        // Agressividade da virada ao mirar um objetivo.
        [SerializeField] private float _steeringGain = 0.06f;

        // Intervalo entre DECISÕES (caça/alvos). Sem ele o bot reavalia a
        // cada frame e fica trocando de alvo 60x por segundo — frenesi.
        [SerializeField] private float _decisionIntervalSeconds = 0.5f;

        private Civilization _civilization;
        private Vector3 _homePosition;
        private Vector3 _sortieTarget;
        private float _exposureClock;
        private bool _returningHome;
        private bool _hasSortieTarget;
        private float _noiseSeed;
        private float _decisionClock;
        private bool _hunting;
        private Vector3 _huntPoint;

        private void Start()
        {
            _civilization = GetComponent<Civilization>();
            if (_civilization == null)
            {
                Debug.LogError($"[BotSteering] {name} precisa do crachá Civilization.");
                enabled = false;
            }

            _homePosition = transform.position;
            _noiseSeed = Random.value * 100f;
            EventBus.Subscribe<BaseRelocatedEvent>(OnBaseRelocated);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<BaseRelocatedEvent>(OnBaseRelocated);
        }

        // DD-100: a nave mudou de lugar — o "para casa" do cérebro acompanha.
        private void OnBaseRelocated(BaseRelocatedEvent relocatedEvent)
        {
            if (_civilization != null && relocatedEvent.OwnerId == _civilization.Id)
            {
                _homePosition = relocatedEvent.NewPosition;
            }
        }

        public float GetSteer()
        {
            ITerritoryOwnership territory = TerritoryOwnershipLocator.Current;
            bool insideOwned =
                territory != null &&
                territory.IsOwnedBy(_civilization.Id, transform.position);

            if (insideOwned)
            {
                // Em casa: novo plano de expansão e de volta ao campo.
                _returningHome = false;
                _hasSortieTarget = false;
                _exposureClock = 0f;
            }
            else
            {
                _exposureClock += Time.deltaTime;
            }

            // Instinto 1 — CAÇA: rastro inimigo ao alcance vale mais que
            // qualquer plano. A decisão é tomada a cada meio segundo e
            // MANTIDA até a próxima (compromisso, como um jogador humano).
            _decisionClock += Time.deltaTime;
            if (_decisionClock >= _decisionIntervalSeconds)
            {
                _decisionClock = 0f;
                _hunting = TryFindNearbyEnemyTrailPoint(out _huntPoint);
            }

            if (_hunting)
            {
                return SteerTowards(_huntPoint);
            }

            // Instinto 2 — RISCO: exposto demais? Aborta e fecha o circuito.
            if (_returningHome || _exposureClock >= _maxExposureSeconds)
            {
                _returningHome = true;
                return SteerTowards(_homePosition);
            }

            // Instinto 3 — EXPANSÃO: persegue um alvo sorteado em terra
            // livre; chegou perto, volta para casa para consolidar.
            if (!_hasSortieTarget)
            {
                _sortieTarget = PickSortieTarget(territory);
                _hasSortieTarget = true;
            }

            if (Vector3.Distance(transform.position, _sortieTarget) < 6f)
            {
                _returningHome = true;
                return SteerTowards(_homePosition);
            }

            // Ruído leve deixa a rota orgânica, menos "robótica".
            float wobble = (Mathf.PerlinNoise(Time.time * 0.4f, _noiseSeed) - 0.5f) * 0.4f;
            return Mathf.Clamp(SteerTowards(_sortieTarget) + wobble, -1f, 1f);
        }

        // Sorteia um ponto de expansão na superfície, preferindo terra livre.
        private Vector3 PickSortieTarget(ITerritoryOwnership territory)
        {
            IPlanet planet = PlanetLocator.Current;
            Vector3 fallback = transform.position + transform.forward * _minSortieDistance;
            if (planet == null)
            {
                return fallback;
            }

            for (int attempt = 0; attempt < 6; attempt++)
            {
                float distance = Random.Range(_minSortieDistance, _maxSortieDistance);
                float sideAngle = Random.Range(-80f, 80f);
                Vector3 up = (transform.position - planet.Center).normalized;
                Vector3 direction = Quaternion.AngleAxis(sideAngle, up) * transform.forward;

                Vector3 candidate = transform.position + direction.normalized * distance;
                Vector3 candidateUp = (candidate - planet.Center).normalized;
                candidate = planet.Center + candidateUp * planet.Radius;

                bool freeLand = territory != null &&
                                !territory.IsOwnedBy(_civilization.Id, candidate);
                if (freeLand)
                {
                    return candidate;
                }
            }

            return fallback;
        }

        private bool TryFindNearbyEnemyTrailPoint(out Vector3 huntPoint)
        {
            huntPoint = Vector3.zero;
            float bestSquared = _huntRange * _huntRange;
            bool found = false;

            IReadOnlyList<ICuttableTrail> trails = TrailRegistry.All;
            for (int t = 0; t < trails.Count; t++)
            {
                ICuttableTrail trail = trails[t];
                if (trail.OwnerId == _civilization.Id)
                {
                    continue;
                }

                IReadOnlyList<Vector3> points = trail.Points;

                // Amostra 1 a cada 3 pontos: precisão suficiente, custo baixo.
                for (int i = 0; i < points.Count; i += 3)
                {
                    float distanceSquared = (points[i] - transform.position).sqrMagnitude;
                    if (distanceSquared < bestSquared)
                    {
                        bestSquared = distanceSquared;
                        huntPoint = points[i];
                        found = true;
                    }
                }
            }

            return found;
        }

        // Quanto o objetivo está à esquerda/direita do focinho decide o volante.
        private float SteerTowards(Vector3 worldPoint)
        {
            Vector3 up = transform.up;
            Vector3 toTarget = Vector3.ProjectOnPlane(worldPoint - transform.position, up);
            float angle = Vector3.SignedAngle(transform.forward, toTarget, up);
            return Mathf.Clamp(angle * _steeringGain, -1f, 1f);
        }
    }
}
