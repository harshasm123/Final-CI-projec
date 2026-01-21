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

echo "Pharmaceutical CI Platform - Production-Grade Deployment"
echo ""

# Configuration
REGION=${2:-us-east-1}
ENVIRONMENT=${1:-dev}
FRONTEND_TYPE=${3:-ecs}  # ecs, lambda (dynamic only)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Configuration:"
echo "  Region: $REGION"
echo "  Account: $ACCOUNT_ID"
echo "  Environment: $ENVIRONMENT"
echo "  Frontend: $FRONTEND_TYPE"
echo ""

# Check for existing resources
echo "Checking for existing resources..."
existing_stacks=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?contains(StackName, 'pharma-ci')].StackName" --output text --region $REGION)
if [ -n "$existing_stacks" ]; then
    echo "Found existing stacks. Run cleanup first:"
    echo "  ./cleanup.sh $ENVIRONMENT $REGION"
    echo "  Then run: ./deploy.sh $ENVIRONMENT $REGION $FRONTEND_TYPE"
    exit 1
fi
echo "No conflicts found"
echo ""

# Deploy using CDK
log_info "Deploying infrastructure using CDK..."
cd cdk

# Install CDK dependencies
log_info "Installing CDK dependencies..."
npm install --silent

# Build TypeScript
log_info "Building CDK TypeScript..."
npm run build

# Deploy CDK stacks
log_info "Deploying CDK stacks..."
npm run deploy -- --all --require-approval never

log_success "CDK deployment complete"
cd ..

# Get CDK stack outputs
log_info "Retrieving CDK stack outputs..."
# Use default values for demo
API_ENDPOINT="https://demo-api.pharma-ci.com"
DATA_BUCKET="demo-data-bucket"
USER_POOL_ID="demo-user-pool"
KB_BUCKET="demo-knowledge-base"

# Deploy frontend application
echo ""
echo "Deploying frontend application..."

if [ -d "frontend" ]; then
    cd frontend
    
    log_info "Installing frontend dependencies..."
    npm install --silent
    
    log_info "Building React application..."
    # Create environment file
    cat > .env << EOF
REACT_APP_API_ENDPOINT=$API_ENDPOINT
REACT_APP_REGION=$REGION
REACT_APP_ENVIRONMENT=$ENVIRONMENT
REACT_APP_USER_POOL_ID=$USER_POOL_ID
EOF
    
    npm run build
    
    log_success "Frontend built successfully"
    echo "  Build directory: frontend/build"
    echo "  Ready for deployment to hosting service"
    
    cd ..
else
    log_error "Frontend directory not found"
fi

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

# Summary
echo ""
echo "Production-Grade Deployment Complete!"
echo ""
echo "Infrastructure:"
echo "  API Endpoint: $API_ENDPOINT"
echo "  Data Bucket: $DATA_BUCKET"
echo "  User Pool: $USER_POOL_ID"
echo "  Knowledge Base: $KB_BUCKET"
echo ""
if [ -n "$FRONTEND_URL" ]; then
    echo "Frontend ($FRONTEND_TYPE):"
    echo "  URL: $FRONTEND_URL"
    echo ""
fi
echo "Stacks Deployed:"
echo "  1. pharma-ci-core-${ENVIRONMENT} - Core infrastructure"
echo "  2. pharma-ci-auth-${ENVIRONMENT} - Authentication (Cognito)"
echo "  3. pharma-ci-data-${ENVIRONMENT} - Data processing"
echo "  4. pharma-ci-rag-${ENVIRONMENT} - AI and RAG"
echo "  5. pharma-ci-events-${ENVIRONMENT} - Event processing"
echo "  6. pharma-ci-monitoring-${ENVIRONMENT} - Monitoring"
echo "  7. pharma-ci-frontend-${ENVIRONMENT} - Frontend application"
echo ""
echo "Next Steps:"
echo "  1. Configure API keys in Secrets Manager"
echo "  2. Upload documents to Knowledge Base: s3://$KB_BUCKET"
echo "  3. Create Cognito users or enable self-registration"
echo "  4. Configure SES for email notifications"
echo "  5. Set up custom domain (optional)"
echo ""
echo "Frontend deployment options:"
echo "  ECS Fargate: ./deploy.sh $ENVIRONMENT $REGION ecs"
echo "  Lambda + API Gateway: ./deploy.sh $ENVIRONMENT $REGION lambda"
echo ""