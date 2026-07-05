using System.Collections.Generic;

namespace Terraforge.Core
{
    /// <summary>
    /// Quadro de avisos dos rastros ativos: cada corredor registra o seu,
    /// e os sensores de corte varrem a lista dos adversários.
    /// </summary>
    public static class TrailRegistry
    {
        private static readonly List<ICuttableTrail> _trails = new();

        public static IReadOnlyList<ICuttableTrail> All => _trails;

        public static void Register(ICuttableTrail trail)
        {
            if (!_trails.Contains(trail))
            {
                _trails.Add(trail);
            }
        }

        public static void Unregister(ICuttableTrail trail)
        {
            _trails.Remove(trail);
        }
    }
}
