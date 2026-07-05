using System.Collections.Generic;
using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// Um rastro que pode ser cortado por adversários: expõe o dono,
    /// os pontos (para o sensor de corte medir distância) e a ordem
    /// de corte em si.
    /// </summary>
    public interface ICuttableTrail
    {
        byte OwnerId { get; }
        IReadOnlyList<Vector3> Points { get; }
        void Cut(byte attackerId);
    }
}
