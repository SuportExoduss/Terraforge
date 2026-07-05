using System.Collections.Generic;
using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando células do planeta mudam de dono para o jogador.
    /// Carrega as posições na superfície e o espaçamento da grade — tudo
    /// que o visual precisa para pintar exatamente o que foi conquistado.
    /// </summary>
    public readonly struct TerritoryCellsClaimedEvent : IGameEvent
    {
        public readonly IReadOnlyList<Vector3> CellPositions;
        public readonly float CellSpacing;

        public TerritoryCellsClaimedEvent(IReadOnlyList<Vector3> cellPositions, float cellSpacing)
        {
            CellPositions = cellPositions;
            CellSpacing = cellSpacing;
        }
    }
}
