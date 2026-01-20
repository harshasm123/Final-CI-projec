# Pharmaceutical Competitive Intelligence Platform

A comprehensive serverless AWS platform for pharmaceutical competitive intelligence, featuring real-time data ingestion from 8+ medical sources, AI-powered analysis, and interactive dashboards.

## 🏗️ Architecture

- **Frontend**: React 18 + TypeScript + Material UI
- **Backend**: AWS Lambda + API Gateway + OpenSearch
- **AI**: AWS Bedrock (Claude 3 Sonnet) + Bedrock Agents
- **Data**: S3 + OpenSearch + EventBridge scheduling
- **Security**: IAM roles + Secrets Manager + encryption

## 📊 Data Sources

1. **PubMed** - Medical literature (2-hour updates)
2. **ClinicalTrials.gov** - Clinical trials (4-hour updates)
3. **FDA** - Drug approvals & safety (6-hour updates)
4. **EMA** - European medicines (daily updates)
5. **USPTO** - Patent filings (daily updates)
6. **News APIs** - Industry news (2-hour updates)
7. **Medical Conferences** - Conference data (weekly updates)
8. **SEC Filings** - Financial data (daily updates)

## 🚀 Quick Start

### Prerequisites

```bash
# Run prerequisites check
chmod +x prereq.sh
./prereq.sh
```

Required:
- AWS CLI 2.0+
- Python 3.8+
- Node.js 16+
- AWS account with appropriate permissions

### Deployment

```bash
# Deploy to development environment
chmod +x deploy.sh
./deploy.sh dev us-east-1

# Deploy to production
./deploy.sh prod us-east-1
```

### Configuration

1. **Configure API Keys** in AWS Secrets Manager:
   ```
   pharma-ci/fda-api-key
   pharma-ci/pubmed-api-key
   pharma-ci/clinicaltrials-api-key
   pharma-ci/news-api-key
   pharma-ci/sec-api-key
   pharma-ci/uspto-api-key
   ```

2. **Access the Platform**:
   - Frontend: `http://[bucket-name].s3-website-[region].amazonaws.com`
   - API: `https://[api-id].execute-api.[region].amazonaws.com/prod`

## 🎯 Features

### Dashboard
- Real-time competitive metrics
- Brand performance tracking
- Market trend analysis
- Alert summaries

### Brand Intelligence
- Comprehensive brand profiles
- Competitive positioning
- Market share analysis
- Pipeline tracking

### Competitive Landscape
- Market mapping
- Competitor analysis
- Therapeutic area insights
- Strategic recommendations

### Alert Center
- Real-time notifications
- Customizable alert rules
- Priority-based filtering
- Action workflows

### AI Insights
- Bedrock-powered analysis
- Natural language queries
- Predictive analytics
- Strategic recommendations

### AI Chatbot
- Interactive CI assistant
- Specialized pharmaceutical knowledge
- Template-based queries
- Context-aware responses

## 📁 Project Structure

```
pharma-ci-platform/
├── architecture.yaml                    # Main CloudFormation template
├── bedrock-agent.yaml                  # Bedrock Agent infrastructure
├── comprehensive-eventbridge-rules.yaml # Scheduling rules
├── deploy.sh                           # Deployment script
├── prereq.sh                          # Prerequisites check
├── backend/
│   └── src/
│       ├── comprehensive_data_ingestion.py  # Main ingestion pipeline
│       ├── data_quality_pipeline.py         # Quality validation
│       ├── dashboard_handler.py             # Dashboard API
│       ├── brand_intelligence_handler.py    # Brand intelligence API
│       ├── alerts_handler.py               # Alerts API
│       └── ai_insights_handler.py          # AI insights API
├── frontend/
│   ├── package.json
│   ├── src/
│   │   ├── App.tsx                     # Main React app
│   │   ├── components/
│   │   │   ├── Dashboard.tsx           # Dashboard component
│   │   │   ├── BrandIntelligence.tsx   # Brand intelligence
│   │   │   ├── CompetitiveLandscape.tsx # Competitive analysis
│   │   │   ├── AlertCenter.tsx         # Alert management
│   │   │   ├── AIInsights.tsx          # AI-powered insights
│   │   │   └── EnhancedAIChatbot.tsx   # Interactive chatbot
│   │   └── services/
│   │       └── api.ts                  # API client
└── docs/
    └── COMPREHENSIVE_DATA_SOURCES.md   # Data source documentation
```

