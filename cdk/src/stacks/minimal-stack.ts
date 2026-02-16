import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as opensearch from 'aws-cdk-lib/aws-opensearchservice';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

interface MinimalStackProps extends cdk.StackProps {
  environment: string;
}

export class MinimalStack extends cdk.Stack {
  public readonly api: apigateway.RestApi;
  public readonly dataLakeBucket: s3.Bucket;
  
  constructor(scope: Construct, id: string, props: MinimalStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // ============================================
    // S3 Data Lake Bucket
    // ============================================
    this.dataLakeBucket = new s3.Bucket(this, 'DataLakeBucket', {
      bucketName: `ci-data-${environment}-${this.account}`,
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      lifecycleRules: [
        {
          transitions: [
            {
              storageClass: s3.StorageClass.INTELLIGENT_TIERING,
              transitionAfter: cdk.Duration.days(30),
            },
          ],
        },
      ],
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // ============================================
    // DynamoDB Tables
    // ============================================
    const conversationTable = new dynamodb.Table(this, 'ConversationTable', {
      tableName: `ci-conversations-${environment}`,
      partitionKey: { name: 'conversationId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'timestamp', type: dynamodb.AttributeType.NUMBER },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const insightsTable = new dynamodb.Table(this, 'InsightsTable', {
      tableName: `ci-insights-${environment}`,
      partitionKey: { name: 'insightId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.NUMBER },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    insightsTable.addGlobalSecondaryIndex({
      indexName: 'CategoryIndex',
      partitionKey: { name: 'category', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.NUMBER },
    });

    const watchlistTable = new dynamodb.Table(this, 'WatchlistTable', {
      tableName: `ci-watchlist-${environment}`,
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'itemId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // ============================================
    // OpenSearch Domain
    // ============================================
    const searchDomain = new opensearch.Domain(this, 'SearchDomain', {
      version: opensearch.EngineVersion.OPENSEARCH_2_11,
      domainName: `ci-search-${environment}`,
      capacity: {
        dataNodes: 1,
        dataNodeInstanceType: 't3.small.search',
      },
      ebs: {
        volumeSize: 10,
        volumeType: ec2.EbsDeviceVolumeType.GP3,
      },
      zoneAwareness: {
        enabled: false,
      },
      logging: {
        slowSearchLogEnabled: true,
        appLogEnabled: true,
        slowIndexLogEnabled: true,
      },
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // ============================================
    // Lambda Execution Role
    // ============================================
    const lambdaRole = new iam.Role(this, 'LambdaExecutionRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    // Grant permissions
    this.dataLakeBucket.grantReadWrite(lambdaRole);
    conversationTable.grantReadWriteData(lambdaRole);
    insightsTable.grantReadWriteData(lambdaRole);
    watchlistTable.grantReadWriteData(lambdaRole);

    // OpenSearch permissions
    lambdaRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['es:*'],
        resources: [searchDomain.domainArn, `${searchDomain.domainArn}/*`],
      })
    );

    // Bedrock permissions
    lambdaRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeModelWithResponseStream',
          'bedrock:InvokeAgent',
        ],
        resources: ['*'],
      })
    );

    // Secrets Manager permissions
    lambdaRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['secretsmanager:GetSecretValue'],
        resources: [`arn:aws:secretsmanager:${this.region}:${this.account}:secret:ci-*`],
      })
    );

    // ============================================
    // Lambda Functions
    // ============================================
    
