using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// O campo de força de uma civilização: registra sua calota no mapa ao
    /// iniciar e, se for totalmente dominado por inimigos (DD-100), decola
    /// após uma contagem de 5 segundos, VOA em arco sobre o planeta e pousa
    /// em um ponto aleatório livre, restabelecendo base + campo de força.
    /// </summary>
    public sealed class HomeTerritory : MonoBehaviour
    {
        private enum BaseState
        {
            OpeningDescent,
            Grounded,
            Countdown,
            Flying,
            Landed
        }

        // DD-096: descida de abertura — 5s do espaço até o ponto de spawn.
        [SerializeField] private float _openingSeconds = 5f;
        [SerializeField] private float _openingAltitude = 60f;

        // DD-100: a nave decola quase imediatamente após perder a base.
        [SerializeField] private float _relocationDelaySeconds = 0.2f;

        // Duração e altitude do voo até o novo lar.
        [SerializeField] private float _flightSeconds = 4f;
        [SerializeField] private float _flightAltitude = 30f;

        // DD-100: contagem na tela = 3s finais de voo + 2s de nave pousada.
        [SerializeField] private float _countdownLeadSeconds = 3f;
        [SerializeField] private float _landedWaitSeconds = 2f;

        // O domo de energia (arraste o filho DomoEnergia aqui): desce
        // invisível e só surge no GO/pouso (pedido do Diretor).
        [SerializeField] private Transform _dome;

        // Vistoria da posse da base a cada meio segundo (barato e suficiente).
        private const float OwnershipCheckInterval = 0.5f;

        private TerritoryMap _map;
        private Civilization _civilization;
        private BaseState _state = BaseState.Grounded;
        private float _checkClock;
        private float _countdown;
        private float _flightClock;
        private float _landedClock;
        private int _lastAnnouncedSecond = -1;
        private Vector3 _departureDirection;
        private Vector3 _arrivalDirection;

        private void Awake()
        {
            // R1: civilização eliminada = a nave se aposenta; o domo fica
            // no planeta como ruína (as informações da rodada permanecem).
            EventBus.Subscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        private void OnEliminated(CivilizationEliminatedEvent eliminatedEvent)
        {
            if (_civilization != null && eliminatedEvent.OwnerId == _civilization.Id)
            {
                enabled = false;
            }
        }

        private void Start()
        {
            IPlanet planet = PlanetLocator.Current;
            _civilization = GetComponent<Civilization>();

            // Busca única na inicialização (nunca em loops de frame);
            // referência direta permitida: TerritoryMap é do mesmo módulo.
            _map = FindAnyObjectByType<TerritoryMap>();

            if (planet == null || _map == null || _civilization == null)
            {
                Debug.LogError(
                    "[World] HomeTerritory requer Planet e TerritoryMap na cena " +
                    "e o crachá Civilization no próprio domo.");
                enabled = false;
                return;
            }

            // DD-096: a partida abre com a nave descendo do espaço até o
            // ponto sorteado pelo MatchSetup — a base só existe ao pousar.
            _arrivalDirection = (transform.position - planet.Center).normalized;
            PlaceOnPlanet(planet, _arrivalDirection, _openingAltitude);
            _flightClock = 0f;
            _lastAnnouncedSecond = -1;
            _state = BaseState.OpeningDescent;

            // O domo começa invisível; surge apenas no GO (pouso concluído).
            SetDomeVisible(false);
        }

        // Posiciona a base a uma altitude sobre a direção da superfície E a
        // deixa "em pé": o topo do domo/nave sempre aponta para o céu,
        // qualquer que seja o lado do planeta onde pouse (pedido do Diretor).
        private void PlaceOnPlanet(IPlanet planet, Vector3 surfaceDirection, float altitude)
        {
            transform.position = planet.Center + surfaceDirection * (planet.Radius + altitude);

            Vector3 forward = Vector3.ProjectOnPlane(transform.forward, surfaceDirection);
            if (forward.sqrMagnitude < 0.001f)
            {
                forward = Vector3.ProjectOnPlane(Vector3.forward, surfaceDirection);
            }

            transform.rotation = Quaternion.LookRotation(forward.normalized, surfaceDirection);
        }

        private void SetDomeVisible(bool visible)
        {
            if (_dome == null)
            {
                return;
            }

            foreach (Renderer domeRenderer in _dome.GetComponentsInChildren<Renderer>(true))
            {
                domeRenderer.enabled = visible;
            }
        }

        private void Update()
        {
            switch (_state)
            {
                case BaseState.OpeningDescent:
                    UpdateOpeningDescent();
                    break;

                case BaseState.Grounded:
                    WatchForBaseTakeover();
                    break;

                case BaseState.Countdown:
                    _countdown -= Time.deltaTime;
                    if (_countdown <= 0f)
                    {
                        BeginFlight();
                    }

                    break;

                case BaseState.Flying:
                    UpdateFlight();
                    break;

                case BaseState.Landed:
                    UpdateLanded();
                    break;
            }
        }

        // Descida vertical suave do espaço até o ponto de spawn, com a
        // contagem regressiva nos 3 segundos finais (DD-096).
        private void UpdateOpeningDescent()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            _flightClock += Time.deltaTime;
            float progress = Mathf.Clamp01(_flightClock / _openingSeconds);
            float smooth = Mathf.SmoothStep(0f, 1f, progress);
            float altitude = _openingAltitude * (1f - smooth);
            PlaceOnPlanet(planet, _arrivalDirection, altitude);

            float descentRemaining = _openingSeconds - _flightClock;
            if (descentRemaining <= _countdownLeadSeconds)
            {
                AnnounceCountdown(descentRemaining + _landedWaitSeconds);
            }

            if (progress >= 1f)
            {
                Land(planet);
            }
        }

        private void WatchForBaseTakeover()
        {
            _checkClock += Time.deltaTime;
            if (_checkClock < OwnershipCheckInterval)
            {
                return;
            }

            _checkClock = 0f;
            if (_map.IsOwnedBy(_civilization.Id, transform.position))
            {
                return;
            }

            // DD-100: quem tomou a base herda o império inteiro.
            byte conqueror = _map.GetOwnerAt(transform.position);
            if (conqueror != 0)
            {
                _map.ConvertAllCellsOf(_civilization.Id, conqueror);
                Debug.Log(
                    $"[World] Civilização {conqueror} tomou a base e HERDOU todo o " +
                    $"império da civilização {_civilization.Id}!");
            }

            // O derrotado embarca no foguete NA HORA (some do campo).
            EventBus.Publish(new BaseFallenEvent(_civilization.Id, conqueror));

            _state = BaseState.Countdown;
            _countdown = _relocationDelaySeconds;
            Debug.Log(
                $"[World] Nave da civilização {_civilization.Id} decola em " +
                $"{_relocationDelaySeconds:F0}s (DD-100).");
        }

        private void BeginFlight()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            Vector3 destination = _map.GetRandomUnownedPosition();
            _departureDirection = (transform.position - planet.Center).normalized;
            _arrivalDirection = (destination - planet.Center).normalized;
            _flightClock = 0f;
            _lastAnnouncedSecond = -1;
            _state = BaseState.Flying;
            Debug.Log($"[World] Nave da civilização {_civilization.Id} decolou!");
        }

        private void UpdateFlight()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            _flightClock += Time.deltaTime;
            float progress = Mathf.Clamp01(_flightClock / _flightSeconds);

            // Suaviza o início e o fim do trajeto (acelera e freia).
            float smooth = Mathf.SmoothStep(0f, 1f, progress);

            // Rota: arco entre partida e chegada; altitude em curva de seno
            // (zero nas pontas, máxima no meio do voo).
            Vector3 direction = Vector3.Slerp(_departureDirection, _arrivalDirection, smooth);
            float altitude = Mathf.Sin(progress * Mathf.PI) * _flightAltitude;
            PlaceOnPlanet(planet, direction, altitude);

            // Contagem na tela: começa quando faltam 3s de voo e segue até
            // o spawn (3s de voo + 2s pousada = 5).
            float flightRemaining = _flightSeconds - _flightClock;
            if (flightRemaining <= _countdownLeadSeconds)
            {
                AnnounceCountdown(flightRemaining + _landedWaitSeconds);
            }

            if (progress >= 1f)
            {
                Land(planet);
            }
        }

        private void Land(IPlanet planet)
        {
            // Pousa exatamente na superfície, em pé (altitude 0).
            PlaceOnPlanet(planet, (transform.position - planet.Center).normalized, 0f);
            EstablishBase(planet);
            _landedClock = 0f;
            _state = BaseState.Landed;
            Debug.Log($"[World] Nave da civilização {_civilization.Id} pousou; campo se restabelecendo (DD-100).");
        }

        // Nave no chão, campo de força se restabelecendo: o personagem só
        // spawna quando a contagem chega a zero.
        private void UpdateLanded()
        {
            _landedClock += Time.deltaTime;
            float remaining = _landedWaitSeconds - _landedClock;
            AnnounceCountdown(remaining);

            if (remaining <= 0f)
            {
                _state = BaseState.Grounded;

                // GO! (contagem zerou): o domo de energia se materializa.
                SetDomeVisible(true);
                EventBus.Publish(new BaseRelocatedEvent(_civilization.Id, transform.position));
                Debug.Log($"[World] Civilização {_civilization.Id} spawnou junto à nave (DD-100).");
            }
        }

        private void AnnounceCountdown(float secondsRemaining)
        {
            int wholeSeconds = Mathf.Max(0, Mathf.CeilToInt(secondsRemaining));
            if (wholeSeconds != _lastAnnouncedSecond)
            {
                _lastAnnouncedSecond = wholeSeconds;
                EventBus.Publish(new RespawnCountdownEvent(_civilization.Id, wholeSeconds));
            }
        }

        // Reivindica a calota sob o domo e registra o campo de força
        // (destino de corredores cortados e zona de regeneração).
        private void EstablishBase(IPlanet planet)
        {
            Vector3 capDirection = (transform.position - planet.Center).normalized;
            _map.ClaimCap(_civilization.Id, capDirection, GetCapAngleDegrees(planet));
            HomeBaseRegistry.Register(
                _civilization.Id, transform.position, transform.lossyScale.x * 0.5f);
        }

        // Geometria do domo: uma esfera de raio r com centro na superfície de
        // um planeta de raio R cobre uma "calota" de meio-ângulo asin(r/R).
        private float GetCapAngleDegrees(IPlanet planet)
        {
            float domeRadius = transform.lossyScale.x * 0.5f;
            return Mathf.Asin(Mathf.Clamp01(domeRadius / planet.Radius)) * Mathf.Rad2Deg;
        }
    }
}
