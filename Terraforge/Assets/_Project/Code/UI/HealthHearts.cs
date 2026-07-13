using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;
using UnityEngine.UI;

namespace Terraforge.UI
{
    /// <summary>
    /// HUD da vida oficial (DD-105): 4 corações × 4 segmentos, construídos
    /// por código (16 quadradinhos em 4 grupos). Segmentos apagam da
    /// direita para a esquerda conforme o dano.
    /// </summary>
    public sealed class HealthHearts : MonoBehaviour
    {
        [SerializeField] private Color _fullColor = new(1f, 0.27f, 0.32f);
        [SerializeField] private Color _emptyColor = new(0.12f, 0.12f, 0.15f, 0.85f);

        // DD-105 visual: 4 quadrados (corações), cada um dividido em 4
        // quadrantes 2×2 — o quadrante APAGA (escurece) ao perder o ponto.
        [SerializeField] private float _quadrantSize = 16f;
        [SerializeField] private float _quadrantGap = 2f;
        [SerializeField] private float _heartGap = 14f;

        private const int Hearts = 4;
        private const int SegmentsPerHeart = 4;

        private readonly List<Image> _segments = new();

        private void Awake()
        {
            BuildSegments();

            // UI não conhece o Gameplay (regra dos módulos): o total vem
            // da própria representação — 4 corações × 4 segmentos.
            Refresh(Hearts * SegmentsPerHeart);
            EventBus.Subscribe<HealthChangedEvent>(OnHealthChanged);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<HealthChangedEvent>(OnHealthChanged);
        }

        private void OnHealthChanged(HealthChangedEvent healthEvent)
        {
            if (healthEvent.OwnerId != Civilization.PlayerId)
            {
                return;
            }

            Refresh(healthEvent.Points);
        }

        private void Refresh(int points)
        {
            for (int i = 0; i < _segments.Count; i++)
            {
                _segments[i].color = i < points ? _fullColor : _emptyColor;
            }
        }

        // 4 quadrados lado a lado, cada um fatiado em 4 quadrantes (2×2):
        // [▐▐]  [▐▐]  [▐▐]  [▐▐]  — cada quadrante = 1 ponto de vida.
        private void BuildSegments()
        {
            float heartWidth = _quadrantSize * 2f + _quadrantGap;

            for (int heart = 0; heart < Hearts; heart++)
            {
                float heartX = heart * (heartWidth + _heartGap);

                for (int quadrant = 0; quadrant < SegmentsPerHeart; quadrant++)
                {
                    // Ordem: superior-esq, superior-dir, inferior-esq, inferior-dir.
                    int column = quadrant % 2;
                    int row = quadrant / 2;

                    var segmentObject =
                        new GameObject($"Heart{heart}_Q{quadrant}", typeof(Image));
                    segmentObject.transform.SetParent(transform, worldPositionStays: false);

                    var rect = segmentObject.GetComponent<RectTransform>();
                    rect.anchorMin = new Vector2(0f, 1f);
                    rect.anchorMax = new Vector2(0f, 1f);
                    rect.pivot = new Vector2(0f, 1f);
                    rect.sizeDelta = new Vector2(_quadrantSize, _quadrantSize);
                    rect.anchoredPosition = new Vector2(
                        heartX + column * (_quadrantSize + _quadrantGap),
                        -row * (_quadrantSize + _quadrantGap));

                    _segments.Add(segmentObject.GetComponent<Image>());
                }
            }
        }
    }
}
