import AWSLambdaDeploymentDescriptor
import Foundation

@main
public struct HttpApiLambdaDeployment: DeploymentDescriptor {
    static func main() throws {
        HttpApiLambdaDeployment().run()
    }

    public func eventSources(_ lambdaName: String) -> [EventSource] {

        if lambdaName == "HttpApiLambda" {
            return [
                .httpApi()
                // .httpApi(method: .GET, path: "/test"),
            ]

        } else if lambdaName == "SQSLambda" {
            return [.sqs(queue: "swift-lambda-test")]

        } else {
            fatalError("Unknown Lambda name : \(lambdaName)")
        }
    }

    public func environmentVariables(_ lambdaName: String) -> EnvironmentVariable {
        // return the same env variables for all functions
        return EnvironmentVariable([ "LOG_LEVEL": "debug" ])
    }

}