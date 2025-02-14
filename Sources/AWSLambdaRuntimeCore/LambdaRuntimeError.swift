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

//TODO: switch to package 
public struct LambdaRuntimeError: Error {
    public enum Code: Sendable {
        case closingRuntimeClient

        case connectionToControlPlaneLost
        case connectionToControlPlaneGoingAway
        case invocationMissingMetadata

        case writeAfterFinishHasBeenSent
        case finishAfterFinishHasBeenSent
        case lostConnectionToControlPlane
        case unexpectedStatusCodeForRequest

        case nextInvocationMissingHeaderRequestID
        case nextInvocationMissingHeaderDeadline
        case nextInvocationMissingHeaderInvokeFuctionARN

        case missingLambdaRuntimeAPIEnvironmentVariable
        case runtimeCanOnlyBeStartedOnce
        case invalidPort
    }

    public init(code: Code, underlying: (any Error)? = nil) {
        self.code = code
        self.underlying = underlying
    }

    private let code: Code
    private let underlying: (any Error)?

}
