#!/bin/bash

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}

echo "Deploying CloudFormation stacks for environment: $ENVIRONMENT in region: $REGION"

# Deploy AI Stack
echo "Deploying AI/RAG stack..."
aws cloudformation deploy \
  --template-file ai-stack.yaml \
  --stack-name pharma-ci-rag-$ENVIRONMENT \
  --parameter-overrides Environment=$ENVIRONMENT \
  --capabilities CAPABILITY_IAM \
  --region $REGION

if [ $? -eq 0 ]; then
  echo "✅ AI stack deployed successfully"
else
  echo "❌ AI stack deployment failed"
fi

# Deploy Frontend Stack
echo "Deploying Frontend stack..."
aws cloudformation deploy \
  --template-file frontend-stack.yaml \
  --stack-name pharma-ci-frontend-$ENVIRONMENT \
  --parameter-overrides Environment=$ENVIRONMENT \
  --region $REGION

if [ $? -eq 0 ]; then
  echo "✅ Frontend stack deployed successfully"
else
  echo "❌ Frontend stack deployment failed"
fi

# Get outputs
echo ""
echo "Stack outputs:"
aws cloudformation describe-stacks \
  --stack-name pharma-ci-rag-$ENVIRONMENT \
  --query 'Stacks[0].Outputs' \
  --region $REGION

aws cloudformation describe-stacks \
  --stack-name pharma-ci-frontend-$ENVIRONMENT \
  --query 'Stacks[0].Outputs' \
  --region $REGION

echo ""
echo "🚀 Deployment complete!"