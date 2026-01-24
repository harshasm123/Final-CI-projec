import * as cdk from 'aws-cdk-lib';
import { DataStack } from './stacks/data-stack';
import { ComputeStack } from './stacks/compute-stack';
import { FrontendStack } from './stacks/frontend-stack';

const app = new cdk.App();

const environment = app.node.tryGetContext('environment') || 'dev';
const region = app.node.tryGetContext('region') || 'us-east-1';

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: region,
};

const stackPrefix = `pharma-ci-${environment}`;

// Data Layer Stack (S3, DynamoDB, OpenSearch)
const dataStack = new DataStack(app, `${stackPrefix}-data`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Data Layer',
});

// Compute Stack (Lambda, API Gateway, Bedrock)
const computeStack = new ComputeStack(app, `${stackPrefix}-compute`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Compute Layer',
  dataBucket: dataStack.dataBucket,
  knowledgeBucket: dataStack.knowledgeBucket,
  conversationTable: dataStack.conversationTable,
  searchDomain: dataStack.searchDomain,
});

// Frontend Stack (S3 + CloudFront)
const frontendStack = new FrontendStack(app, `${stackPrefix}-frontend`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Frontend',
  apiUrl: computeStack.apiUrl,
});

// Dependencies
computeStack.addDependency(dataStack);
frontendStack.addDependency(computeStack);

app.synth();
