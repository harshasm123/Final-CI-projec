#!/bin/bash

# Pharmaceutical CI Platform Deployment Script
set -e

echo "🚀 Starting Pharmaceutical CI Platform Deployment"

# Configuration - Dynamic region detection
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
    REGION="us-west-2"
    aws configure set region $REGION
    echo "ℹ️  No region configured. Using $REGION"
fi

# Check for problematic regions (us-east-1 has CloudFormation hooks)
PROBLEMATIC_REGIONS=("us-east-1" "eu-west-1" "ap-southeast-1")
for prob_region in "${PROBLEMATIC_REGIONS[@]}"; do
    if [ "$REGION" = "$prob_region" ]; then
        echo "⚠️  $REGION has CloudFormation hooks blocking CDK"
        echo "   This region has AWS::EarlyValidation::ResourceExistenceCheck enabled"
        REGION="us-west-2"
        aws configure set region $REGION
        echo "✅ Automatically switched to $REGION"
        echo "   If you need to use $prob_region, contact AWS administrator to disable the hook"
        break
    fi
done

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ENVIRONMENT=${1:-dev}
STACK_NAME="pharma-ci-platform-${ENVIRONMENT}"

echo "📋 Configuration:"
echo "  Region: $REGION"
echo "  Account ID: $ACCOUNT_ID"
echo "  Environment: $ENVIRONMENT"
echo "  Stack Name: $STACK_NAME"

# Check prerequisites
echo ""
echo "🔍 Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install Node.js and npm."
    exit 1
fi

if ! command -v cdk &> /dev/null; then
    echo "📦 Installing AWS CDK..."
    npm install -g aws-cdk
fi

echo "✅ Prerequisites check complete"

# Step 1: Check and clean CDKToolkit stack
echo ""
echo "🧹 Checking CDKToolkit stack health..."
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name CDKToolkit --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NONE")

case $STACK_STATUS in
    "CREATE_COMPLETE"|"UPDATE_COMPLETE")
        echo "  ✅ CDKToolkit is healthy ($STACK_STATUS)"
        # Verify SSM parameter exists
        if aws ssm get-parameter --name /cdk-bootstrap/hnb659fds/version --region $REGION &>/dev/null; then
            echo "  ✅ Bootstrap version parameter exists"
        else
            echo "  ⚠️  Bootstrap parameter missing, will re-bootstrap"
            STACK_STATUS="INCOMPLETE"
        fi
        ;;
    "ROLLBACK_COMPLETE"|"REVIEW_IN_PROGRESS"|"CREATE_FAILED"|"ROLLBACK_IN_PROGRESS")
        echo "  ⚠️  Found failed stack in $STACK_STATUS state. Cleaning up..."
        aws cloudformation delete-stack --stack-name CDKToolkit --region $REGION
        echo "  Waiting for deletion..."
        aws cloudformation wait stack-delete-complete --stack-name CDKToolkit --region $REGION 2>/dev/null || true
        echo "  ✅ Cleanup complete"
        STACK_STATUS="NONE"
        ;;
    "NONE")
        echo "  ℹ️  CDKToolkit not found, will bootstrap"
        ;;
    *)
        echo "  ℹ️  CDKToolkit status: $STACK_STATUS"
        ;;
esac

