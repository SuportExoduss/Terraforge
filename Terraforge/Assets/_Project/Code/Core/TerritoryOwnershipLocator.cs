namespace Terraforge.Core
{
    /// <summary>
    /// Quadro de avisos do mapa de posse territorial ativo
    /// (mesmo padrão do PlanetLocator).
    /// </summary>
    public static class TerritoryOwnershipLocator
    {
        public static ITerritoryOwnership Current { get; private set; }

        public static void Register(ITerritoryOwnership ownership)
        {
            Current = ownership;
        }

        public static void Unregister(ITerritoryOwnership ownership)
        {
            if (ReferenceEquals(Current, ownership))
            {
                Current = null;
            }
        }
    }
}
