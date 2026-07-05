using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// O relógio da partida (GDMD: cinco minutos). Anuncia cada segundo
    /// restante e, uma única vez, o fim da partida — quem deve reagir
    /// (corredor, UI, futuro ranking) decide por conta própria via EventBus.
    /// </summary>
    public sealed class MatchTimer : MonoBehaviour
    {
        [SerializeField] private float _matchDurationSeconds = 300f;

        private float _secondsRemaining;
        private int _lastAnnouncedSecond = -1;
        private bool _ended;

        private void Start()
        {
            _secondsRemaining = _matchDurationSeconds;
        }

        private void Update()
        {
            if (_ended)
            {
                return;
            }

            _secondsRemaining -= Time.deltaTime;

            // Anuncia apenas na virada do segundo (não a cada frame).
            int wholeSeconds = Mathf.Max(0, Mathf.CeilToInt(_secondsRemaining));
            if (wholeSeconds != _lastAnnouncedSecond)
            {
                _lastAnnouncedSecond = wholeSeconds;
                EventBus.Publish(new MatchClockChangedEvent(wholeSeconds));
            }

            if (_secondsRemaining <= 0f)
            {
                _ended = true;
                EventBus.Publish(new MatchEndedEvent());
                Debug.Log("[Core] Fim da partida! O planeta fica para contemplação.");
            }
        }
    }
}