# Step 2: Bootstrap CDK (if needed)
if [ "$STACK_STATUS" = "NONE" ] || [ "$STACK_STATUS" = "INCOMPLETE" ]; then
    echo ""
    echo "🏗️  Bootstrapping CDK in $REGION..."
    if cdk bootstrap aws://${ACCOUNT_ID}/${REGION}; then
        echo "  ✅ CDK bootstrap successful"
        
        # Verify bootstrap completed successfully
        FINAL_STATUS=$(aws cloudformation describe-stacks --stack-name CDKToolkit --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
        if [ "$FINAL_STATUS" != "CREATE_COMPLETE" ] && [ "$FINAL_STATUS" != "UPDATE_COMPLETE" ]; then
            echo "  ❌ Bootstrap failed with status: $FINAL_STATUS"
            exit 1
        fi
        
        # Verify SSM parameter
        if ! aws ssm get-parameter --name /cdk-bootstrap/hnb659fds/version --region $REGION &>/dev/null; then
            echo "  ❌ Bootstrap parameter not created"
            exit 1
        fi
        echo "  ✅ Bootstrap verification passed"
    else
        echo "  ❌ CDK bootstrap failed"
        exit 1
    fi
else
    echo "  ℹ️  CDK already bootstrapped, skipping"
fi

# Step 3: Install dependencies
echo ""
echo "📦 Installing dependencies..."

if [ ! -d "cdk" ]; then
    echo "❌ CDK directory not found"
    exit 1
fi

cd cdk
echo "  Installing CDK dependencies..."
npm install

# Step 4: Build TypeScript
echo ""
echo "🔨 Building TypeScript..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ TypeScript build failed"
    exit 1
fi
echo "  ✅ TypeScript build successful"

# Step 5: Synthesize CloudFormation
echo ""
echo "🧬 Synthesizing CloudFormation template..."
echo "  This may take 2-5 minutes on first run..."

if timeout 600 npm run synth -- --context environment=$ENVIRONMENT --context region=$REGION; then
    echo "  ✅ CloudFormation template synthesized"
else
    echo "  ❌ Synthesis timed out or failed"
    exit 1
fi

# Step 6: Deploy stacks
echo ""
echo "🚀 Deploying CloudFormation stacks..."
echo "  This may take 10-15 minutes..."

DEPLOYED_STACKS=()
FAILED_STACKS=()

deploy_stack() {
    local stack_name=$1
    local description=$2
    
    echo ""
    echo "📦 Deploying $stack_name ($description)..."
    
    if npm run deploy -- \
        --context environment=$ENVIRONMENT \
        --context region=$REGION \
        --require-approval never; then
        DEPLOYED_STACKS+=("$stack_name")
        echo "  ✅ $stack_name deployed successfully"
        return 0
    else
        FAILED_STACKS+=("$stack_name")
        echo "  ❌ $stack_name failed"
        return 1
    fi
}

# Deploy main stack
deploy_stack "$STACK_NAME" "Core Infrastructure"

if [ ${#FAILED_STACKS[@]} -gt 0 ]; then
    echo ""
    echo "❌ Deployment failed"
    exit 1
fi

cd ..

# Step 7: Get stack outputs
echo ""
echo "📋 Retrieving stack outputs..."

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

# Step 8: Deploy Frontend (Optional)
echo ""
read -p "Deploy Frontend stack (ALB + ECS)? (y/n): " deploy_frontend
if [[ "$deploy_frontend" =~ ^[Yy]$ ]]; then
    echo ""
    echo "🎨 Deploying frontend..."
    
    if [ ! -d "frontend" ]; then
        echo "❌ Frontend directory not found"
    else
        cd frontend
        
        # Install dependencies
        echo "  Installing frontend dependencies..."
        npm install
        
        # Create environment file
        echo "  Creating environment configuration..."
        cat > .env.local << EOF
REACT_APP_API_ENDPOINT=$API_ENDPOINT
REACT_APP_ENVIRONMENT=$ENVIRONMENT
REACT_APP_REGION=$REGION
EOF
        
        # Build frontend
        echo "  Building frontend..."
        npm run build
        
        # Create S3 bucket for frontend
        FRONTEND_BUCKET="ci-frontend-${ENVIRONMENT}-${RANDOM}"
        echo "  Creating S3 bucket for frontend: $FRONTEND_BUCKET"
        aws s3 mb s3://$FRONTEND_BUCKET --region $REGION 2>/dev/null || true
        
        # Configure bucket for static website hosting
        echo "  Configuring S3 bucket for static website hosting..."
        aws s3 website s3://$FRONTEND_BUCKET \
            --index-document index.html \
            --error-document index.html
        
        # Upload build files
        echo "  Uploading frontend files to S3..."
        aws s3 sync build/ s3://$FRONTEND_BUCKET --delete --quiet
        
        # Make bucket public
        echo "  Configuring bucket policy..."
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
        echo "  Creating CloudFront distribution..."
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
            echo "  ✅ CloudFront distribution created: $DISTRIBUTION_ID"
            
            # Get CloudFront domain
            echo "  Waiting for CloudFront distribution to be ready..."
            sleep 5
            
            CLOUDFRONT_DOMAIN=$(aws cloudfront get-distribution \
                --id $DISTRIBUTION_ID \
                --query 'Distribution.DomainName' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$CLOUDFRONT_DOMAIN" ]; then
                echo "  ✅ CloudFront domain: $CLOUDFRONT_DOMAIN"
            fi
        else
            echo "  ⚠️  Could not create CloudFront distribution"
            CLOUDFRONT_DOMAIN="$FRONTEND_BUCKET.s3-website-${REGION}.amazonaws.com"
        fi
        
        cd ..
        echo "  ✅ Frontend deployed successfully"
    fi
fi

# Step 9: Configure API Keys
echo ""
echo "🔑 Setting up API keys in Secrets Manager..."

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
        echo "  ✅ Created secret: $secret"
    else
        echo "  ℹ️  Secret already exists: $secret"
    fi
done

echo "  ⚠️  Please configure actual API keys in AWS Secrets Manager"

# Step 10: Deployment Summary
echo ""
echo "🎆 Deployment Summary"
echo "==============================="
echo ""
echo "✅ Successfully Deployed (${#DEPLOYED_STACKS[@]} stacks):"
for stack in "${DEPLOYED_STACKS[@]}"; do
    echo "  ✓ $stack"
done

if [ ${#FAILED_STACKS[@]} -gt 0 ]; then
    echo ""
    echo "❌ Failed Deployments (${#FAILED_STACKS[@]} stacks):"
    for stack in "${FAILED_STACKS[@]}"; do
        echo "  ✗ $stack"
    done
fi

echo ""
echo "📊 Infrastructure Details:"
echo "  Region: $REGION"
echo "  Account: $ACCOUNT_ID"
echo "  Environment: $ENVIRONMENT"

if [ -n "$API_ENDPOINT" ]; then
    echo ""
    echo "🔗 API Endpoint:"
    echo "  $API_ENDPOINT"
fi

if [ -n "$DATA_LAKE_BUCKET" ]; then
    echo ""
    echo "💾 Data Storage:"
    echo "  S3 Bucket: $DATA_LAKE_BUCKET"
fi

if [ -n "$SEARCH_DOMAIN" ]; then
    echo ""
    echo "🔍 Search & Analytics:"
    echo "  Elasticsearch: $SEARCH_DOMAIN"
fi

if [ -n "$CLOUDFRONT_DOMAIN" ]; then
    echo ""
    echo "🌍 Frontend Application:"
    echo "  CloudFront CDN: https://$CLOUDFRONT_DOMAIN"
    echo ""
    echo "  Access your application at:"
    echo "  ${GREEN}https://$CLOUDFRONT_DOMAIN${NC}"
fi

echo ""
echo "📝 Next Steps:"
echo "  1. Configure API keys in Secrets Manager:"
for secret in "${SECRETS[@]}"; do
    echo "     • $secret"
done
echo ""
echo "  2. Enable Bedrock models:"
echo "     AWS Console → Bedrock → Model Access"
echo "     - anthropic.claude-3-5-haiku-20241022-v1:0"
echo "     - anthropic.claude-3-sonnet-20240229-v1:0"
echo "     - amazon.titan-embed-text-v1"
echo ""
echo "  3. Create Bedrock Agent manually:"
echo "     AWS Console → Bedrock → Agents → Create agent"
echo ""
echo "  4. Create Knowledge Base:"
echo "     AWS Console → Bedrock → Knowledge bases → Create"
echo "     - S3 bucket: $DATA_LAKE_BUCKET"
echo "     - Embedding: amazon.titan-embed-text-v1"
echo ""
echo "  5. Monitor Lambda functions:"
echo "     aws logs tail /aws/lambda/ci-* --follow"
echo ""

echo "🧪 Test Commands:"
if [ -n "$API_ENDPOINT" ]; then
    echo "  # Get insights"
    echo "  curl ${API_ENDPOINT}insights"
    echo ""
    echo "  # Add to watchlist"
    echo "  curl -X POST ${API_ENDPOINT}watchlist -H 'Content-Type: application/json' -d '{\"molecule\":\"Keytruda\"}'"
fi
echo ""

echo "🎉 Deployment Complete!"
echo "====================="
