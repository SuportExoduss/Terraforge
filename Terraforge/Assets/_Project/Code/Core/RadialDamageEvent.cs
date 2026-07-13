using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// Dano em área com três anéis exclusivos (DD-107): quem está no anel
    /// interno sofre o dano interno (e pode ser devolvido à base), e assim
    /// por diante. Usado por meteoro, vulcão, verme gigante...
    /// </summary>
    public readonly struct RadialDamageEvent : IGameEvent
    {
        public readonly Vector3 Center;
        public readonly float InnerRadius;
        public readonly int InnerDamage;
        public readonly bool InnerReturnsToBase;
        public readonly float MidRadius;
        public readonly int MidDamage;
        public readonly float OuterRadius;
        public readonly int OuterDamage;

        public RadialDamageEvent(
            Vector3 center,
            float innerRadius, int innerDamage, bool innerReturnsToBase,
            float midRadius, int midDamage,
            float outerRadius, int outerDamage)
        {
            Center = center;
            InnerRadius = innerRadius;
            InnerDamage = innerDamage;
            InnerReturnsToBase = innerReturnsToBase;
            MidRadius = midRadius;
            MidDamage = midDamage;
            OuterRadius = outerRadius;
            OuterDamage = outerDamage;
        }
    }
}
