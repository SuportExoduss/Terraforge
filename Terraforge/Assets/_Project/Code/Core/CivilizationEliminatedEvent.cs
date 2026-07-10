namespace Terraforge.Core
{
    /// <summary>
    /// Anunciado quando uma civilização perde os 4 corações (DD-105/R1):
    /// está fora da partida — vira espectadora, e o ranking final a
    /// marcará como ELIMINADA com o domínio máximo que alcançou.
    /// </summary>
    public readonly struct CivilizationEliminatedEvent : IGameEvent
    {
        public readonly byte OwnerId;

        public CivilizationEliminatedEvent(byte ownerId)
        {
            OwnerId = ownerId;
        }
    }
}
