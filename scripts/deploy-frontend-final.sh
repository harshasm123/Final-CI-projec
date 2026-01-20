#!/bin/bash

################################################################################
# Final Frontend Deployment Script
# Complete deployment with CloudFront, ALB, and all AWS services
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################################################################
# Configuration & Input
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CI Alert Platform - Final Deployment${NC}"
echo -e "${BLUE}CloudFront + ALB + EC2 + Lambda${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get configuration from user
read -p "Enter environment (dev/staging/prod) [dev]: " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}

read -p "Enter AWS region [us-east-1]: " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "Enter domain name (optional): " DOMAIN_NAME

read -p "Enter API endpoint [http://localhost:8000]: " API_ENDPOINT
API_ENDPOINT=${API_ENDPOINT:-"http://localhost:8000"}

read -p "Enter GitHub repository URL: " REPO_URL
if [ -z "$REPO_URL" ]; then
    log_error "Repository URL is required"
    exit 1
fi

read -p "Enter Git branch [main]: " BRANCH
BRANCH=${BRANCH:-main}

read -p "Enter ACM Certificate ARN (optional): " CERTIFICATE_ARN

# Verify AWS credentials
log_info "Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    echo ""
    echo "Configure AWS credentials:"
    echo "  aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS credentials verified (Account: $ACCOUNT_ID)"

echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  AWS Region: $AWS_REGION"
echo "  Domain: ${DOMAIN_NAME:-Not configured}"
echo "  API Endpoint: $API_ENDPOINT"
echo "  Repository: $REPO_URL"
echo "  Branch: $BRANCH"
echo "  Certificate: ${CERTIFICATE_ARN:-Not configured}"
echo ""

read -p "Continue with deployment? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Deployment cancelled"
    exit 0
fi

echo ""

################################################################################
# Step 1: Install Dependencies
################################################################################

log_info "Step 1/10: Installing dependencies..."

sudo apt-get update -y > /dev/null 2>&1
sudo apt-get upgrade -y > /dev/null 2>&1

sudo apt-get install -y \
    build-essential curl wget git vim htop net-tools \
    unzip zip jq ca-certificates gnupg lsb-release \
    python3 python3-pip nginx > /dev/null 2>&1

if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - > /dev/null 2>&1
    sudo apt-get install -y nodejs > /dev/null 2>&1
fi

log_success "Dependencies installed"

################################################################################
# Step 2: Clone Repository
################################################################################

log_info "Step 2/10: Cloning repository from GitHub..."

if [ -d "ci-alert-platform" ]; then
    cd ci-alert-platform
    git fetch origin ${BRANCH} > /dev/null 2>&1
    git reset --hard origin/${BRANCH} > /dev/null 2>&1
    git pull origin ${BRANCH} > /dev/null 2>&1
    cd ..
else
    git clone -b ${BRANCH} ${REPO_URL} ci-alert-platform > /dev/null 2>&1
fi

log_success "Repository cloned/updated"

################################################################################
# Step 3: Build Frontend
################################################################################

log_info "Step 3/10: Building frontend..."

cd ci-alert-platform/frontend

cat > .env.local << EOF
REACT_APP_API_ENDPOINT=${API_ENDPOINT}
REACT_APP_ENVIRONMENT=${ENVIRONMENT}
REACT_APP_ENABLE_CHATBOT=true
EOF

npm install > /dev/null 2>&1
npm run build > /dev/null 2>&1

if [ ! -d "build" ]; then
    log_error "Frontend build failed"
    exit 1
fi

log_success "Frontend built successfully"
cd ../..

################################################################################
# Step 4: Create S3 Bucket for Static Assets
################################################################################

log_info "Step 4/10: Setting up S3 bucket for static assets..."

S3_BUCKET="ci-frontend-assets-${ENVIRONMENT}-${ACCOUNT_ID}-$(date +%s)"

