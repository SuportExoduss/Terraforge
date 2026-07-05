namespace Terraforge.Core
{
    /// <summary>Anunciado a cada segundo restante do relógio da partida.</summary>
    public readonly struct MatchClockChangedEvent : IGameEvent
    {
        public readonly int SecondsRemaining;

        public MatchClockChangedEvent(int secondsRemaining)
        {
            SecondsRemaining = secondsRemaining;
        }
    }
}
