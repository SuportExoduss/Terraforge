using Terraforge.Core;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Terraforge.UI
{
    /// <summary>
    /// A janela do minimapa (DD-104 revisado): sem moldura — só o planeta
    /// flutuando no canto (fundo do satélite é transparente). UM TOQUE
    /// alterna para a visão grande (75% de opacidade) onde ARRASTAR gira o
    /// planeta livremente; outro toque devolve ao canto.
    /// </summary>
    [RequireComponent(typeof(RawImage))]
    public sealed class MinimapView : MonoBehaviour,
        IPointerDownHandler, IPointerUpHandler, IDragHandler
    {
        [SerializeField] private float _expandedSize = 700f;
        [SerializeField] [Range(0f, 1f)] private float _expandedAlpha = 0.75f;

        // Toque = apertar e soltar rápido, sem arrastar.
        [SerializeField] private float _tapMaxSeconds = 0.3f;

        private RawImage _image;
        private RectTransform _rect;
        private bool _expanded;
        private bool _draggedSinceDown;
        private float _pointerDownTime;

        // Fotografia do estado "mini" (canto), restaurada ao fechar.
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

        public void OnPointerDown(PointerEventData eventData)
        {
            TouchSteering.SetUiPointerHeld(true);
            _pointerDownTime = Time.unscaledTime;
            _draggedSinceDown = false;
        }

        public void OnDrag(PointerEventData eventData)
        {
            _draggedSinceDown = true;
            if (_expanded)
            {
                EventBus.Publish(new MinimapDragEvent(eventData.delta));
            }
        }

        public void OnPointerUp(PointerEventData eventData)
        {
            TouchSteering.SetUiPointerHeld(false);
            bool isTap =
                !_draggedSinceDown &&
                Time.unscaledTime - _pointerDownTime <= _tapMaxSeconds;

            if (!isTap)
            {
                return;
            }

            _expanded = !_expanded;
            if (_expanded)
            {
                Expand();
            }
            else
            {
                Collapse();
            }

            EventBus.Publish(new MinimapHoldEvent(_expanded));
        }

        private void Expand()
        {
            Vector2 center = new(0.5f, 0.5f);
            _rect.anchorMin = center;
            _rect.anchorMax = center;
            _rect.pivot = center;
            _rect.anchoredPosition = Vector2.zero;
            _rect.sizeDelta = new Vector2(_expandedSize, _expandedSize);
            SetAlpha(_expandedAlpha);
        }

        private void Collapse()
        {
            _rect.anchorMin = _miniAnchorMin;
            _rect.anchorMax = _miniAnchorMax;
            _rect.pivot = _miniPivot;
            _rect.anchoredPosition = _miniPosition;
            _rect.sizeDelta = _miniSize;
            SetAlpha(_miniAlpha);
        }

        private void SetAlpha(float alpha)
        {
            Color color = _image.color;
            color.a = alpha;
            _image.color = color;
        }
    }
}
