using Terraforge.Core;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Terraforge.UI
{
    /// <summary>
    /// A "TV" do minimapa (DD-104): pequena no canto superior direito;
    /// tocar e segurar a expande no centro com 75% de opacidade e permite
    /// arrastar (os arrastos viajam pelo EventBus até a câmera-satélite);
    /// soltar a devolve ao canto.
    /// </summary>
    [RequireComponent(typeof(RawImage))]
    public sealed class MinimapView : MonoBehaviour,
        IPointerDownHandler, IPointerUpHandler, IDragHandler
    {
        [SerializeField] private float _expandedSize = 600f;
        [SerializeField] [Range(0f, 1f)] private float _expandedAlpha = 0.75f;

        // Janela máxima entre os dois toques do gesto (DD-104).
        [SerializeField] private float _doubleTapWindowSeconds = 0.35f;

        private RawImage _image;
        private RectTransform _rect;
        private float _lastTapTime = -10f;
        private bool _expanded;

        // Fotografia do estado "mini" (canto), restaurada ao soltar.
        private Vector2 _miniAnchorMin;
        private Vector2 _miniAnchorMax;
        private Vector2 _miniPivot;
        private Vector2 _miniPosition;
        private Vector2 _miniSize;
        private float _miniAlpha;

        private void Awake()
        {
            _image = GetComponent<RawImage>();
            _rect = GetComponent<RectTransform>();

            _miniAnchorMin = _rect.anchorMin;
            _miniAnchorMax = _rect.anchorMax;
            _miniPivot = _rect.pivot;
            _miniPosition = _rect.anchoredPosition;
            _miniSize = _rect.sizeDelta;
            _miniAlpha = _image.color.a;
        }

        // DD-104: dois toques rápidos, com o SEGUNDO permanecendo
        // pressionado, expandem o mapa. Toque simples não faz nada.
        public void OnPointerDown(PointerEventData eventData)
        {
            bool isSecondQuickTap = Time.unscaledTime - _lastTapTime <= _doubleTapWindowSeconds;
            _lastTapTime = Time.unscaledTime;

            if (!isSecondQuickTap)
            {
                return;
            }

            _expanded = true;
            Vector2 center = new(0.5f, 0.5f);
            _rect.anchorMin = center;
            _rect.anchorMax = center;
            _rect.pivot = center;
            _rect.anchoredPosition = Vector2.zero;
            _rect.sizeDelta = new Vector2(_expandedSize, _expandedSize);
            SetAlpha(_expandedAlpha);

            EventBus.Publish(new MinimapHoldEvent(true));
        }

        public void OnDrag(PointerEventData eventData)
        {
            if (_expanded)
            {
                EventBus.Publish(new MinimapDragEvent(eventData.delta));
            }
        }

        public void OnPointerUp(PointerEventData eventData)
        {
            if (!_expanded)
            {
                return;
            }

            _expanded = false;
            _rect.anchorMin = _miniAnchorMin;
            _rect.anchorMax = _miniAnchorMax;
            _rect.pivot = _miniPivot;
            _rect.anchoredPosition = _miniPosition;
            _rect.sizeDelta = _miniSize;
            SetAlpha(_miniAlpha);

            EventBus.Publish(new MinimapHoldEvent(false));
        }

        private void SetAlpha(float alpha)
        {
            Color color = _image.color;
            color.a = alpha;
            _image.color = color;
        }
    }
}
