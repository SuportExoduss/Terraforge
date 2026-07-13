using Terraforge.Core;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// O motorista humano: converte o teclado (A/D ou setas) na direção
    /// de corrida que o PlanetRunner consome via ISteeringSource.
    /// </summary>
    public sealed class PlayerSteering : MonoBehaviour, ISteeringSource
    {
        [SerializeField] private float _joystickRadiusPixels = 95f;
        [SerializeField] private float _joystickDeadZone = 0.08f;

        private bool _trackingTouch;
        private int _touchId;
        private Vector2 _touchOrigin;

        private void OnDisable()
        {
            StopTouch();
        }

        private void Update()
        {
            Touchscreen touchscreen = Touchscreen.current;
            if (touchscreen == null)
            {
                return;
            }

            TouchControl touch = touchscreen.primaryTouch;
            if (!_trackingTouch && touch.press.wasPressedThisFrame && !TouchSteering.IsUiPointerHeld)
            {
                _trackingTouch = true;
                _touchId = touch.touchId.ReadValue();
                _touchOrigin = touch.position.ReadValue();
                TouchSteering.Begin(_touchOrigin);
            }

            if (!_trackingTouch)
            {
                return;
            }

            if (TouchSteering.IsUiPointerHeld || touch.press.wasReleasedThisFrame || !touch.press.isPressed)
            {
                StopTouch();
                return;
            }

            if (touch.touchId.ReadValue() == _touchId)
            {
                Vector2 offset = touch.position.ReadValue() - _touchOrigin;
                Vector2 clamped = Vector2.ClampMagnitude(offset, _joystickRadiusPixels);
                float steer = clamped.x / _joystickRadiusPixels;
                TouchSteering.Set(
                    Mathf.Abs(steer) >= _joystickDeadZone ? steer : 0f,
                    clamped);
            }
        }

        public float GetSteer()
        {
            float touchSteer = TouchSteering.Value;
            if (Mathf.Abs(touchSteer) > 0.001f)
            {
                return touchSteer;
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

        private void StopTouch()
        {
            _trackingTouch = false;
            TouchSteering.Clear();
        }
    }
}
