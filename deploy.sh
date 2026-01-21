#!/bin/bash
# Pharmaceutical CI Platform Deployment Script
# Hardened for CDK synth stability

set -e

echo "🚀 Starting Pharmaceutical CI Platform Deployment"

# ===============================
# Global Safety & Stability Flags
# ===============================

# Prevent Node OOM during CDK synth
export NODE_OPTIONS="--max-old-space-size=4096"

# Reduce CDK overhead & noise
export CDK_DISABLE_VERSION_CHECK=true
export CDK_DISABLE_BOOTSTRAP_VERSION_CHECK=true

# ===============================
# Region & Environment Setup
# ===============================

REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
    REGION="us-west-2"
    aws configure set region $REGION
    echo "ℹ️  No region configured. Using $REGION"
fi

PROBLEMATIC_REGIONS=("us-east-1" "eu-west-1" "ap-southeast-1")
for prob_region in "${PROBLEMATIC_REGIONS[@]}"; do
    if [ "$REGION" = "$prob_region" ]; then
        echo "⚠️  $REGION has CloudFormation hooks blocking CDK"
        REGION="us-west-2"
        aws configure set region $REGION
        echo "✅ Switched to $REGION"
        break
    fi
done

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ENVIRONMENT=${1:-dev}
STACK_NAME="pharma-ci-platform-${ENVIRONMENT}"

echo ""
echo "📋 Configuration"
echo "  Account:      $ACCOUNT_ID"
echo "  Region:       $REGION"
echo "  Environment:  $ENVIRONMENT"
echo "  Stack Name:   $STACK_NAME"

# ===============================
# Prerequisite Checks
# ===============================

echo ""
echo "🔍 Checking prerequisites..."

command -v aws >/dev/null || { echo "❌ AWS CLI missing"; exit 1; }
command -v npm >/dev/null || { echo "❌ npm missing"; exit 1; }

if ! command -v cdk &>/dev/null; then
    echo "📦 Installing AWS CDK..."
    npm install -g aws-cdk
fi

echo "✅ Prerequisites OK"

# ===============================
# CDK Bootstrap Validation
# ===============================

echo ""
echo "🧹 Checking CDKToolkit stack..."

STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name CDKToolkit \
  --region $REGION \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "NONE")

if [[ "$STACK_STATUS" =~ FAILED|ROLLBACK|IN_PROGRESS ]]; then
    echo "⚠️  Removing broken CDKToolkit stack..."
    aws cloudformation delete-stack --stack-name CDKToolkit --region $REGION
    aws cloudformation wait stack-delete-complete --stack-name CDKToolkit --region $REGION || true
    STACK_STATUS="NONE"
fi

if [ "$STACK_STATUS" = "NONE" ]; then
    echo "🏗️  Bootstrapping CDK..."
    cdk bootstrap aws://${ACCOUNT_ID}/${REGION}
fi

# ===============================
# Install & Build CDK App
# ===============================

echo ""
echo "📦 Installing CDK dependencies..."
cd cdk
npm install

echo ""
echo "🔨 Building TypeScript..."
npm run build

# ===============================
# CRITICAL: Clear CDK Context
# ===============================

echo ""
echo "🧹 Clearing stale CDK context..."
rm -f cdk.context.json
rm -rf ~/.cdk
echo "  ✅ Context cleared"

# ===============================
# CDK Synth (Hardened)
# ===============================

echo ""
echo "🧬 Synthesizing CloudFormation template (safe mode)..."
echo "  This may take 2–5 minutes on first run"

if timeout 600 npx cdk synth \
  --verbose \
  --no-staging \
  --context environment=$ENVIRONMENT \
  --context region=$REGION; then
    echo "  ✅ Synth successful"
else
    echo "  ❌ Synth failed or timed out"
    exit 1
fi

if [ ! -d "cdk.out" ]; then
    echo "❌ cdk.out missing — synth failed silently"
    exit 1
fi

# ===============================
# Deploy Stack
# ===============================

echo ""
echo "🚀 Deploying stack: $STACK_NAME"
npx cdk deploy \
  --require-approval never \
  --context environment=$ENVIRONMENT \
  --context region=$REGION

cd ..

# ===============================
# Retrieve Outputs
# ===============================

echo ""
echo "📋 Retrieving stack outputs..."

API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
  --output text 2>/dev/null || true)

DATA_LAKE_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`DataLakeBucket`].OutputValue' \
  --output text 2>/dev/null || true)

echo ""
echo "📊 Deployment Summary"
echo "==============================="
echo "Region:        $REGION"
echo "Environment:   $ENVIRONMENT"
echo "Stack:         $STACK_NAME"

[ -n "$API_ENDPOINT" ] && echo "API Endpoint:  $API_ENDPOINT"
[ -n "$DATA_LAKE_BUCKET" ] && echo "Data Lake:     s3://$DATA_LAKE_BUCKET"

# ===============================
# Secrets Setup
# ===============================

echo ""
echo "🔑 Ensuring Secrets Manager keys exist..."

SECRETS=(
  "ci-fda-api-key"
  "ci-pubmed-api-key"
  "ci-clinicaltrials-api-key"
  "ci-news-api-key"
  "ci-uspto-api-key"
)

for secret in "${SECRETS[@]}"; do
  aws secretsmanager describe-secret \
    --secret-id "$secret" \
    --region $REGION &>/dev/null || \
  aws secretsmanager create-secret \
    --name "$secret" \
    --description "Pharma CI Platform API Key" \
    --secret-string "REPLACE_ME" \
    --region $REGION &>/dev/null
done

echo ""
echo "⚠️  Reminder:"
echo "  • Enable Bedrock models (Haiku, Sonnet, Titan Embeddings)"
echo "  • Replace Secrets Manager placeholder API keys"
echo ""
echo "🎉 Deployment complete — system is live"
