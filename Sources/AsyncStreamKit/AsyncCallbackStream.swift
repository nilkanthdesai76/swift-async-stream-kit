import Foundation

final class TeardownBox: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable () -> Void)?
    private var isTerminated = false

    func set(_ handler: (@Sendable () -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
        if isTerminated {
            handler?()
            self.handler = nil
        }
    }

    func terminate() {
        lock.lock()
        defer { lock.unlock() }
        isTerminated = true
        handler?()
        handler = nil
    }
}

/// Utilities for bridging legacy closure, delegate, and observer callbacks into Swift `AsyncStream`.
public enum AsyncCallbackStream {
    /// Creates an `AsyncStream` from a callback producer block with automatic cancellation handling.
    ///
    /// ```swift
    /// let stream = AsyncCallbackStream.makeStream(of: LocationUpdate.self) { continuation in
    ///     let token = locationService.onLocationUpdate { location in
    ///         continuation.yield(location)
    ///     }
    ///     return { locationService.removeObserver(token) }
    /// }
    /// ```
    public static func makeStream<Element: Sendable>(
        of type: Element.Type = Element.self,
        bufferingPolicy limit: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded,
        producer: @Sendable @escaping (AsyncStream<Element>.Continuation) -> (@Sendable () -> Void)?
    ) -> AsyncStream<Element> {
        AsyncStream(Element.self, bufferingPolicy: limit) { continuation in
            let teardownBox = TeardownBox()
            continuation.onTermination = { _ in
                teardownBox.terminate()
            }
            let teardown = producer(continuation)
            teardownBox.set(teardown)
        }
    }
}

/// Utilities for bridging legacy throwing callback patterns into Swift `AsyncThrowingStream`.
public enum AsyncThrowingCallbackStream {
    /// Creates an `AsyncThrowingStream` from a callback producer block with automatic cancellation handling.
    ///
    /// ```swift
    /// let stream = AsyncThrowingCallbackStream.makeStream(of: Data.self) { continuation in
    ///     let session = startSocket { data, error in
    ///         if let error = error {
    ///             continuation.finish(throwing: error)
    ///         } else if let data = data {
    ///             continuation.yield(data)
    ///         }
    ///     }
    ///     return { session.disconnect() }
    /// }
    /// ```
    public static func makeStream<Element: Sendable>(
        of type: Element.Type = Element.self,
        bufferingPolicy limit: AsyncThrowingStream<Element, Error>.Continuation.BufferingPolicy = .unbounded,
        producer: @Sendable @escaping (AsyncThrowingStream<Element, Error>.Continuation) -> (@Sendable () -> Void)?
    ) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream(Element.self, bufferingPolicy: limit) { continuation in
            let teardownBox = TeardownBox()
            continuation.onTermination = { _ in
                teardownBox.terminate()
            }
            let teardown = producer(continuation)
            teardownBox.set(teardown)
        }
    }
}
