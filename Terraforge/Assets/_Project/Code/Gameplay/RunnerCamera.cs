using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// Câmera superior do GDMD: paira acima do corredor olhando para baixo,
    /// com a frente do personagem apontando para o topo da tela. Movimento
    /// suavizado para acompanhar a curvatura do planeta sem solavancos.
    /// </summary>
    public sealed class RunnerCamera : MonoBehaviour
    {
        [SerializeField] private Transform _target;
        [SerializeField] private float _height = 12f;
        [SerializeField] private float _backDistance = 16f;

        // DD-113 (retrato): a câmera mira um ponto À FRENTE do corredor —
        // ele fica no meio-baixo da tela, com horizonte e céu no topo.
        [SerializeField] private float _lookAheadDistance = 18f;
        [SerializeField] private float _positionSmoothing = 5f;
        [SerializeField] private float _rotationSmoothing = 5f;

        private void Awake()
        {
            EventBus.Subscribe<MatchEndedEvent>(OnMatchEnded);
            EventBus.Subscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<MatchEndedEvent>(OnMatchEnded);
            EventBus.Unsubscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        // Fim de partida: esta câmera se aposenta e passa o bastão
        // para a ContemplationCamera.
        private void OnMatchEnded(MatchEndedEvent matchEnded)
        {
            enabled = false;
        }

        // R1: jogador eliminado vira espectador — mesma passagem de bastão.
        private void OnEliminated(CivilizationEliminatedEvent eliminatedEvent)
        {
            if (eliminatedEvent.OwnerId == Civilization.PlayerId)
            {
                enabled = false;
            }
        }

        // LateUpdate roda DEPOIS de todos os Updates do frame: o corredor
        // se move primeiro, a câmera reage por último — nunca o contrário.
        private void LateUpdate()
        {
            if (_target == null)
            {
                return;
            }

            Vector3 up = _target.up;
            Vector3 desiredPosition = _target.position + up * _height - _target.forward * _backDistance;

            // Mira adiante do corredor (não nele): visão de horizonte que
            // gira junto com o jogador, como nas referências do Diretor.
            Vector3 lookPoint = _target.position + _target.forward * _lookAheadDistance;
            Quaternion desiredRotation =
                Quaternion.LookRotation(lookPoint - desiredPosition, up);

            // Suavização exponencial: independe da taxa de quadros (FPS),
            // ao contrário de um Lerp com fator fixo.
            float moveStep = 1f - Mathf.Exp(-_positionSmoothing * Time.deltaTime);
            float turnStep = 1f - Mathf.Exp(-_rotationSmoothing * Time.deltaTime);

            transform.position = Vector3.Lerp(transform.position, desiredPosition, moveStep);
            transform.rotation = Quaternion.Slerp(transform.rotation, desiredRotation, turnStep);
        }
    }
}
