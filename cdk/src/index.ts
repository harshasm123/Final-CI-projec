import * as cdk from 'aws-cdk-lib';
import { MinimalStack } from './stacks/minimal-stack';

const app = new cdk.App();

const environment = app.node.tryGetContext('environment') || 'dev';
const region = app.node.tryGetContext('region') || 'us-west-2';

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: region,
};

// Deploy only minimal stack
new MinimalStack(app, `pharma-ci-platform-${environment}`, {
  env,
  environment,
  description: 'Pharmaceutical CI Platform - Minimal Stack',
});

app.synth();
