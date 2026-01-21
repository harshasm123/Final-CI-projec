#!/bin/bash

#############################################
# Prerequisites Check Script
# Verifies all required tools and AWS setup
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Logging functions
check_pass() { 
    echo -e "${GREEN}[✓]${NC} $1"
    ((PASSED++))
}

check_fail() { 
    echo -e "${RED}[✗]${NC} $1"
    ((FAILED++))
}

check_warn() { 
    echo -e "${YELLOW}[!]${NC} $1"
    ((WARNINGS++))
}

check_info() { 
    echo -e "${BLUE}[i]${NC} $1"
}

echo "=========================================="
echo "Pharmaceutical CI Platform"
echo "Prerequisites Check"
echo "=========================================="
echo ""

# ============================================
# System Commands
# ============================================
echo -e "${BLUE}Checking System Commands...${NC}"

if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    check_pass "Git: $GIT_VERSION"
else
    check_fail "Git: NOT INSTALLED"
fi

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    check_pass "Node.js: $NODE_VERSION"
else
    check_fail "Node.js: NOT INSTALLED"
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    check_pass "npm: $NPM_VERSION"
else
    check_fail "npm: NOT INSTALLED"
fi

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    check_pass "Python 3: $PYTHON_VERSION"
else
    check_fail "Python 3: NOT INSTALLED"
fi

if command -v pip3 &> /dev/null; then
    check_pass "pip3: INSTALLED"
else
    check_fail "pip3: NOT INSTALLED"
fi

if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version | awk '{print $1}')
    check_pass "AWS CLI: $AWS_VERSION"
else
    check_fail "AWS CLI: NOT INSTALLED"
fi

if command -v cdk &> /dev/null; then
    CDK_VERSION=$(cdk --version)
    check_pass "AWS CDK: $CDK_VERSION"
else
    check_warn "AWS CDK: NOT INSTALLED (will install during deployment)"
fi

echo ""

# ============================================
# AWS Configuration
# ============================================
echo -e "${BLUE}Checking AWS Configuration...${NC}"

if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    check_pass "AWS Credentials: Configured"
    check_info "Account ID: $ACCOUNT_ID"
    check_info "User ARN: $USER_ARN"
else
    check_fail "AWS Credentials: NOT CONFIGURED"
fi

if [ -n "$AWS_REGION" ]; then
    check_pass "AWS Region: $AWS_REGION"
else
    check_warn "AWS Region: NOT SET (will use us-east-1)"
fi

echo ""

# ============================================
# System Resources
# ============================================
echo -e "${BLUE}Checking System Resources...${NC}"

# Disk space
DISK_AVAILABLE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$DISK_AVAILABLE" -ge 20 ]; then
    check_pass "Disk Space: ${DISK_AVAILABLE}GB available"
else
    check_warn "Disk Space: Only ${DISK_AVAILABLE}GB available (recommended: 20GB+)"
fi

# Memory
if command -v free &> /dev/null; then
    MEM_AVAILABLE=$(free -BG | awk 'NR==2 {print $7}' | sed 's/G//')
    if [ "$MEM_AVAILABLE" -ge 2 ]; then
        check_pass "Memory: ${MEM_AVAILABLE}GB available"
    else
        check_warn "Memory: Only ${MEM_AVAILABLE}GB available (recommended: 2GB+)"
    fi
fi

echo ""

# ============================================
# Git Configuration
# ============================================
echo -e "${BLUE}Checking Git Configuration...${NC}"

GIT_USER=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$GIT_USER" ]; then
    check_pass "Git User: $GIT_USER"
else
    check_warn "Git User: NOT CONFIGURED"
fi

if [ -n "$GIT_EMAIL" ]; then
    check_pass "Git Email: $GIT_EMAIL"
else
    check_warn "Git Email: NOT CONFIGURED"
fi

echo ""

# ============================================
# AWS Permissions
# ============================================
echo -e "${BLUE}Checking AWS Permissions...${NC}"

# Check CloudFormation
if aws cloudformation describe-stacks --region us-east-1 &> /dev/null; then
    check_pass "CloudFormation: Access granted"
else
    check_warn "CloudFormation: May not have access"
fi

# Check Lambda
if aws lambda list-functions --region us-east-1 &> /dev/null; then
    check_pass "Lambda: Access granted"
else
    check_warn "Lambda: May not have access"
fi

# Check S3
if aws s3 ls &> /dev/null; then
    check_pass "S3: Access granted"
else
    check_warn "S3: May not have access"
fi

# Check DynamoDB
if aws dynamodb list-tables --region us-east-1 &> /dev/null; then
    check_pass "DynamoDB: Access granted"
else
    check_warn "DynamoDB: May not have access"
fi

# Check Elasticsearch
if aws es describe-elasticsearch-domains --region us-east-1 &> /dev/null; then
    check_pass "Elasticsearch: Access granted"
else
    check_warn "Elasticsearch: May not have access"
fi

# Check API Gateway
if aws apigateway get-account --region us-east-1 &> /dev/null; then
    check_pass "API Gateway: Access granted"
else
    check_warn "API Gateway: May not have access"
fi

echo ""

# ============================================
# Project Structure
# ============================================
echo -e "${BLUE}Checking Project Structure...${NC}"

if [ -d "cdk" ]; then
    check_pass "CDK Directory: Found"
else
    check_fail "CDK Directory: NOT FOUND"
fi

if [ -d "frontend" ]; then
    check_pass "Frontend Directory: Found"
else
    check_fail "Frontend Directory: NOT FOUND"
fi

if [ -d "backend" ]; then
    check_pass "Backend Directory: Found"
else
    check_fail "Backend Directory: NOT FOUND"
fi

if [ -d "scripts" ]; then
    check_pass "Scripts Directory: Found"
else
    check_fail "Scripts Directory: NOT FOUND"
fi

echo ""

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "Prerequisites Check Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical prerequisites are met!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. cd cdk"
    echo "  2. npm install"
    echo "  3. ./deploy.sh dev us-east-1"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some critical prerequisites are missing.${NC}"
    echo ""
    echo "Please install missing components and try again."
    echo ""
    exit 1
fi
