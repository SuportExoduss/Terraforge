using System.Collections.Generic;
using Terraforge.Core;
using TMPro;
using UnityEngine;

namespace Terraforge.UI
{
    /// <summary>
    /// A tela de resultados: acompanha o placar de todas as civilizações
    /// (e o AUGE de cada uma) durante a partida, só ouvindo o EventBus.
    /// No fim, exibe o ranking dos sobreviventes e, ao final da lista,
    /// os ELIMINADOS com o domínio máximo que alcançaram (R1).
    /// </summary>
    [RequireComponent(typeof(TMP_Text))]
    public sealed class ResultsPanel : MonoBehaviour
    {
        private readonly Dictionary<byte, float> _latestScores = new();
        private readonly Dictionary<byte, float> _peakScores = new();
        private readonly HashSet<byte> _eliminated = new();
        private TMP_Text _label;

        private void Awake()
        {
            _label = GetComponent<TMP_Text>();
            _label.text = string.Empty;

            EventBus.Subscribe<TerritoryScoreChangedEvent>(OnScoreChanged);
            EventBus.Subscribe<CivilizationEliminatedEvent>(OnEliminated);
            EventBus.Subscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<TerritoryScoreChangedEvent>(OnScoreChanged);
            EventBus.Unsubscribe<CivilizationEliminatedEvent>(OnEliminated);
            EventBus.Unsubscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnScoreChanged(TerritoryScoreChangedEvent scoreEvent)
        {
            _latestScores[scoreEvent.OwnerId] = scoreEvent.OwnedFraction;

            float peak = _peakScores.TryGetValue(scoreEvent.OwnerId, out float value) ? value : 0f;
            _peakScores[scoreEvent.OwnerId] = Mathf.Max(peak, scoreEvent.OwnedFraction);
        }

        private void OnEliminated(CivilizationEliminatedEvent eliminatedEvent)
        {
            _eliminated.Add(eliminatedEvent.OwnerId);
        }

        private void OnMatchEnded(MatchEndedEvent matchEnded)
        {
            // Sobreviventes: ranqueados pelo domínio final.
            var survivors = new List<KeyValuePair<byte, float>>();
            foreach (KeyValuePair<byte, float> entry in _latestScores)
            {
                if (!_eliminated.Contains(entry.Key))
                {
                    survivors.Add(entry);
                }
            }

            survivors.Sort((a, b) => b.Value.CompareTo(a.Value));

            // Eliminados: no fim da lista, ordenados pelo AUGE (R1).
            var fallen = new List<byte>(_eliminated);
            fallen.Sort((a, b) => GetPeak(b).CompareTo(GetPeak(a)));

            var builder = new System.Text.StringBuilder();
            builder.AppendLine("RESULTADO FINAL");
            builder.AppendLine();

            int position = 1;
            foreach (KeyValuePair<byte, float> entry in survivors)
            {
                builder.AppendLine(
                    $"{position}º  {GetName(entry.Key)} — {entry.Value * 100f:F1}%");
                position++;
            }

            foreach (byte ownerId in fallen)
            {
                builder.AppendLine(
                    $"{position}º  {GetName(ownerId)} — ELIMINADO (máx {GetPeak(ownerId) * 100f:F1}%)");
                position++;
            }

            _label.text = builder.ToString();
        }

        private float GetPeak(byte ownerId)
        {
            return _peakScores.TryGetValue(ownerId, out float value) ? value : 0f;
        }

        private static string GetName(byte ownerId)
        {
            return ownerId == Civilization.PlayerId ? "<b>VOCÊ</b>" : $"Civilização {ownerId}";
        }
    }
}
