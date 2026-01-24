#!/bin/bash

echo "Checking deployment status..."

# Check if stacks exist and get their status
echo "AI Stack Status:"
aws cloudformation describe-stacks --stack-name pharma-ci-rag-dev --region us-east-1 --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "Stack not found"

echo "Frontend Stack Status:"
aws cloudformation describe-stacks --stack-name pharma-ci-frontend-dev --region us-east-1 --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "Stack not found"

# Get endpoints if stacks exist
echo ""
echo "Getting endpoints..."
AI_ENDPOINT=$(aws cloudformation describe-stacks --stack-name pharma-ci-rag-dev --query 'Stacks[0].Outputs[?OutputKey==`AIAPIEndpoint`].OutputValue' --output text --region us-east-1 2>/dev/null)
FRONTEND_URL=$(aws cloudformation describe-stacks --stack-name pharma-ci-frontend-dev --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURL`].OutputValue' --output text --region us-east-1 2>/dev/null)

if [ -n "$AI_ENDPOINT" ]; then
    echo "🤖 AI API: $AI_ENDPOINT"
    echo "Test: curl -X POST $AI_ENDPOINT/ai -H 'Content-Type: application/json' -d '{\"query\":\"test\"}'"
else
    echo "❌ AI endpoint not available"
fi

if [ -n "$FRONTEND_URL" ]; then
    echo "🌐 Frontend: $FRONTEND_URL"
else
    echo "❌ Frontend URL not available"
fi