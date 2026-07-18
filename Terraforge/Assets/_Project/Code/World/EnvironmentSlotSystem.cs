using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// Fase 3 do PLS — os Slots Ambientais (DD-110/DD-114/DD-120/DD-122).
    ///
    /// No início da partida o planeta sorteia centenas de POSIÇÕES fixas
    /// (a seed da rodada), cada uma com uma categoria (E01–E12). Todas
    /// nascem INVISÍVEIS: sem render, sem colisão — o planeta neutro é
    /// pelado. Quando o chão de um slot muda de dono, o slot REVELA o
    /// equivalente da civilização dona (cacto do cowboy, cristal do
    /// alien...), nascendo do chão organicamente; se o dono morre, revela
    /// o gêmeo morto (DD-122; sem gêmeo, a versão viva escurecida).
    /// Troca de dono = troca de conteúdo, via pooling. O código nunca
    /// pergunta "qual objeto?" — só "qual asset ocupa este slot?".
    /// </summary>
    public sealed class EnvironmentSlotSystem : MonoBehaviour
    {
        // Auto-instalação: nasce sozinho na carga da cena — nenhum passo
        // de Inspector para o Diretor.
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Install()
        {
            if (FindAnyObjectByType<EnvironmentSlotSystem>() == null)
            {
                new GameObject("EnvironmentSlots").AddComponent<EnvironmentSlotSystem>();
            }
        }

        // Quantos slots o planeta sorteia e o ritmo da vigia de posse.
        // 720 posições com varredura de 12/frame = planeta inteiro
        // conferido a cada ~1s, custo desprezível.
        private const int SlotCount = 720;
        private const int ChecksPerFrame = 12;
        private const float MinSlotDistance = 5f;
        private const float GrowSeconds = 0.9f; // DD-117: nascimento orgânico

        private struct Slot
        {
            public Vector3 Direction;
            public SlotCategory Category;
            public float DensityRoll;   // sorteio fixo: decide se o bioma o usa
            public float Yaw;
            public float ScaleJitter;
            public byte Owner;
            public bool Dead;
            public GameObject Instance;
            public GameObject ShownPrefab;
            public float TargetScale;
            public float RevealClock;
        }

        // O catálogo das categorias: proporção no sorteio e ALTURA PADRÃO
        // no mundo — o modelo arrastado na ficha é normalizado para ela
        // ("se posicione de forma padrão", pedido do Diretor).
        private static readonly (SlotCategory category, float weight, float height)[] Catalog =
        {
            (SlotCategory.VegetationTall, 0.20f, 4.0f),
            (SlotCategory.VegetationMedium, 0.24f, 2.2f),
            (SlotCategory.VegetationLow, 0.18f, 1.1f),
            (SlotCategory.RockLarge, 0.05f, 4.5f),
            (SlotCategory.RockSmall, 0.10f, 1.2f),
            (SlotCategory.StructureSmall, 0.05f, 1.6f),
            (SlotCategory.StructureMedium, 0.05f, 3.5f),
            (SlotCategory.StructureLarge, 0.03f, 6.5f),
            (SlotCategory.DecorationNatural, 0.03f, 1.4f),
            (SlotCategory.DecorationArtificial, 0.03f, 2.0f),
            (SlotCategory.Container, 0.03f, 1.5f),
            (SlotCategory.Landmark, 0.01f, 11f),
        };

        private readonly bool[] _deadCivilizations = new bool[17];
        private readonly Dictionary<GameObject, Stack<GameObject>> _pools = new();
        private readonly Dictionary<GameObject, float> _prefabScaleFactors = new();
        private readonly Dictionary<GameObject, Vector3> _prefabBaseScales = new();
        private readonly List<int> _growing = new();
        private Slot[] _slots;
        private TerritoryMap _map;
        private Transform _container;
        private int _cursor;

        private void Awake()
        {
            EventBus.Subscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<CivilizationEliminatedEvent>(OnEliminated);
        }

        // DD-122: a queda é notada pela varredura normal (em ~1s os slots
        // do morto trocam para o gêmeo morto).
        private void OnEliminated(CivilizationEliminatedEvent eliminatedEvent)
        {
            if (eliminatedEvent.OwnerId < _deadCivilizations.Length)
            {
                _deadCivilizations[eliminatedEvent.OwnerId] = true;
            }
        }

        private void Update()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            if (_slots == null)
            {
                _map = FindAnyObjectByType<TerritoryMap>();
                if (_map == null)
                {
                    return;
                }

                GenerateSlots(planet);
            }

            // A vigia de posse: cada frame confere uma fatia dos slots.
            for (int i = 0; i < ChecksPerFrame; i++)
            {
                _cursor = (_cursor + 1) % _slots.Length;
                RefreshSlot(_cursor, planet);
            }

            AnimateGrowth();
        }

        // ------------------------------------------------------------------
        // O sorteio da rodada: posições uniformes na esfera com distância
        // mínima entre si, categoria por peso, e os dados fixos do slot
        // (sorteio de densidade, giro, variação de tamanho).
        // ------------------------------------------------------------------
        private void GenerateSlots(IPlanet planet)
        {
            _slots = new Slot[SlotCount];
            _container = new GameObject("SlotInstances").transform;
            _container.SetParent(transform, worldPositionStays: false);

            float minDot = Mathf.Cos(MinSlotDistance / planet.Radius);
            int placed = 0;
            int attempts = 0;

            while (placed < SlotCount && attempts < SlotCount * 40)
            {
                attempts++;
                Vector3 direction = Random.onUnitSphere;

                bool tooClose = false;
                for (int i = 0; i < placed; i++)
                {
                    if (Vector3.Dot(_slots[i].Direction, direction) > minDot)
                    {
                        tooClose = true;
                        break;
                    }
                }

                if (tooClose)
                {
                    continue;
                }

                _slots[placed] = new Slot
                {
                    Direction = direction,
                    Category = PickCategory(),
                    DensityRoll = Random.value,
                    Yaw = Random.Range(0f, 360f),
                    ScaleJitter = Random.Range(0.85f, 1.2f),
                };
                placed++;
            }

            if (placed < SlotCount)
            {
                System.Array.Resize(ref _slots, placed);
            }

            Debug.Log($"[World] {placed} Slots Ambientais sorteados (invisíveis) — " +
                      "o planeta neutro está pré-configurado (DD-110).");
        }

        private static SlotCategory PickCategory()
        {
            float roll = Random.value;
            float accumulated = 0f;
            for (int i = 0; i < Catalog.Length; i++)
            {
                accumulated += Catalog[i].weight;
                if (roll <= accumulated)
                {
                    return Catalog[i].category;
                }
            }

            return Catalog[^1].category;
        }

        private static float StandardHeight(SlotCategory category)
        {
            for (int i = 0; i < Catalog.Length; i++)
            {
                if (Catalog[i].category == category)
                {
                    return Catalog[i].height;
                }
            }

            return 2f;
        }

        // DD-118: o Biome DNA decide QUANTOS slots o bioma usa. O sorteio
        // fixo do slot torna a decisão estável e justa por civilização.
        private static float DensityFor(PlanetTheme theme, SlotCategory category)
        {
            return category switch
            {
                SlotCategory.VegetationTall or
                SlotCategory.VegetationMedium or
                SlotCategory.VegetationLow => theme.VegetationDensity,
                SlotCategory.RockLarge or
                SlotCategory.RockSmall => theme.RockDensity,
                SlotCategory.Landmark => 1f, // o ícone do bioma sempre aparece
                _ => 0.5f,
            };
        }

        // ------------------------------------------------------------------
        // A revelação: confere o dono do chão e troca o conteúdo se preciso.
        // ------------------------------------------------------------------
        private void RefreshSlot(int index, IPlanet planet)
        {
            ref Slot slot = ref _slots[index];
            Vector3 mathPosition = planet.Center + slot.Direction * planet.Radius;
            byte owner = _map.GetOwnerAt(mathPosition);
            bool dead = owner != 0 && _deadCivilizations[owner];

            if (owner == slot.Owner && dead == slot.Dead && slot.ShownPrefab != null == (slot.Instance != null))
            {
                return;
            }

            bool deadChanged = dead != slot.Dead;
            slot.Owner = owner;
            slot.Dead = dead;

            GameObject prefab = null;
            bool tintAsDead = false;
            if (owner != 0 && PlanetThemeRegistry.Current != null)
            {
                PlanetTheme theme = PlanetThemeRegistry.Current.Get(owner);
                if (theme != null)
                {
                    GameObject alive = theme.GetSlotAsset(slot.Category);
                    GameObject deadTwin = dead ? theme.GetDeadSlotAsset(slot.Category) : null;
                    prefab = dead ? (deadTwin != null ? deadTwin : alive) : alive;

                    // DD-122 (regra do vazio): morto sem gêmeo usa o modelo
                    // vivo escurecido.
                    tintAsDead = dead && deadTwin == null;

                    // O DNA poda: slot fora da densidade do bioma fica vazio.
                    if (prefab != null && slot.DensityRoll > DensityFor(theme, slot.Category))
                    {
                        prefab = null;
                    }
                }
            }

            bool sameLook = prefab == slot.ShownPrefab &&
                            (prefab == null || slot.Instance != null);
            if (sameLook)
            {
                // Mesmo modelo — mas se a civilização acabou de morrer (ou
                // a ruína caiu), o tingimento precisa acompanhar.
                if (deadChanged && slot.Instance != null)
                {
                    if (tintAsDead)
                    {
                        TintDead(slot.Instance);
                    }
                    else
                    {
                        ClearTint(slot.Instance);
                    }
                }

                return;
            }

            ReturnInstance(ref slot);
            slot.ShownPrefab = prefab;
            if (prefab == null)
            {
                return;
            }

            RevealInstance(ref slot, index, planet, prefab, tintAsDead);
        }

        private void RevealInstance(
            ref Slot slot, int index, IPlanet planet, GameObject prefab, bool tintAsDead)
        {
            GameObject instance = RentInstance(prefab);
            slot.Instance = instance;

            // Pose padrão automática: pés no relevo REAL (inclusive a
            // camada de areia, DD-121), "em pé" na esfera, giro sorteado.
            Vector3 up = slot.Direction;
            float surfaceRadius = planet.GetSurfaceRadius(up);
            instance.transform.SetPositionAndRotation(
                planet.Center + up * surfaceRadius,
                Quaternion.AngleAxis(slot.Yaw, up) * Quaternion.FromToRotation(Vector3.up, up));

            // Escala normalizada: qualquer modelo arrastado na ficha nasce
            // com a altura padrão da categoria.
            float factor = _prefabScaleFactors[prefab] * slot.ScaleJitter;
            slot.TargetScale = factor;
            instance.transform.localScale = _prefabBaseScales[prefab] * (factor * 0.01f);

            // DD-122 (regra do vazio): morto usando o modelo VIVO é escurecido.
            if (tintAsDead)
            {
                TintDead(instance);
            }

            slot.RevealClock = 0f;
            if (!_growing.Contains(index))
            {
                _growing.Add(index);
            }
        }

        // Nascimento orgânico (DD-117): o objeto CRESCE do chão em ~0,9s.
        private void AnimateGrowth()
        {
            for (int i = _growing.Count - 1; i >= 0; i--)
            {
                int index = _growing[i];
                ref Slot slot = ref _slots[index];
                if (slot.Instance == null)
                {
                    _growing.RemoveAt(i);
                    continue;
                }

                slot.RevealClock += Time.deltaTime;
                float progress = Mathf.Clamp01(slot.RevealClock / GrowSeconds);
                float smooth = progress * progress * (3f - 2f * progress);
                slot.Instance.transform.localScale =
                    _prefabBaseScales[slot.ShownPrefab] *
                    Mathf.Max(0.01f, slot.TargetScale * smooth);

                if (progress >= 1f)
                {
                    _growing.RemoveAt(i);
                }
            }
        }

        // ------------------------------------------------------------------
        // Pooling (DD-114): instâncias voltam para a piscina em vez de
        // morrer; trocas de dono reutilizam objetos existentes.
        // ------------------------------------------------------------------
        private GameObject RentInstance(GameObject prefab)
        {
            if (_pools.TryGetValue(prefab, out Stack<GameObject> pool) && pool.Count > 0)
            {
                GameObject pooled = pool.Pop();
                pooled.SetActive(true);
                ClearTint(pooled);
                return pooled;
            }

            GameObject instance = Instantiate(prefab, _container);
            foreach (Collider collider in instance.GetComponentsInChildren<Collider>())
            {
                Destroy(collider); // slot não colide (GDMD: sem colisão)
            }

            MeasurePrefab(prefab, instance);
            return instance;
        }

        private void ReturnInstance(ref Slot slot)
        {
            if (slot.Instance == null)
            {
                return;
            }

            slot.Instance.SetActive(false);
            GameObject prefab = slot.ShownPrefab;
            if (prefab != null)
            {
                if (!_pools.TryGetValue(prefab, out Stack<GameObject> pool))
                {
                    pool = new Stack<GameObject>();
                    _pools[prefab] = pool;
                }

                pool.Push(slot.Instance);
            }

            slot.Instance = null;
            slot.ShownPrefab = null;
        }

        // Mede o modelo UMA vez para descobrir o fator que o leva à altura
        // padrão da categoria — modelos de qualquer tamanho pousam certos.
        private void MeasurePrefab(GameObject prefab, GameObject instance)
        {
            if (_prefabScaleFactors.ContainsKey(prefab))
            {
                return;
            }

            _prefabBaseScales[prefab] = instance.transform.localScale;
            instance.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);

            var renderers = instance.GetComponentsInChildren<Renderer>();
            var bounds = new Bounds(Vector3.zero, Vector3.zero);
            bool started = false;
            foreach (Renderer instanceRenderer in renderers)
            {
                if (!started)
                {
                    bounds = instanceRenderer.bounds;
                    started = true;
                }
                else
                {
                    bounds.Encapsulate(instanceRenderer.bounds);
                }
            }

            float height = Mathf.Max(0.05f, bounds.size.y);

            // A altura padrão da categoria de MAIOR uso deste prefab seria o
            // ideal; na prática o prefab pertence a uma categoria só.
            float target = 2f;
            foreach (Slot slot in _slots)
            {
                if (slot.ShownPrefab == prefab)
                {
                    target = StandardHeight(slot.Category);
                    break;
                }
            }

            _prefabScaleFactors[prefab] = target / height;
        }

        // Escurecimento do "morto sem gêmeo" (DD-122): tinge os materiais
        // via PropertyBlock (sem clonar materiais — leve).
        private static void TintDead(GameObject instance)
        {
            var block = new MaterialPropertyBlock();
            var deadColor = new Color(0.38f, 0.36f, 0.34f, 1f);
            foreach (Renderer instanceRenderer in instance.GetComponentsInChildren<Renderer>())
            {
                instanceRenderer.GetPropertyBlock(block);
                block.SetColor("_BaseColor", deadColor);
                block.SetColor("baseColorFactor", deadColor);
                instanceRenderer.SetPropertyBlock(block);
            }
        }

        private static void ClearTint(GameObject instance)
        {
            foreach (Renderer instanceRenderer in instance.GetComponentsInChildren<Renderer>())
            {
                instanceRenderer.SetPropertyBlock(null);
            }
        }
    }
}
