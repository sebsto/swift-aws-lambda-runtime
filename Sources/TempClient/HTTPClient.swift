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

struct Configuration {
    var ip: String
    var port: Int
}

enum HTTPClientError: Error {
    case malformedResponse, unexpectedEndOfStream
}

/// A simple generic HTTP Client
/// It continuously sends a request and waits for a response until it is cancelled or a gracefull shutdown is requested
struct HTTPClient {

    private let config: Configuration
    private let clientBoostrap: ClientBootstrap
    private let gracefullShutdown = SharedFlag()

    init(config: Configuration) {
        self.config = config
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
            host: self.config.ip,
            port: self.config.port
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
    ) async throws -> String {
        let clientChannel = try await self.createClientChannel()
        let result = try await clientChannel.executeThenClose { inbound, outbound in

            do {
                var inboundIterator = inbound.makeAsyncIterator()

                var run = true
                // loop until the task is cancelled
                // task can be cancelled when the parent task is cancelled or when the gracefullShutdown is requested
                while run  {

                    // is the task cancelled ?
                    try Task.checkCancellation()

                    // did we receive a gracefull shutdown signal ?
                    if let continuation = self.gracefullShutdown.get() {
                        run = false
                        print("gracefully shutdown")
                        continuation.resume()
                    
                    } else {

                        // send a request and wait for the response
                        print("sending \(path)")
                        try await outbound.get(path)
                        //FIXME: how to gracefull shutdown when waiting for a response?
                        let response = try await inboundIterator.readFullResponse()
                        //FIXME : create an async sequence with the responses ?
                        print(response)
                    }
                }

            } catch is CancellationError {
                // do not let CancellationError propagate, exit the loop and let NIO close the channel
                print("Cancelled")
            } 
            return ""
        }
        // anything below this line might not be executed in case of Task cancellation or Gracefull shutdown
        print("exited executeThenClose")
        return result

    }

    func syncShutdownGracefully(continuation: CheckedContinuation<Void, any Error>) {
        self.gracefullShutdown.toggle(continuation: continuation)
    }
}

private final class SharedFlag: Sendable {
    private let flag = Mutex<CheckedContinuation<Void, any Error>?>(nil)

    func get() -> CheckedContinuation<Void, any Error>? {
        flag.withLock {
            if let continuation = $0 {
                $0 = nil
                return continuation
            } else {
                return nil
            }
        }
    }
    func toggle(continuation: CheckedContinuation<Void, any Error>)  {
        flag.withLock {
            if let continuation = $0 {
                // should not happen, but play it nice and resume the previous continuation
                continuation.resume()
                $0 = nil
                fatalError("Unexpected state")
            } else {
                $0 = continuation
            }
        }
    }
}

extension NIOAsyncChannelInboundStream<HTTPClientResponsePart>.AsyncIterator {
    private mutating func _next() async throws -> HTTPClientResponsePart? {
        guard let part = try await self.next() else {
            return nil
        }
        return part
    }
    mutating func readFullResponse() async throws -> String {
        var headers: HTTPHeaders? = nil
        var body = ByteBuffer()
        while let part = try await self._next() {
            switch part {
            case .head(let head):
                headers = head.headers
            case .body(var buf):
                body.writeBuffer(&buf)
            case .end(_):
                guard headers != nil else {
                    throw HTTPClientError.malformedResponse
                }
                return String(buffer: body)
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
