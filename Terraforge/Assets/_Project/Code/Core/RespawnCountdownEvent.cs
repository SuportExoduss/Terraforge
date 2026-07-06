namespace Terraforge.Core
{
    /// <summary>
    /// Tique da contagem regressiva de pouso/respawn (DD-100): começa em 5
    /// (3s finais de voo + 2s de nave pousada) e termina em 0 = spawn.
    /// </summary>
    public readonly struct RespawnCountdownEvent : IGameEvent
    {
        public readonly byte OwnerId;
        public readonly int SecondsRemaining;

        public RespawnCountdownEvent(byte ownerId, int secondsRemaining)
        {
            OwnerId = ownerId;
            SecondsRemaining = secondsRemaining;
        }
    }
}
