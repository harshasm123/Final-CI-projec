#!/bin/bash

echo "Deploying AI and Frontend stacks with dynamic bucket names..."

# Generate unique timestamp
TIMESTAMP=$(date +%s)

# Deploy CloudFormation stacks directly with unique names
echo "Deploying AI stack..."
aws cloudformation deploy \
  --template-file ai-stack.yaml \
  --stack-name pharma-ci-rag-dev-$TIMESTAMP \
  --parameter-overrides Environment=dev \
  --capabilities CAPABILITY_IAM \
  --region us-east-1

echo "Deploying Frontend stack..."
aws cloudformation deploy \
  --template-file frontend-stack.yaml \
  --stack-name pharma-ci-frontend-dev-$TIMESTAMP \
  --parameter-overrides Environment=dev \
  --region us-east-1

# Get outputs
AI_ENDPOINT=$(aws cloudformation describe-stacks --stack-name pharma-ci-rag-dev-$TIMESTAMP --query 'Stacks[0].Outputs[?OutputKey==`AIAPIEndpoint`].OutputValue' --output text --region us-east-1)
FRONTEND_URL=$(aws cloudformation describe-stacks --stack-name pharma-ci-frontend-dev-$TIMESTAMP --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURL`].OutputValue' --output text --region us-east-1)

echo ""
echo "✅ Stacks deployed with unique names!"
echo "🤖 AI API: $AI_ENDPOINT"
echo "🌐 Frontend: $FRONTEND_URL"
echo ""
echo "Test AI: curl -X POST $AI_ENDPOINT/ai -H 'Content-Type: application/json' -d '{\"query\":\"What are competitive threats to Keytruda?\"}'"