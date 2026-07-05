namespace Terraforge.Core
{
    /// <summary>
    /// O "motorista" de um corredor: informa quanto virar neste frame,
    /// de -1 (esquerda total) a +1 (direita total). Implementado pelo
    /// teclado do jogador (Gameplay) ou por um cérebro de bot (AI).
    /// </summary>
    public interface ISteeringSource
    {
        float GetSteer();
    }
}
