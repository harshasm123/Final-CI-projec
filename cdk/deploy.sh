#!/bin/bash

#############################################
# AWS CDK Deployment Script
# Deploys Pharmaceutical CI Platform using CDK
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}

# Validate inputs
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid environment. Use: dev, staging, or prod"
    exit 1
fi

echo "=========================================="
echo "AWS CDK Deployment - Pharmaceutical CI"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""

# Step 1: Check prerequisites
log_info "Checking prerequisites..."
if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    log_error "npm is not installed"
    exit 1
fi

if ! command -v cdk &> /dev/null; then
    log_warning "AWS CDK CLI not found. Installing globally..."
    npm install -g aws-cdk
fi

log_success "Prerequisites check passed"
echo ""

# Step 2: Install dependencies
log_info "Installing CDK dependencies..."
npm install
log_success "Dependencies installed"
echo ""

# Step 3: Build TypeScript
log_info "Building TypeScript..."
npm run build
log_success "TypeScript build completed"
echo ""

# Step 4: Synthesize CloudFormation template
log_info "Synthesizing CloudFormation template..."
npm run synth -- --context environment=$ENVIRONMENT --context region=$REGION
log_success "CloudFormation template synthesized"
echo ""

# Step 5: Show diff (optional)
log_info "Showing infrastructure changes..."
npm run diff -- --context environment=$ENVIRONMENT --context region=$REGION || true
echo ""

# Step 6: Deploy stacks
log_info "Deploying stacks..."
read -p "Do you want to proceed with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_error "Deployment cancelled by user"
    exit 1
fi

npm run deploy -- \
    --context environment=$ENVIRONMENT \
    --context region=$REGION \
    --require-approval never

log_success "Deployment completed successfully!"
echo ""

# Step 7: Display outputs
log_info "Retrieving stack outputs..."
echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""
echo "Stacks deployed:"
echo "  • pharma-ci-platform-${ENVIRONMENT}"
echo "  • pharma-ci-bedrock-${ENVIRONMENT}"
echo "  • pharma-ci-eventbridge-${ENVIRONMENT}"
echo ""
echo "To view outputs, run:"
echo "  aws cloudformation describe-stacks --stack-name pharma-ci-platform-${ENVIRONMENT} --region ${REGION}"
echo ""
echo "To destroy stacks, run:"
echo "  npm run destroy -- --context environment=${ENVIRONMENT} --context region=${REGION}"
echo ""

log_success "Deployment script completed!"
