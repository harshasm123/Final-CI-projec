#!/bin/bash

# Pharmaceutical CI Platform - Complete Deployment Script
set -e

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}

echo "🚀 Starting Pharmaceutical CI Platform Deployment"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm is required but not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is required but not installed"
    exit 1
fi

if ! command -v cdk &> /dev/null; then
    echo "❌ AWS CDK is required. Installing..."
    npm install -g aws-cdk
fi

# Verify AWS credentials
echo "🔐 Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account: $ACCOUNT_ID"

# Deploy CDK Infrastructure
echo "🏗️ Deploying infrastructure..."
cd cdk

# Install dependencies
echo "📦 Installing CDK dependencies..."
npm install

# Bootstrap CDK (if needed)
echo "🔧 Bootstrapping CDK..."
cdk bootstrap aws://$ACCOUNT_ID/$REGION --context environment=$ENVIRONMENT --context region=$REGION

# Build TypeScript
echo "🔨 Building CDK project..."
npm run build

# Deploy all stacks
echo "🚀 Deploying CDK stacks..."
cdk deploy --all --require-approval never --context environment=$ENVIRONMENT --context region=$REGION

# Get stack outputs
echo "📊 Getting deployment outputs..."
DATA_BUCKET=$(aws cloudformation describe-stacks --stack-name pharma-ci-$ENVIRONMENT-data --query 'Stacks[0].Outputs[?OutputKey==`DataBucketName`].OutputValue' --output text --region $REGION)
KNOWLEDGE_BUCKET=$(aws cloudformation describe-stacks --stack-name pharma-ci-$ENVIRONMENT-data --query 'Stacks[0].Outputs[?OutputKey==`KnowledgeBucketName`].OutputValue' --output text --region $REGION)
API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name pharma-ci-$ENVIRONMENT-compute --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' --output text --region $REGION)
FRONTEND_BUCKET=$(aws cloudformation describe-stacks --stack-name pharma-ci-$ENVIRONMENT-frontend --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' --output text --region $REGION)
CLOUDFRONT_URL=$(aws cloudformation describe-stacks --stack-name pharma-ci-$ENVIRONMENT-frontend --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURL`].OutputValue' --output text --region $REGION)

echo "✅ Infrastructure deployed successfully!"
echo "📦 Data Bucket: $DATA_BUCKET"
echo "🧠 Knowledge Bucket: $KNOWLEDGE_BUCKET"
echo "🔗 API Endpoint: $API_ENDPOINT"
echo "🌐 Frontend Bucket: $FRONTEND_BUCKET"

cd ..

# Build and Deploy Frontend
echo "🎨 Building and deploying frontend..."
cd frontend

# Install dependencies
echo "📦 Installing frontend dependencies..."
npm install

# Create environment file
echo "⚙️ Creating environment configuration..."
cat > .env << EOF
REACT_APP_API_URL=$API_ENDPOINT
REACT_APP_ENVIRONMENT=$ENVIRONMENT
EOF

# Build frontend
echo "🔨 Building frontend..."
npm run build

# Deploy to S3
echo "📤 Deploying frontend to S3..."
aws s3 sync build/ s3://$FRONTEND_BUCKET --delete --region $REGION

# Invalidate CloudFront cache
if [ ! -z "$CLOUDFRONT_URL" ]; then
    DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='$FRONTEND_BUCKET.s3.amazonaws.com'].Id" --output text --region $REGION)
    if [ ! -z "$DISTRIBUTION_ID" ]; then
        echo "🔄 Invalidating CloudFront cache..."
        aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*" --region $REGION
    fi
fi

cd ..

# Initialize sample data
echo "📊 Initializing sample data..."
aws lambda invoke --function-name pharma-ci-$ENVIRONMENT-compute-DataIngestionFunction --payload '{"source":"all"}' /tmp/ingestion-response.json --region $REGION

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "====================="
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"
echo ""
echo "🔗 Access URLs:"
echo "Frontend (CloudFront): $CLOUDFRONT_URL"
echo "API Endpoint: $API_ENDPOINT"
echo ""
echo "📦 AWS Resources:"
echo "Data Bucket: $DATA_BUCKET"
echo "Knowledge Bucket: $KNOWLEDGE_BUCKET"
echo "Frontend Bucket: $FRONTEND_BUCKET"
echo ""
echo "🚀 Your Pharmaceutical CI Platform is ready!"
echo "Visit: $CLOUDFRONT_URL"
echo ""
echo "📚 Next Steps:"
echo "1. Access the dashboard at the CloudFront URL"
echo "2. Try the AI chatbot for pharmaceutical intelligence"
echo "3. Monitor data ingestion in the AWS Console"
echo "4. Set up alerts and notifications as needed"
echo ""