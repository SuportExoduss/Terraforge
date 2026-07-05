using Terraforge.Core;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// Câmera de contemplação (GDMD: "o planeta permanece disponível para
    /// contemplação"): dorme durante a partida e desperta no fim — afasta-se
    /// suavemente até enquadrar o planeta inteiro e deixa o jogador girá-lo
    /// arrastando o mouse ou usando setas/A-D (W/S inclinam).
    /// </summary>
    public sealed class ContemplationCamera : MonoBehaviour
    {
        // Distância final = raio do planeta x este fator.
        [SerializeField] private float _distanceFactor = 3f;
        [SerializeField] private float _approachSmoothing = 1.5f;
        [SerializeField] private float _dragDegreesPerPixel = 0.2f;
        [SerializeField] private float _keyOrbitSpeedDegrees = 60f;

        // Giro de vitrine: velocidade da órbita automática quando o
        // jogador não está interagindo.
        [SerializeField] private float _autoOrbitSpeedDegrees = 10f;

        private bool _active;

        private void Awake()
        {
            EventBus.Subscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnMatchEnded(MatchEndedEvent matchEnded)
        {
            _active = true;
        }

        private void LateUpdate()
        {
            if (!_active)
            {
                return;
            }

            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            Vector3 offset = transform.position - planet.Center;

            // 1. Órbita: comandada pelo jogador ou, se ele soltar,
            //    o giro automático de vitrine assume.
            Vector2 orbit = ReadOrbitInput(out bool playerIsControlling);
            if (!playerIsControlling)
            {
                orbit.x = _autoOrbitSpeedDegrees * Time.deltaTime;
            }
            offset = Quaternion.AngleAxis(orbit.x, transform.up) *
                     Quaternion.AngleAxis(orbit.y, transform.right) *
                     offset;

            // 2. Afastamento suave até a distância de contemplação.
            float targetDistance = planet.Radius * _distanceFactor;
            float step = 1f - Mathf.Exp(-_approachSmoothing * Time.deltaTime);
            float distance = Mathf.Lerp(offset.magnitude, targetDistance, step);
            offset = offset.normalized * distance;

            // 3. Sempre olhando para o coração do planeta.
            transform.position = planet.Center + offset;
            transform.rotation = Quaternion.LookRotation(-offset.normalized, transform.up);
        }

        private Vector2 ReadOrbitInput(out bool playerIsControlling)
        {
            Vector2 orbit = Vector2.zero;
            playerIsControlling = false;

            Mouse mouse = Mouse.current;
            if (mouse != null && mouse.leftButton.isPressed)
            {
                playerIsControlling = true;
                Vector2 drag = mouse.delta.ReadValue();
                orbit.x -= drag.x * _dragDegreesPerPixel;
                orbit.y += drag.y * _dragDegreesPerPixel;
            }

            Keyboard keyboard = Keyboard.current;
            if (keyboard != null)
            {
                float keyStep = _keyOrbitSpeedDegrees * Time.deltaTime;
                if (keyboard.aKey.isPressed || keyboard.leftArrowKey.isPressed)
                {
                    orbit.x -= keyStep;
                }

                if (keyboard.dKey.isPressed || keyboard.rightArrowKey.isPressed)
                {
                    orbit.x += keyStep;
                }

                if (keyboard.wKey.isPressed || keyboard.upArrowKey.isPressed)
                {
                    orbit.y += keyStep;
                }

                if (keyboard.sKey.isPressed || keyboard.downArrowKey.isPressed)
                {
                    orbit.y -= keyStep;
                }
            }

            // Qualquer comando de órbita (mouse ou teclas) pausa a vitrine.
            playerIsControlling |= orbit != Vector2.zero;

            return orbit;
        }
    }
}
