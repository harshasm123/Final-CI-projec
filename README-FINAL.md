 # Pharmaceutical CI Platform

Enterprise-grade Competitive Intelligence platform for pharmaceutical companies using AWS serverless architecture.

## 🏗️ Architecture

- **Frontend**: React TypeScript application with Material-UI
- **Backend**: AWS Lambda functions (Python 3.11)
- **Data**: S3, DynamoDB, OpenSearch
- **AI**: AWS Bedrock (Claude 3 Sonnet)
- **Infrastructure**: AWS CDK (TypeScript)

## 📁 Project Structure

```
.
├── cdk/                    # AWS CDK Infrastructure
│   ├── src/
│   │   ├── stacks/         # CloudFormation stacks
│   │   │   ├── data-stack.ts       # Data layer (S3, DynamoDB, OpenSearch)
│   │   │   ├── compute-stack.ts    # Compute layer (Lambda, API Gateway)
│   │   │   └── frontend-stack.ts   # Frontend (S3, CloudFront)
│   │   └── index.ts        # CDK app entry point
│   └── package.json
├── frontend/               # React TypeScript application
│   ├── src/
│   │   ├── components/     # React components
│   │   ├── pages/          # Application pages
│   │   ├── hooks/          # Custom React hooks
│   │   └── store/          # Redux store
│   └── package.json
├── backend/                # Python Lambda functions
│   ├── src/
│   │   ├── handlers/       # Lambda handlers
│   │   │   ├── enhanced_ai_handler.py      # RAG chatbot
│   │   │   └── dashboard_handler.py        # Dashboard API
│   │   └── comprehensive_data_ingestion.py # Data ingestion pipeline
│   └── requirements.txt
└── deploy-complete.sh      # Complete deployment script
```

## 🚀 Quick Deployment

### Prerequisites

- Node.js 18+
- Python 3.11+
- AWS CLI configured with appropriate permissions
- AWS CDK CLI: `npm install -g aws-cdk`

### One-Command Deployment

```bash
./deploy-complete.sh dev us-east-1
```

This script will:
1. Deploy all AWS infrastructure
2. Build and deploy the frontend
3. Initialize sample data
4. Provide access URLs

### Manual Deployment

#### 1. Deploy Infrastructure

```bash
cd cdk
npm install
npm run build
cdk deploy --all --require-approval never
```

#### 2. Deploy Frontend

```bash
cd frontend
npm install
npm run build
# Upload to S3 bucket (get bucket name from CDK outputs)
aws s3 sync build/ s3://YOUR-FRONTEND-BUCKET --delete
```

#### 3. Initialize Data

```bash
# Trigger data ingestion
aws lambda invoke --function-name YOUR-DATA-INGESTION-FUNCTION --payload '{"source":"all"}' response.json
```

## 🔧 Key Features

### Data Ingestion Pipeline
- **FDA**: Regulatory data, adverse events, drug approvals
- **PubMed**: Clinical research and publications
- **ClinicalTrials.gov**: Clinical trial information
- **Patents**: USPTO patent data
- **News**: Pharmaceutical industry news (configurable)

### AI-Powered Analysis
- **RAG Chatbot**: Claude 3 Sonnet with pharmaceutical knowledge base
- **Competitive Intelligence**: Automated brand mention tracking
- **Clinical Trial Analysis**: Phase progression and competitive impact
- **Regulatory Monitoring**: FDA approval tracking and safety alerts
- **Market Intelligence**: Trend analysis and investment tracking

### Interactive Dashboard
- **Real-time Metrics**: Document counts, source distribution
- **Competitive Landscape**: Market share analysis and trends
- **Clinical Trials**: Phase distribution and sponsor analysis
- **Regulatory Updates**: Recent approvals and safety alerts
- **Alert System**: High-impact event notifications

### RAG Chatbot Features
- **Multi-turn Conversations**: Context-aware dialogue
- **Knowledge Base Search**: OpenSearch-powered retrieval
- **Competitive Analysis**: Brand-specific insights
- **Clinical Trial Insights**: Phase and indication analysis
- **Regulatory Intelligence**: FDA and EMA updates

## 📊 AWS Services Used

