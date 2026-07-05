namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando a barra de vida de uma civilização muda (DD-098).
    /// A fração vai de 0 (queda) a 1 (cheia).
    /// </summary>
    public readonly struct HealthChangedEvent : IGameEvent
    {
        public readonly byte OwnerId;
        public readonly float Fraction;

        public HealthChangedEvent(byte ownerId, float fraction)
        {
            OwnerId = ownerId;
            Fraction = fraction;
        }
    }
}
