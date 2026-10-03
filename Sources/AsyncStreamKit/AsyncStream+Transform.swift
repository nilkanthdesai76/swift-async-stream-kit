import Foundation

public extension AsyncStream {
    /// Debounces the stream by postponing emission until after a quiet period of inactivity has passed.
    func debounced(by quietPeriod: TimeInterval) -> AsyncStream<Element> where Element: Sendable {
        AsyncStream { continuation in
            let streamTask = Task {
                var debounceTask: Task<Void, Never>?
                for await element in self {
                    debounceTask?.cancel()
                    debounceTask = Task {
                        do {
                            try await Task.sleep(nanoseconds: UInt64(quietPeriod * 1_000_000_000))
                            if !Task.isCancelled {
                                continuation.yield(element)
                            }
                        } catch {
                            // Cancelled
                        }
                    }
                }
                _ = await debounceTask?.result
                continuation.finish()
            }

            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }

    /// Throttles the stream by emitting at most once within every specified time interval.
    func throttled(by interval: TimeInterval) -> AsyncStream<Element> where Element: Sendable {
        AsyncStream { continuation in
            let streamTask = Task {
                var lastFire: Date?
                for await element in self {
                    let now = Date()
                    if let last = lastFire {
                        if now.timeIntervalSince(last) >= interval {
                            lastFire = now
                            continuation.yield(element)
                        }
                    } else {
                        lastFire = now
                        continuation.yield(element)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }
}