| Service | Purpose | Configuration |
|---------|---------|---------------|
| Lambda | Serverless compute | Python 3.11, up to 15min timeout |
| S3 | Data storage | Versioned, lifecycle policies |
| DynamoDB | Conversation storage | Pay-per-request billing |
| OpenSearch | Search and analytics | t3.small, 20GB storage |
| API Gateway | REST API | CORS enabled |
| Bedrock | AI models | Claude 3 Sonnet, Titan embeddings |
| EventBridge | Scheduled tasks | 6-hour data ingestion |
| CloudFront | CDN | Global distribution |
| CDK | Infrastructure | TypeScript, 3 stacks |

## 🔐 Security Features

- **IAM Roles**: Least privilege access
- **S3 Security**: Public access blocked for data buckets
- **OpenSearch**: Encryption at rest and in transit
- **API Gateway**: CORS configuration
- **CloudFront**: HTTPS enforcement
- **Secrets Manager**: API key management (optional)

## 💰 Cost Estimation (Monthly)

| Service | Estimated Cost |
|---------|----------------|
| Lambda | $20-50 |
| S3 | $10-20 |
| DynamoDB | $5-15 |
| OpenSearch | $50-100 |
| API Gateway | $5-10 |
| CloudFront | $5-15 |
| Bedrock | $30-100 |
| **Total** | **$125-310** |

*Costs vary based on usage patterns and data volume*

## 🛠️ Development

### Local Development

```bash
# Frontend development
cd frontend
npm start

# Backend testing
cd backend
pip install -r requirements.txt
python -m pytest
```

### Environment Variables

#### Backend Lambda Functions
- `DATA_BUCKET`: S3 bucket for raw data
- `KNOWLEDGE_BUCKET`: S3 bucket for processed knowledge base
- `CONVERSATION_TABLE`: DynamoDB table for chat history
- `OPENSEARCH_ENDPOINT`: OpenSearch domain endpoint
- `ENVIRONMENT`: Deployment environment (dev/prod)

#### Frontend Application
- `REACT_APP_API_URL`: API Gateway endpoint
- `REACT_APP_ENVIRONMENT`: Environment identifier

## 📋 API Endpoints

### Chat API
```
POST /chat
{
  "message": "What are the latest clinical trials for pembrolizumab?",
  "conversationId": "optional-conversation-id",
  "userId": "user-identifier"
}
```

### Dashboard API
```
GET /dashboard
# Returns comprehensive dashboard data including:
# - Overview metrics
# - Recent activity
# - Competitive landscape
# - Clinical trials summary
# - Regulatory updates
# - Market intelligence
# - Active alerts
```

## 🐛 Troubleshooting

### Common Issues

1. **CDK Bootstrap Error**
   ```bash
   cdk bootstrap aws://ACCOUNT-ID/REGION
   ```

2. **OpenSearch Access Denied**
   - Check IAM roles and policies
   - Verify VPC configuration if using VPC

3. **Frontend Build Errors**
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   npm run build
   ```

4. **Lambda Timeout Issues**
   - Check CloudWatch logs
   - Increase timeout in CDK configuration
   - Optimize data processing logic

### Monitoring

- **CloudWatch Logs**: Lambda function logs
- **CloudWatch Metrics**: API Gateway and Lambda metrics
- **OpenSearch Dashboards**: Search analytics
- **S3 Metrics**: Storage and request metrics

## 🔄 Data Flow

1. **Ingestion**: EventBridge triggers Lambda every 6 hours
2. **Processing**: Lambda fetches data from external APIs
3. **Storage**: Raw data stored in S3, processed data in OpenSearch
4. **Knowledge Base**: Structured documents for RAG retrieval
5. **Chat Interface**: User queries trigger knowledge base search
6. **AI Response**: Claude 3 Sonnet generates contextual responses
7. **Dashboard**: Real-time metrics from OpenSearch aggregations

## 📈 Scaling Considerations

- **Lambda Concurrency**: Adjust reserved concurrency for high load
- **OpenSearch**: Scale to larger instance types or multi-AZ
- **S3**: Use S3 Transfer Acceleration for global access
- **CloudFront**: Configure additional cache behaviors
- **DynamoDB**: Enable auto-scaling for conversation table

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Submit a pull request

## 📝 License

Proprietary - Pharmaceutical CI Platform

## 📞 Support

For technical support:
1. Check CloudWatch logs for errors
2. Review CDK deployment outputs
3. Verify AWS service quotas
4. Contact your AWS solutions architect

---

**Last Updated**: January 2026  
**Version**: 2.0.0  
**Architecture**: Serverless, Multi-tier, AI-Enhanced