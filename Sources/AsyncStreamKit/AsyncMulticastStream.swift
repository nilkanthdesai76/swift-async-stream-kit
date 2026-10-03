import Foundation

/// A thread-safe, multicast broadcasting hub for Swift Concurrency.
///
/// In standard Swift Concurrency, an `AsyncStream` can only be iterated by a single consumer.
/// `AsyncMulticastStream` allows any number of concurrent tasks to subscribe and receive broadcasted elements.
public actor AsyncMulticastStream<Element: Sendable> {
    private var subscribers: [UUID: AsyncStream<Element>.Continuation] = [:]
    private var isFinished: Bool = false

    public init() {}

    /// Subscribes to the broadcast stream, returning a dedicated `AsyncStream` for the caller.
    /// When the caller cancels their consumption task, the subscription is automatically cleaned up.
    public func subscribe(
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Element> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            if isFinished {
                continuation.finish()
                return
            }

            subscribers[id] = continuation

            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeSubscriber(id: id)
                }
            }
        }
    }

    /// Broadcasts an element to all currently active subscribers.
    public func broadcast(_ element: Element) {
        guard !isFinished else { return }
        for continuation in subscribers.values {
            continuation.yield(element)
        }
    }

    /// Finishes all active streams and closes the multicast hub.
    public func finish() {
        guard !isFinished else { return }
        isFinished = true
        for continuation in subscribers.values {
            continuation.finish()
        }
        subscribers.removeAll()
    }

    /// Current number of active subscribers.
    public var subscriberCount: Int {
        subscribers.count
    }

    private func removeSubscriber(id: UUID) {
        subscribers.removeValue(forKey: id)
    }
}
