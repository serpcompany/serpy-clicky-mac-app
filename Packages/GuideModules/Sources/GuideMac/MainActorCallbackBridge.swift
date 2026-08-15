import Foundation

/// Creates callbacks in a nonisolated context, then explicitly hops delivered
/// values to the main actor. This avoids Swift 6 executor traps when Apple
/// frameworks invoke a callback on an audio or service queue.
public enum MainActorCallbackBridge {
    public nonisolated static func make<Value: Sendable>(
        _ handler: @escaping @MainActor @Sendable (Value) -> Void
    ) -> @Sendable (Value) -> Void {
        { value in
            Task { @MainActor in
                handler(value)
            }
        }
    }
}
