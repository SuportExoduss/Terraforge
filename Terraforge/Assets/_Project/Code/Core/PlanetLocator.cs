namespace Terraforge.Core
{
    /// <summary>
    /// Ponto de encontro entre módulos: o World registra aqui o planeta ativo
    /// e os demais módulos o consultam, sem conhecerem a implementação
    /// (mesma filosofia do EventBus, mas para um objeto sempre presente).
    /// </summary>
    public static class PlanetLocator
    {
        public static IPlanet Current { get; private set; }

        public static void Register(IPlanet planet)
        {
            Current = planet;
        }

        public static void Unregister(IPlanet planet)
        {
            if (ReferenceEquals(Current, planet))
            {
                Current = null;
            }
        }
    }
}
