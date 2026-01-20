#!/bin/bash

################################################################################
# Pharmaceutical CI Platform - Complete Deployment Script
# Deploys the entire serverless competitive intelligence platform
################################################################################

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
BEDROCK_STACK_NAME="pharma-ci-bedrock-${ENVIRONMENT}"
EVENTBRIDGE_STACK_NAME="pharma-ci-eventbridge-${ENVIRONMENT}"

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
echo "Stack Name: $STACK_NAME"
echo ""

# Step 0: Check and cleanup failed stacks
log_info "Checking for failed stacks..."
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ] || [ "$STACK_STATUS" == "CREATE_FAILED" ] || [ "$STACK_STATUS" == "UPDATE_FAILED" ]; then
    log_warning "Stack is in $STACK_STATUS state. Cleaning up..."
    
    # Delete the failed stack
    aws cloudformation delete-stack \
        --stack-name $STACK_NAME \
        --region $REGION
    
    log_info "Waiting for stack deletion to complete (this may take a few minutes)..."
    aws cloudformation wait stack-delete-complete \
        --stack-name $STACK_NAME \
        --region $REGION 2>/dev/null || true
    
    log_success "Failed stack cleaned up successfully"
    echo ""
elif [ "$STACK_STATUS" != "DOES_NOT_EXIST" ]; then
    log_warning "Stack exists with status: $STACK_STATUS"
    read -p "Do you want to continue with update? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Deployment cancelled by user"
        exit 1
    fi
fi
echo ""

# Step 1: Prerequisites Check
log_info "Running prerequisites check..."
if [ -f "prereq.sh" ]; then
    chmod +x prereq.sh
    if ! ./prereq.sh; then
        log_error "Prerequisites check failed. Please fix issues before deployment."
        exit 1
    fi
else
    log_warning "Prerequisites script not found. Continuing with deployment..."
fi
echo ""

# Step 1.5: Install zip if not available
log_info "Checking for zip utility..."
if ! command -v zip &> /dev/null; then
    log_warning "zip not found. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq zip
    elif command -v yum &> /dev/null; then
        sudo yum install -y -q zip
    elif command -v brew &> /dev/null; then
        brew install zip
    else
        log_error "Could not install zip. Please install manually."
        exit 1
    fi
    log_success "zip installed successfully"
else
    log_success "zip is available"
fi
echo ""

# Step 2: Create S3 bucket for deployment artifacts
log_info "Creating deployment bucket..."
BUCKET_NAME="pharma-ci-deployment-${ENVIRONMENT}-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region $REGION
log_success "Created deployment bucket: $BUCKET_NAME"
echo ""

# Step 3: Package Lambda functions
log_info "Packaging Lambda functions..."
mkdir -p dist

# Package comprehensive data ingestion
log_info "Packaging comprehensive data ingestion..."
cd backend/src
zip -r ../../dist/comprehensive-data-ingestion.zip comprehensive_data_ingestion.py
cd ../..

# Package data quality pipeline
log_info "Packaging data quality pipeline..."
cd backend/src
zip -r ../../dist/data-quality-pipeline.zip data_quality_pipeline.py
cd ../..

# Package other Lambda functions (if they exist)
if [ -f "backend/src/dashboard_handler.py" ]; then
    cd backend/src
    zip -r ../../dist/dashboard-handler.zip dashboard_handler.py
    cd ../..
fi

if [ -f "backend/src/brand_intelligence_handler.py" ]; then
    cd backend/src
    zip -r ../../dist/brand-intelligence-handler.zip brand_intelligence_handler.py
    cd ../..
fi

if [ -f "backend/src/alerts_handler.py" ]; then
    cd backend/src
    zip -r ../../dist/alerts-handler.zip alerts_handler.py
    cd ../..
fi

if [ -f "backend/src/ai_insights_handler.py" ]; then
    cd backend/src
    zip -r ../../dist/ai-insights-handler.zip ai_insights_handler.py
    cd ../..
fi

log_success "Lambda functions packaged"
echo ""

# Step 4: Upload Lambda packages to S3
log_info "Uploading Lambda packages..."
aws s3 cp dist/ s3://$BUCKET_NAME/lambda/ --recursive
log_success "Lambda packages uploaded"
echo ""

# Step 5: Deploy main infrastructure
log_info "Deploying main infrastructure stack..."
aws cloudformation deploy \
    --template-file architecture.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        LambdaBucket=$BUCKET_NAME \
    --capabilities CAPABILITY_IAM \
    --region $REGION

if [ $? -eq 0 ]; then
    log_success "Main infrastructure deployed successfully"
else
    log_error "Main infrastructure deployment failed"
    exit 1
fi
echo ""

# Step 6: Deploy Bedrock Agent
log_info "Deploying Bedrock Agent..."
if [ -f "bedrock-agent.yaml" ]; then
    aws cloudformation deploy \
        --template-file bedrock-agent.yaml \
        --stack-name $BEDROCK_STACK_NAME \
        --parameter-overrides \
            Environment=$ENVIRONMENT \
        --capabilities CAPABILITY_IAM \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        log_success "Bedrock Agent deployed successfully"
    else
        log_warning "Bedrock Agent deployment failed (may need manual setup)"
    fi
else
    log_warning "Bedrock Agent template not found"
fi
echo ""

