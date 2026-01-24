import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as elasticsearch from 'aws-cdk-lib/aws-elasticsearch';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

interface DataStackProps extends cdk.StackProps {
  environment: string;
}

export class DataStack extends cdk.Stack {
  public readonly dataBucket: s3.Bucket;
  public readonly knowledgeBucket: s3.Bucket;
  public readonly conversationTable: dynamodb.Table;
  public readonly searchDomain: elasticsearch.Domain;

  constructor(scope: Construct, id: string, props: DataStackProps) {
    super(scope, id, props);

    const { environment } = props;

    // Data Storage Bucket
    this.dataBucket = new s3.Bucket(this, 'DataBucket', {
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      lifecycleRules: [{
        id: 'DeleteOldVersions',
        noncurrentVersionExpiration: cdk.Duration.days(30),
      }],
    });

    // Knowledge Base Bucket
    this.knowledgeBucket = new s3.Bucket(this, 'KnowledgeBucket', {
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Conversation History Table
    this.conversationTable = new dynamodb.Table(this, 'ConversationTable', {
      partitionKey: { name: 'conversationId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'timestamp', type: dynamodb.AttributeType.NUMBER },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pointInTimeRecovery: true,
    });

    // Elasticsearch Domain
    this.searchDomain = new elasticsearch.Domain(this, 'SearchDomain', {
      version: elasticsearch.ElasticsearchVersion.V7_10,
      capacity: {
        dataNodes: 1,
        dataNodeInstanceType: 't3.small.elasticsearch',
      },
      ebs: {
        volumeSize: 20,
        volumeType: cdk.aws_ec2.EbsDeviceVolumeType.GP3,
      },
      zoneAwareness: {
        enabled: false,
      },
      logging: {
        slowSearchLogEnabled: true,
        appLogEnabled: true,
        slowIndexLogEnabled: true,
      },
      nodeToNodeEncryption: true,
      encryptionAtRest: {
        enabled: true,
      },
      domainEndpointOptions: {
        enforceHttps: true,
      },
      accessPolicies: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          principals: [new iam.AnyPrincipal()],
          actions: ['es:*'],
          resources: ['*'],
        }),
      ],
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Outputs
    new cdk.CfnOutput(this, 'DataBucketName', {
      value: this.dataBucket.bucketName,
      exportName: `${this.stackName}-DataBucket`,
    });

    new cdk.CfnOutput(this, 'KnowledgeBucketName', {
      value: this.knowledgeBucket.bucketName,
      exportName: `${this.stackName}-KnowledgeBucket`,
    });

    new cdk.CfnOutput(this, 'ConversationTableName', {
      value: this.conversationTable.tableName,
      exportName: `${this.stackName}-ConversationTable`,
    });

    new cdk.CfnOutput(this, 'SearchDomainEndpoint', {
      value: this.searchDomain.domainEndpoint,
      exportName: `${this.stackName}-SearchDomain`,
    });
  }
}