#!/bin/bash

#############################################
# Pharmaceutical CI Platform Deployment
# Complete deployment with CDK + Frontend
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
STACK_NAME="pharma-ci-platform-${ENVIRONMENT}"

# Validate inputs
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid environment. Use: dev, staging, or prod"
    exit 1
fi

echo "=========================================="
echo "Pharmaceutical CI Platform Deployment"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""

# ============================================
# Step 1: Prerequisites Setup
# ============================================
log_info "Step 1: Setting up prerequisites..."
if [ -f "prereq.sh" ]; then
    chmod +x prereq.sh
    ./prereq.sh
else
    log_error "Prerequisites script not found"
    exit 1
fi
echo ""

# ============================================
# Step 2: Verify AWS Credentials
# ============================================
log_info "Step 2: Verifying AWS credentials..."

if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    log_info "Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
log_success "AWS credentials verified"
log_info "Account ID: $ACCOUNT_ID"
log_info "User ARN: $USER_ARN"
echo ""

# ============================================
# Step 3: Deploy Infrastructure with CDK
# ============================================
log_info "Step 3: Deploying infrastructure with AWS CDK..."

if [ ! -d "cdk" ]; then
    log_error "CDK directory not found"
    exit 1
fi

cd cdk

# Install dependencies
log_info "Installing CDK dependencies..."
npm install --silent

# Build TypeScript
log_info "Building TypeScript..."
npm run build

# Synthesize CloudFormation
log_info "Synthesizing CloudFormation template..."
npm run synth -- --context environment=$ENVIRONMENT --context region=$REGION > /dev/null

# Deploy stacks
log_info "Deploying CloudFormation stacks..."
npm run deploy -- \
    --context environment=$ENVIRONMENT \
    --context region=$REGION \
    --require-approval never

log_success "Infrastructure deployed successfully"
echo ""

# Get stack outputs
log_info "Retrieving stack outputs..."
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
    --output text 2>/dev/null || echo "")

DATA_LAKE_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`DataLakeBucket`].OutputValue' \
    --output text 2>/dev/null || echo "")

SEARCH_DOMAIN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`SearchDomain`].OutputValue' \
    --output text 2>/dev/null || echo "")

cd ..
echo ""

# ============================================
# Step 4: Deploy Frontend
# ============================================
log_info "Step 4: Deploying frontend..."

if [ ! -d "frontend" ]; then
    log_error "Frontend directory not found"
    exit 1
fi

cd frontend

# Install dependencies
log_info "Installing frontend dependencies..."
npm install --silent

# Create environment file
log_info "Creating environment configuration..."
cat > .env.local << EOF
REACT_APP_API_ENDPOINT=$API_ENDPOINT
REACT_APP_ENVIRONMENT=$ENVIRONMENT
REACT_APP_REGION=$REGION
EOF

# Build frontend
log_info "Building frontend..."
npm run build

# Create S3 bucket for frontend
FRONTEND_BUCKET="ci-frontend-${ENVIRONMENT}-${RANDOM}"
log_info "Creating S3 bucket for frontend: $FRONTEND_BUCKET"
aws s3 mb s3://$FRONTEND_BUCKET --region $REGION 2>/dev/null || true

# Configure bucket for static website hosting
log_info "Configuring S3 bucket for static website hosting..."
aws s3 website s3://$FRONTEND_BUCKET \
    --index-document index.html \
    --error-document index.html

# Upload build files
log_info "Uploading frontend files to S3..."
aws s3 sync build/ s3://$FRONTEND_BUCKET --delete --quiet

# Make bucket public
log_info "Configuring bucket policy..."
aws s3api put-bucket-policy \
    --bucket $FRONTEND_BUCKET \
    --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Sid\": \"PublicReadGetObject\",
            \"Effect\": \"Allow\",
            \"Principal\": \"*\",
            \"Action\": \"s3:GetObject\",
            \"Resource\": \"arn:aws:s3:::$FRONTEND_BUCKET/*\"
        }]
    }" 2>/dev/null || true

# Create CloudFront distribution
log_info "Creating CloudFront distribution..."
CLOUDFRONT_CONFIG=$(cat <<EOF
{
    "CallerReference": "pharma-ci-${ENVIRONMENT}-$(date +%s)",
    "Comment": "Pharmaceutical CI Platform Frontend - $ENVIRONMENT",
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [{
            "Id": "S3Origin",
            "DomainName": "$FRONTEND_BUCKET.s3.${REGION}.amazonaws.com",
            "S3OriginConfig": {
                "OriginAccessIdentity": ""
            }
        }]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3Origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"]
        },
        "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
        "Compress": true
    },
    "Enabled": true
}
EOF
)

