using System.Collections.Generic;
using Terraforge.Core;
using TMPro;
using UnityEngine;

namespace Terraforge.UI
{
    /// <summary>
    /// A tela de resultados: acompanha o placar de todas as civilizações
    /// durante a partida (só ouvindo o EventBus) e, no fim, exibe o ranking
    /// sobre o planeta em contemplação. UI pura — não decide nada.
    /// </summary>
    [RequireComponent(typeof(TMP_Text))]
    public sealed class ResultsPanel : MonoBehaviour
    {
        private readonly Dictionary<byte, float> _latestScores = new();
        private TMP_Text _label;

        private void Awake()
        {
            _label = GetComponent<TMP_Text>();
            _label.text = string.Empty;

            EventBus.Subscribe<TerritoryScoreChangedEvent>(OnScoreChanged);
            EventBus.Subscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<TerritoryScoreChangedEvent>(OnScoreChanged);
            EventBus.Unsubscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnScoreChanged(TerritoryScoreChangedEvent scoreEvent)
        {
            _latestScores[scoreEvent.OwnerId] = scoreEvent.OwnedFraction;
        }

        private void OnMatchEnded(MatchEndedEvent matchEnded)
        {
            // Ordena as civilizações da maior fatia do planeta à menor.
            var ranking = new List<KeyValuePair<byte, float>>(_latestScores);
            ranking.Sort((a, b) => b.Value.CompareTo(a.Value));

            var builder = new System.Text.StringBuilder();
            builder.AppendLine("RESULTADO FINAL");
            builder.AppendLine();

            for (int position = 0; position < ranking.Count; position++)
            {
                byte ownerId = ranking[position].Key;
                float fraction = ranking[position].Value;

                string name = ownerId == Civilization.PlayerId
                    ? "<b>VOCÊ</b>"
                    : $"Civilização {ownerId}";

                builder.AppendLine($"{position + 1}º  {name} — {fraction * 100f:F1}%");
            }

            _label.text = builder.ToString();
        }
    }
}
