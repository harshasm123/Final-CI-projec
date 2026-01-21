#!/bin/bash

set -e

echo "🚀 Pharmaceutical CI Platform - Complete Deployment"
echo ""

# Configuration
REGION=${2:-us-west-2}
ENVIRONMENT=${1:-dev}
FRONTEND_TYPE=${3:-amplify}  # amplify, ecs, static
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📋 Configuration:"
echo "  Region: $REGION"
echo "  Account: $ACCOUNT_ID"
echo "  Environment: $ENVIRONMENT"
echo "  Frontend: $FRONTEND_TYPE"
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

# Get outputs AFTER deployment completes
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
echo "🎨 Deploying frontend application ($FRONTEND_TYPE)..."

if [ -d "frontend" ]; then
    case $FRONTEND_TYPE in
        "amplify")
            echo "  🚀 Deploying with AWS Amplify..."
            if [ -f "amplify-frontend.yaml" ]; then
                aws cloudformation deploy \
                    --template-file amplify-frontend.yaml \
                    --stack-name "pharma-ci-amplify-${ENVIRONMENT}" \
                    --parameter-overrides \
                        Environment=$ENVIRONMENT \
                        GitHubRepo="https://github.com/your-org/pharma-ci-platform" \
                        GitHubBranch=main \
                        GitHubToken=${GITHUB_TOKEN:-placeholder} \
                    --capabilities CAPABILITY_IAM \
                    --region $REGION
                
                AMPLIFY_URL=$(aws cloudformation describe-stacks \
                    --stack-name "pharma-ci-amplify-${ENVIRONMENT}" \
                    --region $REGION \
                    --query 'Stacks[0].Outputs[?OutputKey==`AmplifyURL`].OutputValue' \
                    --output text 2>/dev/null || echo "Amplify URL pending...")
                
                echo "  ✅ Amplify deployment initiated: $AMPLIFY_URL"
            else
                echo "  ⚠️  amplify-frontend.yaml not found"
            fi
            ;;
            
        "ecs")
            echo "  🐳 Deploying with ECS Fargate..."
            
            cd frontend
            
            # Build React app
            npm install --silent
            npm run build
            
            # Create Dockerfile if needed
            if [ ! -f "Dockerfile" ]; then
                cat > Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
RUN npm install -g serve
EXPOSE 3000
CMD ["serve", "-s", "build", "-l", "3000"]
EOF
            fi
            
            # Docker build and push
            if command -v docker &> /dev/null; then
                aws ecr describe-repositories --repository-names pharma-ci-frontend --region $REGION 2>/dev/null || \
                aws ecr create-repository --repository-name pharma-ci-frontend --region $REGION
                
                aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
                
                docker build -t pharma-ci-frontend .
                docker tag pharma-ci-frontend:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/pharma-ci-frontend:latest
                docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/pharma-ci-frontend:latest
                
                echo "  ✅ Docker image pushed to ECR"
            else
                echo "  ⚠️  Docker not found, skipping ECS deployment"
            fi
            
            cd ..
            ;;
            
        "static")
            echo "  📁 Deploying static build..."
            
            cd frontend
            npm install --silent
            
            # Create environment file
            cat > .env << EOF
REACT_APP_API_ENDPOINT=$API_ENDPOINT
REACT_APP_REGION=$REGION
REACT_APP_ENVIRONMENT=$ENVIRONMENT
EOF
            
            npm run build
            
            # Upload to existing S3 bucket
            if [ -n "$FRONTEND_BUCKET" ]; then
                aws s3 sync build/ s3://$FRONTEND_BUCKET --delete --quiet
                echo "  ✅ React app deployed to S3"
            else
                echo "  ⚠️  No S3 bucket found for static deployment"
            fi
            
            cd ..
            ;;
            
        *)
            echo "  ❌ Invalid frontend type: $FRONTEND_TYPE"
            echo "  Valid options: amplify, ecs, static"
            ;;
    esac
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
echo "🚀 Frontend deployment options:"
echo "  Amplify: ./deploy.sh $ENVIRONMENT $REGION amplify"
echo "  ECS Fargate: ./deploy.sh $ENVIRONMENT $REGION ecs"
echo "  Static S3: ./deploy.sh $ENVIRONMENT $REGION static"
echo ""
