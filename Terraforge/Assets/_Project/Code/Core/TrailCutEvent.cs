namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando um rastro é cortado (DD-099): a expansão da vítima
    /// quebra; quem reage (vida, som, efeitos) decide via EventBus.
    /// </summary>
    public readonly struct TrailCutEvent : IGameEvent
    {
        public readonly byte VictimId;
        public readonly byte AttackerId;

        public TrailCutEvent(byte victimId, byte attackerId)
        {
            VictimId = victimId;
            AttackerId = attackerId;
        }
    }
}
