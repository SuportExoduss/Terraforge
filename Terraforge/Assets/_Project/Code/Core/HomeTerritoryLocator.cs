namespace Terraforge.Core
{
    /// <summary>
    /// Quadro de avisos do território-base ativo (mesmo padrão do PlanetLocator).
    /// Provisório para o protótipo de um jogador; no multiplayer haverá um
    /// registro de territórios por civilização.
    /// </summary>
    public static class HomeTerritoryLocator
    {
        public static IHomeTerritory Current { get; private set; }

        public static void Register(IHomeTerritory territory)
        {
            Current = territory;
        }

        public static void Unregister(IHomeTerritory territory)
        {
            if (ReferenceEquals(Current, territory))
            {
                Current = null;
            }
        }
    }
}
