import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

interface RAGStackProps extends cdk.StackProps {
  environment: string;
}

export class RAGStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: RAGStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // Knowledge Base S3 Bucket
    const knowledgeBaseBucket = new s3.Bucket(this, 'KnowledgeBaseBucket', {
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // AI Lambda Function
    const aiFunction = new lambda.Function(this, 'AIFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'ai_handler.lambda_handler',
      code: lambda.Code.fromAsset('../backend/src/handlers'),
      timeout: cdk.Duration.seconds(30),
      environment: {
        KNOWLEDGE_BUCKET: knowledgeBaseBucket.bucketName,
      },
    });

    // Grant Bedrock permissions
    aiFunction.addToRolePolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeModelWithResponseStream',
        ],
        resources: [
          `arn:aws:bedrock:${this.region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0`,
          `arn:aws:bedrock:${this.region}::foundation-model/amazon.titan-embed-text-v1`,
        ],
      })
    );

    // Grant S3 permissions
    knowledgeBaseBucket.grantRead(aiFunction);

    // API Gateway
    const api = new apigateway.RestApi(this, 'AIAPI', {
      restApiName: `pharma-ci-ai-${environment}`,
      description: 'AI API for Pharmaceutical CI Platform',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
      },
    });

    const aiIntegration = new apigateway.LambdaIntegration(aiFunction);
    api.root.addResource('ai').addMethod('POST', aiIntegration);

    // Outputs
    new cdk.CfnOutput(this, 'KnowledgeBaseBucketOutput', {
      value: knowledgeBaseBucket.bucketName,
      exportName: `${this.stackName}-KnowledgeBaseBucket`,
    });

    new cdk.CfnOutput(this, 'AIAPIEndpoint', {
      value: api.url,
      exportName: `${this.stackName}-AIAPIEndpoint`,
    });
  }
}