using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// O que qualquer módulo pode saber sobre o planeta: onde está o centro
    /// e qual o raio. A implementação real vive no módulo World.
    /// </summary>
    public interface IPlanet
    {
        Vector3 Center { get; }
        float Radius { get; }
    }
}
