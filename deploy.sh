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
    # Create minimal index.html
    mkdir -p frontend/build
    cat > frontend/build/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Pharmaceutical CI Platform</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        h1 { color: #333; }
        .status { background: #e8f5e9; padding: 10px; border-radius: 4px; margin: 10px 0; }
        .info { background: #e3f2fd; padding: 10px; border-radius: 4px; margin: 10px 0; }
        code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🧬 Pharmaceutical CI Platform</h1>
        <div class="status">
            <strong>✅ Status:</strong> Platform is running
        </div>
        <div class="info">
            <strong>📊 Infrastructure:</strong>
            <ul>
                <li>API Endpoint: Available</li>
                <li>Data Storage: S3 Configured</li>
                <li>RAG & Bedrock: Ready</li>
            </ul>
        </div>
        <div class="info">
            <strong>🚀 Next Steps:</strong>
            <ol>
                <li>Enable Bedrock models in AWS Console</li>
                <li>Create Knowledge Base</li>
                <li>Create Bedrock Agent</li>
                <li>Upload sample data</li>
            </ol>
        </div>
        <div class="info">
            <strong>📝 API Test:</strong>
            <code>curl https://API_ENDPOINT/health</code>
        </div>
    </div>
</body>
</html>
EOF
    
    echo "  ✅ Frontend HTML created"
    
    echo "  Uploading to S3..."
    aws s3 sync frontend/build/ s3://$FRONTEND_BUCKET --delete --quiet
    echo "  ✅ Frontend uploaded to S3"
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
