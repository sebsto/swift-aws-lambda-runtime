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
/// It continuously sends a request and waits for a response until task is cancelled
struct HTTPClient {

    private let config: Configuration
    private let clientBoostrap: ClientBootstrap

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
                    print("sending \(path)")
                    try await outbound.get(path)

                    let response = try await inboundIterator.readFullResponse()
                    //TODO: empile response in a shared tsructured + iterator

                }

            } catch is CancellationError {
                // do not let CancellationError propagate, exit the loop and let NIO close the channel
                print("Cancelled")
            }
            return 
        }
        // anything below this line might not be executed in case of Task cancellation
        print("exited executeThenClose")
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
