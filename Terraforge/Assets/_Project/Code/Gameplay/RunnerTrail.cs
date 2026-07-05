using System.Collections.Generic;
using Terraforge.Core;
using UnityEngine;

namespace Terraforge.Gameplay
{
    /// <summary>
    /// O rastro do corredor (base do SYS-001): registra os pontos da superfície
    /// por onde o personagem passou e os desenha como uma linha colada ao chão.
    /// A LISTA é o dado de jogo (fechamento de circuito, corte por inimigos);
    /// a linha é apenas a projeção visual dela.
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

        private readonly List<Vector3> _points = new();
        private LineRenderer _line;

        /// <summary>Os pontos do rastro, para os sistemas de circuito e corte.</summary>
        public IReadOnlyList<Vector3> Points => _points;

        private void Awake()
        {
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

            Vector3 surfacePoint = GetFootPointOnSurface(planet);

            bool farEnoughFromLast =
                _points.Count == 0 ||
                Vector3.Distance(_points[^1], surfacePoint) >= _pointSpacing;

            if (farEnoughFromLast)
            {
                AddPoint(surfacePoint);
            }
        }

        private Vector3 GetFootPointOnSurface(IPlanet planet)
        {
            Vector3 up = (transform.position - planet.Center).normalized;
            return planet.Center + up * (planet.Radius + _surfaceOffset);
        }

        private void AddPoint(Vector3 point)
        {
            _points.Add(point);
            _line.positionCount = _points.Count;
            _line.SetPosition(_points.Count - 1, point);
        }
    }
}
