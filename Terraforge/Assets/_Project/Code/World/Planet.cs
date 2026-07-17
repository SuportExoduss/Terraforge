using Terraforge.Core;
using UnityEngine;

namespace Terraforge.World
{
    /// <summary>
    /// O planeta do Terraforge. A esfera matemática (raio = escala/2) rege
    /// territórios e órbitas; o TERRENO VISUAL (modelo filho) rege onde os
    /// pés tocam: GetSurfaceRadius sonda o relevo com um raio físico vindo
    /// do espaço, para ninguém flutuar sobre vales nem afundar em morros.
    /// </summary>
    public sealed class Planet : MonoBehaviour, IPlanet
    {
        private readonly RaycastHit[] _probeHits = new RaycastHit[8];
        private bool _hasVisualColliders;
        private TerritoryPainter _painter;

        public Vector3 Center => transform.position;

        // A esfera primitiva da Unity tem 1 unidade de diâmetro,
        // portanto o raio matemático é metade da escala do objeto.
        public float Radius => transform.lossyScale.x * 0.5f;

        private void Awake()
        {
            PlanetLocator.Register(this);
            PrepareVisualColliders();

            // A camada de bioma SOBE sobre o planeta (DD-121); o pintor
            // sabe a altura dela em cada ponto.
            _painter = GetComponent<TerritoryPainter>();
        }

        private void OnDestroy()
        {
            PlanetLocator.Unregister(this);
        }

        public float GetSurfaceRadius(Vector3 surfaceDirection)
        {
            // A camada do bioma dominado eleva o chão (afina até 0 na
            // borda) — quem pisa em areia, pisa POR CIMA dela.
            float elevation = _painter != null
                ? _painter.GetElevationAt(surfaceDirection)
                : 0f;

            if (!_hasVisualColliders)
            {
                return Radius + elevation;
            }

            // Sonda: um raio desce do espaço em direção ao centro; o primeiro
            // toque em algo DO PLANETA é a superfície real naquele ponto.
            Vector3 direction = surfaceDirection.normalized;
            float probeDistance = Radius * 1.5f;
            Vector3 origin = Center + direction * probeDistance;

            int hitCount = Physics.RaycastNonAlloc(
                origin, -direction, _probeHits, probeDistance,
                Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore);

            float highestRadius = -1f;
            for (int i = 0; i < hitCount; i++)
            {
                if (!_probeHits[i].collider.transform.IsChildOf(transform))
                {
                    continue;
                }

                float hitRadius = (_probeHits[i].point - Center).magnitude;
                if (hitRadius > highestRadius)
                {
                    highestRadius = hitRadius;
                }
            }

            return (highestRadius > 0f ? highestRadius : Radius) + elevation;
        }

        // O colisor esférico primitivo sai de cena; o modelo visual filho
        // ganha MeshColliders para servir de chão físico de verdade.
        private void PrepareVisualColliders()
        {
            if (TryGetComponent(out SphereCollider primitiveCollider))
            {
                primitiveCollider.enabled = false;
            }

            foreach (MeshFilter filter in GetComponentsInChildren<MeshFilter>())
            {
                if (filter.gameObject == gameObject)
                {
                    continue;
                }

                if (filter.GetComponent<MeshCollider>() == null)
                {
                    filter.gameObject.AddComponent<MeshCollider>();
                }

                _hasVisualColliders = true;
            }
        }
    }
}
