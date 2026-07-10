namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando a vida de uma civilização muda (DD-105):
    /// 16 pontos = 4 corações de 4 segmentos.
    /// </summary>
    public readonly struct HealthChangedEvent : IGameEvent
    {
        public readonly byte OwnerId;
        public readonly int Points;
        public readonly int MaxPoints;

        public HealthChangedEvent(byte ownerId, int points, int maxPoints)
        {
            OwnerId = ownerId;
            Points = points;
            MaxPoints = maxPoints;
        }
    }
}
