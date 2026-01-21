import * as cdk from 'aws-cdk-lib';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as ses from 'aws-cdk-lib/aws-ses';
import { Construct } from 'constructs';

interface EventProcessingStackProps extends cdk.StackProps {
  environment: string;
}

export class EventProcessingStack extends cdk.Stack {
  public readonly ingestionQueue: sqs.Queue;
  public readonly processingQueue: sqs.Queue;
  public readonly lambdaRole: iam.Role;

  constructor(scope: Construct, id: string, props: EventProcessingStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // ============================================
    // SQS Queues
    // ============================================
    this.ingestionQueue = new sqs.Queue(this, 'IngestionQueue', {
      queueName: `ci-ingestion-queue-${environment}`,
      visibilityTimeout: cdk.Duration.minutes(15),
      messageRetentionPeriod: cdk.Duration.days(4),
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    this.processingQueue = new sqs.Queue(this, 'ProcessingQueue', {
      queueName: `ci-processing-queue-${environment}`,
      visibilityTimeout: cdk.Duration.minutes(10),
      messageRetentionPeriod: cdk.Duration.days(4),
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // ============================================
    // IAM Role for Lambda
    // ============================================
    this.lambdaRole = new iam.Role(this, 'EventProcessingLambdaRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    // SQS permissions
    this.lambdaRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'sqs:ReceiveMessage',
          'sqs:DeleteMessage',
          'sqs:GetQueueAttributes',
          'sqs:SendMessage',
        ],
        resources: [
          this.ingestionQueue.queueArn,
          this.processingQueue.queueArn,
        ],
      })
    );

    // Bedrock permissions
    this.lambdaRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeAgent',
        ],
        resources: ['*'],
      })
    );

    // SES permissions for email
    this.lambdaRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'ses:SendEmail',
          'ses:SendRawEmail',
        ],
        resources: ['*'],
      })
    );

    // ============================================
    // EventBridge Rules
    // ============================================

    // Rule 1: PubMed Ingestion (Midnight)
    new events.Rule(this, 'PubMedIngestionRule', {
      ruleName: `ci-pubmed-ingestion-${environment}`,
      schedule: events.Schedule.cron({
        hour: '0',
        minute: '0',
      }),
      description: 'Trigger PubMed data ingestion at midnight',
    }).addTarget(
      new targets.SqsQueue(this.ingestionQueue, {
        message: events.RuleTargetInput.fromObject({
          source: 'pubmed',
          action: 'ingest',
          timestamp: events.EventField.fromPath('$.time'),
        }),
      })
    );

    // Rule 2: Digest Generation (9 AM)
    new events.Rule(this, 'DigestGenerationRule', {
      ruleName: `ci-digest-generation-${environment}`,
      schedule: events.Schedule.cron({
        hour: '9',
        minute: '0',
      }),
      description: 'Trigger digest generation and email at 9 AM',
    }).addTarget(
      new targets.SqsQueue(this.processingQueue, {
        message: events.RuleTargetInput.fromObject({
          source: 'digest',
          action: 'generate',
          timestamp: events.EventField.fromPath('$.time'),
        }),
      })
    );

    // ============================================
    // Lambda Functions for Event Processing
    // ============================================

    // PubMed Ingestion Lambda
    const pubmedIngestionLambda = new lambda.Function(this, 'PubMedIngestionLambda', {
      functionName: `ci-pubmed-ingestion-${environment}`,
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.lambda_handler',
      role: this.lambdaRole,
      timeout: cdk.Duration.minutes(15),
      memorySize: 2048,
      code: lambda.Code.fromInline(`
import json
import boto3
import requests
from datetime import datetime, timedelta

bedrock = boto3.client('bedrock-runtime')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    # Fetch PubMed data
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y/%m/%d')
    query = f'pharmaceutical AND competitive AND {yesterday}'
    
    # Call PubMed API
    response = requests.get(
        'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi',
        params={
            'db': 'pubmed',
            'term': query,
            'retmax': 100,
            'rettype': 'json'
        }
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps('PubMed ingestion completed')
    }
      `),
      environment: {
        ENVIRONMENT: environment,
      },
    });

    // Digest Generation Lambda
    const digestLambda = new lambda.Function(this, 'DigestLambda', {
      functionName: `ci-digest-generation-${environment}`,
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.lambda_handler',
      role: this.lambdaRole,
      timeout: cdk.Duration.minutes(10),
      memorySize: 1024,
      code: lambda.Code.fromInline(`
import json
import boto3
from datetime import datetime

bedrock = boto3.client('bedrock-runtime')
ses = boto3.client('ses')

def lambda_handler(event, context):
    # Generate digest using Claude 3.5 Haiku
    prompt = "Generate a competitive intelligence digest for pharmaceutical companies"
    
    response = bedrock.invoke_model(
        modelId='anthropic.claude-3-5-haiku-20241022-v1:0',
        body=json.dumps({
            'anthropic_version': 'bedrock-2023-06-01',
            'max_tokens': 2048,
            'messages': [
                {
                    'role': 'user',
                    'content': prompt
                }
            ]
        })
    )
    
    digest = json.loads(response['body'].read())['content'][0]['text']
    
    # Send email
    ses.send_email(
        Source='noreply@pharma-ci.com',
        Destination={'ToAddresses': ['analyst@pharma-ci.com']},
        Message={
            'Subject': {'Data': 'Daily CI Digest'},
            'Body': {'Html': {'Data': digest}}
        }
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Digest sent successfully')
    }
      `),
      environment: {
        ENVIRONMENT: environment,
      },
    });

    // Event source mapping for SQS
    pubmedIngestionLambda.addEventSourceMapping('PubMedQueueMapping', {
      eventSourceArn: this.ingestionQueue.queueArn,
      batchSize: 10,
    });

    digestLambda.addEventSourceMapping('DigestQueueMapping', {
      eventSourceArn: this.processingQueue.queueArn,
      batchSize: 1,
    });

    // ============================================
    // Outputs
    // ============================================
    new cdk.CfnOutput(this, 'IngestionQueueUrl', {
      value: this.ingestionQueue.queueUrl,
      exportName: `${this.stackName}-IngestionQueueUrl`,
    });

    new cdk.CfnOutput(this, 'ProcessingQueueUrl', {
      value: this.processingQueue.queueUrl,
      exportName: `${this.stackName}-ProcessingQueueUrl`,
    });

    new cdk.CfnOutput(this, 'PubMedIngestionLambda', {
      value: pubmedIngestionLambda.functionName,
      exportName: `${this.stackName}-PubMedIngestionLambda`,
    });

    new cdk.CfnOutput(this, 'DigestLambda', {
      value: digestLambda.functionName,
      exportName: `${this.stackName}-DigestLambda`,
    });
  }
}
