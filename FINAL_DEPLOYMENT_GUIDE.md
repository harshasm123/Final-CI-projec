# Final Deployment Guide - CloudFront + ALB + EC2

## Quick Start (10 Minutes)

```bash
# 1. Check prerequisites
chmod +x scripts/check-prerequisites-final.sh
./scripts/check-prerequisites-final.sh

# 2. Deploy
chmod +x scripts/deploy-frontend-final.sh
./scripts/deploy-frontend-final.sh

# 3. Follow prompts and enter configuration
```

---

## Prerequisites Script (`check-prerequisites-final.sh`)

### What It Checks

✅ **System Commands**
- Git
- Node.js
- NPM
- Curl, Wget
- Docker
- AWS CLI

✅ **AWS Configuration**
- AWS credentials
- IAM permissions
- AWS services availability

✅ **System Resources**
- Disk space (20GB minimum)
- Memory (2GB minimum)
- Network ports (80, 443, 3000, 8000)

✅ **Git Configuration**
- User name
- User email

✅ **CloudFront & ALB**
- S3 bucket requirements
- EC2 instance requirements
- SSL/TLS requirements

### Usage

```bash
chmod +x scripts/check-prerequisites-final.sh
./scripts/check-prerequisites-final.sh
```

### Output Example

```
[SUCCESS] AWS Credentials: Configured
  Account ID: 123456789012
  User ARN: arn:aws:iam::123456789012:user/your-user

[SUCCESS] All prerequisites are met!

You can now proceed with deployment:
  bash scripts/deploy-frontend-final.sh
```

---

## Deployment Script (`deploy-frontend-final.sh`)

### What It Does

**Step 1: Install Dependencies**
- Updates system packages
- Installs build tools
- Installs Node.js
- Installs AWS CLI

**Step 2: Clone Repository**
- Clones from GitHub
- Pulls latest code
- Resets to branch

**Step 3: Build Frontend**
- Installs npm packages
- Builds React app
- Creates optimized bundle

**Step 4: Setup S3 Bucket**
- Creates S3 bucket for static assets
- Enables versioning
- Blocks public access
- Uploads build files

**Step 5: Setup ALB**
- Creates Application Load Balancer
- Creates target group
- Configures listener
- Sets up health checks

**Step 6: Setup CloudFront**
- Creates CloudFront distribution
- Configures S3 origin
- Configures ALB origin
- Sets cache behaviors

**Step 7: Setup EC2 Instance**
- Creates systemd service
- Enables auto-start
- Starts frontend service

**Step 8: Setup Nginx**
- Installs Nginx
- Configures reverse proxy
- Enables compression
- Sets security headers

**Step 9: Register with ALB**
- Gets instance ID
- Registers with target group
- Enables traffic routing

**Step 10: Display Summary**
- Shows all resources created
- Provides access information
- Lists useful commands

### Usage

```bash
chmod +x scripts/deploy-frontend-final.sh
./scripts/deploy-frontend-final.sh
```

### Interactive Prompts

```
Enter environment (dev/staging/prod) [dev]: dev
Enter AWS region [us-east-1]: us-east-1
Enter domain name (optional): your-domain.com
Enter API endpoint [http://localhost:8000]: http://api.example.com:8000
Enter GitHub repository URL: https://github.com/your-org/ci-alert-platform.git
Enter Git branch [main]: main
Enter ACM Certificate ARN (optional): arn:aws:acm:...
```

### Configuration Summary

```
Configuration Summary:
  Environment: dev
  AWS Region: us-east-1
  Domain: your-domain.com
  API Endpoint: http://api.example.com:8000
  Repository: https://github.com/your-org/ci-alert-platform.git
  Branch: main
  Certificate: arn:aws:acm:...

Continue with deployment? (y/n) y
```

