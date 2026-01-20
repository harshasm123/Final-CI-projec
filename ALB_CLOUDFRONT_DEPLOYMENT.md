# ALB & CloudFront Deployment Guide

## Overview

Complete deployment architecture using:
- **Application Load Balancer (ALB)** - Distributes traffic across EC2 instances
- **CloudFront** - Global CDN for static assets and API caching
- **S3** - Static asset storage
- **Route 53** - DNS management (optional)

## Architecture

```
Users
  ↓
Route 53 (DNS)
  ↓
CloudFront (CDN)
  ├── S3 Origin (Static Assets)
  └── ALB Origin (Dynamic Content)
  ↓
Application Load Balancer
  ↓
EC2 Instances (Target Group)
  ├── Nginx
  └── Node.js Frontend
  ↓
Backend Services
  ├── Lambda Functions
  ├── OpenSearch
  ├── DynamoDB
  └── Bedrock
```

## Prerequisites

### AWS Services Required

- ✅ EC2 (Elastic Compute Cloud)
- ✅ ELBv2 (Application Load Balancer)
- ✅ CloudFront (CDN)
- ✅ S3 (Static Asset Storage)
- ✅ Route 53 (DNS - Optional)
- ✅ ACM (SSL Certificates)

### Local Requirements

```bash
# Check prerequisites
chmod +x scripts/check-prerequisites-alb-cdn.sh
./scripts/check-prerequisites-alb-cdn.sh
```

## Step 1: Prepare Code

### Push to GitHub

```bash
# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Push code
chmod +x scripts/push-to-github.sh
./scripts/push-to-github.sh https://github.com/your-org/ci-alert-platform.git main
```

## Step 2: Deploy with ALB & CloudFront

### Basic Deployment

```bash
# SSH into EC2 instance
ssh -i your-key-pair.pem ubuntu@<INSTANCE_IP>

# Download deployment script
wget https://raw.githubusercontent.com/your-org/ci-alert-platform/main/scripts/deploy-frontend-alb-cdn.sh
chmod +x deploy-frontend-alb-cdn.sh

# Deploy
./deploy-frontend-alb-cdn.sh dev http://api.example.com:8000
```

### Full Deployment with Domain & SSL

```bash
# Get ACM Certificate ARN
CERT_ARN=$(aws acm list-certificates --region us-east-1 \
  --query 'CertificateSummaryList[0].CertificateArn' \
  --output text)

# Deploy with domain and certificate
./deploy-frontend-alb-cdn.sh dev http://api.example.com:8000 \
  your-domain.com \
  https://github.com/your-org/ci-alert-platform.git \
  main \
  us-east-1 \
  $CERT_ARN
```

### Parameters

```bash
./deploy-frontend-alb-cdn.sh [ENVIRONMENT] [API_ENDPOINT] [DOMAIN] [REPO_URL] [BRANCH] [REGION] [CERT_ARN]
```

