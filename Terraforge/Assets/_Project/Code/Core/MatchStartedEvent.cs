namespace Terraforge.Core
{
    /// <summary>
    /// O "GO!" da partida (DD-096): anunciado quando todas as naves
    /// pousaram e os personagens spawnam. Antes dele, ninguém corre
    /// e o relógio não anda.
    /// </summary>
    public readonly struct MatchStartedEvent : IGameEvent
    {
    }
}
