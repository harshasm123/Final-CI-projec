# Quick Start Guide

Deploy the Pharmaceutical CI Platform in 5 minutes.

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured: `aws configure`
- Node.js 18+
- Python 3.11+

## One-Command Deployment

```bash
# Make scripts executable
chmod +x prereq.sh deploy.sh

# Run prerequisites check
./prereq.sh

# Deploy everything (infrastructure + frontend)
./deploy.sh dev us-east-1
```

## What Gets Deployed

✅ **Infrastructure (AWS CDK)**
- Lambda functions (12 total)
- S3 buckets (Data Lake, Processed Data, Metadata)
- DynamoDB (Conversation storage)
- Elasticsearch (Search & analytics)
- API Gateway (REST API)
- SNS (Alerts)
- EventBridge (Scheduled tasks)

✅ **Frontend**
- React TypeScript application
- S3 static hosting
- CloudFront CDN distribution

✅ **Configuration**
- IAM roles with least privilege
- Secrets Manager for API keys
- CloudWatch logging

## Access Your Application

After deployment completes, you'll see:

```
CloudFront CDN: https://d1234567890.cloudfront.net
```

**Open this URL in your browser to access the UI!**

## Configuration

### Add API Keys

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

## Monitoring

### View Logs

```bash
# All Lambda logs
aws logs tail /aws/lambda/ci-* --follow

# Specific function
aws logs tail /aws/lambda/ci-api-dev --follow
```

### Check Stack Status

```bash
aws cloudformation describe-stacks \
  --stack-name pharma-ci-platform-dev \
  --region us-east-1
```

### View API Endpoint

```bash
aws cloudformation describe-stacks \
  --stack-name pharma-ci-platform-dev \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

## Troubleshooting

### Deployment Failed

```bash
# Check stack events
aws cloudformation describe-stack-events \
  --stack-name pharma-ci-platform-dev \
  --region us-east-1

# Check Lambda logs
aws logs tail /aws/lambda/ci-* --follow
```

### Frontend Not Loading

```bash
# Check CloudFront distribution
aws cloudfront list-distributions

# Invalidate cache
aws cloudfront create-invalidation \
  --distribution-id D1234567890 \
  --paths "/*"
```

### API Not Responding

```bash
# Check API Gateway
aws apigateway get-rest-apis --region us-east-1

# Check Lambda function
aws lambda get-function --function-name ci-api-dev --region us-east-1
```

## Cleanup

### Destroy Everything

```bash
# Destroy infrastructure
cd cdk
npm run destroy -- --context environment=dev --context region=us-east-1

# Delete frontend S3 bucket
aws s3 rb s3://ci-frontend-dev-* --force

# Delete CloudFront distribution
aws cloudfront delete-distribution --id D1234567890
```

## Next Steps

1. ✅ Access UI at CloudFront CDN link
2. ✅ Configure API keys in Secrets Manager
3. ✅ Monitor Lambda functions
4. ✅ Set up alerts and notifications
5. ✅ Configure custom domain (optional)

## Documentation

- **[README.md](./README.md)** - Project overview
- **[SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md)** - System design
- **[FINAL_DEPLOYMENT_GUIDE.md](./FINAL_DEPLOYMENT_GUIDE.md)** - Detailed deployment
- **[cdk/README.md](./cdk/README.md)** - CDK documentation

## Support

For issues:
1. Check logs: `aws logs tail /aws/lambda/ci-* --follow`
2. Review stack events: `aws cloudformation describe-stack-events --stack-name pharma-ci-platform-dev`
3. Check documentation in README.md

---

**Deployment Time**: ~10-15 minutes
**Cost**: ~$90-190/month
**Status**: Production Ready ✅
