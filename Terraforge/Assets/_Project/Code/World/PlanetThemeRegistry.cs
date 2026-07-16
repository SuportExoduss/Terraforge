using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// DD-114/DD-115: o catálogo de Planet Themes da partida. Vive no
    /// planeta e responde "qual é o theme da civilização X?".
    ///
    /// É o único ponto que precisa saber que existem civilizações
    /// temáticas — adicionar uma civilização é adicionar um theme aqui,
    /// sem tocar em código (PLS).
    /// </summary>
    public sealed class PlanetThemeRegistry : MonoBehaviour
    {
        [Tooltip("O planeta neutro, exibido onde ninguém domina.")]
        [SerializeField] private PlanetTheme _baseTheme;

        [Tooltip("Elemento 0 = civilização 1, elemento 1 = civilização 2...")]
        [SerializeField] private PlanetTheme[] _civilizationThemes;

        public static PlanetThemeRegistry Current { get; private set; }

        public PlanetTheme BaseTheme => _baseTheme;

        private void Awake()
        {
            Current = this;
        }

        private void OnDestroy()
        {
            if (Current == this)
            {
                Current = null;
            }
        }

        /// <summary>O theme da civilização (null se ela não tiver um).</summary>
        public PlanetTheme Get(byte civilizationId)
        {
            int index = civilizationId - 1;
            if (_civilizationThemes == null || index < 0 || index >= _civilizationThemes.Length)
            {
                return null;
            }

            return _civilizationThemes[index];
        }
    }
}
