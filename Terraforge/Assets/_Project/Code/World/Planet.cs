using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// O planeta do Terraforge. No protótipo é uma esfera simples; no futuro,
    /// este componente será a porta de entrada para territórios, biomas e clima.
    /// </summary>
    public sealed class Planet : MonoBehaviour, IPlanet
    {
        public Vector3 Center => transform.position;

        // A esfera primitiva da Unity tem 1 unidade de diâmetro,
        // portanto o raio real é metade da escala do objeto.
        public float Radius => transform.lossyScale.x * 0.5f;

        private void Awake()
        {
            PlanetLocator.Register(this);
        }

        private void OnDestroy()
        {
            PlanetLocator.Unregister(this);
        }
    }
}
