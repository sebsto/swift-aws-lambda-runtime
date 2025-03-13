// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AWSLambdaRuntime", targets: ["AWSLambdaRuntime"]),

        //
        // The plugins
        // 'lambda-init' creates a new Lambda function
        // 'lambda-build' packages the Lambda function
        // 'lambda-deploy' deploys the Lambda function
        //
        //  Plugins requires Linux or at least macOS v15
        //

        // plugin to create a new Lambda function, based on a template
        .plugin(name: "AWSLambdaInitializer", targets: ["AWSLambdaInitializer"]),

        // plugin to package the lambda, creating an archive that can be uploaded to AWS
        .plugin(name: "AWSLambdaBuilder", targets: ["AWSLambdaBuilder"]),

        // plugin to deploy a Lambda function
        .plugin(name: "AWSLambdaDeployer", targets: ["AWSLambdaDeployer"]),
    ],
    traits: [
        "FoundationJSONSupport",
        "ServiceLifecycleSupport",
        "LocalServerSupport",
        .default(
            enabledTraits: [
                "FoundationJSONSupport",
                "ServiceLifecycleSupport",
                "LocalServerSupport",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.81.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.6.3"),
    ],
    targets: [
        .target(
            name: "AWSLambdaRuntime",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(
                    name: "ServiceLifecycle",
                    package: "swift-service-lifecycle",
                    condition: .when(traits: ["ServiceLifecycleSupport"])
                ),
            ]
        ),
        .plugin(
            name: "AWSLambdaInitializer",
            capability: .command(
                intent: .custom(
                    verb: "lambda-init",
                    description:
                        "Create a new Lambda function in the current project directory."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Create a file with an HelloWorld Lambda function.")
                ]
            ),
            dependencies: [
                .target(name: "AWSLambdaPluginHelper")
            ]
        ),
        // keep this one (with "archive") to not break workflows
        // This will be deprecated at some point in the future
        //        .plugin(
        //            name: "AWSLambdaPackager",
        //            capability: .command(
        //                intent: .custom(
        //                    verb: "archive",
        //                    description:
        //                        "Archive the Lambda binary and prepare it for uploading to AWS. Requires docker on macOS or non Amazonlinux 2 distributions."
        //                ),
        //                permissions: [
        //                    .allowNetworkConnections(
        //                        scope: .docker,
        //                        reason: "This plugin uses Docker to create the AWS Lambda ZIP package."
        //                    )
        //                ]
        //            ),
        //            path: "Plugins/AWSLambdaBuilder" // same sources as the new "lambda-build" plugin
        //        ),
        .plugin(
            name: "AWSLambdaBuilder",
            capability: .command(
                intent: .custom(
                    verb: "lambda-build",
                    description:
                        "Archive the Lambda binary and prepare it for uploading to AWS. Requires docker on macOS or non Amazonlinux 2 distributions."
                ),
                permissions: [
                    .allowNetworkConnections(
                        scope: .docker,
                        reason: "This plugin uses Docker to create the AWS Lambda ZIP package."
                    )
                ]
            ),
            dependencies: [
                .target(name: "AWSLambdaPluginHelper")
            ]
        ),
        .plugin(
            name: "AWSLambdaDeployer",
            capability: .command(
                intent: .custom(
                    verb: "lambda-deploy",
                    description:
                        "Deploy the Lambda function. You must have an AWS account and know an access key and secret access key."
                ),
                permissions: [
                    .allowNetworkConnections(
                        scope: .all(ports: [443]),
                        reason: "This plugin uses the AWS Lambda API to deploy the function."
                    )
                ]
            ),
            dependencies: [
                .target(name: "AWSLambdaPluginHelper")
            ]
        ),
        .executableTarget(
            name: "AWSLambdaPluginHelper",
            dependencies: [
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AWSLambdaRuntimeTests",
            dependencies: [
                .byName(name: "AWSLambdaRuntime"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
            ]
        ),
        // for perf testing
        .executableTarget(
            name: "MockServer",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "AWSLambdaPluginHelperTests",
            dependencies: [
                .byName(name: "AWSLambdaPluginHelper")
            ]
        ),

    ]
)
