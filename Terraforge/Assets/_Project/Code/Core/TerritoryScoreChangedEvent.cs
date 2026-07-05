namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando a fatia do planeta de uma civilização muda.
    /// A fração vai de 0 (nada) a 1 (planeta inteiro).
    /// </summary>
    public readonly struct TerritoryScoreChangedEvent : IGameEvent
    {
        public readonly byte OwnerId;
        public readonly float OwnedFraction;

        public TerritoryScoreChangedEvent(byte ownerId, float ownedFraction)
        {
            OwnerId = ownerId;
            OwnedFraction = ownedFraction;
        }
    }
}
