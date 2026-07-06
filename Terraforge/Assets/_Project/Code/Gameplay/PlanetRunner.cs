using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// Movimento contínuo sobre a superfície do planeta (GDMD: "o jogador
    /// nunca para de correr"). A direção vem de um "motorista"
    /// (ISteeringSource) no mesmo objeto: teclado para o jogador,
    /// cérebro de bot para adversários. A gravidade aponta sempre para o
    /// centro do planeta.
    /// </summary>
    public sealed class PlanetRunner : MonoBehaviour
    {
        [SerializeField] private float _moveSpeed = 8f;
        [SerializeField] private float _turnSpeedDegrees = 140f;

        // Distância entre o pé e o centro da cápsula (cápsula padrão tem 2 de altura).
        [SerializeField] private float _heightOffset = 1f;

        private Vector3 _forward;
        private ISteeringSource _steering;
        private Renderer[] _renderers;
        private bool _matchStarted;

        private void Awake()
        {
            _steering = GetComponent<ISteeringSource>();
            if (_steering == null)
            {
                Debug.LogError($"[PlanetRunner] {name} não tem um motorista (ISteeringSource).");
            }

            // DD-096: o personagem só aparece e corre no GO! da abertura.
            _renderers = GetComponentsInChildren<Renderer>();
            SetVisible(false);

            EventBus.Subscribe<MatchStartedEvent>(OnMatchStarted);
            EventBus.Subscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<MatchStartedEvent>(OnMatchStarted);
            EventBus.Unsubscribe<MatchEndedEvent>(OnMatchEnded);
        }

        private void OnMatchStarted(MatchStartedEvent matchStarted)
        {
            _matchStarted = true;
            SetVisible(true);
        }

        private void SetVisible(bool visible)
        {
            foreach (Renderer childRenderer in _renderers)
            {
                childRenderer.enabled = visible;
            }
        }

        // Fim de partida: o corredor para; o planeta permanece para
        // contemplação (GDMD, encerramento da partida).
        private void OnMatchEnded(MatchEndedEvent matchEnded)
        {
            enabled = false;
        }

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
            // tangente a ela (perpendicular ao "up" local). O eixo de
            // referência troca se o spawn cair alinhado a ele (evita direção
            // nula em pontos raros do planeta).
            Vector3 up = (transform.position - planet.Center).normalized;
            Vector3 reference =
                Mathf.Abs(Vector3.Dot(up, Vector3.forward)) < 0.99f ? Vector3.forward : Vector3.right;
            _forward = Vector3.ProjectOnPlane(reference, up).normalized;

            // Postura aplicada JÁ no nascimento: a câmera enquadra a direção
            // de corrida durante a descida da nave (DD-096), sem solavanco no GO.
            transform.SetPositionAndRotation(
                planet.Center + up * (planet.Radius + _heightOffset),
                Quaternion.LookRotation(_forward, up));
        }

        private void Update()
        {
            if (!_matchStarted)
            {
                return;
            }

            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            float steer = _steering?.GetSteer() ?? 0f;

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
    }
}
