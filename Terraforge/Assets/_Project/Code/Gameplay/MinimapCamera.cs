using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// A câmera-satélite do minimapa (DD-104 revisado): no modo normal,
    /// paira sobre o JOGADOR — ele fica no centro do mini-planeta e o
    /// mundo gira conforme ele anda e vira. No modo expandido (um toque),
    /// vira órbita livre: arrastar gira o planeta para observar tudo.
    /// </summary>
    [RequireComponent(typeof(Camera))]
    public sealed class MinimapCamera : MonoBehaviour
    {
        // O corredor do jogador (arraste o Runner aqui).
        [SerializeField] private Transform _followTarget;

        // Fração do enquadramento que o planeta ocupa (0.95 = quase tudo).
        [SerializeField] [Range(0.5f, 1f)] private float _planetFillFactor = 0.95f;
        [SerializeField] private float _dragDegreesPerPixel = 0.4f;
        [SerializeField, Min(1f)] private float _normalRefreshRate = 15f;
        [SerializeField, Min(1f)] private float _expandedRefreshRate = 30f;

        private Camera _camera;
        private bool _expanded;
        private Vector2 _pendingDrag;
        private Vector3 _orbitDirection = Vector3.back;
        private float _nextRenderTime;

        private void Awake()
        {
            _camera = GetComponent<Camera>();
            EventBus.Subscribe<MinimapHoldEvent>(OnExpandChanged);
            EventBus.Subscribe<MinimapDragEvent>(OnDragged);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<MinimapHoldEvent>(OnExpandChanged);
            EventBus.Unsubscribe<MinimapDragEvent>(OnDragged);
        }

        private void OnExpandChanged(MinimapHoldEvent holdEvent)
        {
            _expanded = holdEvent.IsHeld;
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

            // Enquadramento automático (o planeta preenche o quadro).
            float halfFovRadians = _camera.fieldOfView * 0.5f * Mathf.Deg2Rad;
            float distance = planet.Radius / Mathf.Sin(halfFovRadians * _planetFillFactor);

            if (!_expanded)
            {
                // MODO BÚSSOLA: pairando sobre o jogador — ele no centro,
                // o mundo girando sob os pés dele (posição E direção).
                Vector3 direction = _followTarget != null
                    ? (_followTarget.position - planet.Center).normalized
                    : Vector3.up;
                Vector3 upHint = _followTarget != null ? _followTarget.forward : Vector3.forward;

                transform.position = planet.Center + direction * distance;
                transform.rotation = Quaternion.LookRotation(-direction, upHint);
                _orbitDirection = direction;
            }
            else
            {
                // MODO OBSERVATÓRIO: órbita livre comandada pelo arrasto.
                float yaw = -_pendingDrag.x * _dragDegreesPerPixel;
                float pitch = _pendingDrag.y * _dragDegreesPerPixel;
                _orbitDirection = Quaternion.AngleAxis(yaw, transform.up) *
                                  Quaternion.AngleAxis(pitch, transform.right) * _orbitDirection;
                _orbitDirection.Normalize();

                transform.position = planet.Center + _orbitDirection * distance;
                transform.rotation = Quaternion.LookRotation(-_orbitDirection, transform.up);
            }

            _pendingDrag = Vector2.zero;

            // O minimapa é uma segunda renderização integral da cena. Em
            // modo compacto, 15 FPS é visualmente estável para um ícone de
            // HUD; aberto, sobe para 30 FPS para preservar o arrasto.
            float refreshRate = _expanded ? _expandedRefreshRate : _normalRefreshRate;
            if (Time.unscaledTime >= _nextRenderTime)
            {
                _camera.enabled = true;
                _nextRenderTime = Time.unscaledTime + 1f / refreshRate;
            }
            else
            {
                _camera.enabled = false;
            }
        }
    }
}
