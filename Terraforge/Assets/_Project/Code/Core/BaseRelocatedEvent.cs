using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando a nave de uma civilização pousa em um novo ponto
    /// após perder a base (DD-100). Corredor e cérebros de bot reagem.
    /// </summary>
    public readonly struct BaseRelocatedEvent : IGameEvent
    {
        public readonly byte OwnerId;
        public readonly Vector3 NewPosition;

        public BaseRelocatedEvent(byte ownerId, Vector3 newPosition)
        {
            OwnerId = ownerId;
            NewPosition = newPosition;
        }
    }
}
