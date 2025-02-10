import NIOHTTP1

@main
struct Test {
    static func main() async throws {

        let config: Configuration = Configuration(ip: "127.0.0.1", port: 7000)

        let _defaultHeaders = [
            ("host", "\(config.ip):\(config.port)"),
            ("user-agent", Consts.userAgent),
        ]
        /// These are the default headers that must be sent along an invocation
        let defaultHeaders = HTTPHeaders(_defaultHeaders)

        /// These headers must be sent along an invocation or initialization error report
        let errorHeaders = HTTPHeaders(
            _defaultHeaders + [
                ("lambda-runtime-function-error-type", "Unhandled")
            ]
        )
        /// These headers must be sent when streaming a response
        let streamingHeaders = HTTPHeaders(
            _defaultHeaders + [
                ("transfer-encoding", "chunked")
            ]
        )

        var task: Task<String, any Error>!
        var client: HTTPClient!

        client = HTTPClient(config: config)  //, continuation: continuation)
        task = Task {
            do {
                // FIXME : return an async sequence of responses, then invoke the user lambda function handler, then post the response or the error 
                return try await client.repeatSendingUntilCancelled("/next", headers: defaultHeaders)
/*
                for invocation in try await client.repeatSendingUntilCancelled("/next", headers: defaultHeaders) {
                    print("invocation: \(invocation)")
                    let response = try await body(payload)
                    print("response: \(response)")
                    let result = try await client.sendResponse(response, headers: defaultHeaders)
                    print("result: \(result)")
                }
*/                
            } catch {
                print("client sent an error: \(error)")
                throw error
            }
        }

        try await Task.sleep(nanoseconds: 500_000_000)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in

            // 30% chance of cancellation
            print("With checked continuation")
            if Double.random(in: 0...1) < 0.5 {
                print("initiating a cancel")
                task.cancel()
                continuation.resume()
            } else {
                print("initiating a gracefull shutdown")
                client.syncShutdownGracefully(continuation: continuation)
            }
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        print("done")

    }
}
