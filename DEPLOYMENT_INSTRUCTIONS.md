# Deployment Instructions

Complete step-by-step guide to deploy the Pharmaceutical CI Platform.

## Prerequisites

- Linux or macOS (WSL on Windows)
- Internet connection
- AWS account with appropriate permissions
- ~30 minutes for first-time setup

## Quick Start (3 Steps)

```bash
# 1. Make scripts executable
chmod +x prereq.sh deploy.sh

# 2. Setup prerequisites (installs all required tools)
./prereq.sh

# 3. Deploy everything
./deploy.sh dev us-east-1
```

## Detailed Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/ci-alert-platform.git
cd ci-alert-platform
```

### Step 2: Run Prerequisites Setup

```bash
chmod +x prereq.sh
./prereq.sh
```

**What this does:**
- ✅ Installs AWS CLI v2
- ✅ Installs Node.js 20 LTS
- ✅ Installs Python 3
- ✅ Installs Docker
- ✅ Installs AWS CDK
- ✅ Installs Git
- ✅ Configures AWS credentials
- ✅ Verifies all tools
- ✅ Checks AWS access

**Output:**
```
✅ Prerequisites setup complete!
✅ AWS credentials valid
✅ All tools verified
```

### Step 3: Enable Bedrock Models

1. Go to [AWS Bedrock Console](https://console.aws.amazon.com/bedrock/home#/modelaccess)
2. Click "Model Access"
3. Request access to:
   - Claude 3.5 Haiku
   - Claude 3.5 Sonnet
4. Wait for approval (usually instant)

### Step 4: Deploy Infrastructure

```bash
chmod +x deploy.sh
./deploy.sh dev us-east-1
```

**Parameters:**
- `dev` - Environment (dev/staging/prod)
- `us-east-1` - AWS region

**What this does:**
- ✅ Verifies AWS credentials
- ✅ Deploys CDK stacks
- ✅ Creates ECS Fargate cluster
- ✅ Sets up Cognito authentication
- ✅ Creates API Gateway
- ✅ Deploys Lambda functions
- ✅ Creates DynamoDB tables
- ✅ Sets up Elasticsearch
- ✅ Configures EventBridge rules
- ✅ Creates SQS queues
- ✅ Deploys frontend

**Deployment Time:** 10-15 minutes

### Step 5: Access Your Application

After deployment completes, you'll see:

```
========================================
Deployment Complete!
========================================

Frontend:
  ALB DNS: ci-frontend-alb-dev-123456.us-east-1.elb.amazonaws.com
  Access at: http://ci-frontend-alb-dev-123456.us-east-1.elb.amazonaws.com

API Endpoint:
  https://api-id.execute-api.us-east-1.amazonaws.com/dev

Cognito:
  User Pool: ci-platform-dev
  Login URL: https://ci-platform-dev-123456.auth.us-east-1.amazoncognito.com/login
```

### Step 6: Configure API Keys

```bash
# FDA API
aws secretsmanager put-secret-value \
  --secret-id ci-fda-api-key \
  --secret-string "YOUR_API_KEY"

# PubMed API
aws secretsmanager put-secret-value \
  --secret-id ci-pubmed-api-key \
  --secret-string "YOUR_API_KEY"

# Clinical Trials API
aws secretsmanager put-secret-value \
  --secret-id ci-clinicaltrials-api-key \
  --secret-string "YOUR_API_KEY"

# News API
aws secretsmanager put-secret-value \
  --secret-id ci-news-api-key \
  --secret-string "YOUR_API_KEY"

# SEC API
aws secretsmanager put-secret-value \
  --secret-id ci-sec-api-key \
  --secret-string "YOUR_API_KEY"

# USPTO API
aws secretsmanager put-secret-value \
  --secret-id ci-uspto-api-key \
  --secret-string "YOUR_API_KEY"
```

### Step 7: Create Cognito User

```bash
# Create a test user
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_XXXXXXXXX \
  --username testuser@example.com \
  --message-action SUPPRESS \
  --temporary-password TempPassword123!

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_XXXXXXXXX \
  --username testuser@example.com \
  --password Password123! \
  --permanent
