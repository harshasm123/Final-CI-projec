#!/bin/bash

################################################################################
# Pharmaceutical CI Platform - Production-Grade Deployment Script
# Deploys enterprise-grade competitive intelligence platform
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🚀 Pharmaceutical CI Platform - Production-Grade Deployment"
echo ""

# Configuration
REGION=${2:-us-east-1}
ENVIRONMENT=${1:-dev}
FRONTEND_TYPE=${3:-ecs}  # ecs, lambda (dynamic only)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📋 Configuration:"
echo "  Region: $REGION"
echo "  Account: $ACCOUNT_ID"
echo "  Environment: $ENVIRONMENT"
echo "  Frontend: $FRONTEND_TYPE"
echo ""

# Check for existing resources
echo "🔍 Checking for existing resources..."
existing_stacks=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?contains(StackName, 'pharma-ci')].StackName" --output text --region $REGION)
if [ -n "$existing_stacks" ]; then
    echo "⚠️  Found existing stacks. Run cleanup first:"
    echo "  ./cleanup.sh $ENVIRONMENT $REGION"
    echo "  Then run: ./deploy.sh $ENVIRONMENT $REGION $FRONTEND_TYPE"
    exit 1
fi
echo "✅ No conflicts found"
echo ""

# Deploy Core Infrastructure Stack
log_info "Deploying core infrastructure..."
aws cloudformation deploy \
    --template-file architecture.yaml \
    --stack-name "pharma-ci-core-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Deploy Authentication Stack
log_info "Deploying authentication infrastructure..."
aws cloudformation deploy \
    --template-file auth-stack.yaml \
    --stack-name "pharma-ci-auth-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Deploy Data Processing Stack
log_info "Deploying data processing infrastructure..."
aws cloudformation deploy \
    --template-file data-stack.yaml \
    --stack-name "pharma-ci-data-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Deploy AI/RAG Stack
log_info "Deploying AI and RAG infrastructure..."
aws cloudformation deploy \
    --template-file rag-stack.yaml \
    --stack-name "pharma-ci-rag-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Deploy Event Processing Stack
log_info "Deploying event processing infrastructure..."
aws cloudformation deploy \
    --template-file events-stack.yaml \
    --stack-name "pharma-ci-events-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Deploy Monitoring Stack
log_info "Deploying monitoring infrastructure..."
aws cloudformation deploy \
    --template-file monitoring-stack.yaml \
    --stack-name "pharma-ci-monitoring-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Get core stack outputs
log_info "Retrieving stack outputs..."
CORE_STACK="pharma-ci-core-${ENVIRONMENT}"
AUTH_STACK="pharma-ci-auth-${ENVIRONMENT}"
DATA_STACK="pharma-ci-data-${ENVIRONMENT}"
RAG_STACK="pharma-ci-rag-${ENVIRONMENT}"

# Core outputs
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $CORE_STACK \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
    --output text 2>/dev/null || echo "")

DATA_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $DATA_STACK \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`DataBucket`].OutputValue' \
    --output text 2>/dev/null || echo "")

USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name $AUTH_STACK \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text 2>/dev/null || echo "")

KB_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $RAG_STACK \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`KnowledgeBaseBucket`].OutputValue' \
    --output text 2>/dev/null || echo "")

# Deploy frontend files
echo ""
echo "🎨 Deploying frontend application ($FRONTEND_TYPE)..."

if [ -d "frontend" ]; then
    case $FRONTEND_TYPE in
        "ecs")
            echo "  🐳 Deploying with ECS Fargate + ALB..."
            
            # Build and push Docker image
            cd frontend
            
            # Create production Dockerfile
            cat > Dockerfile << 'EOF'
# Multi-stage build for production
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Production stage with Nginx
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

            # Create Nginx config
            cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;
        
        # SPA routing
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        # Health check
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
    }
}
EOF

            # Build React app
            npm install --silent
            
            # Create environment file
            cat > .env << EOF
