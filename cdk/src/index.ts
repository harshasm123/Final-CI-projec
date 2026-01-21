import * as cdk from 'aws-cdk-lib';
import { PharmaciStack } from './stacks/pharmaci-stack';
import { BedrockAgentStack } from './stacks/bedrock-agent-stack';
import { EventBridgeStack } from './stacks/eventbridge-stack';
import { FrontendStack } from './stacks/frontend-stack';
import { AuthStack } from './stacks/auth-stack';
import { RAGStack } from './stacks/rag-stack';
import { EventProcessingStack } from './stacks/event-processing-stack';

const app = new cdk.App();

const environment = app.node.tryGetContext('environment') || 'dev';
const region = app.node.tryGetContext('region') || 'us-east-1';

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: region,
};

// ============================================
// Core Infrastructure Stack
// ============================================
const mainStack = new PharmaciStack(app, `pharma-ci-platform-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Main Infrastructure',
});

// ============================================
// Authentication Stack (Cognito)
// ============================================
const authStack = new AuthStack(app, `pharma-ci-auth-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Cognito Authentication',
});

// ============================================
// Frontend Stack (ECS Fargate + ALB)
// ============================================
const frontendStack = new FrontendStack(app, `pharma-ci-frontend-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - ECS Fargate Frontend',
});

// ============================================
// RAG Stack (Knowledge Base)
// ============================================
const ragStack = new RAGStack(app, `pharma-ci-rag-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Bedrock RAG Knowledge Base',
});

// ============================================
// Event Processing Stack (EventBridge + SQS + Lambda)
// ============================================
const eventProcessingStack = new EventProcessingStack(app, `pharma-ci-events-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Event-Driven Processing',
});

// ============================================
// Bedrock Agent Stack
// ============================================
const bedrockStack = new BedrockAgentStack(app, `pharma-ci-bedrock-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Bedrock Agent',
});

// ============================================
// EventBridge Stack
// ============================================
const eventBridgeStack = new EventBridgeStack(app, `pharma-ci-eventbridge-${environment}`, {
  env,
  environment,
  mainStackName: mainStack.stackName,
  description: 'Pharmaceutical CI Platform - EventBridge Rules',
});

// ============================================
// Stack Dependencies
// ============================================
authStack.addDependency(mainStack);
frontendStack.addDependency(mainStack);
frontendStack.addDependency(authStack);
ragStack.addDependency(mainStack);
eventProcessingStack.addDependency(mainStack);
bedrockStack.addDependency(mainStack);
bedrockStack.addDependency(ragStack);
eventBridgeStack.addDependency(mainStack);
eventBridgeStack.addDependency(eventProcessingStack);

app.synth();
