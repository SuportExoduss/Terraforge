using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// A barra de vida (DD-098): corte de rastro tira 1/6 e devolve o
    /// corredor à base; o campo de força regenera lentamente (DD-097);
    /// barra zerada = queda e respawn em ponto aleatório livre do planeta.
    /// </summary>
    public sealed class Health : MonoBehaviour
    {
        [SerializeField] private float _cutDamageFraction = 1f / 6f;

        // Fração da barra recuperada por segundo dentro do campo de força.
        [SerializeField] private float _regenFractionPerSecond = 0.06f;

        private Civilization _civilization;
        private float _fraction = 1f;

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
        }

        private void Start()
        {
            PublishFraction();
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<TrailCutEvent>(OnTrailCut);
        }

        private void Update()
        {
            bool insideForceField =
                HomeBaseRegistry.TryGet(_civilization.Id, out HomeBaseRegistry.BaseInfo baseInfo) &&
                Vector3.Distance(transform.position, baseInfo.Position) <= baseInfo.Radius;

            if (insideForceField && _fraction < 1f)
            {
                SetFraction(_fraction + _regenFractionPerSecond * Time.deltaTime);
            }
        }

        private void OnTrailCut(TrailCutEvent cutEvent)
        {
            if (cutEvent.VictimId != _civilization.Id)
            {
                return;
            }

            SetFraction(_fraction - _cutDamageFraction);

            if (_fraction <= 0f)
            {
                RespawnAtRandomFreeSpot();
            }
            else
            {
                ReturnToForceField();
            }
        }

        private void ReturnToForceField()
        {
            if (HomeBaseRegistry.TryGet(_civilization.Id, out HomeBaseRegistry.BaseInfo baseInfo))
            {
                transform.position = baseInfo.Position;
            }
        }

        private void RespawnAtRandomFreeSpot()
        {
            ITerritoryOwnership territory = TerritoryOwnershipLocator.Current;
            if (territory != null)
            {
                transform.position = territory.GetRandomUnownedPosition();
            }

            SetFraction(1f);
            Debug.Log($"[Gameplay] Civilização {_civilization.Id} caiu e renasceu em novo ponto do planeta.");
        }

        private void SetFraction(float value)
        {
            _fraction = Mathf.Clamp01(value);
            PublishFraction();
        }

        private void PublishFraction()
        {
            EventBus.Publish(new HealthChangedEvent(_civilization.Id, _fraction));
        }
    }
}