- `ENVIRONMENT`: dev/staging/prod (default: dev)
- `API_ENDPOINT`: Backend API URL (default: http://localhost:8000)
- `DOMAIN`: Domain name for CloudFront (optional)
- `REPO_URL`: GitHub repository URL
- `BRANCH`: Git branch (default: main)
- `REGION`: AWS region (default: us-east-1)
- `CERT_ARN`: ACM certificate ARN (optional)

## Step 3: Configure ALB

### Add EC2 Instances to Target Group

```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ci-alert-frontend-dev" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names ci-frontend-tg-dev \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Register instance with target group
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$INSTANCE_ID,Port=3000
```

### Configure Health Checks

```bash
# Update health check settings
aws elbv2 modify-target-group \
  --target-group-arn $TG_ARN \
  --health-check-protocol HTTP \
  --health-check-path / \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2
```

## Step 4: Configure CloudFront

### Create Distribution

```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names ci-frontend-alb-dev \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Create CloudFront distribution
aws cloudfront create-distribution \
  --distribution-config file://cloudfront-config.json
```

### CloudFront Configuration

```json
{
  "CallerReference": "ci-frontend-dev-$(date +%s)",
  "Comment": "CI Alert Platform Frontend",
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 2,
    "Items": [
      {
        "Id": "S3Origin",
        "DomainName": "ci-frontend-assets-dev-TIMESTAMP.s3.us-east-1.amazonaws.com",
        "S3OriginConfig": {}
      },
      {
        "Id": "ALBOrigin",
        "DomainName": "ci-frontend-alb-dev-123456.us-east-1.elb.amazonaws.com",
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
```

### Cache Behaviors

**Static Assets (S3)**
- Path: `*.js`, `*.css`, `*.png`, `*.jpg`, etc.
- TTL: 1 year
- Compress: Yes

**API Requests (ALB)**
- Path: `/api/*`
- TTL: 0 (no caching)
- Methods: GET, POST, PUT, DELETE, PATCH

**HTML (S3)**
- Path: `*.html`, `/`
- TTL: 5 minutes
- Compress: Yes

## Step 5: Configure Route 53 (Optional)

### Create DNS Records

```bash
# Get CloudFront domain
CF_DOMAIN=$(aws cloudfront list-distributions \
  --query 'DistributionList.Items[0].DomainName' \
  --output text)

# Create Route 53 record
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456 \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "your-domain.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "'$CF_DOMAIN'",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'
```

## Step 6: Setup SSL Certificate

### Request ACM Certificate

```bash
# Request certificate
aws acm request-certificate \
  --domain-name your-domain.com \
  --subject-alternative-names www.your-domain.com \
  --validation-method DNS \
  --region us-east-1
```

### Attach to CloudFront

```bash
# Update CloudFront distribution with certificate
aws cloudfront update-distribution \
  --id E123456 \
  --distribution-config file://updated-config.json
```

## Verification

### Check ALB Status

```bash
# List load balancers
aws elbv2 describe-load-balancers

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN
```

### Check CloudFront Status

```bash
# List distributions
aws cloudfront list-distributions

# Get distribution status
aws cloudfront get-distribution \
  --id E123456
```

### Test Frontend

```bash
# Test ALB
curl http://<ALB_DNS>

# Test CloudFront
curl https://<CLOUDFRONT_DOMAIN>

# Test domain
curl https://your-domain.com
```

## Monitoring

### CloudWatch Metrics

```bash
# ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 300 \
  --statistics Average

# CloudFront metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 300 \
  --statistics Sum
```

### View Logs

```bash
# ALB access logs
aws s3 ls s3://alb-logs-bucket/

# CloudFront logs
aws s3 ls s3://cloudfront-logs-bucket/
```

## Scaling

### Add More EC2 Instances

```bash
# Launch new instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.large \
  --key-name your-key-pair

# Register with target group
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=i-new-instance,Port=3000
```

### Auto Scaling Group

```bash
# Create launch template
aws ec2 create-launch-template \
  --launch-template-name ci-frontend-template \
  --launch-template-data file://launch-template.json

# Create auto scaling group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name ci-frontend-asg \
  --launch-template LaunchTemplateName=ci-frontend-template \
  --min-size 2 \
  --max-size 10 \
  --desired-capacity 3 \
  --target-group-arns $TG_ARN
```

## Troubleshooting

### ALB Not Routing Traffic

```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Check security group
aws ec2 describe-security-groups --group-ids sg-123456

# Check instance status
aws ec2 describe-instance-status --instance-ids i-123456
```

### CloudFront Not Caching

```bash
# Check cache behaviors
aws cloudfront get-distribution --id E123456

# Invalidate cache
aws cloudfront create-invalidation \
  --distribution-id E123456 \
  --paths "/*"
```

### High Latency

```bash
# Check ALB response time
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/ci-frontend-alb-dev/1234567890abcdef \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 60 \
  --statistics Average,Maximum
```

## Cost Optimization

### CloudFront

- Use S3 origin for static assets (cheaper)
- Enable compression
- Set appropriate TTLs
- Use regional edge caches

### ALB

- Use target group stickiness
- Enable connection draining
- Monitor unused resources

### EC2

- Use reserved instances
- Enable auto-scaling
- Right-size instances

## Security Best Practices

### ALB Security

```bash
# Restrict security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-123456 \
  --protocol tcp \
  --port 3000 \
  --source-security-group-id sg-alb

# Enable access logs
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn $ALB_ARN \
  --attributes Key=access_logs.s3.enabled,Value=true \
    Key=access_logs.s3.bucket,Value=alb-logs-bucket
```

### CloudFront Security

```bash
# Enable WAF
aws cloudfront update-distribution \
  --id E123456 \
  --distribution-config file://config-with-waf.json

# Restrict HTTP methods
# Only allow GET, HEAD for static content
# Allow POST, PUT, DELETE for API
```

## Cleanup

### Delete Resources

```bash
# Delete CloudFront distribution
aws cloudfront delete-distribution --id E123456

# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN

# Delete target group
aws elbv2 delete-target-group --target-group-arn $TG_ARN

# Delete S3 bucket
aws s3 rb s3://ci-frontend-assets-dev-TIMESTAMP --force

# Terminate EC2 instances
aws ec2 terminate-instances --instance-ids i-123456
```

## Summary

| Component | Purpose | Cost |
|-----------|---------|------|
| ALB | Load balancing | ~$16/month |
| CloudFront | CDN | Pay per GB |
| S3 | Static storage | Pay per GB |
| EC2 | Compute | ~$30-100/month |
| **Total** | | **~$50-150/month** |

## Next Steps

1. ✅ Deploy with ALB & CloudFront
2. ✅ Configure Route 53
3. ✅ Setup SSL certificate
4. ✅ Enable monitoring
5. ✅ Setup auto-scaling
6. ✅ Optimize caching
7. ✅ Monitor costs
