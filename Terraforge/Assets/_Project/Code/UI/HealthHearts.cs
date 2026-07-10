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
        [SerializeField] private float _segmentSize = 16f;
        [SerializeField] private float _segmentGap = 3f;
        [SerializeField] private float _heartGap = 12f;

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

        // 16 quadradinhos: [■■■■]  [■■■■]  [■■■■]  [■■■■]
        private void BuildSegments()
        {
            float x = 0f;
            for (int heart = 0; heart < Hearts; heart++)
            {
                for (int segment = 0; segment < SegmentsPerHeart; segment++)
                {
                    var segmentObject = new GameObject($"Heart{heart}_Seg{segment}", typeof(Image));
                    segmentObject.transform.SetParent(transform, worldPositionStays: false);

                    var rect = segmentObject.GetComponent<RectTransform>();
                    rect.anchorMin = new Vector2(0f, 1f);
                    rect.anchorMax = new Vector2(0f, 1f);
                    rect.pivot = new Vector2(0f, 1f);
                    rect.sizeDelta = new Vector2(_segmentSize, _segmentSize);
                    rect.anchoredPosition = new Vector2(x, 0f);

                    _segments.Add(segmentObject.GetComponent<Image>());
                    x += _segmentSize + _segmentGap;
                }

                x += _heartGap;
            }
        }
    }
}
