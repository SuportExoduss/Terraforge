using Terraforge.Core;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// Movimento contínuo sobre a superfície do planeta (GDMD: "o jogador
    /// nunca para de correr"). O jogador controla apenas a direção (A/D ou
    /// setas); a gravidade aponta sempre para o centro do planeta.
    /// </summary>
    public sealed class PlanetRunner : MonoBehaviour
    {
        [SerializeField] private float _moveSpeed = 8f;
        [SerializeField] private float _turnSpeedDegrees = 140f;

        // Distância entre o pé e o centro da cápsula (cápsula padrão tem 2 de altura).
        [SerializeField] private float _heightOffset = 1f;

        private Vector3 _forward;

        private void Start()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                Debug.LogError("[PlanetRunner] Nenhum planeta registrado na cena.");
                enabled = false;
                return;
            }

            // Cola o personagem na superfície e escolhe uma direção inicial
            // tangente a ela (perpendicular ao "up" local).
            Vector3 up = (transform.position - planet.Center).normalized;
            transform.position = planet.Center + up * (planet.Radius + _heightOffset);
            _forward = Vector3.ProjectOnPlane(Vector3.forward, up).normalized;
        }

        private void Update()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            float steer = ReadSteerInput();

            // 1. Gira a direção de corrida ao redor do "up" local (o volante).
            Vector3 up = (transform.position - planet.Center).normalized;
            _forward = Quaternion.AngleAxis(steer * _turnSpeedDegrees * Time.deltaTime, up) * _forward;

            // 2. Avança sempre (nunca para de correr).
            Vector3 next = transform.position + _forward * (_moveSpeed * Time.deltaTime);

            // 3. Recola na superfície: num planeta, andar em linha reta te
            //    afastaria da esfera; reprojetamos o ponto de volta ao raio correto.
            Vector3 nextUp = (next - planet.Center).normalized;
            next = planet.Center + nextUp * (planet.Radius + _heightOffset);

            // 4. A direção de corrida precisa continuar tangente à superfície
            //    (sem componente "para cima/baixo"), senão acumula erro a cada frame.
            _forward = Vector3.ProjectOnPlane(_forward, nextUp).normalized;

            // 5. Aplica posição e postura: pés para o centro, olhar para frente.
            transform.SetPositionAndRotation(next, Quaternion.LookRotation(_forward, nextUp));
        }

        private static float ReadSteerInput()
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
