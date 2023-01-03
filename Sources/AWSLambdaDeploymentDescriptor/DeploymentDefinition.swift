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

public protocol DeploymentDefinition: Encodable {}

// maybe this file might be generated entirely or partially automatically from
// https://github.com/aws/serverless-application-model/blob/develop/samtranslator/validator/sam_schema/schema.json

// a Swift definition of a SAM deployment decsriptor.
// currently limited to the properties I needed for the examples.
// An immediate TODO if this code is accepted is to add more properties and more classes
public struct SAMDeployment: DeploymentDefinition {
    
    let awsTemplateFormatVersion: String
    let transform: String
    let description: String
    var resources: [String: Resource]
    
    public init(
        templateVersion: String = "2010-09-09",
        transform: String = "AWS::Serverless-2016-10-31",
        description: String = "A SAM template to deploy a Swift Lambda function",
        resources: [Resource] = []
    ) {
        
        self.awsTemplateFormatVersion = templateVersion
        self.transform = transform
        self.description = description
        self.resources = [String: Resource]()
        
        for res in resources {
            self.resources[res.name] = res
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case awsTemplateFormatVersion = "AWSTemplateFormatVersion"
        case transform = "Transform"
        case description = "Description"
        case resources = "Resources"
    }
}

public protocol SAMResource: Encodable {}
public protocol SAMResourceProperties: Encodable {}

public struct Resource: SAMResource, Equatable {
    
    let type: String
    let properties: SAMResourceProperties
    let name: String
        
    public static func none() -> [Resource] { return [] }
    
    public static func == (lhs: Resource, rhs: Resource) -> Bool {
        lhs.type == rhs.type && lhs.name == rhs.name
    }
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
    
    // this is to make the compiler happy : Resource now confoms to Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(self.type, forKey: .type)
        try? container.encode(self.properties, forKey: .properties)
    }
}

//MARK: Lambda Function resource definition
/*---------------------------------------------------------------------------------------
 Lambda Function
 
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-function.html
-----------------------------------------------------------------------------------------*/

extension Resource {
    public static func serverlessFunction(name: String,
                                          codeUri: String,
                                          eventSources: [EventSource] = [],
                                          environment: EnvironmentVariable = EnvironmentVariable.none()) -> Resource {
        
        let properties = ServerlessFunctionProperties(codeUri: codeUri,
                                                       eventSources: eventSources,
                                                       environment: environment)
        return Resource(type: "AWS::Serverless::Function",
                        properties: properties,
                        name: name)
    }

}

public struct ServerlessFunctionProperties: SAMResourceProperties {
    public enum Architectures: String, Encodable {
        case x64 = "x86_64"
        case arm64 = "arm64"
    }
    let architectures: [Architectures]
    let handler: String
    let runtime: String
    let codeUri: String
    let autoPublishAlias: String
    var eventSources: [String: EventSource]
    var environment: EnvironmentVariable
    
    public init(codeUri: String,
                eventSources: [EventSource] = [],
                environment: EnvironmentVariable = EnvironmentVariable.none()) {
        
        #if arch(arm64) //when we build on Arm, we deploy on Arm
        self.architectures = [.arm64]
        #else
        self.architectures = [.x64]
        #endif
        self.handler = "Provided"
        self.runtime = "provided.al2" // Amazon Linux 2 supports both arm64 and x64
        self.autoPublishAlias = "Live"
        self.codeUri = codeUri
        self.eventSources = [String: EventSource]()
        self.environment = environment
        
        for es in eventSources {
            self.eventSources[es.name] = es
        }
    }
    
    // custom encoding to not provide Environment variables when there is none
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.architectures, forKey: .architectures)
        try container.encode(self.handler, forKey: .handler)
        try container.encode(self.runtime, forKey: .runtime)
        try container.encode(self.codeUri, forKey: .codeUri)
        try container.encode(self.autoPublishAlias, forKey: .autoPublishAlias)
        try container.encode(self.eventSources, forKey: .eventSources)
        if !environment.isEmpty() {
            try container.encode(self.environment, forKey: .environment)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case architectures = "Architectures"
        case handler = "Handler"
        case runtime = "Runtime"
        case codeUri = "CodeUri"
        case autoPublishAlias = "AutoPublishAlias"
        case eventSources = "Events"
        case environment = "Environment"
    }
}