DISTRIBUTION_ID=$(aws cloudfront create-distribution \
    --distribution-config "$CLOUDFRONT_CONFIG" \
    --query 'Distribution.Id' \
    --output text 2>/dev/null || echo "")

if [ -n "$DISTRIBUTION_ID" ]; then
    log_success "CloudFront distribution created: $DISTRIBUTION_ID"
    
    # Get CloudFront domain
    log_info "Waiting for CloudFront distribution to be ready..."
    sleep 5
    
    CLOUDFRONT_DOMAIN=$(aws cloudfront get-distribution \
        --id $DISTRIBUTION_ID \
        --query 'Distribution.DomainName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$CLOUDFRONT_DOMAIN" ]; then
        log_success "CloudFront domain: $CLOUDFRONT_DOMAIN"
    fi
else
    log_warning "Could not create CloudFront distribution"
    CLOUDFRONT_DOMAIN="$FRONTEND_BUCKET.s3-website-${REGION}.amazonaws.com"
fi

cd ..
echo ""

# ============================================
# Step 5: Configure API Keys
# ============================================
log_info "Step 5: Setting up API keys in Secrets Manager..."

SECRETS=(
    "ci-fda-api-key"
    "ci-pubmed-api-key"
    "ci-clinicaltrials-api-key"
    "ci-news-api-key"
    "ci-sec-api-key"
    "ci-uspto-api-key"
)

for secret in "${SECRETS[@]}"; do
    if ! aws secretsmanager describe-secret --secret-id "$secret" --region $REGION &>/dev/null; then
        aws secretsmanager create-secret \
            --name "$secret" \
            --description "API key for pharmaceutical CI platform" \
            --secret-string "PLACEHOLDER_KEY_NEEDS_CONFIGURATION" \
            --region $REGION &>/dev/null
        log_info "Created secret: $secret"
    else
        log_info "Secret already exists: $secret"
    fi
done

log_warning "Please configure actual API keys in AWS Secrets Manager"
echo ""

# ============================================
# Step 6: Deployment Summary
# ============================================
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}Infrastructure:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo "  Stack: $STACK_NAME"
echo ""

if [ -n "$API_ENDPOINT" ]; then
    echo -e "${GREEN}API Endpoint:${NC}"
    echo "  $API_ENDPOINT"
    echo ""
fi

if [ -n "$DATA_LAKE_BUCKET" ]; then
    echo -e "${GREEN}Data Storage:${NC}"
    echo "  S3 Bucket: $DATA_LAKE_BUCKET"
    echo ""
fi

if [ -n "$SEARCH_DOMAIN" ]; then
    echo -e "${GREEN}Search & Analytics:${NC}"
    echo "  Elasticsearch: $SEARCH_DOMAIN"
    echo ""
fi

echo -e "${GREEN}Frontend:${NC}"
echo "  S3 Bucket: $FRONTEND_BUCKET"
if [ -n "$CLOUDFRONT_DOMAIN" ]; then
    echo -e "  ${YELLOW}CloudFront CDN: https://$CLOUDFRONT_DOMAIN${NC}"
    echo ""
    echo -e "${BLUE}Access your application at:${NC}"
    echo -e "  ${GREEN}https://$CLOUDFRONT_DOMAIN${NC}"
else
    echo "  S3 Website: http://$FRONTEND_BUCKET.s3-website-${REGION}.amazonaws.com"
fi
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Configure API keys in Secrets Manager:"
for secret in "${SECRETS[@]}"; do
    echo "     • $secret"
done
echo ""
echo "  2. Access the application:"
if [ -n "$CLOUDFRONT_DOMAIN" ]; then
    echo "     https://$CLOUDFRONT_DOMAIN"
else
    echo "     http://$FRONTEND_BUCKET.s3-website-${REGION}.amazonaws.com"
fi
echo ""
echo "  3. Monitor Lambda functions:"
echo "     aws logs tail /aws/lambda/ci-* --follow"
echo ""
echo "  4. View stack outputs:"
echo "     aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  View logs: aws logs tail /aws/lambda/ci-* --follow"
echo "  Check stack: aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION"
echo "  Destroy: cd cdk && npm run destroy -- --context environment=$ENVIRONMENT --context region=$REGION"
echo ""

log_success "Deployment script completed successfully!"
echo "=========================================="
