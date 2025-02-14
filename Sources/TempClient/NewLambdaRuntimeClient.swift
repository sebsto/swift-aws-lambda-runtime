import NIOCore
import NIOHTTP1
import Synchronization
import AWSLambdaRuntimeCore

@main
struct Test {
    static func main() async throws {



        let ip = "127.0.0.1"
        let port = 7000

        let _defaultHeaders = [
            ("host", "\(ip):\(port)"),
            ("user-agent", Consts.userAgent),
        ]
        /// These are the default headers that must be sent along an invocation
        let defaultHeaders = HTTPHeaders(_defaultHeaders)

        /// These headers must be sent along an invocation or initialization error report
        // let errorHeaders = HTTPHeaders(
        //     _defaultHeaders + [
        //         ("lambda-runtime-function-error-type", "Unhandled")
        //     ]
        // )
        /// These headers must be sent when streaming a response
        // let streamingHeaders = HTTPHeaders(
        //     _defaultHeaders + [
        //         ("transfer-encoding", "chunked")
        //     ]
        // )

        // this pool never releases control, it indifinitively waits for next invocation
        let invocations = Pool<Invocation>()

        // launch a client 
        let httpClientTask : Task<Void, any Error>! = Task {
            do {
                var client: HTTPClient!
                client = HTTPClient(ip: ip, port: port, invocations: invocations)
                try await client.repeatSendingUntilCancelled(Consts.getNextInvocationURLSuffix, headers: defaultHeaders)
            } catch {
                print("httpClientTask error : \(error)")
            }
        }

        // launch a reader
        let invocationTask : Task<Void, any Error>! = Task {
            do {
                // iterate over the invocations
                print("Wait for invocations")
                for try await invocation in invocations {
                    print("invocation: \(String(buffer: invocation.event)) metadata: \(invocation.metadata)")

                    //TODO: invoke the Lambda function
                    // try await Task.sleep(nanoseconds: 1_000_000)
                    let handlerResult = ByteBuffer(string: "Hello, world!")

                    // notify the HTTPClient that a response is ready to send
                    invocation.continuation.resume(returning: handlerResult)
                }
            } catch {
                print("invocationTask error : \(error)")
            }

        }

        // just for testing 
        // code below this line should not be moved to the library 

        print("client and reader launched, waiting 5 secs")
        try await Task.sleep(for: .seconds(5))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in

            // 30% chance of cancellation
            print("With checked continuation")
            // if Double.random(in: 0...1) < 0.5 {
                print("initiating a cancel")
                httpClientTask.cancel()
                invocationTask.cancel()
                continuation.resume()
            // } else {
            //     print("initiating a gracefull shutdown")
            //     client.syncShutdownGracefully(continuation: continuation)
            // }
        }
        // give time to the client to shutdown 
        try await Task.sleep(nanoseconds: 500_000_000)
        print("done")

    }
}
