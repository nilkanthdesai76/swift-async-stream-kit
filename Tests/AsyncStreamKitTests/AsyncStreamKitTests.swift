import XCTest
@testable import AsyncStreamKit

final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag: Bool = false

    func mark() {
        lock.lock()
        defer { lock.unlock() }
        flag = true
    }

    var isMarked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }
}

final class AsyncStreamKitTests: XCTestCase {
    func testCallbackStreamYieldAndTeardown() async {
        let flag = AtomicFlag()

        let stream = AsyncCallbackStream.makeStream(of: Int.self) { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish()
            return {
                flag.mark()
            }
        }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        XCTAssertEqual(results, [1, 2])
        // Allow brief moment for termination handler if dispatched asynchronously
        for _ in 0..<10 {
            if flag.isMarked { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(flag.isMarked)
    }

    func testThrowingCallbackStreamError() async {
        struct TestError: Error, Equatable {}

        let stream = AsyncThrowingCallbackStream.makeStream(of: String.self) { continuation in
            continuation.yield("Alpha")
            continuation.finish(throwing: TestError())
            return nil
        }

        var collected: [String] = []
        do {
            for try await item in stream {
                collected.append(item)
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
            XCTAssertEqual(collected, ["Alpha"])
        }
    }

    func testMulticastStreamFanOut() async {
        let hub = AsyncMulticastStream<String>()

        let stream1 = await hub.subscribe()
        let stream2 = await hub.subscribe()

        let count = await hub.subscriberCount
        XCTAssertEqual(count, 2)

        async let task1: [String] = {
            var items: [String] = []
            for await val in stream1 {
                items.append(val)
            }
            return items
        }()

        async let task2: [String] = {
            var items: [String] = []
            for await val in stream2 {
                items.append(val)
            }
            return items
        }()

        await hub.broadcast("Ping")
        await hub.broadcast("Pong")
        await hub.finish()

        let res1 = await task1
        let res2 = await task2

        XCTAssertEqual(res1, ["Ping", "Pong"])
        XCTAssertEqual(res2, ["Ping", "Pong"])

        let finalCount = await hub.subscriberCount
        XCTAssertEqual(finalCount, 0)
    }

    func testThrottledStream() async {
        let (rawStream, continuation) = AsyncStream.makeStream(of: Int.self)

        let throttled = rawStream.throttled(by: 0.05)

        async let consumer: [Int] = {
            var items: [Int] = []
            for await item in throttled {
                items.append(item)
            }
            return items
        }()

        // Fire 4 items rapidly without delay
        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)
        continuation.yield(4)
        continuation.finish()

        let collected = await consumer
        XCTAssertFalse(collected.isEmpty)
        XCTAssertEqual(collected.first, 1)
        XCTAssertLessThanOrEqual(collected.count, 2)
    }
}