## 🔧 API Endpoints

### Core APIs
- `GET /dashboard` - Dashboard metrics
- `GET /brand-intelligence` - Brand analysis
- `GET /competitive-landscape` - Market analysis
- `GET /alerts` - Alert management
- `GET /ai-insights` - AI-powered insights

### Data Management
- `POST /trigger-ingestion` - Manual data ingestion
- `GET /data-quality` - Quality metrics
- `POST /validate-data` - Data validation

### AI Services
- `POST /bedrock-agent/query` - Chatbot queries
- `POST /ai-analysis` - AI analysis requests

## 🛡️ Security

- **IAM Roles**: Least privilege access
- **Encryption**: At-rest and in-transit
- **Secrets Management**: AWS Secrets Manager
- **API Security**: API Gateway authentication
- **Data Privacy**: PII anonymization

## 📈 Monitoring

### CloudWatch Metrics
- Data ingestion rates
- API response times
- Error rates
- Quality scores

### Alarms
- Failed ingestions
- High error rates
- Quality threshold breaches
- Cost anomalies

### Logs
- Application logs in CloudWatch
- API Gateway access logs
- Lambda execution logs
- Data quality reports

## 🔄 Data Pipeline

### Ingestion Flow
1. **EventBridge** triggers Lambda functions
2. **Lambda** fetches data from external APIs
3. **AI Analysis** extracts insights using Bedrock
4. **Quality Validation** ensures data integrity
5. **OpenSearch** indexes processed data
6. **S3** stores raw and processed data

### Quality Dimensions
- **Completeness**: Required fields present
- **Accuracy**: Data format validation
- **Timeliness**: Freshness checks
- **Consistency**: Cross-source validation
- **Uniqueness**: Duplicate detection

## 🎛️ Configuration

### Environment Variables
```bash
ENVIRONMENT=dev|staging|prod
REGION=us-east-1
OPENSEARCH_ENDPOINT=https://...
S3_BUCKET=pharma-ci-data-bucket
BEDROCK_AGENT_ID=agent-id
```

### Scaling Configuration
- **Lambda**: Concurrent executions (1000)
- **OpenSearch**: Instance types (t3.small.search)
- **API Gateway**: Rate limiting (1000 req/sec)
- **S3**: Lifecycle policies (90 days)

## 🧪 Testing

### Unit Tests
```bash
cd backend
python -m pytest tests/
```

### Integration Tests
```bash
cd frontend
npm test
```

### Load Testing
```bash
# API load testing
artillery run load-test.yml
```

## 📚 Documentation

- **API Documentation**: Available at `/docs` endpoint
- **Data Sources**: See `COMPREHENSIVE_DATA_SOURCES.md`
- **Architecture**: See CloudFormation templates
- **Deployment**: See deployment scripts

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Run tests
5. Submit pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

### Common Issues

1. **Deployment Fails**
   - Check AWS permissions
   - Verify region availability
   - Review CloudFormation events

2. **Data Ingestion Issues**
   - Verify API keys in Secrets Manager
   - Check network connectivity
   - Review Lambda logs

3. **Frontend Not Loading**
   - Check S3 bucket policy
   - Verify API endpoint configuration
   - Review browser console

### Getting Help

- Check CloudWatch logs
- Review deployment outputs
- Consult AWS documentation
- Open GitHub issue

## 🔮 Roadmap

- [ ] Multi-tenant support
- [ ] Advanced ML models
- [ ] Real-time streaming
- [ ] Mobile application
- [ ] Advanced visualizations
- [ ] Integration APIs
- [ ] Compliance reporting
- [ ] Advanced security features

---

**Built with ❤️ for pharmaceutical competitive intelligence**