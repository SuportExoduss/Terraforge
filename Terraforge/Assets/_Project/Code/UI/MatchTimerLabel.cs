using Terraforge.Core;
using TMPro;
using UnityEngine;

namespace Terraforge.UI
{
    /// <summary>HUD: exibe o tempo restante da partida no formato M:SS.</summary>
    [RequireComponent(typeof(TMP_Text))]
    public sealed class MatchTimerLabel : MonoBehaviour
    {
        private TMP_Text _label;

        private void Awake()
        {
            _label = GetComponent<TMP_Text>();
            EventBus.Subscribe<MatchClockChangedEvent>(OnClockChanged);
            EventBus.Subscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<MatchClockChangedEvent>(OnClockChanged);
            EventBus.Unsubscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnClockChanged(MatchClockChangedEvent clockEvent)
        {
            int minutes = clockEvent.SecondsRemaining / 60;
            int seconds = clockEvent.SecondsRemaining % 60;
            _label.text = $"{minutes}:{seconds:00}";
        }

        // O pódio (ResultsPanel) assume a tela; o relógio se recolhe.
        private void OnMatchEnded(MatchEndedEvent matchEnded)
        {
            _label.text = string.Empty;
        }
    }
}
