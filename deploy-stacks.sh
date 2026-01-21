#!/bin/bash

echo "Building and deploying AI and Frontend stacks..."

cd cdk

# Build CDK
npm run build

# Deploy stacks in order
echo "Deploying core stack..."
npm run cdk -- deploy pharma-ci-platform-dev --require-approval never

echo "Deploying AI/RAG stack..."
npm run cdk -- deploy pharma-ci-rag-dev --require-approval never

echo "Deploying frontend stack..."
npm run cdk -- deploy pharma-ci-frontend-dev --require-approval never

echo "All stacks deployed successfully!"