aws s3 mb s3://${S3_BUCKET} --region ${AWS_REGION} 2>/dev/null || true

aws s3api put-bucket-versioning \
    --bucket ${S3_BUCKET} \
    --versioning-configuration Status=Enabled \
    --region ${AWS_REGION} 2>/dev/null || true

aws s3api put-public-access-block \
    --bucket ${S3_BUCKET} \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region ${AWS_REGION} 2>/dev/null || true

log_info "Uploading build files to S3..."
aws s3 sync ci-alert-platform/frontend/build s3://${S3_BUCKET}/ \
    --region ${AWS_REGION} \
    --cache-control "max-age=31536000" > /dev/null 2>&1

log_success "S3 bucket created: $S3_BUCKET"

################################################################################
# Step 5: Setup Application Load Balancer
################################################################################

log_info "Step 5/10: Setting up Application Load Balancer..."

ALB_NAME="ci-frontend-alb-${ENVIRONMENT}"
TG_NAME="ci-frontend-tg-${ENVIRONMENT}"

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' --output text --region ${AWS_REGION})

# Get subnets
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].SubnetId' --output text --region ${AWS_REGION})

# Create ALB
log_info "Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name ${ALB_NAME} \
    --subnets ${SUBNETS} \
    --scheme internet-facing \
    --type application \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$ALB_ARN" ]; then
    ALB_ARN=$(aws elbv2 describe-load-balancers \
        --names ${ALB_NAME} \
        --region ${AWS_REGION} \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text 2>/dev/null)
fi

