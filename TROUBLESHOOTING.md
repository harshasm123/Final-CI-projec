# Troubleshooting Guide

## Common Issues and Solutions

### 1. Prerequisites Check Fails

**Error**: `[ERROR] Prerequisites check failed`

**Solution**:
```bash
# Install missing tools manually
sudo apt-get update
sudo apt-get install -y git nodejs npm python3 python3-pip

# Install AWS CLI
sudo apt-get install -y awscli

# Install AWS CDK
npm install -g aws-cdk

# Verify installation
node --version
npm --version
python3 --version
aws --version
cdk --version
```

### 2. AWS Credentials Not Configured

**Error**: `AWS credentials not configured`

**Solution**:
```bash
# Configure AWS credentials
aws configure

# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region (us-east-1)
# Enter default output format (json)

# Verify credentials
aws sts get-caller-identity
```

### 3. Node.js Not Found

**Error**: `command not found: node`

**Solution**:
```bash
# Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify
node --version
npm --version
```

### 4. AWS CDK Not Found

**Error**: `command not found: cdk`

**Solution**:
```bash
# Install AWS CDK globally
npm install -g aws-cdk

# Verify
cdk --version
```

### 5. Permission Denied

**Error**: `Permission denied: ./deploy.sh`

**Solution**:
```bash
# Make script executable
chmod +x deploy.sh
chmod +x prereq.sh
chmod +x quick-deploy.sh

# Run again
./deploy.sh dev us-east-1
```

### 6. CDK Deployment Fails

**Error**: `ValidationError` or `AccessDenied`

**Solution**:
```bash
# Check AWS permissions
aws iam get-user

# Check CloudFormation access
aws cloudformation describe-stacks --region us-east-1

# Check if stack already exists
aws cloudformation describe-stacks --stack-name pharma-ci-platform-dev --region us-east-1

# If stack exists in failed state, delete it
aws cloudformation delete-stack --stack-name pharma-ci-platform-dev --region us-east-1

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name pharma-ci-platform-dev --region us-east-1

# Try deployment again
./deploy.sh dev us-east-1
```

### 7. npm install Fails

**Error**: `npm ERR!` or `ERESOLVE unable to resolve dependency tree`

**Solution**:
```bash
# Clear npm cache
npm cache clean --force

# Remove node_modules and lock file
rm -rf node_modules package-lock.json

# Reinstall
npm install
```

### 8. TypeScript Build Fails

**Error**: `error TS...` or `tsc: command not found`

**Solution**:
```bash
cd cdk

# Install TypeScript
npm install -g typescript

# Build manually
npm run build

# Or use npx
npx tsc
```

### 9. Lambda Function Not Found

**Error**: `Function not found` or `ResourceNotFoundException`

**Solution**:
```bash
# Check if Lambda functions were created
aws lambda list-functions --region us-east-1

# Check CloudFormation stack status
aws cloudformation describe-stacks --stack-name pharma-ci-platform-dev --region us-east-1

# Check stack events for errors
aws cloudformation describe-stack-events --stack-name pharma-ci-platform-dev --region us-east-1
```

### 10. API Gateway Not Responding

**Error**: `502 Bad Gateway` or `403 Forbidden`

**Solution**:
```bash
# Check API Gateway
aws apigateway get-rest-apis --region us-east-1

# Check Lambda permissions
aws lambda get-policy --function-name ci-api-dev --region us-east-1

# Check CloudWatch logs
aws logs tail /aws/lambda/ci-api-dev --follow --region us-east-1
```

### 11. DynamoDB Table Not Found

**Error**: `ResourceNotFoundException` for DynamoDB

**Solution**:
```bash
# List DynamoDB tables
aws dynamodb list-tables --region us-east-1

# Check table details
aws dynamodb describe-table --table-name ci-chatbot-conversations-dev --region us-east-1

# Check CloudFormation stack
aws cloudformation describe-stack-resources --stack-name pharma-ci-platform-dev --region us-east-1
```

