import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import { Construct } from 'constructs';

interface MinimalStackProps extends cdk.StackProps {
  environment: string;
}

export class MinimalStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: MinimalStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // S3 Data Lake Bucket
    const dataLakeBucket = new s3.Bucket(this, 'DataLakeBucket', {
      bucketName: `ci-data-${environment}-${this.account}`,
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // DynamoDB Table for conversations
    const conversationTable = new dynamodb.Table(this, 'ConversationTable', {
      tableName: `ci-conversations-${environment}`,
      partitionKey: { name: 'conversationId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Lambda Execution Role
    const lambdaRole = new iam.Role(this, 'LambdaExecutionRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    // Grant permissions
    dataLakeBucket.grantReadWrite(lambdaRole);
    conversationTable.grantReadWriteData(lambdaRole);

    // Simple Lambda function
    const apiHandler = new lambda.Function(this, 'APIHandler', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.handler',
      role: lambdaRole,
      code: lambda.Code.fromInline(`
def handler(event, context):
    return {
        'statusCode': 200,
        'body': 'Pharmaceutical CI Platform is running'
    }
      `),
      environment: {
        ENVIRONMENT: environment,
        TABLE_NAME: conversationTable.tableName,
        BUCKET_NAME: dataLakeBucket.bucketName,
      },
    });

    // API Gateway
    const api = new apigateway.RestApi(this, 'API', {
      restApiName: `ci-api-${environment}`,
      description: 'Pharmaceutical CI Platform API',
    });

    const resource = api.root.addResource('health');
    resource.addMethod('GET', new apigateway.LambdaIntegration(apiHandler));

    // Outputs
    new cdk.CfnOutput(this, 'APIEndpointOutput', {
      value: api.url,
      exportName: `${this.stackName}-APIEndpoint`,
    });

    new cdk.CfnOutput(this, 'DataLakeBucketOutput', {
      value: dataLakeBucket.bucketName,
      exportName: `${this.stackName}-DataLakeBucket`,
    });

    new cdk.CfnOutput(this, 'ConversationTableOutput', {
      value: conversationTable.tableName,
      exportName: `${this.stackName}-ConversationTable`,
    });
  }
}