# Create target group
log_info "Creating target group..."
TG_ARN=$(aws elbv2 create-target-group \
    --name ${TG_NAME} \
    --protocol HTTP \
    --port 3000 \
    --vpc-id ${VPC_ID} \
    --region ${AWS_REGION} \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$TG_ARN" ]; then
    TG_ARN=$(aws elbv2 describe-target-groups \
        --names ${TG_NAME} \
        --region ${AWS_REGION} \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null)
fi

# Create listener
aws elbv2 create-listener \
    --load-balancer-arn ${ALB_ARN} \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=${TG_ARN} \
    --region ${AWS_REGION} 2>/dev/null || true

log_success "ALB created: $ALB_NAME"

################################################################################
# Step 6: Setup CloudFront Distribution
################################################################################

log_info "Step 6/10: Setting up CloudFront distribution..."

# Get ALB DNS
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns ${ALB_ARN} \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

# Create CloudFront config
cat > /tmp/cloudfront-config.json << EOF
{
  "CallerReference": "ci-frontend-${ENVIRONMENT}-$(date +%s)",
  "Comment": "CI Alert Platform Frontend - ${ENVIRONMENT}",
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 2,
    "Items": [
      {
        "Id": "S3Origin",
        "DomainName": "${S3_BUCKET}.s3.${AWS_REGION}.amazonaws.com",
        "S3OriginConfig": {}
      },
      {
        "Id": "ALBOrigin",
        "DomainName": "${ALB_DNS}",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only"
        }
      }
    ]
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
  "CacheBehaviors": [
    {
      "PathPattern": "/api/*",
      "TargetOriginId": "ALBOrigin",
      "ViewerProtocolPolicy": "https-only",
      "AllowedMethods": {
        "Quantity": 7,
        "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      },
      "CachePolicyId": "4135ea3d-c35d-46eb-81d7-reeSJmXQQpQ"
    }
  ],
  "Enabled": true
}
EOF

# Create distribution
CF_ID=$(aws cloudfront create-distribution \
    --distribution-config file:///tmp/cloudfront-config.json \
    --query 'Distribution.Id' \
    --output text 2>/dev/null || echo "")

if [ -z "$CF_ID" ]; then
    log_warning "CloudFront distribution creation failed or already exists"
else
    log_success "CloudFront distribution created: $CF_ID"
fi

rm -f /tmp/cloudfront-config.json

################################################################################
# Step 7: Setup EC2 Instance
################################################################################

log_info "Step 7/10: Setting up EC2 instance..."

# Create systemd service
sudo tee /etc/systemd/system/ci-frontend.service > /dev/null << EOF
[Unit]
Description=CI Alert Platform Frontend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/ci-alert-platform/frontend
Environment="NODE_ENV=production"
Environment="PORT=3000"
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ci-frontend
sudo systemctl start ci-frontend

log_success "EC2 instance configured"

################################################################################
# Step 8: Setup Nginx Reverse Proxy
################################################################################

log_info "Step 8/10: Setting up Nginx reverse proxy..."

sudo tee /etc/nginx/sites-available/ci-frontend > /dev/null << EOF
upstream frontend {
    server localhost:3000;
}

server {
    listen 80;
    server_name _;
    
    gzip on;
    gzip_types text/plain text/css text/javascript application/json application/javascript;
    gzip_min_length 1000;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/ci-frontend /etc/nginx/sites-enabled/ci-frontend
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t > /dev/null 2>&1
sudo systemctl enable nginx
sudo systemctl start nginx

log_success "Nginx configured"

################################################################################
# Step 9: Register Instance with ALB
################################################################################

log_info "Step 9/10: Registering instance with ALB..."

INSTANCE_ID=$(ec2-metadata --instance-id 2>/dev/null | cut -d' ' -f2 || echo "")

if [ ! -z "$INSTANCE_ID" ]; then
    aws elbv2 register-targets \
        --target-group-arn ${TG_ARN} \
        --targets Id=${INSTANCE_ID},Port=3000 \
        --region ${AWS_REGION} 2>/dev/null || true
    
    log_success "Instance registered with ALB"
else
    log_warning "Could not determine instance ID. Register manually."
fi

################################################################################
# Step 10: Display Summary
################################################################################

log_info "Step 10/10: Deployment complete!"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}Configuration:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  AWS Region: $AWS_REGION"
echo "  Account ID: $ACCOUNT_ID"
echo ""

echo -e "${BLUE}AWS Resources Created:${NC}"
echo "  S3 Bucket: $S3_BUCKET"
echo "  ALB: $ALB_NAME"
echo "  Target Group: $TG_NAME"
if [ ! -z "$CF_ID" ]; then
    echo "  CloudFront: $CF_ID"
fi
echo ""

echo -e "${BLUE}Access Information:${NC}"
echo "  Direct: http://$(hostname -I | awk '{print $1}')"
echo "  ALB DNS: $ALB_DNS"
if [ ! -z "$CF_ID" ]; then
    CF_DOMAIN=$(aws cloudfront get-distribution --id ${CF_ID} \
        --query 'Distribution.DomainName' --output text 2>/dev/null || echo "")
    echo "  CloudFront: https://${CF_DOMAIN}"
fi
if [ ! -z "$DOMAIN_NAME" ]; then
    echo "  Domain: https://${DOMAIN_NAME}"
fi
echo ""

echo -e "${BLUE}Service Management:${NC}"
echo "  View logs: sudo journalctl -u ci-frontend -f"
echo "  Restart: sudo systemctl restart ci-frontend"
echo "  Status: sudo systemctl status ci-frontend"
echo ""

echo -e "${BLUE}AWS CLI Commands:${NC}"
echo "  List ALBs: aws elbv2 describe-load-balancers --region ${AWS_REGION}"
echo "  List CloudFront: aws cloudfront list-distributions"
echo "  List S3 buckets: aws s3 ls"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Verify frontend is running: curl http://localhost/health"
echo "  2. Check ALB target health: aws elbv2 describe-target-health --target-group-arn ${TG_ARN} --region ${AWS_REGION}"
if [ ! -z "$DOMAIN_NAME" ]; then
    echo "  3. Update DNS records to point to CloudFront"
    echo "  4. Setup SSL certificate in ACM"
fi
echo ""

log_success "Deployment completed successfully!"
