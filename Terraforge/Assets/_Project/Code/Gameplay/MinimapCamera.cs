using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// A câmera-satélite do minimapa (DD-104): orbita o planeta filmando-o
    /// inteiro para uma Render Texture. Gira sozinha em modo vitrine; com
    /// o minimapa seguro, obedece aos arrastos vindos do EventBus.
    /// </summary>
    [RequireComponent(typeof(Camera))]
    public sealed class MinimapCamera : MonoBehaviour
    {
        // Fração do enquadramento que o planeta ocupa (0.95 = quase tudo).
        [SerializeField] [Range(0.5f, 1f)] private float _planetFillFactor = 0.95f;
        [SerializeField] private float _autoOrbitSpeedDegrees = 12f;
        [SerializeField] private float _dragDegreesPerPixel = 0.4f;

        private Camera _camera;
        private bool _held;
        private Vector2 _pendingDrag;

        private void Awake()
        {
            _camera = GetComponent<Camera>();
            EventBus.Subscribe<MinimapHoldEvent>(OnHoldChanged);
            EventBus.Subscribe<MinimapDragEvent>(OnDragged);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<MinimapHoldEvent>(OnHoldChanged);
            EventBus.Unsubscribe<MinimapDragEvent>(OnDragged);
        }

        private void OnHoldChanged(MinimapHoldEvent holdEvent)
        {
            _held = holdEvent.IsHeld;
        }

        private void OnDragged(MinimapDragEvent dragEvent)
        {
            _pendingDrag += dragEvent.DeltaPixels;
        }

        private void LateUpdate()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            Vector3 offset = transform.position - planet.Center;
            if (offset.sqrMagnitude < 0.01f)
            {
                offset = Vector3.back;
            }

            if (_held)
            {
                // Arrasto do jogador gira a órbita (mesma matemática da
                // câmera de contemplação).
                float yaw = -_pendingDrag.x * _dragDegreesPerPixel;
                float pitch = _pendingDrag.y * _dragDegreesPerPixel;
                offset = Quaternion.AngleAxis(yaw, transform.up) *
                         Quaternion.AngleAxis(pitch, transform.right) * offset;
            }
            else
            {
                // Vitrine: giro lento e constante.
                offset = Quaternion.AngleAxis(
                    _autoOrbitSpeedDegrees * Time.deltaTime, Vector3.up) * offset;
            }

            _pendingDrag = Vector2.zero;

            // Enquadramento automático: a que distância o planeta ocupa a
            // fração desejada da lente? Trigonometria: o raio aparente do
            // planeta visto de uma distância d é asin(R/d); resolvemos para
            // que ele preencha _planetFillFactor do meio-campo de visão.
            float halfFovRadians = _camera.fieldOfView * 0.5f * Mathf.Deg2Rad;
            float distance = planet.Radius / Mathf.Sin(halfFovRadians * _planetFillFactor);

            offset = offset.normalized * distance;
            transform.position = planet.Center + offset;
            transform.rotation = Quaternion.LookRotation(-offset.normalized, transform.up);
        }
    }
}
