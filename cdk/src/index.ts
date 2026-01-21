import * as cdk from 'aws-cdk-lib';
import { PharmaciStack } from './stacks/pharmaci-stack';

const app = new cdk.App();

const environment = app.node.tryGetContext('environment') || 'dev';
const region = app.node.tryGetContext('region') || 'us-east-1';

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: region,
};

// ============================================
// Core Infrastructure Stack (Minimal)
// ============================================
const mainStack = new PharmaciStack(app, `pharma-ci-platform-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Core Infrastructure',
});

app.synth();
