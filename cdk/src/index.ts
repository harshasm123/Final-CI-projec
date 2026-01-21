import * as cdk from 'aws-cdk-lib';
import { MinimalStack } from './stacks/minimal-stack';
import { RAGStack } from './stacks/rag-stack';
import { FrontendSimpleStack } from './stacks/frontend-simple-stack';

const app = new cdk.App();

const environment = app.node.tryGetContext('environment') || 'dev';
const region = app.node.tryGetContext('region') || 'us-east-1';

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: region,
};

// Core Infrastructure Stack
const coreStack = new MinimalStack(app, `pharma-ci-platform-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Core Infrastructure',
});

// RAG Stack (Bedrock + Knowledge Base)
const ragStack = new RAGStack(app, `pharma-ci-rag-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - RAG & Bedrock',
});

// Frontend Stack (S3 + CloudFront)
const frontendStack = new FrontendSimpleStack(app, `pharma-ci-frontend-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Frontend',
});

// Dependencies
ragStack.addDependency(coreStack);
frontendStack.addDependency(coreStack);

app.synth();
