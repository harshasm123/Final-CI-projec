import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

interface RAGStackProps extends cdk.StackProps {
  environment: string;
}

export class RAGStack extends cdk.Stack {
  public readonly knowledgeBaseBucket: s3.Bucket;
  public readonly bedrockRagRole: iam.Role;

  constructor(scope: Construct, id: string, props: RAGStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // ============================================
    // S3 Bucket for Knowledge Base
    // ============================================
    this.knowledgeBaseBucket = new s3.Bucket(this, 'KnowledgeBaseBucket', {
      bucketName: `ci-knowledge-base-${environment}-${this.account}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
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
    });

    // ============================================
    // IAM Role for Bedrock RAG
    // ============================================
    this.bedrockRagRole = new iam.Role(this, 'BedrockRAGRole', {
      assumedBy: new iam.ServicePrincipal('bedrock.amazonaws.com'),
      description: 'Role for Bedrock RAG with Knowledge Base access',
    });

    // S3 access for knowledge base
    this.bedrockRagRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          's3:GetObject',
          's3:ListBucket',
          's3:GetBucketLocation',
        ],
        resources: [
          this.knowledgeBaseBucket.bucketArn,
          this.knowledgeBaseBucket.arnForObjects('*'),
        ],
      })
    );

    // Bedrock model invocation
    this.bedrockRagRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeModelWithResponseStream',
        ],
        resources: ['*'],
      })
    );

    // ============================================
    // Outputs
    // ============================================
    new cdk.CfnOutput(this, 'KnowledgeBaseBucket', {
      value: this.knowledgeBaseBucket.bucketName,
      exportName: `${this.stackName}-KnowledgeBaseBucket`,
    });

    new cdk.CfnOutput(this, 'BedrockRAGRoleArn', {
      value: this.bedrockRagRole.roleArn,
      exportName: `${this.stackName}-BedrockRAGRoleArn`,
    });

    new cdk.CfnOutput(this, 'KnowledgeBaseUploadCommand', {
      value: `aws s3 cp your-documents/ s3://${this.knowledgeBaseBucket.bucketName}/ --recursive`,
      exportName: `${this.stackName}-KnowledgeBaseUploadCommand`,
    });
  }
}
