using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// O que os módulos podem perguntar ao território-base do jogador:
    /// apenas "este ponto está dentro de você?".
    /// </summary>
    public interface IHomeTerritory
    {
        bool Contains(Vector3 worldPosition);
    }
}
