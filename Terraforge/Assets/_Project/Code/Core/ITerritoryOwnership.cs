using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// O que os módulos podem perguntar sobre posse territorial:
    /// "este ponto do mundo pertence à civilização X?".
    /// </summary>
    public interface ITerritoryOwnership
    {
        bool IsOwnedBy(byte civilizationId, Vector3 worldPosition);

        /// <summary>Um ponto aleatório da superfície ainda sem dono (respawn, DD-098).</summary>
        Vector3 GetRandomUnownedPosition();
    }
}
