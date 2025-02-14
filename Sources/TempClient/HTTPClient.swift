//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import Synchronization
import AWSLambdaRuntimeCore

enum HTTPClientError: Error {
    case malformedResponse
    case unexpectedEndOfStream
}

/// A simple, Swift Concurrency-compliant Lambda HTTP Client
///
/// It continuously sends a 'GET /next' request to the Lamnbda control plane and waits for a response until the Task is cancelled.
/// The lambda control plance responds with Lambda invocation events. Invocation events are enqueued in a shared Pool data structure that is shared with the caller.
/// Once put in the queue, the client waits for the caller to process the invocation event (the caller invokes the body of the Lambda function).
/// When the callers tells us we can continue, we send the response to the Lambda service control plane with a `POST /response`.
struct HTTPClient {

    private let ip: String 
    private let port: Int
    private let clientBoostrap: ClientBootstrap

    private let invocationsPool: Pool<Invocation>

    init(ip: String, port: Int, invocations: Pool<Invocation>) {
        self.ip = ip
        self.port = port
        self.invocationsPool = invocations
        self.clientBoostrap = ClientBootstrap(
            group: NIOSingletons.posixEventLoopGroup
        )
        .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .channelInitializer { channel in
            channel.eventLoop.makeCompletedFuture {
                try channel.pipeline.syncOperations.addHTTPClientHandlers()
            }
        }
    }

    private func createClientChannel() async throws -> NIOAsyncChannel<HTTPClientResponsePart, HTTPClientRequestPart> {
        try await clientBoostrap.connect(
            host: self.ip,
            port: self.port
        )
        .flatMapThrowing { channel in
            try NIOAsyncChannel(
                wrappingChannelSynchronously: channel,
                configuration: NIOAsyncChannel.Configuration(
                    inboundType: HTTPClientResponsePart.self,
                    outboundType: HTTPClientRequestPart.self
                )
            )
        }
        .get()
    }

    func repeatSendingUntilCancelled(
        _ path: String,
        method: HTTPMethod = .GET,
        headers: HTTPHeaders = HTTPHeaders()
    ) async throws -> Void {
        let clientChannel = try await self.createClientChannel()
        try await clientChannel.executeThenClose { inbound, outbound in

            do {

                var inboundIterator = inbound.makeAsyncIterator()

                // loop until the task is cancelled
                // task can be cancelled when the parent task is cancelled or when the gracefullShutdown is requested
                while true {
                    // is the task cancelled ?
                    try Task.checkCancellation()

                    // send a request and wait for the response
                    let nextPath = Consts.getNextInvocationURLSuffix
                    print("sending \(nextPath)")
                    try await outbound.get(nextPath)

                    // wait for next invocation
                    print("Waiting for next invocation")
                    let (headers, body) = try await inboundIterator.readFullResponse()
                    print("Received next invocation")
                    print(headers)
                    print(body)
                    let metadata: InvocationMetadata = try InvocationMetadata(headers: headers) 

                    let response = await withCheckedContinuation { (continuation: CheckedContinuation<ByteBuffer, Never>)  in

                        // invocation received, wrap it in an Invocation object
                        let invocation = Invocation(metadata: metadata, event: body, continuation: continuation)

                        // enqueue invocation in a shared structured on which our caller can iterate
                        self.invocationsPool.push(invocation)

                        // the consumer of the invocation will call continuation.resume()
                    }
                    print("response received from lambda : \(String(buffer: response))")

                    // now we have a response
                    print("sending response POST /response")
                    try await outbound.post(Consts.postResponseURLSuffix, body: response)

                    // read the server response from our response
                    let (respHeaders, respBody) = try await inboundIterator.readFullResponse()
                    print(respHeaders)
                    print(respBody)
                    //TODO: verify response is OK or accepted

                }

            } catch is CancellationError {
                // do not let CancellationError propagate, exit the loop and let NIO close the channel
                print("Client Task Cancelled")
            } catch let error as HTTPClientError {
                print("HTTPClientError: \(error)")
                // throw error
            }

            return 
        }
        // anything below this line might not be executed in case of Task cancellation
        print("server closed the connection - exited executeThenClose")
    }

    // func pushInvocation(_ invocation: Invocation, complete) {
    //     self.invocationsPool.push(invocation)
    // }
}

extension NIOAsyncChannelInboundStream<HTTPClientResponsePart>.AsyncIterator {
    private mutating func _next() async throws -> HTTPClientResponsePart? {
        guard let part = try await self.next() else {
            return nil
        }
        return part
    }
    mutating func readFullResponse() async throws -> (HTTPHeaders, ByteBuffer) {
        var headers: HTTPHeaders? = nil
        var body = ByteBuffer()
        while let part = try await self._next() {
            switch part {
            case .head(let head):
                headers = head.headers
            case .body(var buf):
                body.writeBuffer(&buf)
            case .end(_):
                guard let headers = headers else {
                    throw HTTPClientError.malformedResponse
                }
                return (headers, body)
            }
        }
        // server closed the connection
        throw HTTPClientError.unexpectedEndOfStream
    }
}

extension NIOAsyncChannelOutboundWriter<HTTPClientRequestPart> {
    func get(_ path: String) async throws {
        try await self.write(.head(HTTPRequestHead(version: .http1_1, method: .GET, uri: path)))
        try await self.write(.end(nil))
    }

    func post(_ path: String, body: ByteBuffer) async throws {
        try await self.write(.head(HTTPRequestHead(version: .http1_1, method: .POST, uri: path)))
        try await self.write(.body(IOData.byteBuffer(body)))
        try await self.write(.end(nil))
    }
}
