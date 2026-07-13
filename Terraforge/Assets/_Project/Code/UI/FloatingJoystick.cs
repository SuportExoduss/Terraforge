using Terraforge.Core;
using UnityEngine;
using UnityEngine.UI;

namespace Terraforge.UI
{
    /// <summary>
    /// Analógico flutuante para retrato: nasce sob o dedo, mostra o limite
    /// do arrasto e entrega somente o eixo horizontal para a corrida contínua.
    /// Tocar nos elementos de UI existentes (como o minimapa) não o ativa.
    /// </summary>
    public sealed class FloatingJoystick : MonoBehaviour
    {
        [SerializeField] private float _outerDiameter = 190f;
        [SerializeField] private float _knobDiameter = 82f;

        private RectTransform _canvasRect;
        private RectTransform _outer;
        private RectTransform _knob;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void SpawnUnderCanvas()
        {
            if (FindAnyObjectByType<FloatingJoystick>() != null)
            {
                return;
            }

            Canvas canvas = FindAnyObjectByType<Canvas>();
            if (canvas == null)
            {
                return;
            }

            var joystickObject = new GameObject("FloatingJoystick", typeof(RectTransform));
            joystickObject.transform.SetParent(canvas.transform, worldPositionStays: false);
            var rootRect = joystickObject.GetComponent<RectTransform>();
            rootRect.anchorMin = Vector2.zero;
            rootRect.anchorMax = Vector2.one;
            rootRect.pivot = new Vector2(0.5f, 0.5f);
            rootRect.offsetMin = Vector2.zero;
            rootRect.offsetMax = Vector2.zero;
            joystickObject.AddComponent<FloatingJoystick>();
        }

        private void Awake()
        {
            _canvasRect = GetComponentInParent<Canvas>().transform as RectTransform;
            _outer = CreateCircle("Outer", _outerDiameter, new Color(0.16f, 0.31f, 0.55f, 0.34f));
            _knob = CreateCircle("Knob", _knobDiameter, new Color(0.54f, 0.84f, 1f, 0.72f));
            SetVisible(false);
        }

        private void Update()
        {
            if (!TouchSteering.IsActive)
            {
                if (_outer.gameObject.activeSelf)
                {
                    SetVisible(false);
                }

                return;
            }

            Vector2 origin = ScreenToCanvas(TouchSteering.Origin);
            float visualScale = _outerDiameter / 190f;
            _outer.anchoredPosition = origin;
            _knob.anchoredPosition = origin + TouchSteering.KnobOffset * visualScale;
            if (!_outer.gameObject.activeSelf)
            {
                SetVisible(true);
            }
        }

        private RectTransform CreateCircle(string objectName, float diameter, Color color)
        {
            var circleObject = new GameObject(objectName, typeof(RectTransform), typeof(Image));
            circleObject.transform.SetParent(transform, worldPositionStays: false);

            var rect = circleObject.GetComponent<RectTransform>();
            rect.anchorMin = new Vector2(0.5f, 0.5f);
            rect.anchorMax = new Vector2(0.5f, 0.5f);
            rect.pivot = new Vector2(0.5f, 0.5f);
            rect.sizeDelta = new Vector2(diameter, diameter);

            var image = circleObject.GetComponent<Image>();
            image.sprite = Resources.GetBuiltinResource<Sprite>("UI/Skin/UISprite.psd");
            image.type = Image.Type.Simple;
            image.color = color;
            image.raycastTarget = false;
            return rect;
        }

        private Vector2 ScreenToCanvas(Vector2 screenPosition)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(
                _canvasRect, screenPosition, null, out Vector2 localPosition);
            return localPosition;
        }

        private void SetVisible(bool visible)
        {
            _outer.gameObject.SetActive(visible);
            _knob.gameObject.SetActive(visible);
        }
    }
}
