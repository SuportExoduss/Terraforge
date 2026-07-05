using System.Collections.Generic;
using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado no EventBus quando o corredor retorna ao seu território
    /// fechando um circuito (SYS-001). Carrega o trajeto percorrido — é a
    /// matéria-prima do cálculo de área conquistada.
    /// </summary>
    public readonly struct TerritoryLoopClosedEvent : IGameEvent
    {
        public readonly IReadOnlyList<Vector3> TrailPoints;

        public TerritoryLoopClosedEvent(IReadOnlyList<Vector3> trailPoints)
        {
            TrailPoints = trailPoints;
        }
    }
}
