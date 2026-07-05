using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// O crachá de civilização: identifica a qual civilização um objeto
    /// pertence (corredor, base...). 1 = jogador local; 2+ = adversários.
    /// </summary>
    public sealed class Civilization : MonoBehaviour
    {
        /// <summary>Id da civilização do jogador local.</summary>
        public const byte PlayerId = 1;

        [SerializeField] private byte _id = PlayerId;

        public byte Id => _id;
    }
}
