namespace Terraforge.Core
{
    /// <summary>
    /// Contrato de todo evento do jogo. Qualquer acontecimento que um módulo
    /// queira anunciar aos demais (território conquistado, vida perdida,
    /// evento global iniciado...) é uma struct/classe que implementa isto.
    /// </summary>
    public interface IGameEvent
    {
    }
}