# Step 7: Deploy EventBridge Rules
log_info "Deploying EventBridge scheduling rules..."
if [ -f "comprehensive-eventbridge-rules.yaml" ]; then
    aws cloudformation deploy \
        --template-file comprehensive-eventbridge-rules.yaml \
        --stack-name $EVENTBRIDGE_STACK_NAME \
        --parameter-overrides \
            Environment=$ENVIRONMENT \
            MainStackName=$STACK_NAME \
        --capabilities CAPABILITY_IAM \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        log_success "EventBridge rules deployed successfully"
    else
        log_warning "EventBridge rules deployment failed"
    fi
else
    log_warning "EventBridge rules template not found"
fi
echo ""

# Step 8: Get stack outputs
log_info "Retrieving stack outputs..."
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
    --output text)

S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`DataBucket`].OutputValue' \
    --output text)

OPENSEARCH_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`OpenSearchEndpoint`].OutputValue' \
    --output text)

log_success "Stack outputs retrieved"
echo ""

# Step 9: Configure API keys in Secrets Manager
log_info "Setting up API keys in Secrets Manager..."

# Create secrets for external APIs
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
    else
        log_info "Secret already exists: $secret"
    fi
done

log_warning "Please configure actual API keys in AWS Secrets Manager"
echo ""

# Step 10: Deploy Frontend
log_info "Deploying frontend..."
if [ -d "frontend" ]; then
    cd frontend
    
    # Install dependencies
    log_info "Installing frontend dependencies..."
    npm install
    
    # Create environment file
    log_info "Creating environment configuration..."
    cat > .env << EOF
REACT_APP_API_ENDPOINT=$API_ENDPOINT
REACT_APP_REGION=$REGION
REACT_APP_ENVIRONMENT=$ENVIRONMENT
EOF
    
    # Build frontend
    log_info "Building frontend..."
    npm run build
    
    # Deploy to S3 (if bucket exists)
    if [ -n "$S3_BUCKET" ]; then
        FRONTEND_BUCKET="${S3_BUCKET}-frontend"
        
        # Create frontend bucket
        aws s3 mb s3://$FRONTEND_BUCKET --region $REGION 2>/dev/null || true
        
        # Configure bucket for static website hosting
        aws s3 website s3://$FRONTEND_BUCKET \
            --index-document index.html \
            --error-document error.html
        
        # Upload build files
        aws s3 sync build/ s3://$FRONTEND_BUCKET --delete
        
        # Make bucket public (for demo purposes)
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
            }"
        
        FRONTEND_URL="http://$FRONTEND_BUCKET.s3-website-$REGION.amazonaws.com"
        log_success "Frontend deployed to: $FRONTEND_URL"
    else
        log_warning "Frontend built but not deployed (no S3 bucket found)"
    fi
    
    cd ..
else
    log_warning "Frontend directory not found"
fi
echo ""

# Step 11: Initialize data ingestion
log_info "Initializing data ingestion..."
if [ -n "$API_ENDPOINT" ]; then
    # Trigger initial data ingestion
    curl -X POST "$API_ENDPOINT/trigger-ingestion" \
        -H "Content-Type: application/json" \
        -d '{"source": "all", "initial": true}' \
        &>/dev/null || log_warning "Could not trigger initial ingestion"
    
    log_success "Initial data ingestion triggered"
else
    log_warning "API endpoint not available for triggering ingestion"
fi
echo ""

# Step 12: Cleanup deployment artifacts
log_info "Cleaning up deployment artifacts..."
rm -rf dist/
aws s3 rb s3://$BUCKET_NAME --force
log_success "Deployment artifacts cleaned up"
echo ""

# Step 13: Deployment summary
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
log_success "Pharmaceutical CI Platform deployed successfully!"
echo ""
echo "Infrastructure:"
echo "• Environment: $ENVIRONMENT"
echo "• Region: $REGION"
echo "• Main Stack: $STACK_NAME"
echo "• Bedrock Stack: $BEDROCK_STACK_NAME"
echo "• EventBridge Stack: $EVENTBRIDGE_STACK_NAME"
echo ""

if [ -n "$API_ENDPOINT" ]; then
    echo "API Endpoints:"
    echo "• Main API: $API_ENDPOINT"
    echo "• Dashboard: $API_ENDPOINT/dashboard"
    echo "• Brand Intelligence: $API_ENDPOINT/brand-intelligence"
    echo "• Alerts: $API_ENDPOINT/alerts"
    echo "• AI Insights: $API_ENDPOINT/ai-insights"
    echo ""
fi

if [ -n "$FRONTEND_URL" ]; then
    echo "Frontend:"
    echo "• URL: $FRONTEND_URL"
    echo ""
fi

echo "Data Infrastructure:"
echo "• S3 Bucket: $S3_BUCKET"
echo "• OpenSearch: $OPENSEARCH_ENDPOINT"
echo ""

echo "Next Steps:"
echo "1. Configure API keys in AWS Secrets Manager:"
for secret in "${SECRETS[@]}"; do
    echo "   • $secret"
done
echo ""
echo "2. Access the application:"
if [ -n "$FRONTEND_URL" ]; then
    echo "   • Frontend: $FRONTEND_URL"
fi
if [ -n "$API_ENDPOINT" ]; then
    echo "   • API: $API_ENDPOINT"
fi
echo ""
echo "3. Monitor data ingestion in CloudWatch Logs"
echo "4. Configure alerts and notifications"
echo "5. Set up user authentication (if required)"
echo ""

echo "Documentation:"
echo "• Architecture: architecture.yaml"
echo "• Data Sources: COMPREHENSIVE_DATA_SOURCES.md"
echo "• API Documentation: Available at $API_ENDPOINT/docs"
echo ""

log_success "Deployment completed successfully!"
echo "=========================================="