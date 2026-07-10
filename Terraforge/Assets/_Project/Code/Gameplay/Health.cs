using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// A vida oficial (DD-105): 16 pontos = 4 corações × 4 segmentos.
    /// Corte de rastro tira 2 pontos e devolve o corredor à base (R2);
    /// o campo de força regenera 1 ponto a cada 1,5s (R3); zerar os 4
    /// corações ELIMINA a civilização da partida (R1).
    /// Eventos, defensores e armadilhas usarão TakeDamage(1/2/4).
    /// </summary>
    public sealed class Health : MonoBehaviour
    {
        public const int MaxPoints = 16;

        [SerializeField] private int _cutDamagePoints = 2;

        // R3: segundos para regenerar 1 ponto dentro do campo de força.
        [SerializeField] private float _secondsPerRegenPoint = 1.5f;

        private Civilization _civilization;
        private int _points = MaxPoints;
        private float _regenClock;
        private bool _eliminated;

        private void Awake()
        {
            _civilization = GetComponent<Civilization>();
            if (_civilization == null)
            {
                Debug.LogError($"[Health] {name} precisa do crachá Civilization.");
                enabled = false;
                return;
            }

            EventBus.Subscribe<TrailCutEvent>(OnTrailCut);
            EventBus.Subscribe<BaseRelocatedEvent>(OnBaseRelocated);
        }

        private void Start()
        {
            PublishPoints();
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<TrailCutEvent>(OnTrailCut);
            EventBus.Unsubscribe<BaseRelocatedEvent>(OnBaseRelocated);
        }

        private void Update()
        {
            if (_eliminated || _points >= MaxPoints)
            {
                return;
            }

            bool insideForceField =
                HomeBaseRegistry.TryGet(_civilization.Id, out HomeBaseRegistry.BaseInfo baseInfo) &&
                Vector3.Distance(transform.position, baseInfo.Position) <= baseInfo.Radius;

            if (!insideForceField)
            {
                _regenClock = 0f;
                return;
            }

            _regenClock += Time.deltaTime;
            if (_regenClock >= _secondsPerRegenPoint)
            {
                _regenClock -= _secondsPerRegenPoint;
                Heal(1);
            }
        }

        /// <summary>Dano de qualquer origem (corte, eventos, defensores).</summary>
        public void TakeDamage(int points)
        {
            if (_eliminated)
            {
                return;
            }

            _points = Mathf.Max(0, _points - points);
            PublishPoints();

            if (_points <= 0)
            {
                Eliminate();
            }
        }

        public void Heal(int points)
        {
            if (_eliminated)
            {
                return;
            }

            _points = Mathf.Min(MaxPoints, _points + points);
            PublishPoints();
        }

        private void OnTrailCut(TrailCutEvent cutEvent)
        {
            if (cutEvent.VictimId != _civilization.Id || _eliminated)
            {
                return;
            }

            TakeDamage(_cutDamagePoints);

            if (!_eliminated)
            {
                ReturnToForceField();
            }
        }

        // DD-100: perdeu a base = recomeço junto à nave, com a vida cheia.
        private void OnBaseRelocated(BaseRelocatedEvent relocatedEvent)
        {
            if (relocatedEvent.OwnerId != _civilization.Id || _eliminated)
            {
                return;
            }

            transform.position = relocatedEvent.NewPosition;
            _points = MaxPoints;
            PublishPoints();
        }

        private void ReturnToForceField()
        {
            if (HomeBaseRegistry.TryGet(_civilization.Id, out HomeBaseRegistry.BaseInfo baseInfo))
            {
                transform.position = baseInfo.Position;
            }
        }

        // R1: os 4 corações zeraram — fora da partida.
        private void Eliminate()
        {
            _eliminated = true;
            EventBus.Publish(new CivilizationEliminatedEvent(_civilization.Id));
            Debug.Log($"[Gameplay] Civilização {_civilization.Id} foi ELIMINADA da partida!");
        }

        private void PublishPoints()
        {
            EventBus.Publish(new HealthChangedEvent(_civilization.Id, _points, MaxPoints));
        }
    }
}
