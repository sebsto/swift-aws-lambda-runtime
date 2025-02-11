import NIOCore
import NIOHTTP1

package typealias Invocation = (ByteBuffer?, InvocationMetadata)

package struct InvocationMetadata: Hashable {
    package let requestID: String
    package let deadlineInMillisSinceEpoch: Int64
    package let invokedFunctionARN: String
    package let traceID: String
    package let clientContext: String?
    package let cognitoIdentity: String?

    package init(headers: HTTPHeaders) throws(LambdaRuntimeError) {
        guard let requestID = headers.first(name: AmazonHeaders.requestID), !requestID.isEmpty else {
            throw LambdaRuntimeError(code: .nextInvocationMissingHeaderRequestID)
        }

        guard let deadline = headers.first(name: AmazonHeaders.deadline),
            let unixTimeInMilliseconds = Int64(deadline)
        else {
            throw LambdaRuntimeError(code: .nextInvocationMissingHeaderDeadline)
        }

        guard let invokedFunctionARN = headers.first(name: AmazonHeaders.invokedFunctionARN) else {
            throw LambdaRuntimeError(code: .nextInvocationMissingHeaderInvokeFuctionARN)
        }

        self.requestID = requestID
        self.deadlineInMillisSinceEpoch = unixTimeInMilliseconds
        self.invokedFunctionARN = invokedFunctionARN
        self.traceID =
            headers.first(name: AmazonHeaders.traceID) ?? "Root=\(AmazonHeaders.generateXRayTraceID());Sampled=0"
        self.clientContext = headers["Lambda-Runtime-Client-Context"].first
        self.cognitoIdentity = headers["Lambda-Runtime-Cognito-Identity"].first
    }
}