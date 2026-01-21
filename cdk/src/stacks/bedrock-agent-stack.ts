import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

interface BedrockAgentStackProps extends cdk.StackProps {
  environment: string;
}

export class BedrockAgentStack extends cdk.Stack {
  public readonly agentRoleArn: string;

  constructor(scope: Construct, id: string, props: BedrockAgentStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // ============================================
    // IAM Role for Bedrock Agent
    // ============================================
    const agentRole = new iam.Role(this, 'BedrockAgentRole', {
      assumedBy: new iam.ServicePrincipal('bedrock.amazonaws.com'),
      description: 'Role for Bedrock Agent in CI Platform',
    });

    // Bedrock model invocation permissions
    agentRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeModelWithResponseStream',
        ],
        resources: ['*'],
      })
    );

    // Lambda invocation for agent tools
    agentRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ['lambda:InvokeFunction'],
        resources: [`arn:aws:lambda:${this.region}:${this.account}:function:ci-*`],
      })
    );

    // CloudWatch logs
    agentRole.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: [
          'logs:CreateLogGroup',
          'logs:CreateLogStream',
          'logs:PutLogEvents',
        ],
        resources: [`arn:aws:logs:${this.region}:${this.account}:*`],
      })
    );

    this.agentRoleArn = agentRole.roleArn;

    // ============================================
    // Outputs
    // ============================================
    new cdk.CfnOutput(this, 'BedrockAgentRoleArn', {
      value: agentRole.roleArn,
      exportName: `${this.stackName}-BedrockAgentRoleArn`,
    });

    new cdk.CfnOutput(this, 'BedrockAgentRoleName', {
      value: agentRole.roleName,
      exportName: `${this.stackName}-BedrockAgentRoleName`,
    });
  }
}