---

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Users                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Route 53 (DNS)                           │
│              your-domain.com → CloudFront                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  CloudFront (CDN)                           │
│  ├── S3 Origin (Static Assets)                              │
│  │   ├── *.js, *.css (1 year cache)                         │
│  │   ├── *.html (5 min cache)                               │
│  │   └── *.png, *.jpg (1 year cache)                        │
│  └── ALB Origin (Dynamic Content)                           │
│      └── /api/* (no cache)                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│        Application Load Balancer (ALB)                      │
│  ├── Port 80 (HTTP)                                         │
│  ├── Port 443 (HTTPS - optional)                            │
│  └── Target Group: ci-frontend-tg-dev                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              EC2 Instance(s)                                │
│  ├── Nginx (Reverse Proxy)                                  │
│  │   └── Port 80 → 3000                                     │
│  └── Node.js Frontend                                       │
│      └── Port 3000                                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Backend Services                               │
│  ├── Lambda Functions                                       │
│  ├── API Gateway                                            │
│  ├── OpenSearch                                             │
│  ├── DynamoDB                                               │
│  └── Bedrock                                                │
└─────────────────────────────────────────────────────────────┘
```

---

## AWS Resources Created

### S3 Bucket
- **Name**: `ci-frontend-assets-{env}-{account-id}-{timestamp}`
- **Purpose**: Store static assets
- **Versioning**: Enabled
- **Public Access**: Blocked

### Application Load Balancer
- **Name**: `ci-frontend-alb-{env}`
- **Type**: Application
- **Scheme**: Internet-facing
- **Listeners**: Port 80 (HTTP)

### Target Group
- **Name**: `ci-frontend-tg-{env}`
- **Protocol**: HTTP
- **Port**: 3000
- **Health Check**: Every 30 seconds

### CloudFront Distribution
- **Origins**: S3 + ALB
- **Default Cache**: S3 (static assets)
- **API Cache**: ALB (no caching)
- **Compression**: Enabled

---

## Verification

### Check Prerequisites

```bash
./scripts/check-prerequisites-final.sh
```

### Check Deployment Status

```bash
# Check frontend service
sudo systemctl status ci-frontend

# Check Nginx
sudo systemctl status nginx

# Check health endpoint
curl http://localhost/health

# Check ALB targets
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --region us-east-1
```

### View Logs

```bash
# Frontend logs
sudo journalctl -u ci-frontend -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

---

## Post-Deployment

### 1. Configure DNS (Route 53)

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

### 2. Setup SSL Certificate

```bash
# Request ACM certificate
aws acm request-certificate \
  --domain-name your-domain.com \
  --subject-alternative-names www.your-domain.com \
  --validation-method DNS \
  --region us-east-1

# Update CloudFront with certificate
aws cloudfront update-distribution \
  --id E123456 \
  --distribution-config file://updated-config.json
```

### 3. Enable Monitoring

```bash
# CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 300 \
  --statistics Average
```

### 4. Setup Auto-Scaling

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
  --target-group-arns arn:aws:elasticloadbalancing:...
```

---

## Troubleshooting

### Frontend Not Accessible

```bash
# Check service status
sudo systemctl status ci-frontend

# Check Nginx
sudo systemctl status nginx

# Check ports
sudo netstat -tlnp | grep -E ':(80|3000)'

# View logs
sudo journalctl -u ci-frontend -n 50
```

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
# Check distribution status
aws cloudfront get-distribution --id E123456

# Invalidate cache
aws cloudfront create-invalidation \
  --distribution-id E123456 \
  --paths "/*"
```

---

## Useful Commands

### Service Management

```bash
# Start/stop/restart
sudo systemctl start ci-frontend
sudo systemctl stop ci-frontend
sudo systemctl restart ci-frontend

# View status
sudo systemctl status ci-frontend

# View logs
sudo journalctl -u ci-frontend -f
```

### AWS CLI

```bash
# List ALBs
aws elbv2 describe-load-balancers --region us-east-1

# List CloudFront distributions
aws cloudfront list-distributions

# List S3 buckets
aws s3 ls

# Get instance details
aws ec2 describe-instances --region us-east-1
```

### Monitoring

```bash
# Check CPU/Memory
top

# Check disk usage
df -h

# Check network
netstat -i

# Check processes
ps aux | grep node
```

---

## Cost Estimation

| Service | Monthly Cost |
|---------|--------------|
| ALB | ~$16 |
| CloudFront | ~$20-50 (pay per GB) |
| S3 | ~$5-10 (pay per GB) |
| EC2 (t3.large) | ~$60 |
| Data Transfer | ~$10-20 |
| **Total** | **~$110-160** |

---

## Security Checklist

- ✅ AWS credentials configured
- ✅ IAM permissions verified
- ✅ Security groups configured
- ✅ S3 bucket public access blocked
- ✅ Nginx security headers enabled
- ✅ SSL/TLS certificate installed
- ✅ CloudFront HTTPS enabled
- ✅ Regular backups configured

---

## Next Steps

1. ✅ Run prerequisites check
2. ✅ Run deployment script
3. ✅ Verify deployment
4. ✅ Configure DNS
5. ✅ Setup SSL certificate
6. ✅ Enable monitoring
7. ✅ Setup auto-scaling
8. ✅ Monitor costs

---

## Support

For issues:
1. Check logs: `sudo journalctl -u ci-frontend -f`
2. Run prerequisites: `./scripts/check-prerequisites-final.sh`
3. Review troubleshooting section
4. Contact support team

---

## Summary

You now have:
- ✅ Automated prerequisite checking
- ✅ Interactive deployment script
- ✅ CloudFront CDN setup
- ✅ ALB load balancing
- ✅ EC2 instance configuration
- ✅ Nginx reverse proxy
- ✅ Complete monitoring

**Start with:** `./scripts/check-prerequisites-final.sh`

**Then deploy:** `./scripts/deploy-frontend-final.sh`

**Access at:** `https://your-domain.com` (after DNS setup)
