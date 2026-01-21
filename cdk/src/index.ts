import * as cdk from 'aws-cdk-lib';
import { PharmaciStack } from './stacks/pharmaci-stack';
import { BedrockAgentStack } from './stacks/bedrock-agent-stack';
import { EventBridgeStack } from './stacks/eventbridge-stack';

const app = new cdk.App();

const environment = app.node.tryGetContext('environment') || 'dev';
const region = app.node.tryGetContext('region') || 'us-east-1';

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: region,
};

// Main infrastructure stack
const mainStack = new PharmaciStack(app, `pharma-ci-platform-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Main Infrastructure',
});

// Bedrock Agent stack
const bedrockStack = new BedrockAgentStack(app, `pharma-ci-bedrock-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Bedrock Agent',
});

// EventBridge stack
const eventBridgeStack = new EventBridgeStack(app, `pharma-ci-eventbridge-${environment}`, {
  env,
  environment,
  mainStackName: mainStack.stackName,
  description: 'Pharmaceutical CI Platform - EventBridge Rules',
});

// Stack dependencies
bedrockStack.addDependency(mainStack);
eventBridgeStack.addDependency(mainStack);

app.synth();
