# Pharmaceutical CI Platform - AWS CDK

Complete Infrastructure as Code for the Pharmaceutical Competitive Intelligence Platform using AWS CDK.

## Prerequisites

- Node.js 18+ and npm
- AWS CLI configured with credentials
- AWS CDK CLI: `npm install -g aws-cdk`
- AWS account with appropriate permissions

## Project Structure

```
cdk/
├── src/
│   ├── index.ts                 # Main CDK app entry point
│   └── stacks/
│       ├── pharmaci-stack.ts    # Main infrastructure stack
│       ├── bedrock-agent-stack.ts # Bedrock Agent configuration
│       └── eventbridge-stack.ts # EventBridge scheduling rules
├── package.json                 # Dependencies
├── tsconfig.json               # TypeScript configuration
├── cdk.json                    # CDK configuration
└── deploy.sh                   # Deployment script
```

## Quick Start

### 1. Install Dependencies

```bash
cd cdk
npm install
```

### 2. Build TypeScript

```bash
npm run build
```

### 3. Synthesize CloudFormation

```bash
npm run synth -- --context environment=dev --context region=us-east-1
```

### 4. Deploy Stacks

```bash
./deploy.sh dev us-east-1
```

Or manually:

```bash
npm run deploy -- --context environment=dev --context region=us-east-1 --require-approval never
```

## Available Commands

```bash
# Build TypeScript
npm run build

# Watch for changes
npm run watch

# Synthesize CloudFormation template
npm run synth

# Show infrastructure changes
npm run diff

# Deploy stacks
npm run deploy

# Destroy stacks
npm run destroy

# Run tests
npm run test
```

## Stacks

### 1. PharmaciStack (Main Infrastructure)

Deploys:
- **S3 Buckets**: Data Lake, Processed Data, Metadata
- **DynamoDB**: Conversation table for chatbot
- **Elasticsearch**: Search domain for competitive data
- **Lambda Functions**: 12 Lambda functions for data processing and analysis
- **IAM Roles**: Lambda execution role with all necessary permissions
- **API Gateway**: REST API for frontend and external integrations
- **SNS Topic**: Alert notifications

### 2. BedrockAgentStack

Deploys:
- **IAM Role**: For Bedrock Agent with model invocation permissions
- **Permissions**: Lambda invocation, CloudWatch logs

### 3. EventBridgeStack

Deploys:
- **EventBridge Rules**: 7 scheduled rules for:
  - Comprehensive data ingestion (every 6 hours)
  - Data quality checks (every 4 hours)
  - AI insights generation (every 8 hours)
  - Alert generation (every 2 hours)
  - Competitive analysis (every 12 hours)
  - Brand intelligence (every 24 hours)
  - Dashboard refresh (every 1 hour)

## Configuration

### Environment Variables

Set in `cdk.json` or via command line:

```bash
npm run deploy -- \
  --context environment=dev \
  --context region=us-east-1
```

### Supported Environments

- `dev` - Development environment
- `staging` - Staging environment
- `prod` - Production environment

### Supported Regions

- `us-east-1` (default)
- `us-west-2`
- `eu-west-1`
- Any AWS region with required services

## Deployment

### Development Deployment

```bash
./deploy.sh dev us-east-1
```

### Production Deployment

```bash
./deploy.sh prod us-east-1
```

### With Custom Region

```bash
./deploy.sh dev eu-west-1
```

## Outputs

After deployment, retrieve outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name pharma-ci-platform-dev \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

Key outputs:
- `APIEndpoint`: REST API URL
- `DataLakeBucket`: S3 bucket for raw data
- `SearchDomain`: Elasticsearch domain endpoint

## Cleanup

### Destroy All Stacks

```bash
npm run destroy -- --context environment=dev --context region=us-east-1
```

Or:

```bash
./deploy.sh dev us-east-1  # Then select destroy option
```

### Destroy Specific Stack

```bash
aws cloudformation delete-stack \
  --stack-name pharma-ci-platform-dev \
  --region us-east-1
```

## Troubleshooting

### CDK Not Found

```bash
npm install -g aws-cdk
```

### AWS Credentials Not Configured

```bash
aws configure
```

### Insufficient Permissions

Ensure your AWS user has permissions for:
- CloudFormation
- Lambda
- S3
- DynamoDB
- Elasticsearch
- API Gateway
- IAM
- EventBridge
- SNS

### Build Errors

```bash
npm run build
```

If errors persist:

```bash
rm -rf node_modules package-lock.json
npm install
npm run build
```

## Development

### Add New Stack

1. Create new file in `src/stacks/`
2. Extend `cdk.Stack`
3. Import in `src/index.ts`
4. Add to app

Example:

```typescript
// src/stacks/my-stack.ts
import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';

export class MyStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    // Add resources here
  }
}
```

### Add New Lambda Function

In `pharmaci-stack.ts`, add to `lambdaConfigs`:

```typescript
{
  name: 'MyFunction',
  handler: 'my_module.lambda_handler',
  timeout: 300,
  memory: 1024,
}
```

### Add New EventBridge Rule

In `eventbridge-stack.ts`:

```typescript
new events.Rule(this, 'MyRule', {
  ruleName: `ci-my-rule-${environment}`,
  schedule: events.Schedule.rate(cdk.Duration.hours(6)),
}).addTarget(
  new targets.LambdaFunction(myFunction)
);
```

## Best Practices

1. **Use Contexts**: Pass configuration via `--context` flags
2. **Separate Stacks**: Keep concerns separated (main, bedrock, eventbridge)
3. **Use Outputs**: Export important values for cross-stack references
4. **IAM Least Privilege**: Grant only necessary permissions
5. **Removal Policies**: Set appropriate removal policies for data resources
6. **Tagging**: Add tags for cost tracking and organization

## Cost Estimation

| Service | Monthly Cost |
|---------|--------------|
| Lambda | ~$20-50 |
| S3 | ~$10-20 |
| DynamoDB | ~$5-10 |
| Elasticsearch | ~$50-100 |
| API Gateway | ~$5-10 |
| **Total** | **~$90-190** |

## Support

For issues or questions:
1. Check AWS CDK docum