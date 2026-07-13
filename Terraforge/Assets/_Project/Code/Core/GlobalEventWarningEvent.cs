namespace Terraforge.Core
{
    /// <summary>
    /// Tique do aviso prévio de um evento global (DD-106): "METEORO... 5".
    /// SecondsRemaining 0 = o evento está acontecendo AGORA.
    /// </summary>
    public readonly struct GlobalEventWarningEvent : IGameEvent
    {
        public readonly string EventName;
        public readonly int SecondsRemaining;

        public GlobalEventWarningEvent(string eventName, int secondsRemaining)
        {
            EventName = eventName;
            SecondsRemaining = secondsRemaining;
        }
    }
}
