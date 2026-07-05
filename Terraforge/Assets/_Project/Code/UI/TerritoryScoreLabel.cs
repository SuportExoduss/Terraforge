using Terraforge.Core;
using TMPro;
using UnityEngine;

namespace Terraforge.UI
{
    /// <summary>
    /// HUD: exibe a porcentagem do planeta dominada pelo jogador.
    /// Apenas escuta o placar no EventBus e escreve na tela —
    /// UI exibe estados, nunca decide nada (regra do GDMD Cap. 5).
    /// </summary>
    [RequireComponent(typeof(TMP_Text))]
    public sealed class TerritoryScoreLabel : MonoBehaviour
    {
        private TMP_Text _label;

        private void Awake()
        {
            _label = GetComponent<TMP_Text>();
            _label.text = "Domínio: 0,0%";
            EventBus.Subscribe<TerritoryScoreChangedEvent>(OnScoreChanged);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<TerritoryScoreChangedEvent>(OnScoreChanged);
        }

        private void OnScoreChanged(TerritoryScoreChangedEvent scoreEvent)
        {
            _label.text = $"Domínio: {scoreEvent.OwnedFraction * 100f:F1}%";
        }
    }
}
