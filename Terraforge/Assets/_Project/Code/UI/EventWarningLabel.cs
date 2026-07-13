using Terraforge.Core;
using TMPro;
using UnityEngine;

namespace Terraforge.UI
{
    /// <summary>
    /// HUD: o alerta de evento global (DD-106) — "METEORO CAINDO... 5" e,
    /// no zero, "IMPACTO!" por um instante.
    /// </summary>
    [RequireComponent(typeof(TMP_Text))]
    public sealed class EventWarningLabel : MonoBehaviour
    {
        [SerializeField] private float _impactDisplaySeconds = 1.2f;

        // Auto-instalação: o alerta nasce sozinho no Canvas ao dar Play —
        // nenhuma montagem manual de cena é necessária.
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void SpawnUnderCanvas()
        {
            if (FindAnyObjectByType<EventWarningLabel>() != null)
            {
                return;
            }

            Canvas canvas = FindAnyObjectByType<Canvas>();
            if (canvas == null)
            {
                return;
            }

            var labelObject = new GameObject("EventLabel", typeof(RectTransform));
            labelObject.transform.SetParent(canvas.transform, worldPositionStays: false);

            var rect = labelObject.GetComponent<RectTransform>();
            rect.anchorMin = new Vector2(0.5f, 1f);
            rect.anchorMax = new Vector2(0.5f, 1f);
            rect.pivot = new Vector2(0.5f, 1f);
            rect.anchoredPosition = new Vector2(0f, -90f);
            rect.sizeDelta = new Vector2(900f, 60f);

            var text = labelObject.AddComponent<TextMeshProUGUI>();
            text.fontSize = 40f;
            text.alignment = TextAlignmentOptions.Center;
            text.color = new Color(1f, 0.85f, 0.3f); // âmbar de alerta

            labelObject.AddComponent<EventWarningLabel>();
        }

        private TMP_Text _label;
        private float _clearTime;

        private void Awake()
        {
            _label = GetComponent<TMP_Text>();
            _label.text = string.Empty;
            EventBus.Subscribe<GlobalEventWarningEvent>(OnWarningTick);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<GlobalEventWarningEvent>(OnWarningTick);
        }

        private void Update()
        {
            if (_clearTime > 0f && Time.time >= _clearTime)
            {
                _label.text = string.Empty;
                _clearTime = 0f;
            }
        }

        private void OnWarningTick(GlobalEventWarningEvent warningEvent)
        {
            if (warningEvent.SecondsRemaining > 0)
            {
                _label.text = $"{warningEvent.EventName}... {warningEvent.SecondsRemaining}";
                _clearTime = 0f;
            }
            else
            {
                _label.text = "IMPACTO!";
                _clearTime = Time.time + _impactDisplaySeconds;
            }
        }
    }
}
