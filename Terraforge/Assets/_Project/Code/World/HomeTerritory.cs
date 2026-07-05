using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// O domo do território inicial: além do visual da base, registra a
    /// calota correspondente no TerritoryMap quando a partida começa —
    /// a partir daí, a posse é toda gerenciada pelo mapa de células.
    /// </summary>
    public sealed class HomeTerritory : MonoBehaviour
    {
        private void Start()
        {
            IPlanet planet = PlanetLocator.Current;

            // Busca única na inicialização (nunca em loops de frame);
            // referência direta permitida: TerritoryMap é do mesmo módulo.
            TerritoryMap map = FindAnyObjectByType<TerritoryMap>();

            if (planet == null || map == null)
            {
                Debug.LogError("[World] HomeTerritory requer Planet e TerritoryMap na cena.");
                return;
            }

            Vector3 capDirection = (transform.position - planet.Center).normalized;
            map.ClaimCap(capDirection, GetCapAngleDegrees(planet));
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
