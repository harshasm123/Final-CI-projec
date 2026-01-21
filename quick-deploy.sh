#!/bin/bash

#############################################
# Quick Deployment Script
# Minimal setup for fast deployment
#############################################

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

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}

echo "=========================================="
echo "Quick Deployment - Pharmaceutical CI"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""

# Step 1: Install Node.js if needed
if ! command -v node &> /dev/null; then
    log_info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Step 2: Install AWS CDK if needed
if ! command -v cdk &> /dev/null; then
    log_info "Installing AWS CDK..."
    npm install -g aws-cdk
fi

# Step 3: Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    log_info "Run: aws configure"
    exit 1
fi

log_success "Prerequisites verified"
echo ""

# Step 4: Deploy CDK
log_info "Deploying infrastructure..."
cd cdk

npm install --silent
npm run build
npm run deploy -- \
    --context environment=$ENVIRONMENT \
    --context region=$REGION \
    --require-approval never

cd ..

log_success "Deployment completed!"
echo ""
echo "Next steps:"
echo "  1. Configure API keys in Secrets Manager"
echo "  2. Access your application"
echo "  3. Monitor logs: aws logs tail /aws/lambda/ci-* --follow"
echo ""
