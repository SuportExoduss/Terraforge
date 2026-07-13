using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// SYS-004 / DD-107: o METEORO. Segue o ciclo oficial de todo evento
    /// global (DD-106): AVISO (contagem + sombra crescendo no ponto de
    /// impacto) → EXECUÇÃO (rocha cai do céu; dano em 3 anéis: 4/2/1, com
    /// o centro devolvendo a vítima à base) → CICATRIZ (cratera escura que
    /// desvanece, DD-108). Visuais em primitivas reutilizadas (nunca cria
    /// nem destrói durante a partida — filosofia dos Slots).
    /// </summary>
    public sealed class MeteorEventSystem : MonoBehaviour
    {
        [Header("Agenda")]
        [SerializeField] private float _minSecondsBetween = 45f;
        [SerializeField] private float _maxSecondsBetween = 90f;

        // Janela de eventos (DD-106): paz nos primeiros e últimos 25s.
        [SerializeField] private float _quietAfterStartSeconds = 25f;
        [SerializeField] private float _quietBeforeEndSeconds = 25f;

        [Header("Ciclo (DD-106/107)")]
        [SerializeField] private float _warningSeconds = 5f;
        [SerializeField] private float _scarSeconds = 25f;

        [Header("Anéis de dano")]
        [SerializeField] private float _innerRadius = 6f;
        [SerializeField] private float _midRadius = 12f;
        [SerializeField] private float _outerRadius = 20f;

        [Header("Rocha")]
        [SerializeField] private float _rockFallSeconds = 1.5f;
        [SerializeField] private float _rockAltitude = 80f;
        [SerializeField] private float _rockScale = 5f;

        // Giro de tombo durante a queda (graus/segundo) — drama espacial.
        [SerializeField] private float _rockTumbleDegrees = 220f;

        // Modelo 3D do meteoro (opcional): sem ele, usa a esfera primitiva.
        [SerializeField] private GameObject _rockModel;

        private const string EventName = "METEORO CAINDO";

        private enum State { WaitingMatch, Cooldown, Warning, Scar }

        private State _state = State.WaitingMatch;
        private float _clock;
        private float _cooldownTarget;
        private int _matchSecondsRemaining = int.MaxValue;
        private int _lastAnnouncedSecond = -1;
        private Vector3 _impactDirection;
        private Vector3 _impactPoint;
        private Transform _shadow;
        private Transform _rock;
        private Transform _scar;

        private void Awake()
        {
            _shadow = CreateDisc("MeteorShadow", new Color(0.05f, 0.05f, 0.08f, 1f));
            _scar = CreateDisc("MeteorScar", new Color(0.12f, 0.07f, 0.04f, 1f));
            _rock = _rockModel != null
                ? CreateFromModel(_rockModel, "MeteorRock")
                : CreatePrimitive(PrimitiveType.Sphere, "MeteorRock",
                    new Color(0.45f, 0.3f, 0.2f, 1f));

            EventBus.Subscribe<MatchStartedEvent>(OnMatchStarted);
            EventBus.Subscribe<MatchEndedEvent>(OnMatchEnded);
            EventBus.Subscribe<MatchClockChangedEvent>(OnClockChanged);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<MatchStartedEvent>(OnMatchStarted);
            EventBus.Unsubscribe<MatchEndedEvent>(OnMatchEnded);
            EventBus.Unsubscribe<MatchClockChangedEvent>(OnClockChanged);
        }

        private void OnMatchStarted(MatchStartedEvent matchStarted)
        {
            BeginCooldown();

            // DD-106: o primeiro meteoro respeita a paz inicial de 25s.
            _cooldownTarget = Mathf.Max(_cooldownTarget, _quietAfterStartSeconds);
        }

        private void OnClockChanged(MatchClockChangedEvent clockEvent)
        {
            _matchSecondsRemaining = clockEvent.SecondsRemaining;
        }

        private void OnMatchEnded(MatchEndedEvent matchEnded)
        {
            _shadow.gameObject.SetActive(false);
            _rock.gameObject.SetActive(false);
            _scar.gameObject.SetActive(false);
            _state = State.WaitingMatch;
        }

        private void Update()
        {
            switch (_state)
            {
                case State.Cooldown:
                    _clock += Time.deltaTime;
                    if (_clock >= _cooldownTarget)
                    {
                        // DD-106: o impacto precisa acontecer antes dos 25s
                        // finais — sem tempo hábil, os céus se calam.
                        bool fitsBeforeQuietEnd =
                            _matchSecondsRemaining > _quietBeforeEndSeconds + _warningSeconds;

                        if (fitsBeforeQuietEnd)
                        {
                            BeginWarning();
                        }
                    }

                    break;

                case State.Warning:
                    UpdateWarning();
                    break;

                case State.Scar:
                    UpdateScar();
                    break;
            }
        }

        private void BeginCooldown()
        {
            _state = State.Cooldown;
            _clock = 0f;
            _cooldownTarget = Random.Range(_minSecondsBetween, _maxSecondsBetween);
        }

        // AVISO: sorteia o ponto de impacto e a sombra começa a crescer.
        private void BeginWarning()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                BeginCooldown();
                return;
            }

            _impactDirection = Random.onUnitSphere;
            float surfaceRadius = planet.GetSurfaceRadius(_impactDirection);
            _impactPoint = planet.Center + _impactDirection * surfaceRadius;

            PlaceFlatOnSurface(_shadow, _impactPoint, _impactDirection, 2f);
            _shadow.gameObject.SetActive(true);

            _state = State.Warning;
            _clock = 0f;
            _lastAnnouncedSecond = -1;
            Debug.Log("[World] METEORO a caminho! (DD-107)");
        }

        private void UpdateWarning()
        {
            _clock += Time.deltaTime;
            float remaining = _warningSeconds - _clock;

            // Sombra cresce até o diâmetro do anel interno.
            float growth = Mathf.Clamp01(_clock / _warningSeconds);
            float shadowDiameter = Mathf.Lerp(2f, _innerRadius * 2f, growth);
            _shadow.localScale = new Vector3(shadowDiameter, 0.15f, shadowDiameter);

            AnnounceCountdown(Mathf.Max(0, Mathf.CeilToInt(remaining)));

            // A rocha só aparece no finalzinho, despencando do céu.
            if (remaining <= _rockFallSeconds)
            {
                if (!_rock.gameObject.activeSelf)
                {
                    _rock.localScale = Vector3.one * _rockScale;
                    _rock.gameObject.SetActive(true);
                }

                float fall = Mathf.Clamp01(1f - remaining / _rockFallSeconds);
                float altitude = Mathf.Lerp(_rockAltitude, _rockScale * 0.3f, fall);
                _rock.position = _impactPoint + _impactDirection * altitude;
                _rock.Rotate(Vector3.one * (_rockTumbleDegrees * Time.deltaTime));
            }

            if (remaining <= 0f)
            {
                Impact();
            }
        }

        // EXECUÇÃO: o golpe (3 anéis exclusivos) e a cicatriz.
        private void Impact()
        {
            EventBus.Publish(new RadialDamageEvent(
                _impactPoint,
                _innerRadius, 4, innerReturnsToBase: true,
                _midRadius, 2,
                _outerRadius, 1));

            _shadow.gameObject.SetActive(false);
            _rock.gameObject.SetActive(false);

            PlaceFlatOnSurface(_scar, _impactPoint, _impactDirection, _midRadius * 2f);
            _scar.gameObject.SetActive(true);

            _state = State.Scar;
            _clock = 0f;
            Debug.Log("[World] IMPACTO do meteoro! Cratera aberta (DD-108).");
        }

        // CICATRIZ: a cratera desvanece encolhendo (DD-108, ~25s).
        private void UpdateScar()
        {
            _clock += Time.deltaTime;
            float life = Mathf.Clamp01(1f - _clock / _scarSeconds);
            float diameter = _midRadius * 2f * life;
            _scar.localScale = new Vector3(diameter, 0.12f, diameter);

            if (life <= 0f)
            {
                _scar.gameObject.SetActive(false);
                BeginCooldown();
            }
        }

        private void AnnounceCountdown(int wholeSeconds)
        {
            if (wholeSeconds != _lastAnnouncedSecond)
            {
                _lastAnnouncedSecond = wholeSeconds;
                EventBus.Publish(new GlobalEventWarningEvent(EventName, wholeSeconds));
            }
        }

        // ------------------------------------------------------------------
        // Fábrica de primitivas reutilizadas (nascem uma vez, escondidas).
        // ------------------------------------------------------------------
        private Transform CreateDisc(string name, Color color)
        {
            Transform disc = CreatePrimitive(PrimitiveType.Cylinder, name, color);
            return disc;
        }

        // Instância única do modelo 3D, escondida entre eventos (pooling).
        private Transform CreateFromModel(GameObject model, string name)
        {
            GameObject instance = Instantiate(model);
            instance.name = name;

            foreach (Collider collider in instance.GetComponentsInChildren<Collider>())
            {
                Destroy(collider);
            }

            instance.SetActive(false);
            return instance.transform;
        }

        private Transform CreatePrimitive(PrimitiveType type, string name, Color color)
        {
            GameObject instance = GameObject.CreatePrimitive(type);
            instance.name = name;

            // Sem colisor: são efeitos visuais, não obstáculos (e não podem
            // confundir a sonda de terreno da gravidade).
            Destroy(instance.GetComponent<Collider>());

            var material = new Material(Shader.Find("Universal Render Pipeline/Unlit"))
            {
                color = color
            };
            instance.GetComponent<MeshRenderer>().material = material;

            instance.SetActive(false);
            return instance.transform;
        }

        private static void PlaceFlatOnSurface(
            Transform disc, Vector3 surfacePoint, Vector3 up, float diameter)
        {
            disc.position = surfacePoint + up * 0.25f;
            disc.rotation = Quaternion.FromToRotation(Vector3.up, up);
            disc.localScale = new Vector3(diameter, 0.15f, diameter);
        }
    }
}
