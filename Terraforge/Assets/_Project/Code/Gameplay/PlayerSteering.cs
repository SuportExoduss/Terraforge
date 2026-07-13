using Terraforge.Core;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// O motorista humano. Direção por PONTEIRO (Pointer.current unifica
    /// toque no celular e mouse no Editor): tocar/clicar cria um analógico
    /// flutuante sob o dedo; arrastar para os lados curva a corrida. O
    /// teclado (A/D, setas) continua valendo como alternativa.
    /// A UI do joystick lê o mesmo canal TouchSteering (Core).
    /// </summary>
    public sealed class PlayerSteering : MonoBehaviour, ISteeringSource
    {
        [SerializeField] private float _joystickRadiusPixels = 120f;
        [SerializeField] private float _joystickDeadZone = 0.08f;

        private bool _tracking;
        private Vector2 _origin;

        private void OnDisable()
        {
            StopTracking();
        }

        private void Update()
        {
            Pointer pointer = Pointer.current;
            if (pointer == null)
            {
                return;
            }

            bool pressed = pointer.press.isPressed;
            Vector2 position = pointer.position.ReadValue();

            // Começa a rastrear quando o dedo/mouse encosta fora da UI
            // (o minimapa avisa quando está sendo tocado).
            if (!_tracking)
            {
                if (pointer.press.wasPressedThisFrame && !TouchSteering.IsUiPointerHeld)
                {
                    _tracking = true;
                    _origin = position;
                    TouchSteering.Begin(_origin);
                }

                return;
            }

            // Soltou (ou a UI assumiu o ponteiro): some o analógico.
            if (!pressed || TouchSteering.IsUiPointerHeld)
            {
                StopTracking();
                return;
            }

            // Arrasto: só o eixo horizontal vira direção (a corrida é
            // sempre automática, DD — o jogador só controla a curva).
            Vector2 offset = position - _origin;
            Vector2 clamped = Vector2.ClampMagnitude(offset, _joystickRadiusPixels);
            float steer = clamped.x / _joystickRadiusPixels;
            TouchSteering.Set(Mathf.Abs(steer) >= _joystickDeadZone ? steer : 0f, clamped);
        }

        public float GetSteer()
        {
            if (_tracking && Mathf.Abs(TouchSteering.Value) > 0.001f)
            {
                return TouchSteering.Value;
            }

            Keyboard keyboard = Keyboard.current;
            if (keyboard == null)
            {
                return 0f;
            }

            float steer = 0f;
            if (keyboard.aKey.isPressed || keyboard.leftArrowKey.isPressed)
            {
                steer -= 1f;
            }

            if (keyboard.dKey.isPressed || keyboard.rightArrowKey.isPressed)
            {
                steer += 1f;
            }

            return steer;
        }

        private void StopTracking()
        {
            if (_tracking)
            {
                _tracking = false;
                TouchSteering.Clear();
            }
        }
    }
}