### 12. Elasticsearch Domain Not Available

**Error**: `ResourceNotFoundException` for Elasticsearch

**Solution**:
```bash
# List Elasticsearch domains
aws es describe-elasticsearch-domains --region us-east-1

# Check domain status
aws es describe-elasticsearch-domain-config --domain-name ci-search-dev --region us-east-1

# Wait for domain to be active (can take 10-15 minutes)
```

### 13. S3 Bucket Already Exists

**Error**: `BucketAlreadyExists` or `BucketAlreadyOwnedByYou`

**Solution**:
```bash
# List S3 buckets
aws s3 ls

# Delete bucket if needed
aws s3 rb s3://bucket-name --force

# Or use different environment name
./deploy.sh staging us-east-1
```

### 14. Insufficient IAM Permissions

**Error**: `User: arn:aws:iam::... is not authorized to perform: ...`

**Solution**:
```bash
# Check current user permissions
aws iam get-user

# Ensure user has these policies:
# - AdministratorAccess (for testing)
# - Or specific policies for CloudFormation, Lambda, S3, DynamoDB, etc.

# Contact AWS account administrator to add permissions
```

### 15. Timeout During Deployment

**Error**: `Timeout waiting for stack creation`

**Solution**:
```bash
# Check stack status
aws cloudformation describe-stacks --stack-name pharma-ci-platform-dev --region us-east-1

# Check stack events
aws cloudformation describe-stack-events --stack-name pharma-ci-platform-dev --region us-east-1

# If stuck, delete and retry
aws cloudformation delete-stack --stack-name pharma-ci-platform-dev --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name pharma-ci-platform-dev --region us-east-1
./deploy.sh dev us-east-1
```

## Quick Fixes

### Reset Everything
```bash
# Delete all stacks
aws cloudformation delete-stack --stack-name pharma-ci-platform-dev --region us-east-1
aws cloudformation delete-stack --stack-name pharma-ci-auth-dev --region us-east-1
aws cloudformation delete-stack --stack-name pharma-ci-frontend-dev --region us-east-1
aws cloudformation delete-stack --stack-name pharma-ci-rag-dev --region us-east-1
aws cloudformation delete-stack --stack-name pharma-ci-events-dev --region us-east-1
aws cloudformation delete-stack --stack-name pharma-ci-bedrock-dev --region us-east-1
aws cloudformation delete-stack --stack-name pharma-ci-eventbridge-dev --region us-east-1

# Wait for deletion
sleep 60

# Deploy fresh
./deploy.sh dev us-east-1
```

### Check Logs
```bash
# All Lambda logs
aws logs tail /aws/lambda/ci-* --follow --region us-east-1

# Specific function
aws logs tail /aws/lambda/ci-api-dev --follow --region us-east-1

# Last 100 lines
aws logs tail /aws/lambda/ci-api-dev --max-items 100 --region us-east-1
```

### View Stack Outputs
```bash
# Get all outputs
aws cloudformation describe-stacks \
  --stack-name pharma-ci-platform-dev \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

## Getting Help

1. **Check logs**: `aws logs tail /aws/lambda/ci-* --follow`
2. **Check stack events**: `aws cloudformation describe-stack-events --stack-name pharma-ci-platform-dev`
3. **Review documentation**: See README.md and ARCHITECTURE_V2.md
4. **Check AWS console**: https://console.aws.amazon.com/

## Support Resources

- AWS CDK Documentation: https://docs.aws.amazon.com/cdk/
- AWS CloudFormation: https://docs.aws.amazon.com/cloudformation/
- AWS Lambda: https://docs.aws.amazon.com/lambda/
- AWS Cognito: https://docs.aws.amazon.com/cognito/
- AWS ECS: https://docs.aws.amazon.com/ecs/

---

**Last Updated**: January 2026
