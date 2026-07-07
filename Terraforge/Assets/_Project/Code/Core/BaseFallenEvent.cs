namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado no INSTANTE em que a base de uma civilização é dominada
    /// (DD-100): o império inteiro já foi herdado pelo conquistador e o
    /// corredor derrotado embarca imediatamente no foguete.
    /// </summary>
    public readonly struct BaseFallenEvent : IGameEvent
    {
        public readonly byte OwnerId;
        public readonly byte ConquerorId;

        public BaseFallenEvent(byte ownerId, byte conquerorId)
        {
            OwnerId = ownerId;
            ConquerorId = conquerorId;
        }
    }
}
