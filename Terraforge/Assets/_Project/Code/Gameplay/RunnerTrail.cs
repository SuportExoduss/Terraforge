using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// O rastro do corredor (SYS-001): existe apenas FORA do território do
    /// jogador (base inicial + tudo que já foi conquistado). Sair do domínio
    /// inicia a gravação; retornar a qualquer parte dele fecha o circuito,
    /// anuncia TerritoryLoopClosedEvent no EventBus e limpa a trilha.
    /// A LISTA é o dado de jogo; a linha é apenas a projeção visual dela.
    /// </summary>
    [RequireComponent(typeof(LineRenderer))]
    public sealed class RunnerTrail : MonoBehaviour
    {
        [SerializeField] private Material _trailMaterial;

        // Espaçamento entre pontos gravados: menor = curva mais fiel, porém
        // mais pontos para processar. 1.5 equilibra bem no raio atual.
        [SerializeField] private float _pointSpacing = 1.5f;
        [SerializeField] private float _width = 0.8f;

        // Levanta a linha um tiquinho do chão para não "brigar" com a
        // superfície da esfera (efeito zebrado chamado z-fighting).
        [SerializeField] private float _surfaceOffset = 0.15f;

        // Um circuito precisa de pelo menos um triângulo para cercar área.
        private const int MinPointsForLoop = 3;

        private readonly List<Vector3> _points = new();
        private LineRenderer _line;
        private Civilization _civilization;
        private bool _wasInsideOwnedTerritory = true;

        /// <summary>Os pontos do rastro, para os sistemas de circuito e corte.</summary>
        public IReadOnlyList<Vector3> Points => _points;

        private void Awake()
        {
            _civilization = GetComponent<Civilization>();
            if (_civilization == null)
            {
                Debug.LogError($"[RunnerTrail] {name} precisa do crachá Civilization.");
                enabled = false;
            }

            _line = GetComponent<LineRenderer>();
            _line.useWorldSpace = true;
            _line.startWidth = _width;
            _line.endWidth = _width;
            _line.material = _trailMaterial;
            _line.positionCount = 0;
        }

        private void Update()
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return;
            }

            ITerritoryOwnership territory = TerritoryOwnershipLocator.Current;
            bool insideOwned =
                territory != null && territory.IsOwnedBy(_civilization.Id, transform.position);

            if (insideOwned)
            {
                bool closedLoop = !_wasInsideOwnedTerritory && _points.Count >= MinPointsForLoop;
                if (closedLoop)
                {
                    // Cópia da lista: o rastro é limpo em seguida, mas quem
                    // recebeu o evento precisa dos pontos intactos.
                    EventBus.Publish(
                        new TerritoryLoopClosedEvent(_civilization.Id, new List<Vector3>(_points)));
                }

                if (_points.Count > 0)
                {
                    ClearTrail();
                }
            }
            else
            {
                RecordPointIfFarEnough(GetFootPointOnSurface(planet));
            }

            _wasInsideOwnedTerritory = insideOwned;
        }

        private void RecordPointIfFarEnough(Vector3 surfacePoint)
        {
            bool farEnoughFromLast =
                _points.Count == 0 ||
                Vector3.Distance(_points[^1], surfacePoint) >= _pointSpacing;

            if (farEnoughFromLast)
            {
                _points.Add(surfacePoint);
                _line.positionCount = _points.Count;
                _line.SetPosition(_points.Count - 1, surfacePoint);
            }
        }

        private void ClearTrail()
        {
            _points.Clear();
            _line.positionCount = 0;
        }

        private Vector3 GetFootPointOnSurface(IPlanet planet)
        {
            Vector3 up = (transform.position - planet.Center).normalized;
            return planet.Center + up * (planet.Radius + _surfaceOffset);
        }
    }
}
