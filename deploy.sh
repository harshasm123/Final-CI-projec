#!/bin/bash

set -e

echo "🚀 Pharmaceutical CI Platform - Complete Deployment"
echo ""

# Configuration
REGION=${2:-us-west-2}
ENVIRONMENT=${1:-dev}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📋 Configuration:"
echo "  Region: $REGION"
echo "  Account: $ACCOUNT_ID"
echo "  Environment: $ENVIRONMENT"
echo ""

# Prerequisites
echo "🔍 Checking prerequisites..."
command -v aws &> /dev/null || { echo "❌ AWS CLI not found"; exit 1; }
command -v npm &> /dev/null || { echo "❌ npm not found"; exit 1; }
command -v cdk &> /dev/null || npm install -g aws-cdk
echo "✅ Prerequisites OK"
echo ""

# Bootstrap CDK
echo "🏗️  Bootstrapping CDK..."
cdk bootstrap aws://${ACCOUNT_ID}/${REGION} --region $REGION 2>/dev/null || echo "  ℹ️  Already bootstrapped"
echo ""

# Build and deploy
cd cdk

echo "📦 Installing dependencies..."
npm install --silent

echo "🔨 Building TypeScript..."
npm run build

echo "🚀 Deploying stacks..."
npm run deploy -- \
  --context environment=$ENVIRONMENT \
  --context region=$REGION \
  --require-approval never \
  --all

cd ..

# Get outputs
echo ""
echo "📋 Retrieving stack outputs..."
CORE_STACK="pharma-ci-platform-${ENVIRONMENT}"
RAG_STACK="pharma-ci-rag-${ENVIRONMENT}"
FRONTEND_STACK="pharma-ci-frontend-${ENVIRONMENT}"

# Core Stack Outputs
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name $CORE_STACK \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`APIEndpointOutput`].OutputValue' \
  --output text 2>/dev/null || echo "")

DATA_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name $CORE_STACK \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`DataLakeBucketOutput`].OutputValue' \
  --output text 2>/dev/null || echo "")

TABLE_NAME=$(aws cloudformation describe-stacks \
  --stack-name $CORE_STACK \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ConversationTableOutput`].OutputValue' \
  --output text 2>/dev/null || echo "")

# RAG Stack Outputs
KB_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name $RAG_STACK \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`KnowledgeBaseBucketOutput`].OutputValue' \
  --output text 2>/dev/null || echo "")

BEDROCK_ROLE=$(aws cloudformation describe-stacks \
  --stack-name $RAG_STACK \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`BedrockRoleArnOutput`].OutputValue' \
  --output text 2>/dev/null || echo "")

# Frontend Stack Outputs
FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name $FRONTEND_STACK \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketOutput`].OutputValue' \
  --output text 2>/dev/null || echo "")

CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
  --stack-name $FRONTEND_STACK \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURLOutput`].OutputValue' \
  --output text 2>/dev/null || echo "")

# Deploy frontend files
echo ""
echo "🎨 Deploying frontend application..."

if [ -d "frontend" ]; then
    cd frontend
    
    echo "  Installing frontend dependencies..."
    npm install --silent
    
    echo "  Creating environment configuration..."
    cat > .env.local << EOF
REACT_APP_API_ENDPOINT=$API_ENDPOINT
REACT_APP_ENVIRONMENT=$ENVIRONMENT
REACT_APP_REGION=$REGION
EOF
    
    echo "  Building frontend..."
    npm run build
    
    echo "  Uploading to S3..."
    aws s3 sync build/ s3://$FRONTEND_BUCKET --delete --quiet
    
    cd ..
    echo "  ✅ Frontend deployed"
else
    echo "  ⚠️  Frontend directory not found"
fi

# Summary
echo ""
echo "✅ Deployment Complete!"
echo ""
echo "🔗 Core Infrastructure:"
echo "  API Endpoint: $API_ENDPOINT"
echo "  Data Bucket: $DATA_BUCKET"
echo "  Table: $TABLE_NAME"
echo ""
echo "🧠 RAG & Bedrock:"
echo "  Knowledge Base Bucket: $KB_BUCKET"
echo "  Bedrock Role: $BEDROCK_ROLE"
echo ""
echo "🌍 Frontend:"
echo "  S3 Bucket: $FRONTEND_BUCKET"
echo "  CloudFront URL: $CLOUDFRONT_URL"
echo ""
echo "🧪 Test API:"
echo "  curl $API_ENDPOINT/health"
echo ""
echo "📝 Next Steps:"
echo "  1. Enable Bedrock models: AWS Console → Bedrock → Model Access"
echo "  2. Create Knowledge Base: AWS Console → Bedrock → Knowledge bases"
echo "  3. Create Bedrock Agent: AWS Console → Bedrock → Agents"
echo "  4. Upload sample data to: s3://$KB_BUCKET"
echo "  5. Configure API keys in Secrets Manager"
echo ""
