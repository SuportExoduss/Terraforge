namespace Terraforge.Core
{
    /// <summary>
    /// DD-123: a retaguarda da expansão caiu — o ponto de onde o corredor
    /// saiu do próprio território foi tomado. A expansão evapora e o
    /// corredor é chamado de volta ao domo (sem dano: não foi corte).
    /// </summary>
    public readonly struct TrailAnchorLostEvent : IGameEvent
    {
        public readonly byte OwnerId;

        public TrailAnchorLostEvent(byte ownerId)
        {
            OwnerId = ownerId;
        }
    }
}
