#!/bin/bash

set -e

echo "🚀 Pharmaceutical CI Platform - Minimal Deployment"
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

echo "🧬 Synthesizing template..."
npm run synth -- --context environment=$ENVIRONMENT --context region=$REGION

echo "🚀 Deploying stack..."
npm run deploy -- \
  --context environment=$ENVIRONMENT \
  --context region=$REGION \
  --require-approval never

cd ..

# Get outputs
echo ""
echo "📋 Stack Outputs:"
STACK_NAME="pharma-ci-platform-${ENVIRONMENT}"

API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
  --output text 2>/dev/null || echo "")

DATA_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`DataLakeBucket`].OutputValue' \
  --output text 2>/dev/null || echo "")

TABLE_NAME=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ConversationTable`].OutputValue' \
  --output text 2>/dev/null || echo "")

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "🔗 API Endpoint: $API_ENDPOINT"
echo "💾 Data Bucket: $DATA_BUCKET"
echo "📊 Table: $TABLE_NAME"
echo ""
echo "🧪 Test:"
echo "  curl $API_ENDPOINT/health"
echo ""
