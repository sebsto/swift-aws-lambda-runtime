/// A shared data structure to store the current invocation requests.
/// The iterator never yield control and infinitively waits for a next message to process

/// This data structure is shared between instances of the HTTPHandler
/// (one instance to serve requests from the Lambda function and one instance to serve requests from the client invoking the lambda function).

import Synchronization
import NIOCore

//TODO: switch to package
public final class Pool<T>: AsyncSequence, AsyncIteratorProtocol, Sendable where T: Sendable {
    public typealias Element = T
    public init() {}

    private let _buffer = Mutex<CircularBuffer<T>>(.init())
    private let _continuation = Mutex<CheckedContinuation<T, any Error>?>(nil)
    
    /// retrieve the first element from the buffer
    public func popFirst() async -> T? {
        self._buffer.withLock { $0.popFirst() }
    }

    /// enqueue an element, or give it back immediately to the iterator if it is waiting for an element
    public func push(_ invocation: T) {
        // if the iterator is waiting for an element, give it to it
        // otherwise, enqueue the element
        if let continuation = self._continuation.withLock({ $0 }) {
            self._continuation.withLock { $0 = nil }
            continuation.resume(returning: invocation)
        } else {
            self._buffer.withLock { $0.append(invocation) }
        }
    }

    public func next() async throws -> T? {

        // exit the async for loop if the task is cancelled
        guard !Task.isCancelled else {
            return nil
        }

        if let element = await self.popFirst() {
            return element
        } else {

            // we can't return nil if there is nothing to dequeue otherwise the async for loop will stop
            // wait for an element to be enqueued
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                // store the continuation for later, when an element is enqueued
                //FIXME: when a continuation is already stored, we must call continuation.resume(throwing: error)
                self._continuation.withLock {
                    if $0 != nil {
                        $0!.resume(throwing: PoolError.nextAlreadyCalled)
                    }
                    $0 = continuation

                }
            }
        }
    }

    public func makeAsyncIterator() -> Pool {
        self
    }
}

//TODO: switch to package
public enum PoolError: Error {
    case nextAlreadyCalled
}