/*
 Environment:
   Variables:
     LOG_LEVEL: debug
 */
public struct EnvironmentVariable: Codable {
    public var variables: [String:String]
    public init(_ variables: [String:String]) {
        self.variables = variables
    }
    public static func none() -> EnvironmentVariable { return EnvironmentVariable([:]) }
    public func isEmpty() -> Bool { return variables.count == 0 }
    
    public mutating func append(_ key: String, _ value: String) {
        variables[key] = value
    }
    
    enum CodingKeys: String, CodingKey {
        case variables = "Variables"
    }
}

//MARK: Lambda Function event source

public protocol SAMEvent : Encodable, Equatable {}
public protocol SAMEventProperties : Encodable {}

public struct EventSource: SAMEvent {

    let type: String
    let properties: SAMEventProperties?
    let name: String
        
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
    
    public static func == (lhs: EventSource, rhs: EventSource) -> Bool {
        lhs.type == rhs.type && lhs.name == rhs.name
    }

    public static func none() -> [EventSource] { return [] }

    // this is to make the compiler happy : Resource now confoms to Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(self.type, forKey: .type)
        if let properties = self.properties {
            try? container.encode(properties, forKey: .properties)
        }
    }
}


//MARK: HTTP API Event definition
/*---------------------------------------------------------------------------------------
 HTTP API Event (API Gateway v2)
 
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-httpapi.html
-----------------------------------------------------------------------------------------*/

extension EventSource {
    public static func httpApi(name: String = "HttpApiEvent",
                               method: HttpVerb? = nil,
                               path: String? = nil) -> EventSource {
        
        var properties: SAMEventProperties? = nil
        if method != nil || path != nil {
            properties = HttpApiProperties(method: method, path: path)
        }
        
        return EventSource(type: "HttpApi",
                           properties: properties,
                           name: name)
    }
}

struct HttpApiProperties: SAMEventProperties, Equatable {
    init(method: HttpVerb? = nil, path: String? = nil) {
        self.method = method
        self.path = path
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: HttpApiKeys.self)
        if let method = self.method {
            try container.encode(method, forKey: .method)
        }
        if let path = self.path {
            try container.encode(path, forKey: .path)
        }
    }
    let method: HttpVerb?
    let path: String?
    
    enum HttpApiKeys: String, CodingKey {
        case method = "Method"
        case path = "Path"
    }
}

public enum HttpVerb: String, Encodable {
    case GET
    case POST
}

//MARK: SQS event definition
/*---------------------------------------------------------------------------------------
 SQS Event
 
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-sqs.html
-----------------------------------------------------------------------------------------*/

extension EventSource {
    private static func sqs(name: String = "SQSEvent",
                            properties: SQSEventProperties) -> EventSource {
        
        return EventSource(type: "SQS",
                           properties: properties,
                           name: name)
    }
    public static func sqs(name: String = "SQSEvent",
                           queue queueRef: String) -> EventSource {
        
        let properties = SQSEventProperties(byRef: queueRef)
        return EventSource.sqs(name: name,
                               properties: properties)
    }
    
    public static func sqs(name: String = "SQSEvent",
                           queue: Resource) -> EventSource {
        
        let properties = SQSEventProperties(queue)
        return EventSource.sqs(name: name,
                               properties: properties)
    }
}

/**
   Represents SQS queue properties.
   When `queue` name  is a shorthand YAML reference to another resource, like `!GetAtt`, it splits the shorthand into proper YAML to make the parser happy
 */
public struct SQSEventProperties: SAMEventProperties, Equatable {
    
    public var queueByArn: String? = nil
    public var queue: Resource? = nil
    
    init(byRef ref: String) {
        
        // when the ref is an ARN, leave it as it, otherwise, create a queue resource and pass a reference to it
        if let arn = Arn(ref)?.arn {
            self.queueByArn = arn
        } else {
            let logicalName = Resource.logicalName(resourceType: "Queue",
                                                   resourceName: ref)
            self.queue = Resource.sqsQueue(name: logicalName,
                                           properties: SQSResourceProperties(queueName: ref))
        }
        
    }
    init(_ queue: Resource) { self.queue = queue }

