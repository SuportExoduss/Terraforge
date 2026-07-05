using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// O que os módulos podem perguntar sobre posse territorial:
    /// "este ponto do mundo pertence ao jogador?".
    /// </summary>
    public interface ITerritoryOwnership
    {
        bool IsOwnedByPlayer(Vector3 worldPosition);
    }
}
