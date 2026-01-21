#!/bin/bash

echo "Fixing S3 conflicts and deploying..."

# Wait for any pending S3 operations
sleep 10

# Use CloudFormation deployment instead of CDK
echo "Deploying AI stack..."
aws cloudformation deploy \
  --template-file ai-stack.yaml \
  --stack-name pharma-ci-rag-dev \
  --parameter-overrides Environment=dev \
  --capabilities CAPABILITY_IAM \
  --region us-east-1

echo "Deploying Frontend stack..."
aws cloudformation deploy \
  --template-file frontend-stack.yaml \
  --stack-name pharma-ci-frontend-dev \
  --parameter-overrides Environment=dev \
  --region us-east-1

echo "Getting endpoints..."
AI_ENDPOINT=$(aws cloudformation describe-stacks --stack-name pharma-ci-rag-dev --query 'Stacks[0].Outputs[?OutputKey==`AIAPIEndpoint`].OutputValue' --output text)
FRONTEND_URL=$(aws cloudformation describe-stacks --stack-name pharma-ci-frontend-dev --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURL`].OutputValue' --output text)

echo ""
echo "✅ Deployment complete!"
echo "AI API: $AI_ENDPOINT"
echo "Frontend: $FRONTEND_URL"