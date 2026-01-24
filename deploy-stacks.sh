#!/bin/bash

echo "Cleaning up and deploying AI and Frontend stacks..."

# Clean up failed CDK stack
echo "Cleaning up failed CDK stack..."
aws cloudformation delete-stack --stack-name pharma-ci-platform-dev --region us-east-1
echo "Waiting for cleanup..."
aws cloudformation wait stack-delete-complete --stack-name pharma-ci-platform-dev --region us-east-1 2>/dev/null || echo "Stack already deleted or doesn't exist"

# Deploy CloudFormation stacks directly
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

# Get outputs
AI_ENDPOINT=$(aws cloudformation describe-stacks --stack-name pharma-ci-rag-dev --query 'Stacks[0].Outputs[?OutputKey==`AIAPIEndpoint`].OutputValue' --output text --region us-east-1)
FRONTEND_URL=$(aws cloudformation describe-stacks --stack-name pharma-ci-frontend-dev --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURL`].OutputValue' --output text --region us-east-1)

echo ""
echo "✅ All stacks deployed successfully!"
echo "🤖 AI API: $AI_ENDPOINT"
echo "🌐 Frontend: $FRONTEND_URL"
echo ""
echo "Test AI: curl -X POST $AI_ENDPOINT/ai -H 'Content-Type: application/json' -d '{\"query\":\"What are competitive threats to Keytruda?\"}'"