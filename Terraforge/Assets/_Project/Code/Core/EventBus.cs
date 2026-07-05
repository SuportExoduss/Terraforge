using System;
using System.Collections.Generic;

namespace Terraforge.Core
{
    /// <summary>
    /// Correio interno do jogo (DD-053/DD-054): módulos publicam eventos e
    /// assinam eventos sem conhecerem uns aos outros. Nenhum módulo referencia
    /// outro diretamente — todos conversam apenas por aqui.
    /// </summary>
    public static class EventBus
    {
        private static readonly Dictionary<Type, List<Delegate>> _subscribers = new();

        /// <summary>Registra interesse em receber eventos do tipo T.</summary>
        public static void Subscribe<T>(Action<T> handler) where T : IGameEvent
        {
            if (!_subscribers.TryGetValue(typeof(T), out List<Delegate> handlers))
            {
                handlers = new List<Delegate>();
                _subscribers[typeof(T)] = handlers;
            }

            handlers.Add(handler);
        }

        /// <summary>Cancela um registro feito com Subscribe.</summary>
        public static void Unsubscribe<T>(Action<T> handler) where T : IGameEvent
        {
            if (_subscribers.TryGetValue(typeof(T), out List<Delegate> handlers))
            {
                handlers.Remove(handler);
            }
        }

        /// <summary>Anuncia um evento a todos os assinantes do tipo T.</summary>
        public static void Publish<T>(T gameEvent) where T : IGameEvent
        {
            if (!_subscribers.TryGetValue(typeof(T), out List<Delegate> handlers))
            {
                return;
            }

            // Cópia defensiva: um assinante pode se desinscrever enquanto o
            // evento é entregue, o que alteraria a lista no meio do percurso.
            Delegate[] snapshot = handlers.ToArray();
            foreach (Delegate handler in snapshot)
            {
                ((Action<T>)handler).Invoke(gameEvent);
            }
        }

        /// <summary>Esvazia todos os registros (usado ao encerrar uma partida).</summary>
        public static void Clear()
        {
            _subscribers.Clear();
        }
    }
}
