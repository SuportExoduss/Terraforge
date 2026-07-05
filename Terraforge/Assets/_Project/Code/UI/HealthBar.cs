using Terraforge.Core;
using UnityEngine;
using UnityEngine.UI;

namespace Terraforge.UI
{
    /// <summary>
    /// HUD: a barra de vida do jogador local (DD-098). Escuta o EventBus
    /// e apenas exibe — como toda UI do Terraforge.
    /// </summary>
    [RequireComponent(typeof(Slider))]
    public sealed class HealthBar : MonoBehaviour
    {
        private Slider _slider;

        private void Awake()
        {
            _slider = GetComponent<Slider>();
            _slider.minValue = 0f;
            _slider.maxValue = 1f;
            _slider.value = 1f;
            _slider.interactable = false;

            EventBus.Subscribe<HealthChangedEvent>(OnHealthChanged);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<HealthChangedEvent>(OnHealthChanged);
        }

        private void OnHealthChanged(HealthChangedEvent healthEvent)
        {
            if (healthEvent.OwnerId != Civilization.PlayerId)
            {
                return;
            }

            _slider.value = healthEvent.Fraction;
        }
    }
}
