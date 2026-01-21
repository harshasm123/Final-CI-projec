import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as elasticsearch from 'aws-cdk-lib/aws-elasticsearch';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

interface PharmaciStackProps extends cdk.StackProps {
  environment: string;
}

export class PharmaciStack extends cdk.Stack {
  public readonly dataLakeBucket: s3.Bucket;
  public readonly processedDataBucket: s3.Bucket;
  public readonly metadataBucket: s3.Bucket;
  public readonly conversationTable: dynamodb.Table;
  public readonly lambdaExecutionRole: iam.Role;
  public readonly alertTopic: sns.Topic;
  public readonly apiEndpoint: string;

  constructor(scope: Construct, id: string, props: PharmaciStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // ============================================
    // S3 Buckets
    // ============================================
    this.dataLakeBucket = new s3.Bucket(this, 'DataLakeBucket', {
      bucketName: `ci-alert-datalake-${environment}-${this.account}`,
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      lifecycleRules: [
        {
          transitions: [
            {
              storageClass: s3.StorageClass.INTELLIGENT_TIERING,
              transitionAfter: cdk.Duration.days(30),
            },
            {
              storageClass: s3.StorageClass.GLACIER,
              transitionAfter: cdk.Duration.days(90),
            },
          ],
        },
      ],
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    this.processedDataBucket = new s3.Bucket(this, 'ProcessedDataBucket', {
      bucketName: `ci-alert-processed-${environment}-${this.account}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    this.metadataBucket = new s3.Bucket(this, 'MetadataBucket', {
      bucketName: `ci-metadata-${environment}-${this.account}`,
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // ============================================
    // DynamoDB Table for Conversations
    // ============================================
    this.conversationTable = new dynamodb.Table(this, 'ConversationTable', {
      tableName: `ci-chatbot-conversations-${environment}`,
      partitionKey: { name: 'conversationId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      stream: dynamodb.StreamSpecification.NEW_AND_OLD_IMAGES,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      timeToLiveAttribute: 'ttl',
    });

    // GSI for user queries
    this.conversationTable.addGlobalSecondaryIndex({
      indexName: 'UserIdIndex',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // ============================================
    // SNS Topic for Alerts
    // ============================================
    this.alertTopic = new sns.Topic(this, 'AlertTopic', {
      topicName: `ci-alerts-${environment}`,
      displayName: 'CI Alert System Notifications',
    });

    // ============================================
    // Elasticsearch Domain
    // ============================================
    const esDomain = new elasticsearch.Domain(this, 'SearchDomain', {
      domainName: `ci-search-${environment}`,
      version: elasticsearch.ElasticsearchVersion.V7_10,
      capacity: {
        dataNodes: 1,
        dataNodeInstanceType: 't3.small.elasticsearch',
      },
      ebs: {
        enabled: true,
        volumeSize: 20,
        volumeType: ec2.EbsDeviceVolumeType.GP2,
      },
      encryptionAtRest: {
        enabled: true,
      },
      nodeToNodeEncryption: true,
      enforceHttps: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // ============================================
    // IAM Role for Lambda
    // ============================================
    this.lambdaExecutionRole = new iam.Role(this, 'LambdaExecutionRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    // S3 permissions
    this.lambdaExecutionRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['s3:GetObject', 's3:PutObject', 's3:DeleteObject', 's3:ListBucket'],
        resources: [
          this.dataLakeBucket.bucketArn,
          this.dataLakeBucket.arnForObjects('*'),
          this.processedDataBucket.bucketArn,
          this.processedDataBucket.arnForObjects('*'),
          this.metadataBucket.bucketArn,
          this.metadataBucket.arnForObjects('*'),
        ],
      })
    );

    // Elasticsearch permissions
    this.lambdaExecutionRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['es:ESHttpPost', 'es:ESHttpPut', 'es:ESHttpGet', 'es:ESHttpDelete'],
        resources: [`arn:aws:es:${this.region}:${this.account}:domain/ci-search-${environment}/*`],
      })
    );

    // Bedrock permissions
    this.lambdaExecutionRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeAgent',
          'bedrock:Retrieve',
          'bedrock:RetrieveAndGenerate',
        ],
        resources: ['*'],
      })
    );

    this.lambdaExecutionRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['bedrock-agent-runtime:InvokeAgent'],
        resources: ['*'],
      })
    );

    // SNS permissions
    this.lambdaExecutionRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['sns:Publish'],
        resources: [this.alertTopic.topicArn],
      })
    );

    // DynamoDB permissions
    this.lambdaExecutionRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'dynamodb:GetItem',
          'dynamodb:PutItem',
          'dynamodb:UpdateItem',
          'dynamodb:Query',
          'dynamodb:Scan',
        ],
        resources: [
          this.conversationTable.tableArn,
          `${this.conversationTable.tableArn}/index/*`,
        ],
      })
    );

    // Secrets Manager permissions
    this.lambdaExecutionRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['secretsmanager:GetSecretValue'],
        resources: [`arn:aws:secretsmanager:${this.region}:${this.account}:secret:ci-*`],
      })
    );

    // EventBridge permissions
    this.lambdaExecutionRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['events:PutEvents'],
        resources: ['*'],
      })
    );

    // ============================================
    // Lambda Functions
    // ============================================
    const lambdaFunctions = this.createLambdaFunctions(environment);

    // ============================================
    // API Gateway
    // ============================================
    const api = new apigateway.RestApi(this, 'RestAPI', {
      restApiName: `ci-alert-api-${environment}`,
      description: 'CI Alert System API',
      deployOptions: {
        stageName: environment,
      },
    });

    // Proxy resource for all paths
    const proxyResource = api.root.addResource('{proxy+}');
    proxyResource.addMethod('ANY', new apigateway.LambdaIntegration(lambdaFunctions.apiFunction));

    this.apiEndpoint = api.url;

    // ============================================
    // Outputs
    // ============================================
    new cdk.CfnOutput(this, 'APIEndpoint', {
      value: this.apiEndpoint,
      exportName: `${this.stackName}-APIEndpoint`,
    });

    new cdk.CfnOutput(this, 'DataLakeBucket', {
      value: this.dataLakeBucket.bucketName,
      exportName: `${this.stackName}-DataLakeBucket`,
    });

    new cdk.CfnOutput(this, 'SearchDomain', {
      value: esDomain.domainEndpoint,
      exportName: `${this.stackName}-SearchDomain`,
    });
  }

  private createLambdaFunctions(environment: string) {
    const functions: { [key: string]: lambda.Function } = {};

    const lambdaConfigs = [
      {
        name: 'ComprehensiveDataIngestion',
        handler: 'comprehensive_data_ingestion.lambda_handler',
        timeout: 900,
        memory: 2048,
      },
      {
        name: 'DataQualityPipeline',
        handler: 'data_quality_pipeline.lambda_handler',
        timeout: 600,
        memory: 1024,
      },
      {
        name: 'DataIngestion',
        handler: 'data_ingestion.lambda_handler',
        timeout: 900,
        memory: 1024,
      },
      {
        name: 'ProcessDocument',
        handler: 'document_processor.lambda_handler',
        timeout: 900,
        memory: 3008,
      },
      {
        name: 'AIHandler',
        handler: 'handlers.ai_handler.lambda_handler',
        timeout: 300,
        memory: 2048,
      },
      {
        name: 'AlertHandler',
        handler: 'handlers.alert_handler.lambda_handler',
        timeout: 60,
        memory: 512,
      },
      {
        name: 'CompetitiveAnalysis',
        handler: 'handlers.competitive_analysis.lambda_handler',
        timeout: 300,
        memory: 2048,
      },
      {
        name: 'BrandHandler',
        handler: 'handlers.brand_handler.lambda_handler',
        timeout: 120,
        memory: 1024,
      },
      {
        name: 'DashboardHandler',
        handler: 'handlers.dashboard_handler.lambda_handler',
        timeout: 60,
        memory: 512,
      },
      {
        name: 'DataQualityCheck',
        handler: 'handlers.data_quality.lambda_handler',
        timeout: 300,
        memory: 1024,
      },
      {
        name: 'ChatbotHandler',
        handler: 'handlers.chatbot_handler.lambda_handler',
        timeout: 120,
        memory: 2048,
      },
      {
        name: 'API',
        handler: 'lambda_function.lambda_handler',
        timeout: 30,
        memory: 512,
      },
    ];

    for (const config of lambdaConfigs) {
      functions[config.name] = new lambda.Function(this, `${config.name}Function`, {
        functionName: `ci-${config.name.toLowerCase()}-${environment}`,
        runtime: lambda.Runtime.PYTHON_3_11,
        handler: config.handler,
        role: this.lambdaExecutionRole,
        timeout: cdk.Duration.seconds(config.timeout),
        memorySize: config.memory,
        code: lambda.Code.fromAsset('../backend/src'),
        environment: {
          ENVIRONMENT: environment,
        },
      });
    }

    return functions;
  }
}
