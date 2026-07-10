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

        /// <summary>
        /// O raio REAL da superfície (terreno visual) na direção dada —
        /// vales e morros incluídos. Retorna o raio matemático quando não
        /// há terreno detectável.
        /// </summary>
        float GetSurfaceRadius(Vector3 surfaceDirection);
    }
}
