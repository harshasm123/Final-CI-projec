# Pharmaceutical CI Platform

Enterprise-grade Competitive Intelligence platform for pharmaceutical companies using AWS serverless architecture.

## 🏗️ Architecture

- **Frontend**: React TypeScript application
- **Backend**: AWS Lambda functions (Python 3.11)
- **Data**: S3, DynamoDB, Elasticsearch
- **AI**: AWS Bedrock (Claude 3 Sonnet)
- **Infrastructure**: AWS CDK (TypeScript)

## 📁 Project Structure

```
.
├── cdk/                    # AWS CDK Infrastructure as Code
│   ├── src/
│   │   ├── index.ts       # CDK app entry point
│   │   └── stacks/        # CloudFormation stacks
│   ├── deploy.sh          # Deployment script
│   └── README.md          # CDK documentation
├── frontend/              # React TypeScript application
│   ├── src/
│   ├── public/
│   └── package.json
├── backend/               # Python Lambda functions
│   ├── src/
│   │   ├── handlers/      # Lambda handlers
│   │   └── services/      # AWS service integrations
│   └── requirements.txt
├── scripts/               # Utility scripts
│   ├── ec2setup.sh       # EC2 setup script
│   └── push-to-github.sh # GitHub push script
├── SYSTEM_ARCHITECTURE.md # System design documentation
├── FINAL_DEPLOYMENT_GUIDE.md # Deployment instructions
└── README.md             # This file
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Python 3.11+
- AWS CLI configured
- AWS CDK CLI: `npm install -g aws-cdk`

### Deploy Infrastructure

```bash
cd cdk
npm install
./deploy.sh dev us-east-1
```

### Deploy Frontend

```bash
cd frontend
npm install
npm run build
npm run deploy
```

### Deploy Backend

```bash
cd backend
pip install -r requirements.txt
# Lambda functions are deployed via CDK
```

## 📚 Documentation

- **[SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md)** - Complete system design and data flows
- **[FINAL_DEPLOYMENT_GUIDE.md](./FINAL_DEPLOYMENT_GUIDE.md)** - Step-by-step deployment instructions
- **[cdk/README.md](./cdk/README.md)** - CDK infrastructure documentation

## 🔧 Key Features

### Data Ingestion
- FDA regulatory data
- PubMed clinical research
- Clinical trials information
- News and market intelligence
- SEC filings and patents

### AI Analysis
- Competitive landscape analysis
- Threat assessment
- Market opportunity identification
- Brand intelligence aggregation
- Automated alert generation

### Interactive Chatbot
- Bedrock Claude 3 Sonnet integration
- Multi-turn conversations
- Agent-based complex analysis
- Conversation history tracking

### Real-time Monitoring
- EventBridge scheduled tasks
- Data quality checks
- Alert generation
- Dashboard refresh

## 📊 AWS Services Used

| Service | Purpose |
|---------|---------|
| Lambda | Serverless compute |
| S3 | Data storage |
| DynamoDB | Conversation storage |
| Elasticsearch | Search and analytics |
| API Gateway | REST API |
| Bedrock | AI models |
| EventBridge | Scheduled tasks |
| SNS | Notifications |
| CloudFormation | Infrastructure |

## 🛠️ Development

### Local Development

```bash
# Frontend
cd frontend
npm install
npm start

# Backend (local testing)
cd backend
pip install -r requirements.txt
python -m pytest
```

### Deploy Changes

```bash
# Infrastructure changes
cd cdk
npm run build
npm run deploy

# Frontend changes
cd frontend
npm run build
npm run deploy

# Backend changes (automatic via CDK)
cd cdk
npm run deploy
```

## 📋 Available Commands

### CDK Commands
```bash
cd cdk
npm run build      # Build TypeScript
npm run synth      # Generate CloudFormation
npm run diff       # Show infrastructure changes
npm run deploy     # Deploy stacks
npm run destroy    # Delete stacks
```

### Frontend Commands
```bash
cd frontend
npm install        # Install dependencies
npm start          # Start dev server
npm run build      # Build for production
npm run deploy     # Deploy to S3
```

### Backend Commands
```bash
cd backend
pip install -r requirements.txt  # Install dependencies
python -m pytest                 # Run tests
```

### Utility Scripts
```bash
# Setup EC2 instance
./scripts/ec2setup.sh <repo-url> <branch>

# Push code to GitHub
./scripts/push-to-github.sh <repo-url> <branch>
```

## 🔐 Security

- IAM roles with least privilege
- S3 bucket public access blocked
- Elasticsearch encryption enabled
- Secrets Manager for API keys
- VPC endpoints for private access

## 💰 Cost Estimation

| Service | Monthly Cost |
|---------|--------------|
| Lambda | $20-50 |
| S3 | $10-20 |
| DynamoDB | $5-10 |
| Elasticsearch | $50-100 |
| API Gateway | $5-10 |
| **Total** | **~$90-190** |

## 🐛 Troubleshooting

### CDK Deployment Issues

```bash
# Check stack status
aws cloudformation describe-stacks --stack-name pharma-ci-platform-dev

# View stack events
aws cloudformation describe-stack-events --stack-name pharma-ci-platform-dev

# Check Lambda logs
aws logs tail /aws/lambda/ci-* --follow
```

### Frontend Issues

```bash
# Clear cache and rebuild
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Backend Issues

```bash
# Check Lambda function
aws lambda get-function --function-name ci-api-dev

# View function logs
aws logs tail /aws/lambda/ci-api-dev --follow
```

## 📞 Support

For issues or questions:
1. Check documentation in `SYSTEM_ARCHITECTURE.md`
2. Review deployment guide in `FINAL_DEPLOYMENT_GUIDE.md`
3. Check CDK documentation in `cdk/README.md`
4. Review AWS CloudFormation events for deployment errors

## 📝 License

Proprietary - Pharmaceutical CI Platform

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test locally
4. Push to GitHub
5. Create pull request

## 📅 Deployment Checklist

- [ ] AWS credentials configured
- [ ] CDK dependencies installed
- [ ] Infrastructure deployed (`cdk deploy`)
- [ ] API keys configured in Secrets Manager
- [ ] Frontend built and deployed
- [ ] Backend Lambda functions deployed
- [ ] EventBridge rules active
- [ ] Monitoring and alerts configured
- [ ] Backup strategy implemented
- [ ] Documentation updated

---

**Last Updated**: January 2026
**Version**: 1.0.0
