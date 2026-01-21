#!/bin/bash

#############################################
# Prerequisites Setup Script for CI Alert System
#############################################

set -e

echo "🔧 Setting up prerequisites for CI Alert System..."

# Check OS
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    echo "❌ Windows detected. Please use WSL or Linux/macOS"
    exit 1
fi

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Wait for any running apt processes to complete
echo "⏳ Waiting for package manager to be available..."
sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && echo "Waiting for other package managers to finish..." && sleep 60
sudo pkill -f apt >/dev/null 2>&1 || true
sleep 10

# Install unzip if not present
if ! command -v unzip &> /dev/null; then
    echo "📦 Installing unzip..."
    sudo apt-get update
    sudo apt-get install -y unzip
fi

# Install AWS CLI v2
if ! command -v aws &> /dev/null; then
    echo "📦 Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Install Node.js 20 LTS (avoid deprecation warnings)
if ! command -v node &> /dev/null || [[ $(node -v | cut -d'.' -f1 | cut -d'v' -f2) -lt 20 ]]; then
    echo "📦 Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi

# Install Python 3 (use system default)
if ! command -v python3 &> /dev/null; then
    echo "📦 Installing Python 3..."
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv
else
    echo "✓ Python 3 already installed: $(python3 --version)"
fi

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo chmod 666 /var/run/docker.sock
    rm get-docker.sh
    echo "✅ Docker installed"
else
    echo "✓ Docker already installed"
    # Fix permissions if Docker exists but has permission issues
    if ! docker ps &>/dev/null; then
        echo "🔧 Fixing Docker permissions..."
        sudo usermod -aG docker $USER
        sudo systemctl start docker
        sudo chmod 666 /var/run/docker.sock
    fi
fi

# Install AWS CDK
if ! command -v cdk &> /dev/null; then
    echo "📦 Installing AWS CDK..."
    sudo npm install -g aws-cdk
fi

# Install Git
if ! command -v git &> /dev/null; then
    echo "📦 Installing Git..."
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git
fi

# Configure AWS CLI
echo "🔐 Configuring AWS CLI..."
if [ ! -f ~/.aws/credentials ]; then
    echo "Please enter your AWS credentials:"
    aws configure
else
    echo "AWS credentials already configured. Reconfigure? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        aws configure
    fi
fi

# Check and fix region for CloudFormation hook issues
CURRENT_REGION=$(aws configure get region)
echo "🌍 Current region: $CURRENT_REGION"

PROBLEMATIC_REGIONS=("us-west-2")
for region in "${PROBLEMATIC_REGIONS[@]}"; do
    if [ "$CURRENT_REGION" = "$region" ]; then
        echo "⚠️  $region has CloudFormation hooks blocking CDK"
        aws configure set region us-east-1
        echo "✅ Switched to us-east-1"
        break
    fi
done

# Verify AWS access
echo "🔍 Verifying AWS access..."
if aws sts get-caller-identity &>/dev/null; then
    echo "✅ AWS credentials valid"
    aws sts get-caller-identity
else
    echo "❌ AWS credentials invalid or not configured"
    echo "   Please reconfigure your credentials:"
    echo ""
    aws configure
    echo ""
    echo "Verifying again..."
    if aws sts get-caller-identity; then
        echo "✅ AWS credentials now valid"
    else
        echo "❌ Still invalid. Check your Access Key ID and Secret Access Key"
        exit 1
    fi
fi

# Verify all tools are installed
echo ""
echo "📋 Verifying all tools..."
echo ""

TOOLS=("git" "node" "npm" "python3" "aws" "cdk" "docker")
ALL_GOOD=true

for tool in "${TOOLS[@]}"; do
    if command -v $tool &> /dev/null; then
        VERSION=$($tool --version 2>&1 | head -n1)
        echo "✅ $tool: $VERSION"
    else
        echo "❌ $tool: NOT FOUND"
        ALL_GOOD=false
    fi
done

echo ""
echo "⚠️  IMPORTANT: Enable Bedrock models manually"
echo "   1. Go to AWS Console > Bedrock > Model Access"
echo "   2. Request access to: Claude 3.5 Haiku and Claude 3.5 Sonnet"
echo "   3. Wait for approval (usually instant for standard models)"
echo ""

echo "✅ Prerequisites setup complete!"
echo ""

echo "🐳 Docker Status:"
if docker ps &>/dev/null; then
    echo "  ✅ Docker is working"
else
    echo "  ⚠️  Docker needs group refresh"
    echo "  Run: newgrp docker"
    echo "  Or logout and login again"
fi

echo ""
echo "Next steps:"
echo "1. If Docker permission error: logout and login OR run 'newgrp docker'"
echo "2. Enable Bedrock models: https://console.aws.amazon.com/bedrock/home#/modelaccess"
echo "3. Run: ./deploy.sh dev us-east-1"
echo ""

if [ "$ALL_GOOD" = true ]; then
    exit 0
else
    echo "❌ Some tools are missing. Please install them and try again."
    exit 1
fi
