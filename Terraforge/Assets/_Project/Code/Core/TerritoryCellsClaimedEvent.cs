using System.Collections.Generic;
using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando células do planeta mudam para o domínio de uma
    /// civilização. Carrega o dono, as posições na superfície e o
    /// espaçamento da grade — tudo que o visual precisa para pintar.
    /// </summary>
    public readonly struct TerritoryCellsClaimedEvent : IGameEvent
    {
        public readonly byte OwnerId;
        public readonly IReadOnlyList<Vector3> CellPositions;
        public readonly float CellSpacing;

        public TerritoryCellsClaimedEvent(
            byte ownerId, IReadOnlyList<Vector3> cellPositions, float cellSpacing)
        {
            OwnerId = ownerId;
            CellPositions = cellPositions;
            CellSpacing = cellSpacing;
        }
    }
}
