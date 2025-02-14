import NIO
import NIOHTTP1
import AWSLambdaRuntimeCore
import Dispatch


private final class HTTPHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)

        switch reqPart {
        case .head(let request):
            if request.method == .GET && request.uri == "/next" {
                print("Received a GET request")
                let headers = HTTPHeaders([
                    (AmazonHeaders.requestID, "123"),
                    (
                        AmazonHeaders.invokedFunctionARN,
                        "arn:aws:lambda:us-east-1:\(Int16.random(in: Int16.min ... Int16.max)):function:custom-runtime"
                    ),
                    (AmazonHeaders.traceID, "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=1"),
                    (AmazonHeaders.deadline, "\(DispatchWallTime.distantFuture.millisSinceEpoch)"),
                    ])
                let responseHead = HTTPResponseHead(version: request.version, status: .ok, headers: headers)
                context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)

                let responseBody = HTTPServerResponsePart.body(.byteBuffer(context.channel.allocator.buffer(string: "{\"message\": \"Hello, world!\"}")))
                context.write(self.wrapOutboundOut(responseBody), promise: nil)

                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                // close the connection to test client behaviour
                // context.close(promise: nil)
            }
            if request.method == .POST && request.uri == "/response" {
                print("Received a POST request")
                let responseHead = HTTPResponseHead(version: request.version, status: .accepted)
                context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)

                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                // close the connection to test client behaviour
                // context.close(promise: nil)
            }
        case .body:
            break
        case .end:
            break
        }
    }
}

let socketBootstrap = ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
    // Specify backlog and enable SO_REUSEADDR for the server itself
    .serverChannelOption(.backlog, value: 256)
    .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)

    // Set the handlers that are applied to the accepted Channels
    .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                channel.pipeline.addHandler(HTTPHandler())
            }
    }
    // Enable SO_REUSEADDR for the accepted Channels
    .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
    .childChannelOption(.maxMessagesPerRead, value: 1)

let channel = try socketBootstrap.bind(host: "127.0.0.1", port: 7000).wait()

let localAddress: String
guard let channelLocalAddress = channel.localAddress else {
    fatalError(
        "Address was unable to bind. Please check that the socket was not closed or that the address family was understood."
    )
}
localAddress = "\(channelLocalAddress)"

print("Server started and listening on \(localAddress)")

// This will never unblock as we don't close the ServerChannel
try channel.closeFuture.wait()

print("Server closed")

/*
let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
let bootstrap = ServerBootstrap(group: group)
    .serverChannelOption(ChannelOptions.backlog, value: 256)
    .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline().flatMap {
            channel.pipeline.addHandler(HTTPHandler())
        }
    }
    .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
    .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

let channel = try bootstrap.bind(host: "127.0.0.1", port: 7000).wait()
print("Server running on:", channel.localAddress!)

try channel.closeFuture.wait()
try group.syncShutdownGracefully()
*/