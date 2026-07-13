namespace Terraforge.Core
{
    /// <summary>
    /// Valor de direção vindo da interface de toque. O Core mantém apenas o
    /// dado; Gameplay e UI continuam sem dependência direta entre si.
    /// </summary>
    public static class TouchSteering
    {
        public static float Value { get; private set; }
        public static bool IsActive { get; private set; }
        public static bool IsUiPointerHeld { get; private set; }
        public static UnityEngine.Vector2 Origin { get; private set; }
        public static UnityEngine.Vector2 KnobOffset { get; private set; }

        public static void Begin(UnityEngine.Vector2 origin)
        {
            IsActive = true;
            Origin = origin;
            KnobOffset = UnityEngine.Vector2.zero;
            Value = 0f;
        }

        public static void Set(float value, UnityEngine.Vector2 knobOffset)
        {
            Value = UnityEngine.Mathf.Clamp(value, -1f, 1f);
            KnobOffset = knobOffset;
        }

        public static void SetUiPointerHeld(bool held)
        {
            IsUiPointerHeld = held;
            if (held)
            {
                Clear();
            }
        }

        public static void Clear()
        {
            Value = 0f;
            IsActive = false;
            KnobOffset = UnityEngine.Vector2.zero;
        }
    }
}