REACT_APP_API_ENDPOINT=$API_ENDPOINT
REACT_APP_REGION=$REGION
REACT_APP_ENVIRONMENT=$ENVIRONMENT
REACT_APP_USER_POOL_ID=$USER_POOL_ID
EOF
            
            npm run build
            
            # Docker operations
            if command -v docker &> /dev/null; then
                # Create ECR repository
                aws ecr describe-repositories --repository-names pharma-ci-frontend --region $REGION 2>/dev/null || \
                aws ecr create-repository --repository-name pharma-ci-frontend --region $REGION
                
                # Login to ECR
                aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
                
                # Build and push
                docker build -t pharma-ci-frontend .
                docker tag pharma-ci-frontend:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/pharma-ci-frontend:latest
                docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/pharma-ci-frontend:latest
                
                echo "  ✅ Docker image pushed to ECR"
            fi
            
            cd ..
            
            # Deploy ECS infrastructure
            aws cloudformation deploy \
                --template-file ecs-frontend.yaml \
                --stack-name "pharma-ci-frontend-${ENVIRONMENT}" \
                --parameter-overrides \
                    Environment=$ENVIRONMENT \
                    ImageUri=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/pharma-ci-frontend:latest \
                --capabilities CAPABILITY_IAM \
                --region $REGION
            
            FRONTEND_URL=$(aws cloudformation describe-stacks \
                --stack-name "pharma-ci-frontend-${ENVIRONMENT}" \
                --region $REGION \
                --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
                --output text 2>/dev/null || echo "ECS URL pending...")
            
            echo "  ✅ ECS deployment complete: $FRONTEND_URL"
            ;;
            
        "lambda")
            echo "  ⚡ Deploying with Lambda + API Gateway..."
            
            if [ -f "lambda-frontend.yaml" ]; then
                aws cloudformation deploy \
                    --template-file lambda-frontend.yaml \
                    --stack-name "pharma-ci-lambda-${ENVIRONMENT}" \
                    --parameter-overrides \
                        Environment=$ENVIRONMENT \
                    --capabilities CAPABILITY_IAM \
                    --region $REGION
                
                LAMBDA_URL=$(aws cloudformation describe-stacks \
                    --stack-name "pharma-ci-lambda-${ENVIRONMENT}" \
                    --region $REGION \
                    --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
                    --output text 2>/dev/null || echo "Lambda URL pending...")
                
                echo "  ✅ Lambda deployment complete: $LAMBDA_URL"
            else
                echo "  ⚠️  lambda-frontend.yaml not found"
            fi
            ;;
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
            
        "static")
# Configure secrets
log_info "Setting up API keys in Secrets Manager..."
SECRETS=(
    "pharma-ci/fda-api-key"
    "pharma-ci/pubmed-api-key"
    "pharma-ci/clinicaltrials-api-key"
    "pharma-ci/news-api-key"
    "pharma-ci/sec-api-key"
    "pharma-ci/uspto-api-key"
)

for secret in "${SECRETS[@]}"; do
    if ! aws secretsmanager describe-secret --secret-id "$secret" --region $REGION &>/dev/null; then
        aws secretsmanager create-secret \
            --name "$secret" \
            --description "API key for pharmaceutical CI platform" \
            --secret-string "PLACEHOLDER_KEY_NEEDS_CONFIGURATION" \
            --region $REGION &>/dev/null
        log_info "Created secret: $secret"
    fi
done
    esac
else
    echo "  ⚠️  Frontend directory not found"
fi

# Summary
echo ""
echo "✅ Production-Grade Deployment Complete!"
echo ""
echo "🔗 Infrastructure:"
echo "  API Endpoint: $API_ENDPOINT"
echo "  Data Bucket: $DATA_BUCKET"
echo "  User Pool: $USER_POOL_ID"
echo "  Knowledge Base: $KB_BUCKET"
echo ""
if [ -n "$FRONTEND_URL" ]; then
    echo "🌍 Frontend ($FRONTEND_TYPE):"
    echo "  URL: $FRONTEND_URL"
    echo ""
fi
echo "📊 Stacks Deployed:"
echo "  1. pharma-ci-core-${ENVIRONMENT} - Core infrastructure"
echo "  2. pharma-ci-auth-${ENVIRONMENT} - Authentication (Cognito)"
echo "  3. pharma-ci-data-${ENVIRONMENT} - Data processing"
echo "  4. pharma-ci-rag-${ENVIRONMENT} - AI and RAG"
echo "  5. pharma-ci-events-${ENVIRONMENT} - Event processing"
echo "  6. pharma-ci-monitoring-${ENVIRONMENT} - Monitoring"
echo "  7. pharma-ci-frontend-${ENVIRONMENT} - Frontend application"
echo ""
echo "🔧 Next Steps:"
echo "  1. Configure API keys in Secrets Manager"
echo "  2. Upload documents to Knowledge Base: s3://$KB_BUCKET"
echo "  3. Create Cognito users or enable self-registration"
echo "  4. Configure SES for email notifications"
echo "  5. Set up custom domain (optional)"
echo ""
echo "🚀 Frontend deployment options:"
echo "  ECS Fargate: ./deploy.sh $ENVIRONMENT $REGION ecs"
echo "  Lambda + API Gateway: ./deploy.sh $ENVIRONMENT $REGION lambda"
echo ""
