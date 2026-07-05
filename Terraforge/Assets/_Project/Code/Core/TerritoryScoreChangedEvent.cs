namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando a fatia do planeta dominada pelo jogador muda.
    /// A fração vai de 0 (nada) a 1 (planeta inteiro).
    /// </summary>
    public readonly struct TerritoryScoreChangedEvent : IGameEvent
    {
        public readonly float OwnedFraction;

        public TerritoryScoreChangedEvent(float ownedFraction)
        {
            OwnedFraction = ownedFraction;
        }
    }
}
