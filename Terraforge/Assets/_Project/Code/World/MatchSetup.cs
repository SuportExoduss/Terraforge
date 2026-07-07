using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// DD-095: no início da partida, sorteia a posição das bases (e leva
    /// junto seus corredores) para pontos aleatórios e bem afastados do
    /// planeta. Roda no Awake — antes de HomeTerritory registrar a calota
    /// e de os corredores se colarem à superfície (ambos no Start).
    /// </summary>
    public sealed class MatchSetup : MonoBehaviour
    {
        [System.Serializable]
        private struct SpawnEntry
        {
            public Transform HomeBase;
            public Transform Runner;
        }

        [SerializeField] private SpawnEntry[] _spawns;

        // Separação angular mínima entre bases (graus vistos do centro):
        // 90° = pelo menos um quarto de volta de distância.
        [SerializeField] private float _minSeparationDegrees = 90f;

        private readonly HashSet<byte> _landedCivilizations = new();
        private bool _matchStarted;

        // DD-096: o GO! sai quando TODAS as naves da abertura pousaram.
        private void OnBaseLanded(BaseRelocatedEvent landedEvent)
        {
            if (_matchStarted)
            {
                return;
            }

            _landedCivilizations.Add(landedEvent.OwnerId);
            if (_landedCivilizations.Count >= _spawns.Length)
            {
                _matchStarted = true;
                EventBus.Publish(new MatchStartedEvent());
                Debug.Log("[World] GO! Todas as naves pousaram — partida iniciada.");
            }
        }

        private void OnDestroy()
        {
            EventBus.Unsubscribe<BaseRelocatedEvent>(OnBaseLanded);
        }

        // DD-095 revisado: abertura em formação de cubo — cada civilização
        // nasce em uma das 6 "faces" do planeta (±X, ±Y, ±Z). A ordem das
        // faces é embaralhada a cada partida; realocações posteriores
        // continuam 100% aleatórias (DD-100).
        private static readonly Vector3[] CubeFaceDirections =
        {
            Vector3.up, Vector3.down, Vector3.right,
            Vector3.left, Vector3.forward, Vector3.back
        };

        private void Awake()
        {
            EventBus.Subscribe<BaseRelocatedEvent>(OnBaseLanded);

            // Referência direta (mesmo módulo); o PlanetLocator ainda pode
            // não ter sido preenchido nesta ordem de Awake.
            Planet planet = FindAnyObjectByType<Planet>();
            if (planet == null || _spawns == null || _spawns.Length == 0)
            {
                Debug.LogError("[World] MatchSetup precisa do Planet na cena e de spawns configurados.");
                return;
            }

            Vector3 center = planet.Center;
            float radius = planet.Radius;
            var takenDirections = new List<Vector3>();

            // Embaralha as faces do cubo para variar quem nasce onde.
            var faces = new List<Vector3>(CubeFaceDirections);
            for (int i = faces.Count - 1; i > 0; i--)
            {
                int j = Random.Range(0, i + 1);
                (faces[i], faces[j]) = (faces[j], faces[i]);
            }

            for (int s = 0; s < _spawns.Length; s++)
            {
                SpawnEntry spawn = _spawns[s];

                // Até 6 civilizações: uma face do cubo para cada; acima
                // disso (futuro multiplayer), sorteio com separação mínima.
                Vector3 direction = s < faces.Count
                    ? faces[s]
                    : PickSeparatedDirection(takenDirections);
                takenDirections.Add(direction);

                Vector3 surfacePoint = center + direction * radius;
                if (spawn.HomeBase != null)
                {
                    spawn.HomeBase.position = surfacePoint;
                }

                if (spawn.Runner != null)
                {
                    // O corredor nasce sobre a própria base; o PlanetRunner
                    // ajusta a altura exata ao colar na superfície no Start.
                    spawn.Runner.position = surfacePoint;
                }
            }
        }

        private Vector3 PickSeparatedDirection(List<Vector3> takenDirections)
        {
            Vector3 candidate = Random.onUnitSphere;
            for (int attempt = 0; attempt < 64; attempt++)
            {
                candidate = Random.onUnitSphere;
                bool farFromAll = true;
                foreach (Vector3 taken in takenDirections)
                {
                    if (Vector3.Angle(candidate, taken) < _minSeparationDegrees)
                    {
                        farFromAll = false;
                        break;
                    }
                }

                if (farFromAll)
                {
                    return candidate;
                }
            }

            // Planeta lotado de bases (futuro multiplayer cheio): aceita o
            // último sorteio mesmo mais próximo que o ideal.
            return candidate;
        }
    }
}
