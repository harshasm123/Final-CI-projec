#!/bin/bash

# Deploy Bedrock Agent for CI Analysis

set -e

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
MAIN_STACK_NAME="pharma-ci-backend-${ENVIRONMENT}"
AGENT_STACK_NAME="pharma-ci-agent-${ENVIRONMENT}"

echo "Deploying Bedrock Agent for CI Analysis..."
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${REGION}"

# Get outputs from main stack
echo "Getting main stack outputs..."
OPENSEARCH_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${MAIN_STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`OpenSearchEndpoint`].OutputValue' \
  --output text \
  --region ${REGION})

METADATA_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name ${MAIN_STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`DataLakeBucket`].OutputValue' \
  --output text \
  --region ${REGION})

if [ -z "$OPENSEARCH_ENDPOINT" ] || [ -z "$METADATA_BUCKET" ]; then
  echo "Error: Could not get required outputs from main stack"
  exit 1
fi

echo "OpenSearch Endpoint: ${OPENSEARCH_ENDPOINT}"
echo "Metadata Bucket: ${METADATA_BUCKET}"

# Package CI Analysis Tools Lambda
echo "Packaging CI Analysis Tools Lambda..."
cd backend/src
zip -r ../ci-analysis-tools.zip . -x "*.pyc" "__pycache__/*"
cd ../..

# Deploy Bedrock Agent stack
echo "Deploying Bedrock Agent stack..."
aws cloudformation deploy \
  --template-file bedrock-agent.yaml \
  --stack-name ${AGENT_STACK_NAME} \
  --parameter-overrides \
    Environment=${ENVIRONMENT} \
    OpenSearchEndpoint=${OPENSEARCH_ENDPOINT} \
    MetadataBucket=${METADATA_BUCKET} \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ${REGION}

# Update CI Analysis Tools Lambda code
echo "Updating CI Analysis Tools Lambda code..."
CI_ANALYSIS_FUNCTION="ci-analysis-tools-${ENVIRONMENT}"

aws lambda update-function-code \
  --function-name ${CI_ANALYSIS_FUNCTION} \
  --zip-file fileb://backend/ci-analysis-tools.zip \
  --region ${REGION}

# Get Bedrock Agent details
echo "Getting Bedrock Agent details..."
AGENT_ID=$(aws cloudformation describe-stacks \
  --stack-name ${AGENT_STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`AgentId`].OutputValue' \
  --output text \
  --region ${REGION})

AGENT_ALIAS_ID=$(aws cloudformation describe-stacks \
  --stack-name ${AGENT_STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`AgentAliasId`].OutputValue' \
  --output text \
  --region ${REGION})

KNOWLEDGE_BASE_ID=$(aws cloudformation describe-stacks \
  --stack-name ${AGENT_STACK_NAME} \
  --query 'Stacks[0].Outputs[?OutputKey==`KnowledgeBaseId`].OutputValue' \
  --output text \
  --region ${REGION})

# Update main API Lambda with agent configuration
echo "Updating main API Lambda with agent configuration..."
API_FUNCTION="ci-api-${ENVIRONMENT}"

aws lambda update-function-configuration \
  --function-name ${API_FUNCTION} \
  --environment Variables="{
    METADATA_BUCKET=${METADATA_BUCKET},
    OPENSEARCH_ENDPOINT=${OPENSEARCH_ENDPOINT},
    BEDROCK_AGENT_ID=${AGENT_ID},
    BEDROCK_AGENT_ALIAS_ID=${AGENT_ALIAS_ID},
    KNOWLEDGE_BASE_ID=${KNOWLEDGE_BASE_ID}
  }" \
  --region ${REGION}

# Prepare and sync knowledge base data
echo "Preparing knowledge base data..."
python3 scripts/prepare_knowledge_base.py \
  --environment ${ENVIRONMENT} \
  --region ${REGION} \
  --knowledge-base-id ${KNOWLEDGE_BASE_ID}

echo "Bedrock Agent deployment completed successfully!"
echo ""
echo "Agent Details:"
echo "  Agent ID: ${AGENT_ID}"
echo "  Agent Alias ID: ${AGENT_ALIAS_ID}"
echo "  Knowledge Base ID: ${KNOWLEDGE_BASE_ID}"
echo ""
echo "The CI Analysis Assistant is now available in the frontend at /chatbot"
echo ""
echo "Next steps:"
echo "1. Test the chatbot with sample CI questions"
echo "2. Monitor agent performance and costs"
echo "3. Customize agent instructions based on user feedback"