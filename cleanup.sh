#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🧹 Cleaning up existing resources..."
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""

# Delete existing stacks
echo "🗑️  Finding and deleting CloudFormation stacks..."
stacks=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?contains(StackName, 'pharma-ci')].StackName" --output text --region $REGION)

for stack in $stacks; do
    if [ -n "$stack" ]; then
        echo "  Deleting stack: $stack"
        aws cloudformation delete-stack --stack-name "$stack" --region $REGION
    fi
done

# Wait for all deletions to complete
if [ -n "$stacks" ]; then
    echo "⏳ Waiting for stack deletions to complete..."
    for stack in $stacks; do
        if [ -n "$stack" ]; then
            aws cloudformation wait stack-delete-complete --stack-name "$stack" --region $REGION 2>/dev/null || true
            echo "  ✅ Stack deleted: $stack"
        fi
    done
fi

# Clean up S3 buckets (empty them first)
echo "🗑️  Finding and cleaning S3 buckets..."
buckets=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'pharma-ci') || contains(Name, 'ci-data')].Name" --output text)
for bucket in $buckets; do
    if [ -n "$bucket" ]; then
        echo "  Emptying bucket: $bucket"
        aws s3 rm s3://$bucket --recursive --quiet 2>/dev/null || true
        echo "  Deleting bucket: $bucket"
        aws s3api delete-bucket --bucket $bucket --region $REGION 2>/dev/null || true
    fi
done

echo ""
echo "✅ Cleanup complete! You can now run deployment."
echo "Run: ./deploy.sh $ENVIRONMENT $REGION"