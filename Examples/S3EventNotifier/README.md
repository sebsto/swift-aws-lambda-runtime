# S3 Event Notifier

This example demonstrates how to write a Lambda that is invoked by an event originating from Amazon S3, such as a new object being uploaded to a bucket.

## Code

In this example the Lambda function receives an `S3Event` object defined in the `AWSLambdaEvents` library as input object. The `S3Event` object contains all the information about the S3 event that triggered the function, but what we are interested in is the bucket name and the object key, which are inside of a notification `Record`. The object contains an array of records, however since the Lambda function is triggered by a single event, we can safely assume that there is only one record in the array: the first one. Inside of this record, we can find the bucket name and the object key:

```swift
guard let s3NotificationRecord = event.records.first else {
    throw LambdaError.noNotificationRecord
}

let bucket = s3NotificationRecord.s3.bucket.name
let key = s3NotificationRecord.s3.object.key.replacingOccurrences(of: "+", with: " ")
```

The key is URL encoded, so we replace the `+` with a space.

## Build & Package 

To build & archive the package you can use the following commands:

```bash
swift build
swift package archive --allow-network-connections docker
```

If there are no errors, a ZIP file should be ready to deploy, located at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/S3EventNotifier/S3EventNotifier.zip`.

## Deploy

> [!IMPORTANT]
> The Lambda function and the S3 bucket must be located in the same AWS Region. In the code below, we use `eu-west-1` (Ireland). 

To deploy the Lambda function, you can use the `aws` command line:

```bash
REGION=eu-west-1
aws lambda create-function \
    --region "${REGION}" \
    --function-name S3EventNotifier \
    --zip-file fileb://.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/S3EventNotifier/S3EventNotifier.zip \
    --runtime provided.al2 \
    --handler provided  \
    --architectures arm64 \
    --role arn:aws:iam::<YOUR_ACCOUNT_ID>:role/lambda_basic_execution
```

The `--architectures` flag is only required when you build the binary on an Apple Silicon machine (Apple M1 or more recent). It defaults to `x64`.

Be sure to define `REGION` with the region where you want to deploy your Lambda function and replace `<YOUR_ACCOUNT_ID>` with your actual AWS account ID (for example: 012345678901).

Besides deploying the Lambda function you also need to create the S3 bucket and configure it to send events to the Lambda function. You can do this using the following commands:

```bash
REGION=eu-west-1

aws s3api create-bucket     \
    --region "${REGION}"    \
    --bucket my-test-bucket \
    --create-bucket-configuration LocationConstraint="${REGION}"

aws lambda add-permission           \
    --region "${REGION}"            \
    --function-name S3EventNotifier \
    --statement-id S3InvokeFunction \
    --action lambda:InvokeFunction  \
    --principal s3.amazonaws.com    \
    --source-arn arn:aws:s3:::my-test-bucket

aws s3api put-bucket-notification-configuration \
    --region "${REGION}"    \
    --bucket my-test-bucket \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [{
            "LambdaFunctionArn": "arn:aws:lambda:${REGION}:<YOUR_ACCOUNT_ID>:function:S3EventNotifier",
            "Events": ["s3:ObjectCreated:*"]
        }]
    }'

touch testfile.txt && aws s3 cp testfile.txt s3://my-test-bucket/
```

This will:
 - create a bucket named `my-test-bucket` in the `$REGION` region;
 - add a permission to the Lambda function to be invoked by Amazon S3;
 - configure the bucket to send `s3:ObjectCreated:*` events to the Lambda function named `S3EventNotifier`;
 - upload a file named `testfile.txt` to the bucket.

Replace `my-test-bucket` with your bucket name (bucket names are unique globaly and this one is already taken). Also replace `REGION` environment variable with the AWS Region where you deployed the Lambda function and `<YOUR_ACCOUNT_ID>` with your actual AWS account ID.

> [!IMPORTANT]
> The Lambda function and the S3 bucket must be located in the same AWS Region. Adjust the code above according to your closest AWS Region.