    // AI Handler Lambda
    const aiHandler = new lambda.Function(this, 'AIHandler', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.handler',
      role: lambdaRole,
      code: lambda.Code.fromInline(`
import json
import boto3
import os
from datetime import datetime

bedrock = boto3.client('bedrock-runtime')
dynamodb = boto3.resource('dynamodb')

CONVERSATION_TABLE = os.environ['CONVERSATION_TABLE']
INSIGHTS_TABLE = os.environ['INSIGHTS_TABLE']

def handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        query = body.get('query', '')
        conversation_id = body.get('conversationId', f"conv-{datetime.now().timestamp()}")
        
        # Invoke Bedrock Claude
        response = bedrock.invoke_model(
            modelId='anthropic.claude-3-sonnet-20240229-v1:0',
            body=json.dumps({
                'anthropic_version': 'bedrock-2023-05-31',
                'max_tokens': 2000,
                'messages': [{
                    'role': 'user',
                    'content': query
                }]
            })
        )
        
        result = json.loads(response['body'].read())
        ai_response = result['content'][0]['text']
        
        # Store conversation
        table = dynamodb.Table(CONVERSATION_TABLE)
        table.put_item(Item={
            'conversationId': conversation_id,
            'timestamp': int(datetime.now().timestamp()),
            'query': query,
            'response': ai_response,
            'model': 'claude-3-sonnet'
        })
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'conversationId': conversation_id,
                'response': ai_response
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
      `),
      environment: {
        ENVIRONMENT: environment,
        CONVERSATION_TABLE: conversationTable.tableName,
        INSIGHTS_TABLE: insightsTable.tableName,
        BUCKET_NAME: this.dataLakeBucket.bucketName,
      },
      timeout: cdk.Duration.seconds(30),
      memorySize: 512,
      logRetention: logs.RetentionDays.ONE_WEEK,
    });

    // Dashboard Handler Lambda
    const dashboardHandler = new lambda.Function(this, 'DashboardHandler', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.handler',
      role: lambdaRole,
      code: lambda.Code.fromInline(`
import json
import boto3
import os
from datetime import datetime, timedelta
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')

INSIGHTS_TABLE = os.environ['INSIGHTS_TABLE']

def handler(event, context):
    try:
        table = dynamodb.Table(INSIGHTS_TABLE)
        
        # Get recent insights
        seven_days_ago = int((datetime.now() - timedelta(days=7)).timestamp())
        
        response = table.scan(
            FilterExpression=Key('createdAt').gte(seven_days_ago),
            Limit=50
        )
        
        insights = response.get('Items', [])
        
        # Aggregate by category
        categories = {}
        for insight in insights:
            cat = insight.get('category', 'Other')
            categories[cat] = categories.get(cat, 0) + 1
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'totalInsights': len(insights),
                'categories': categories,
                'recentInsights': insights[:10]
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
      `),
      environment: {
        ENVIRONMENT: environment,
        INSIGHTS_TABLE: insightsTable.tableName,
      },
      timeout: cdk.Duration.seconds(15),
      memorySize: 256,
      logRetention: logs.RetentionDays.ONE_WEEK,
    });

    // Data Ingestion Lambda
    const dataIngestionHandler = new lambda.Function(this, 'DataIngestionHandler', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.handler',
      role: lambdaRole,
      code: lambda.Code.fromInline(`
import json
import boto3
import os
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ['BUCKET_NAME']
INSIGHTS_TABLE = os.environ['INSIGHTS_TABLE']

def handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        data_type = body.get('type', 'general')
        content = body.get('content', {})
        
        # Store in S3
        timestamp = datetime.now().isoformat()
        s3_key = f"ingestion/{data_type}/{timestamp}.json"
        
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key,
            Body=json.dumps(content),
            ContentType='application/json'
        )
        
        # Store metadata in DynamoDB
        table = dynamodb.Table(INSIGHTS_TABLE)
        insight_id = f"{data_type}-{int(datetime.now().timestamp())}"
        
        table.put_item(Item={
            'insightId': insight_id,
            'createdAt': int(datetime.now().timestamp()),
            'category': data_type,
            's3Key': s3_key,
            'status': 'ingested'
        })
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'insightId': insight_id,
                's3Key': s3_key,
                'message': 'Data ingested successfully'
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
      `),
      environment: {
        ENVIRONMENT: environment,
        BUCKET_NAME: this.dataLakeBucket.bucketName,
        INSIGHTS_TABLE: insightsTable.tableName,
      },
      timeout: cdk.Duration.seconds(30),
      memorySize: 512,
      logRetention: logs.RetentionDays.ONE_WEEK,
    });

    // Health Check Lambda
    const healthHandler = new lambda.Function(this, 'HealthHandler', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.handler',
      role: lambdaRole,
      code: lambda.Code.fromInline(`
import json
from datetime import datetime

def handler(event, context):
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'service': 'Pharmaceutical CI Platform'
        })
    }
      `),
      environment: {
        ENVIRONMENT: environment,
      },
      timeout: cdk.Duration.seconds(5),
      memorySize: 128,
      logRetention: logs.RetentionDays.ONE_WEEK,
    });

    // ============================================
    // API Gateway
    // ============================================
    this.api = new apigateway.RestApi(this, 'API', {
      restApiName: `ci-api-${environment}`,
      description: 'Pharmaceutical CI Platform API',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: ['Content-Type', 'Authorization'],
      },
      deployOptions: {
        stageName: 'prod',
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
    });

    // Health endpoint
    const health = this.api.root.addResource('health');
    health.addMethod('GET', new apigateway.LambdaIntegration(healthHandler));

    // AI endpoint
    const ai = this.api.root.addResource('ai');
    ai.addMethod('POST', new apigateway.LambdaIntegration(aiHandler));

    // Dashboard endpoint
    const dashboard = this.api.root.addResource('dashboard');
    dashboard.addMethod('GET', new apigateway.LambdaIntegration(dashboardHandler));

    // Ingestion endpoint
    const ingest = this.api.root.addResource('ingest');
    ingest.addMethod('POST', new apigateway.LambdaIntegration(dataIngestionHandler));

    // ============================================
    // Outputs
    // ============================================
    new cdk.CfnOutput(this, 'APIEndpointOutput', {
      value: this.api.url,
      exportName: `${this.stackName}-APIEndpoint`,
      description: 'API Gateway endpoint URL',
    });

    new cdk.CfnOutput(this, 'DataLakeBucketOutput', {
      value: this.dataLakeBucket.bucketName,
      exportName: `${this.stackName}-DataLakeBucket`,
      description: 'S3 Data Lake bucket name',
    });

    new cdk.CfnOutput(this, 'ConversationTableOutput', {
      value: conversationTable.tableName,
      exportName: `${this.stackName}-ConversationTable`,
      description: 'DynamoDB Conversation table name',
    });

    new cdk.CfnOutput(this, 'InsightsTableOutput', {
      value: insightsTable.tableName,
      exportName: `${this.stackName}-InsightsTable`,
      description: 'DynamoDB Insights table name',
    });

    new cdk.CfnOutput(this, 'SearchDomainOutput', {
      value: searchDomain.domainEndpoint,
      exportName: `${this.stackName}-SearchDomain`,
      description: 'OpenSearch domain endpoint',
    });
  }
}
