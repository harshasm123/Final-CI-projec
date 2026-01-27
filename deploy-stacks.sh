#!/bin/bash

################################################################################
# Production-Grade Pharmaceutical CI Platform Deployment
# Enterprise AWS Serverless Architecture with Security & Monitoring
################################################################################

set -euo pipefail

# Colors and logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

echo "🏭 Production-Grade Pharmaceutical CI Platform Deployment"
echo "📊 Enterprise AWS Serverless Architecture"
echo ""

# Configuration
ENVIRONMENT=${1:-prod}
REGION=${2:-us-east-1}
GITHUB_TOKEN=${3:-}

# Prompt for GitHub token if not provided
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo -n "Enter GitHub Personal Access Token: "
    read -s GITHUB_TOKEN
    echo ""
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "GitHub token is required for Amplify deployment"
        exit 1
    fi
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TIMESTAMP=$(date +%s)

log_info "Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo "  Account: $ACCOUNT_ID"
echo ""

# Skip VPC deployment - use existing VPC
log_info "Using existing VPC infrastructure..."
VPC_STACK_NAME="pharma-ci-vpc-prod-1769535728"

# Get VPC outputs
VPC_ID=$(aws cloudformation describe-stacks \
    --stack-name $VPC_STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`VPC`].OutputValue' \
    --output text --region $REGION)

SUBNET_IDS=$(aws cloudformation describe-stacks \
    --stack-name $VPC_STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnets`].OutputValue' \
    --output text --region $REGION)

log_info "VPC ID: $VPC_ID"
log_info "Private Subnets: $SUBNET_IDS"

# Deploy AI Stack with VPC
log_info "Deploying AI/RAG stack with VPC security..."
AI_STACK_NAME="pharma-ci-rag-${ENVIRONMENT}-${TIMESTAMP}"

aws cloudformation deploy \
    --template-file ai-stack.yaml \
    --stack-name $AI_STACK_NAME \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        VpcId=$VPC_ID \
        PrivateSubnetIds=$SUBNET_IDS \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --tags Environment=$ENVIRONMENT Project=PharmaCI

if [[ $? -eq 0 ]]; then
    log_success "AI stack deployed successfully"
else
    log_error "AI stack deployment failed"
    exit 1
fi

# Get AI API endpoint
AI_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $AI_STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`AIAPIEndpoint`].OutputValue' \
    --output text --region $REGION)

# Deploy Frontend Stack
log_info "Deploying frontend with Amplify..."
FRONTEND_STACK_NAME="pharma-ci-frontend-${ENVIRONMENT}-${TIMESTAMP}"

aws cloudformation deploy \
    --template-file frontend-stack.yaml \
    --stack-name $FRONTEND_STACK_NAME \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        GitHubToken=$GITHUB_TOKEN \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --tags Environment=$ENVIRONMENT Project=PharmaCI

if [[ $? -eq 0 ]]; then
    log_success "Frontend stack deployed successfully"
else
    log_error "Frontend stack deployment failed"
    exit 1
fi

# Get deployment outputs
AMPLIFY_URL=$(aws cloudformation describe-stacks \
    --stack-name $FRONTEND_STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`AmplifyURL`].OutputValue' \
    --output text --region $REGION)

# Final summary
echo ""
echo "🎉 Production-Grade Deployment Complete!"
echo ""
echo "📊 Infrastructure Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  VPC Stack: $VPC_STACK_NAME"
echo "  AI Stack: $AI_STACK_NAME"
echo "  Frontend Stack: $FRONTEND_STACK_NAME"
echo ""
echo "🔗 Access Points:"
echo "  🤖 AI API: $AI_ENDPOINT"
echo "  🌐 Frontend: $AMPLIFY_URL"
echo ""
echo "🧪 Testing:"
echo "  API Test: curl -X POST '$AI_ENDPOINT/ai' -H 'Content-Type: application/json' -d '{\"query\":\"What are the latest FDA approvals?\"}'"
echo "  Frontend: Open $AMPLIFY_URL in browser"
echo ""
echo "🔐 Security Features Enabled:"
echo "  ✅ VPC isolation (Lambda functions)"
echo "  ✅ KMS encryption (S3, logs)"
echo "  ✅ IAM least privilege"
echo "  ✅ API Gateway throttling"
echo "  ✅ Request validation"
echo "  ✅ Private subnets with NAT Gateway"
echo ""
log_success "Deployment completed successfully at $(date)"
echo "Stack Names: $VPC_STACK_NAME, $AI_STACK_NAME, $FRONTEND_STACK_NAME" > deployment-info.txt