```

### Step 8: Login and Test

1. Open the ALB URL in your browser
2. Click "Login"
3. Enter credentials:
   - Email: `testuser@example.com`
   - Password: `Password123!`
4. You should see the dashboard

## Deployment Stacks

The deployment creates 7 CloudFormation stacks:

1. **pharma-ci-platform-dev** - Core infrastructure
   - Lambda functions
   - DynamoDB tables
   - Elasticsearch domain
   - API Gateway
   - SNS topics

2. **pharma-ci-auth-dev** - Cognito authentication
   - User pool
   - User pool client
   - Cognito domain

3. **pharma-ci-frontend-dev** - ECS Fargate frontend
   - ECS cluster
   - Fargate service
   - Application Load Balancer
   - Auto-scaling

4. **pharma-ci-rag-dev** - Knowledge base
   - S3 bucket for documents
   - Bedrock RAG role

5. **pharma-ci-events-dev** - Event processing
   - SQS queues
   - EventBridge rules
   - Lambda processors

6. **pharma-ci-bedrock-dev** - Bedrock agent
   - Bedrock agent role
   - Model permissions

7. **pharma-ci-eventbridge-dev** - EventBridge rules
   - Scheduled tasks
   - Lambda triggers

## Monitoring

### View Logs

```bash
# All Lambda logs
aws logs tail /aws/lambda/ci-* --follow

# Specific function
aws logs tail /aws/lambda/ci-api-dev --follow

# ECS logs
aws logs tail /ecs/ci-frontend-service-dev --follow
```

### Check Stack Status

```bash
# List all stacks
aws cloudformation list-stacks --region us-east-1

# Check specific stack
aws cloudformation describe-stacks \
  --stack-name pharma-ci-platform-dev \
  --region us-east-1

# View stack events
aws cloudformation describe-stack-events \
  --stack-name pharma-ci-platform-dev \
  --region us-east-1
```

### Monitor Services

```bash
# Check ECS service
aws ecs describe-services \
  --cluster ci-frontend-cluster-dev \
  --services ci-frontend-service-dev

# Check Lambda functions
aws lambda list-functions --region us-east-1

# Check DynamoDB tables
aws dynamodb list-tables --region us-east-1

# Check Elasticsearch domain
aws es describe-elasticsearch-domains --region us-east-1
```

## Troubleshooting

### Issue: Prerequisites script fails

**Solution:**
```bash
# Run with verbose output
bash -x prereq.sh

# Check specific tool
which aws
which node
which cdk
```

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for more issues.

### Issue: Deployment fails

**Solution:**
```bash
# Check stack events
aws cloudformation describe-stack-events \
  --stack-name pharma-ci-platform-dev

# Check Lambda logs
aws logs tail /aws/lambda/ci-* --follow

# Delete failed stack and retry
aws cloudformation delete-stack --stack-name pharma-ci-platform-dev
aws cloudformation wait stack-delete-complete --stack-name pharma-ci-platform-dev
./deploy.sh dev us-east-1
```

### Issue: Can't access frontend

**Solution:**
```bash
# Check ALB status
aws elbv2 describe-load-balancers

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...

# Check ECS service
aws ecs describe-services \
  --cluster ci-frontend-cluster-dev \
  --services ci-frontend-service-dev
```

## Cleanup

### Delete Everything

```bash
# Delete all stacks
aws cloudformation delete-stack --stack-name pharma-ci-platform-dev
aws cloudformation delete-stack --stack-name pharma-ci-auth-dev
aws cloudformation delete-stack --stack-name pharma-ci-frontend-dev
aws cloudformation delete-stack --stack-name pharma-ci-rag-dev
aws cloudformation delete-stack --stack-name pharma-ci-events-dev
aws cloudformation delete-stack --stack-name pharma-ci-bedrock-dev
aws cloudformation delete-stack --stack-name pharma-ci-eventbridge-dev

# Wait for deletion
sleep 120

# Verify deletion
aws cloudformation list-stacks --region us-east-1
```

### Delete Specific Stack

```bash
aws cloudformation delete-stack --stack-name pharma-ci-platform-dev
aws cloudformation wait stack-delete-complete --stack-name pharma-ci-platform-dev
```

## Cost Estimation

| Service | Monthly Cost |
|---------|--------------|
| ECS Fargate | $50-100 |
| Lambda | $20-50 |
| DynamoDB | $10-20 |
| Elasticsearch | $50-100 |
| API Gateway | $5-10 |
| Cognito | $5-10 |
| SQS | $1-5 |
| SES | $1-5 |
| S3 | $10-20 |
| **Total** | **~$150-320** |

## Next Steps

1. ✅ Run `./prereq.sh`
2. ✅ Enable Bedrock models
3. ✅ Run `./deploy.sh dev us-east-1`
4. ✅ Configure API keys
5. ✅ Create Cognito user
6. ✅ Login and test
7. ✅ Monitor logs
8. ✅ Configure alerts

## Support

For issues:
1. Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
2. Review logs: `aws logs tail /aws/lambda/ci-* --follow`
3. Check stack events: `aws cloudformation describe-stack-events --stack-name pharma-ci-platform-dev`
4. Review documentation: [README.md](./README.md), [ARCHITECTURE_V2.md](./ARCHITECTURE_V2.md)

---

**Deployment Time**: 10-15 minutes
**Cost**: ~$150-320/month
**Status**: Production Ready ✅
