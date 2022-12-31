// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import Foundation
import Yams

// this is the developer-visible part of the deployment decsriptor.
// the rest is generated automatically.
public protocol DeploymentDescriptor {
    
    // returns the event sources for a given Lambda function
    func eventSources(_ lambdaName: String) -> [EventSource]
    
    // returns environment variables to associate with the given Lambda function
    func environmentVariables(_ lambdaName: String) -> EnvironmentVariable

    // returns additional resources to create in the cloud (ex : a dynamoDB table)
    func addResource() -> [Resource]
}

// Generates a deployment descriptor modelized by DeploymentDefinition
extension DeploymentDescriptor {
    
    // create the SAM deployment descriptor data structure
    // this method use multiple data sources :
    // - it calls protocol functions implemented by the lambda function developer to get function-specific
    //   details (event source, environment variables)
    // - it uses command line arguments (list of lambda names)
    // - it uses some default values (like the ZIP file produced by archive command)
    public func deploymentDefinition() -> DeploymentDefinition {
        
        var additionalressources : [Resource] = []
        
        // create function resources for each Lambda function
        var resources = self.lambdaNames().map { name in
            
            // default output dir for archive plugin is
            // .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/HttpApiLambda/HttpApiLambda.zip
            // FIXME: what if use used --output-path option on packager ?
            let package = ".build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/\(name)/\(name).zip"

            // add event sources provided by Lambda developer
            var eventSources = self.eventSources(name)
            
            // do we need to create a SQS queue ? Filter on SQSEvent source without Queue Arn
            let sqsEventSources: [EventSource] = eventSources.filter{ eventSource in
                // Arn regex from https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-eventsourcemapping.html#cfn-lambda-eventsourcemapping-eventsourcearn
                let arnRegex = #"arn:(aws[a-zA-Z0-9-]*):([a-zA-Z0-9\-])+:([a-z]{2}(-gov)?-[a-z]+-\d{1})?:(\d{12})?:(.*)"#
                let queueName = (eventSource.properties as? SQSEventProperties)?.queue
                return
                    eventSource.type == "SQS" &&
                    queueName?.range(of: arnRegex, options: .regularExpression) == nil
            }

            // for each of SQSEvent Source without queue Arn, add a SQS resource and modify the event source to point ot that new resource
            for sqsES in sqsEventSources {
                
                // add a queue resource to the SAM teamplate
                guard let queueName = (sqsES.properties as? SQSEventProperties)?.queue else {
                    fatalError("SQS Event Source's properties is not a SAMEventProperties")
                }
                let logicalName = logicalName(resourceType: "Queue",
                                              resourceName: queueName)
                additionalressources.append(Resource.sqsQueue(name: logicalName,
                                                              properties: SQSResourceProperties(queueName: queueName)))
                                                
                // replace the event source to point to this new queue resource
                eventSources.removeAll{ $0 == sqsES }
                eventSources.append(EventSource.sqs(queue: "!GetAtt \(logicalName).Arn"))

            }
            
            // finally, let's build the function definition
            return Resource.serverlessFunction(name: name,
                                               codeUri: package,
                                               eventSources: eventSources,
                                               environment: environmentVariables(name))
            
        }
        
        // add newly created resources (non-functions)
        resources.append(contentsOf: additionalressources)
        
        // add developer-provided resources
        resources.append(contentsOf: self.addResource())

        // craete the SAM deployment decsriptor
        return SAMDeployment(resources: resources)
    }
    
    // returns environment variables to associate with the given Lambda function
    // This is a default implementation to avoid forcing the lambda developer to implement it when not needed
    public func environmentVariables(_ lambdaName: String) -> EnvironmentVariable {
        return EnvironmentVariable.none()
    }
    
    // returns additional resources to create in the cloud (ex : a dynamoDB table)
    // This is a default implementation to avoid forcing the lambda developer to implement it when not needed
    public func addResource() -> [Resource] {
        return []
    }
    
    // entry point and main function. Lambda developer must call this function.
    public func run() {
        do {
            let sam = try toYaml()
            print(sam)
        } catch {
            print(error)
        }
    }
    
    // The lambda function names that are passed as command line argument
    // it is used to infer the directory and the name of the ZIP files
    public func lambdaNames() -> [String] {
        if CommandLine.arguments.count < 2 {
            fatalError(
                "You must pass the AWS Lambda function names as list of arguments\n\nFor example: ./deploy LambdaOne LambdaTwo"
            )
        } else {
            return [String](CommandLine.arguments[1...])
        }
    }
    
    // generate the YAML version of the deployment descriptor
    public func toYaml() throws -> String {
        let deploy = deploymentDefinition()
        
        do {
            let yaml = try YAMLEncoder().encode(deploy)
            return yaml
        } catch {
            throw DeploymentEncodingError.yamlError(causedBy: error)
        }
    }
    
    // generate the JSON version of the deployment descriptor
    public func toJson() throws -> String {
        let deploy = deploymentDefinition()
        
        do {
            let jsonData = try JSONEncoder().encode(deploy)
            guard let json = String(data: jsonData, encoding: .utf8) else {
                throw DeploymentEncodingError.stringError(causedBy: jsonData)
            }
            return json
        } catch {
            throw DeploymentEncodingError.jsonError(causedBy: error)
        }
    }
    
    // Transform resourceName :
    // remove space
    // remove hyphen
    // camel case 
    func logicalName(resourceType: String, resourceName: String) -> String {
        
        let noSpaceName = resourceName.split(separator: " ").map{ $0.capitalized }.joined(separator: "")
        let noHyphenName = noSpaceName.split(separator: "-").map{ $0.capitalized }.joined(separator: "")
        return resourceType.capitalized + noHyphenName
    }
}