namespace Terraforge.Core
{
    /// <summary>Anunciado quando o jogador segura ou solta o minimapa (DD-104).</summary>
    public readonly struct MinimapHoldEvent : IGameEvent
    {
        public readonly bool IsHeld;

        public MinimapHoldEvent(bool isHeld)
        {
            IsHeld = isHeld;
        }
    }
}