    enum CodingKeys: String, CodingKey {
        case queue = "Queue"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // if we have an Arn, return the Arn, otherwise pass a reference with GetAtt
        // https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-sqs.html#sam-function-sqs-queue
        if  let queueByArn {
            try container.encode(queueByArn, forKey: .queue)
        } else if let queue {
            var getAttIntrinsicFunction: [String:[String]] = [:]
            getAttIntrinsicFunction["Fn::GetAtt"] = [ queue.name, "Arn"]
            try container.encode(getAttIntrinsicFunction, forKey: .queue)
        }
    }
}

//MARK: SQS queue resource definition
/*---------------------------------------------------------------------------------------
 SQS Queue Resource
 
 Documentation
 https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-sqs-queue.html
-----------------------------------------------------------------------------------------*/
extension Resource {
    public static func sqsQueue(name: String,
                                properties: SQSResourceProperties) -> Resource {
                                                
        return Resource(type: "AWS::SQS::Queue",
                        properties: properties,
                        name: name)
    }

    public static func sqsQueue(logicalName: String,
                                physicalName: String ) -> Resource {
                                    
        let sqsProperties = SQSResourceProperties(queueName: physicalName)
        return sqsQueue(name: logicalName, properties: sqsProperties)
    }
}

public struct SQSResourceProperties: SAMResourceProperties {
    public let queueName: String
    enum CodingKeys: String, CodingKey {
        case queueName = "QueueName"
    }
}

//MARK: Simple DynamoDB table resource definition
/*---------------------------------------------------------------------------------------
 Simple DynamoDB Table Resource
 
 Documentation
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-simpletable.html
-----------------------------------------------------------------------------------------*/

extension Resource {
    public static func simpleTable(name: String,
                                   properties: SimpleTableProperties) -> Resource {
                                                
        return Resource(type: "AWS::Serverless::SimpleTable",
                        properties: properties,
                        name: name)
    }
    public static func simpleTable(logicalName: String,
                                   physicalname: String,
                                   primaryKeyName: String,
                                   primaryKeyValue: String) -> Resource {
        let primaryKey = SimpleTableProperties.PrimaryKey(name: primaryKeyName, type: primaryKeyValue)
        let properties = SimpleTableProperties(primaryKey: primaryKey, tableName: physicalname)
        return simpleTable(name: logicalName, properties: properties)
    }}

public struct SimpleTableProperties: SAMResourceProperties {
    let primaryKey: PrimaryKey
    let tableName: String
    let provisionedThroughput: ProvisionedThroughput? = nil
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(tableName, forKey: .tableName)
        try? container.encode(primaryKey, forKey: .primaryKey)
        if let provisionedThroughput = self.provisionedThroughput {
            try container.encode(provisionedThroughput, forKey: .provisionedThroughput)
        }
    }
    enum CodingKeys: String, CodingKey {
        case primaryKey = "PrimaryKey"
        case tableName = "TableName"
        case provisionedThroughput = "ProvisionedThroughput"
    }
    struct PrimaryKey: Codable {
        let name: String
        let type: String
        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case type = "Type"
        }
    }
    struct ProvisionedThroughput: Codable {
        let readCapacityUnits: Int
        let writeCapacityUnits: Int
        enum CodingKeys: String, CodingKey {
            case readCapacityUnits = "ReadCapacityUnits"
            case writeCapacityUnits = "WriteCapacityUnits"
        }
    }
}


//MARK: Utils

struct Arn {
    public let arn: String
    init?(_ arn: String) {
        // Arn regex from https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-eventsourcemapping.html#cfn-lambda-eventsourcemapping-eventsourcearn
        let arnRegex = #"arn:(aws[a-zA-Z0-9-]*):([a-zA-Z0-9\-])+:([a-z]{2}(-gov)?-[a-z]+-\d{1})?:(\d{12})?:(.*)"#
        if arn.range(of: arnRegex, options: .regularExpression) != nil {
            self.arn = arn
        } else {
            return nil
        }
    }
}

extension Resource {
    // Transform resourceName :
    // remove space
    // remove hyphen
    // camel case
    static func logicalName(resourceType: String, resourceName: String) -> String {
        let noSpaceName = resourceName.split(separator: " ").map{ $0.capitalized }.joined(separator: "")
        let noHyphenName = noSpaceName.split(separator: "-").map{ $0.capitalized }.joined(separator: "")
        return resourceType.capitalized + noHyphenName
    }
}

public enum DeploymentEncodingError: Error {
    case yamlError(causedBy: Error)
    case jsonError(causedBy: Error)
    case stringError(causedBy: Data)
}
