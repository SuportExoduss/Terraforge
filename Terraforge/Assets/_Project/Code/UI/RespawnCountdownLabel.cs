using Terraforge.Core;
using TMPro;
using UnityEngine;

namespace Terraforge.UI
{
    /// <summary>
    /// HUD: contagem regressiva de pouso da nave do jogador (DD-100).
    /// Aparece nos 5 segundos finais (3 de voo + 2 pousada) e some no spawn.
    /// </summary>
    [RequireComponent(typeof(TMP_Text))]
    public sealed class RespawnCountdownLabel : MonoBehaviour
    {
        // Quanto tempo o "GO!" fica na tela antes de sumir.
        [SerializeField] private float _goDisplaySeconds = 1f;

        private TMP_Text _label;
        private float _clearTime;

        private void Awake()
        {
            _label = GetComponent<TMP_Text>();
            _label.text = string.Empty;
            EventBus.Subscribe<RespawnCountdownEvent>(OnCountdownTick);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<RespawnCountdownEvent>(OnCountdownTick);
        }

        private void Update()
        {
            if (_clearTime > 0f && Time.time >= _clearTime)
            {
                _label.text = string.Empty;
                _clearTime = 0f;
            }
        }

        private void OnCountdownTick(RespawnCountdownEvent tickEvent)
        {
            if (tickEvent.OwnerId != Civilization.PlayerId)
            {
                return;
            }

            if (tickEvent.SecondsRemaining > 0)
            {
                _label.text = tickEvent.SecondsRemaining.ToString();
                _clearTime = 0f;
            }
            else
            {
                _label.text = "GO!";
                _clearTime = Time.time + _goDisplaySeconds;
            }
        }
    }
}
