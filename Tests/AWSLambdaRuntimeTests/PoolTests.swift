import Testing
@testable import AWSLambdaRuntime

struct PoolTests {
    
    @Test
    func testBasicPushAndIteration() async throws {
        let pool = LambdaHTTPServer.Pool<String>()
        
        // Push values
        await pool.push("first")
        await pool.push("second")
        
        // Iterate and verify order
        var values = [String]()
        for try await value in pool {
            values.append(value)
            if values.count == 2 { break }
        }
        
        #expect(values == ["first", "second"])
    }
    
    @Test
    func testCancellation() async throws {
        let pool = LambdaHTTPServer.Pool<String>()
        
        // Create a task that will be cancelled
        let task = Task {
            for try await _ in pool {
                Issue.record("Should not receive any values after cancellation")
            }
        }
        
        // Cancel the task immediately
        task.cancel()
        
        // This should complete without receiving any values
        try await task.value
    }
    
    @Test
    func testConcurrentPushAndIteration() async throws {
        let pool = LambdaHTTPServer.Pool<Int>()
        let iterations = 1000
        var receivedValues = Set<Int>()
        
        // Start consumer task first
        let consumer = Task {
            var count = 0
            for try await value in pool {
                receivedValues.insert(value)
                count += 1
                if count >= iterations { break }
            }
        }
        
        // Create multiple producer tasks
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    await pool.push(i)
                }
            }
            try await group.waitForAll()
        }
        
        // Wait for consumer to complete
        try await consumer.value
        
        // Verify all values were received exactly once
        #expect(receivedValues.count == iterations)
        #expect(Set(0..<iterations) == receivedValues)
    }
    
    @Test
    func testPushToWaitingConsumer() async throws {
        let pool = LambdaHTTPServer.Pool<String>()
        let expectedValue = "test value"
        
        // Start a consumer that will wait for a value
        let consumer = Task {
            for try await value in pool {
                #expect(value == expectedValue)
                break
            }
        }
        
        // Give consumer time to start waiting
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Push a value
        await pool.push(expectedValue)
        
        // Wait for consumer to complete
        try await consumer.value
    }
    
    @Test
    func testStressTest() async throws {
        let pool = LambdaHTTPServer.Pool<Int>()
        let producerCount = 10
        let messagesPerProducer = 1000
        var receivedValues = [Int]()
        
        // Start consumer
        let consumer = Task {
            var count = 0
            for try await value in pool {
                receivedValues.append(value)
                count += 1
                if count >= producerCount * messagesPerProducer { break }
            }
        }
        
        // Create multiple producers
        try await withThrowingTaskGroup(of: Void.self) { group in
            for p in 0..<producerCount {
                group.addTask {
                    for i in 0..<messagesPerProducer {
                        await pool.push(p * messagesPerProducer + i)
                    }
                }
            }
            try await group.waitForAll()
        }
        
        // Wait for consumer to complete
        try await consumer.value
        
        // Verify we received all values
        #expect(receivedValues.count == producerCount * messagesPerProducer)
        #expect(Set(receivedValues).count == producerCount * messagesPerProducer)
    }
}