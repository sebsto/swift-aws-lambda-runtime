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

import AWSLambdaRuntime
import NIOCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct SendNumbersWithPause: StreamingLambdaHandler {
    func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws {

        // Send HTTP status code and headers before streaming the response body
        try await responseWriter.writeStatusAndHeaders(
            StreamingLambdaStatusAndHeadersResponse(
                statusCode: 418,  // I'm a tea pot
                headers: [
                    "Content-Type": "text/plain",
                    "x-my-custom-header": "streaming-example",
                ]
            )
        )

        // Stream numbers with pauses to demonstrate streaming functionality
        for i in 1...3 {
            // Send partial data
            try await responseWriter.write(ByteBuffer(string: "Number: \(i)\n"))

            // Perform some long asynchronous work to simulate processing
            try await Task.sleep(for: .milliseconds(1000))
        }

        // Send final message
        try await responseWriter.write(ByteBuffer(string: "Streaming complete!\n"))

        // All data has been sent. Close off the response stream.
        try await responseWriter.finish()
    }
}

let runtime = LambdaRuntime(handler: SendNumbersWithPause())
try await runtime.run()
