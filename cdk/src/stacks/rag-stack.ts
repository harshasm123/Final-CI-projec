import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
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
      bucketName: `ci-knowledge-base-${environment}-${this.account}`,
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Bedrock Agent Role
    const bedrockRole = new iam.Role(this, 'BedrockAgentRole', {
      assumedBy: new iam.ServicePrincipal('bedrock.amazonaws.com'),
      description: 'Role for Bedrock Agent',
    });

    // Grant Bedrock permissions to S3
    knowledgeBaseBucket.grantRead(bedrockRole);

    // Grant Bedrock model invocation permissions
    bedrockRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeModelWithResponseStream',
        ],
        resources: [
          `arn:aws:bedrock:${this.region}::foundation-model/anthropic.claude-3-5-haiku-20241022-v1:0`,
          `arn:aws:bedrock:${this.region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0`,
          `arn:aws:bedrock:${this.region}::foundation-model/amazon.titan-embed-text-v1`,
        ],
      })
    );

    // Outputs
    new cdk.CfnOutput(this, 'KnowledgeBaseBucketOutput', {
      value: knowledgeBaseBucket.bucketName,
      exportName: `${this.stackName}-KnowledgeBaseBucket`,
    });

    new cdk.CfnOutput(this, 'BedrockRoleArnOutput', {
      value: bedrockRole.roleArn,
      exportName: `${this.stackName}-BedrockRoleArn`,
    });
  }
}
