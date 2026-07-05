using System.Collections.Generic;
using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado no EventBus quando um corredor retorna ao território da sua
    /// civilização fechando um circuito (SYS-001). Carrega o dono e o
    /// trajeto percorrido — a matéria-prima da conquista.
    /// </summary>
    public readonly struct TerritoryLoopClosedEvent : IGameEvent
    {
        public readonly byte OwnerId;
        public readonly IReadOnlyList<Vector3> TrailPoints;

        public TerritoryLoopClosedEvent(byte ownerId, IReadOnlyList<Vector3> trailPoints)
        {
            OwnerId = ownerId;
            TrailPoints = trailPoints;
        }
    }
}
