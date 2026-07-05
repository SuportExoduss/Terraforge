using Terraforge.Core;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// O motorista humano: converte o teclado (A/D ou setas) na direção
    /// de corrida que o PlanetRunner consome via ISteeringSource.
    /// </summary>
    public sealed class PlayerSteering : MonoBehaviour, ISteeringSource
    {
        public float GetSteer()
        {
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
    }
}
