#!/bin/bash

echo "Getting frontend URL..."
FRONTEND_URL=$(aws cloudformation describe-stacks --stack-name pharma-ci-frontend-dev --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURL`].OutputValue' --output text --region us-east-1 2>/dev/null)

if [ -n "$FRONTEND_URL" ] && [ "$FRONTEND_URL" != "None" ]; then
    echo "🌐 Frontend URL: $FRONTEND_URL"
else
    # Try website URL instead
    WEBSITE_URL=$(aws cloudformation describe-stacks --stack-name pharma-ci-frontend-dev --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' --output text --region us-east-1 2>/dev/null)
    echo "🌐 Website URL: $WEBSITE_URL"
fi

echo ""
echo "Waiting for AI stack to complete..."
aws cloudformation wait stack-create-complete --stack-name pharma-ci-rag-dev --region us-east-1

echo "Getting AI endpoint..."
AI_ENDPOINT=$(aws cloudformation describe-stacks --stack-name pharma-ci-rag-dev --query 'Stacks[0].Outputs[?OutputKey==`AIAPIEndpoint`].OutputValue' --output text --region us-east-1 2>/dev/null)

echo ""
echo "✅ Deployment Complete!"
echo "🤖 AI API: $AI_ENDPOINT"
echo "🌐 Frontend: $FRONTEND_URL"
echo ""
echo "Test AI: curl -X POST $AI_ENDPOINT/ai -H 'Content-Type: application/json' -d '{\"query\":\"What are competitive threats to Keytruda?\"}'"