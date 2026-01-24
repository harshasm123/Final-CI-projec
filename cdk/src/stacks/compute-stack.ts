import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as elasticsearch from 'aws-cdk-lib/aws-elasticsearch';
import { Construct } from 'constructs';

interface ComputeStackProps extends cdk.StackProps {
  environment: string;
  dataBucket: s3.Bucket;
  knowledgeBucket: s3.Bucket;
  conversationTable: dynamodb.Table;
  searchDomain: elasticsearch.Domain;
}

export class ComputeStack extends cdk.Stack {
  public readonly apiUrl: string;

  constructor(scope: Construct, id: string, props: ComputeStackProps) {
    super(scope, id, props);

    const { environment, dataBucket, knowledgeBucket, conversationTable, searchDomain } = props;

    // Lambda Layer for common dependencies
    const commonLayer = new lambda.LayerVersion(this, 'CommonLayer', {
      code: lambda.Code.fromAsset('../backend'),
      compatibleRuntimes: [lambda.Runtime.PYTHON_3_11],
      description: 'Common dependencies for pharmaceutical CI platform',
    });

    // Data Ingestion Lambda
    const dataIngestionFunction = new lambda.Function(this, 'DataIngestionFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'comprehensive_data_ingestion.lambda_handler',
      code: lambda.Code.fromAsset('../backend/src'),
      timeout: cdk.Duration.minutes(15),
      memorySize: 1024,
      layers: [commonLayer],
      environment: {
        DATA_BUCKET: dataBucket.bucketName,
        KNOWLEDGE_BUCKET: knowledgeBucket.bucketName,
        OPENSEARCH_ENDPOINT: searchDomain.domainEndpoint,
        ENVIRONMENT: environment,
      },
    });

    // AI Chatbot Lambda
    const chatbotFunction = new lambda.Function(this, 'ChatbotFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'enhanced_ai_handler.lambda_handler',
      code: lambda.Code.fromAsset('../backend/src/handlers'),
      timeout: cdk.Duration.minutes(5),
      memorySize: 2048,
      layers: [commonLayer],
      environment: {
        KNOWLEDGE_BUCKET: knowledgeBucket.bucketName,
        CONVERSATION_TABLE: conversationTable.tableName,
        OPENSEARCH_ENDPOINT: searchDomain.domainEndpoint,
        ENVIRONMENT: environment,
      },
    });

    // Dashboard API Lambda
    const dashboardFunction = new lambda.Function(this, 'DashboardFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'dashboard_handler.lambda_handler',
      code: lambda.Code.fromAsset('../backend/src/handlers'),
      timeout: cdk.Duration.seconds(30),
      memorySize: 512,
      layers: [commonLayer],
      environment: {
        DATA_BUCKET: dataBucket.bucketName,
        OPENSEARCH_ENDPOINT: searchDomain.domainEndpoint,
        ENVIRONMENT: environment,
      },
    });

    // Grant permissions
    dataBucket.grantReadWrite(dataIngestionFunction);
    knowledgeBucket.grantReadWrite(dataIngestionFunction);
    knowledgeBucket.grantRead(chatbotFunction);
    dataBucket.grantRead(dashboardFunction);
    conversationTable.grantReadWriteData(chatbotFunction);

    // OpenSearch permissions
    [dataIngestionFunction, chatbotFunction, dashboardFunction].forEach(fn => {
      fn.addToRolePolicy(new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'es:ESHttpPost',
          'es:ESHttpPut',
          'es:ESHttpGet',
          'es:ESHttpDelete',
        ],
        resources: [searchDomain.domainArn + '/*'],
      }));
    });

    // Bedrock permissions
    [dataIngestionFunction, chatbotFunction].forEach(fn => {
      fn.addToRolePolicy(new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeModelWithResponseStream',
        ],
        resources: [
          `arn:aws:bedrock:${this.region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0`,
          `arn:aws:bedrock:${this.region}::foundation-model/amazon.titan-embed-text-v1`,
        ],
      }));
    });

    // API Gateway
    const api = new apigateway.RestApi(this, 'PharmaAPI', {
      restApiName: `pharma-ci-api-${environment}`,
      description: 'Pharmaceutical CI Platform API',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: ['Content-Type', 'X-Amz-Date', 'Authorization', 'X-Api-Key'],
      },
    });

    // API Routes
    const chatbotIntegration = new apigateway.LambdaIntegration(chatbotFunction);
    const dashboardIntegration = new apigateway.LambdaIntegration(dashboardFunction);

    api.root.addResource('chat').addMethod('POST', chatbotIntegration);
    api.root.addResource('dashboard').addMethod('GET', dashboardIntegration);

    // EventBridge for scheduled data ingestion
    const dataIngestionRule = new events.Rule(this, 'DataIngestionRule', {
      schedule: events.Schedule.rate(cdk.Duration.hours(6)),
      description: 'Trigger data ingestion every 6 hours',
    });

    dataIngestionRule.addTarget(new targets.LambdaFunction(dataIngestionFunction));

    this.apiUrl = api.url;

    // Outputs
    new cdk.CfnOutput(this, 'APIEndpoint', {
      value: api.url,
      exportName: `${this.stackName}-APIEndpoint`,
    });

    new cdk.CfnOutput(this, 'DataIngestionFunctionName', {
      value: dataIngestionFunction.functionName,
      exportName: `${this.stackName}-DataIngestionFunction`,
    });

    new cdk.CfnOutput(this, 'ChatbotFunctionName', {
      value: chatbotFunction.functionName,
      exportName: `${this.stackName}-ChatbotFunction`,
    });
  }
}