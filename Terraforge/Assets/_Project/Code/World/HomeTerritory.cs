using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// Território inicial do jogador: um domo (esfera semi-enterrada) cuja
    /// área lógica na superfície é derivada do próprio tamanho visual —
    /// redimensionar o domo redimensiona o território automaticamente.
    /// </summary>
    public sealed class HomeTerritory : MonoBehaviour, IHomeTerritory
    {
        private void Awake()
        {
            HomeTerritoryLocator.Register(this);
            EventBus.Subscribe<TerritoryLoopClosedEvent>(OnLoopClosed);
        }

        private void OnDestroy()
        {
            HomeTerritoryLocator.Unregister(this);
            EventBus.Unsubscribe<TerritoryLoopClosedEvent>(OnLoopClosed);
        }

        public bool Contains(Vector3 worldPosition)
        {
            IPlanet planet = PlanetLocator.Current;
            if (planet == null)
            {
                return false;
            }

            Vector3 baseDirection = (transform.position - planet.Center).normalized;
            Vector3 pointDirection = (worldPosition - planet.Center).normalized;
            return Vector3.Angle(baseDirection, pointDirection) <= GetCapAngleDegrees(planet);
        }

        // Geometria do domo: uma esfera de raio r com centro na superfície de
        // um planeta de raio R cobre uma "calota" de meio-ângulo asin(r/R).
        private float GetCapAngleDegrees(IPlanet planet)
        {
            float domeRadius = transform.lossyScale.x * 0.5f;
            return Mathf.Asin(Mathf.Clamp01(domeRadius / planet.Radius)) * Mathf.Rad2Deg;
        }

        // Reação provisória: na Entrega 3, aqui nasce a conquista real da área.
        private void OnLoopClosed(TerritoryLoopClosedEvent loopEvent)
        {
            Debug.Log(
                $"[World] Circuito fechado com {loopEvent.TrailPoints.Count} pontos! " +
                "Área será conquistada na próxima entrega.");
        }
    }
}
