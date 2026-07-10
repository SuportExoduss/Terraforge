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
        // DD-111: partidas oficiais de 10 minutos (planeta escala 200).
        [SerializeField] private float _matchDurationSeconds = 600f;

        private float _secondsRemaining;
        private int _lastAnnouncedSecond = -1;
        private bool _ended;
        private bool _running;

        private void Awake()
        {
            // DD-096: o relógio só dispara no GO! da abertura.
            EventBus.Subscribe<MatchStartedEvent>(OnMatchStarted);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<MatchStartedEvent>(OnMatchStarted);
        }

        private void OnMatchStarted(MatchStartedEvent matchStarted)
        {
            _running = true;
        }

        private void Start()
        {
            _secondsRemaining = _matchDurationSeconds;
        }

        private void Update()
        {
            if (!_running || _ended)
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
