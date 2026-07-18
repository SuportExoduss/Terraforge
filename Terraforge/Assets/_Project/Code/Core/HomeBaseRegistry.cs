using System.Collections.Generic;
using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// Onde fica o campo de força (base) de cada civilização — usado para
    /// devolver corredores cortados e para a regeneração de vida (DD-097).
    /// </summary>
    public static class HomeBaseRegistry
    {
        public readonly struct BaseInfo
        {
            public readonly Vector3 Position;
            public readonly float Radius;

            public BaseInfo(Vector3 position, float radius)
            {
                Position = position;
                Radius = radius;
            }
        }

        private static readonly Dictionary<byte, BaseInfo> _bases = new();

        public static void Register(byte civilizationId, Vector3 position, float radius)
        {
            _bases[civilizationId] = new BaseInfo(position, radius);
        }

        public static bool TryGet(byte civilizationId, out BaseInfo baseInfo)
        {
            return _bases.TryGetValue(civilizationId, out baseInfo);
        }

        /// <summary>A base deixou de existir (ex.: ruína conquistada, DD-122).</summary>
        public static void Unregister(byte civilizationId)
        {
            _bases.Remove(civilizationId);
        }
    }
}
