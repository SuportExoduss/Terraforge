using UnityEngine;

namespace Terraforge.Core
{
    /// <summary>Arrasto sobre o minimapa expandido (DD-104), em pixels do frame.</summary>
    public readonly struct MinimapDragEvent : IGameEvent
    {
        public readonly Vector2 DeltaPixels;

        public MinimapDragEvent(Vector2 deltaPixels)
        {
            DeltaPixels = deltaPixels;
        }
    }
}
