# Pharmaceutical CI Platform - Architecture v2.0

## Overview

Enterprise-grade Competitive Intelligence platform with advanced authentication, event-driven processing, and AI-powered analysis using AWS serverless and container services.

## Architecture Diagram

```
┌─────────┐    ┌──────────┐    ┌─────────────┐    ┌──────────────────┐
│  User   │───▶│ Route 53 │───▶│ ALB (HTTPS) │───▶│ ECS Fargate      │
└─────────┘    └──────────┘    └─────────────┘    │ (React + Nginx)  │
                                                   └──────────────────┘
                                                            ▼
                                                   ┌───────────────┐
                                                   │ Cognito Auth  │
                                                   │ (JWT Tokens)  │
                                                   └───────────────┘
                                                            │
                                                            ▼
                                                   ┌─────────────────────┐
                                                   │   API Gateway       │
                                                   │ (Cognito Authorizer)│
                                                   └─────────────────────┘
                                                            │
                    ┌───────────────────────────────────────┼───────────────────────────────────┐
                    │                                       │                                   │
                    ▼                                       ▼                                   ▼
            ┌───────────────┐                      ┌──────────────┐                   ┌──────────────┐
            │ Lambda        │                      │ Bedrock      │                   │ Lambda       │
            │ Functions     │◀─────────────────────▶│ Agent (RAG)  │                   │ Functions    │
            └───────────────┘                      └──────────────┘                   └──────────────┘
                    │                                       │                                   │
                    ▼                                       ▼                                   ▼
            ┌───────────────┐                      ┌──────────────┐                   ┌──────────────┐
            │ DynamoDB      │                      │ Knowledge    │                   │ OpenSearch   │
            │ Tables        │                      │ Base (S3)    │                   │ Serverless   │
            └───────────────┘                      └──────────────┘                   └──────────────┘
                    │                                                                         │
                    └─────────────────────────────────────────────────────────────────────────┘
                                                    │
                                                    ▼
                    ┌─────────────────────────────────────────────────────────────────────────┐
                    │                        Event-Driven Processing                          │
                    ├─────────────────────────────────────────────────────────────────────────┤
                    │ EventBridge (Midnight) → PubMed Ingestion → SQS → Processor            │
                    │                                                      │                  │
                    │                                                      ▼                  │
                    │                                              Claude 3.5 Haiku          │
                    │                                                                         │
                    │ EventBridge (9 AM) → Digest Lambda → AI Summary → SES Email            │
                    └─────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Frontend Layer

**ECS Fargate + Application Load Balancer**
- React TypeScript application
- Nginx reverse proxy
- Auto-scaling (2-10 instances)
- Health checks and monitoring
- HTTPS support

### 2. Authentication Layer

**AWS Cognito**
- User pool with email verification
- JWT token-based authentication
- OAuth 2.0 support
- Multi-factor authentication ready
- Self-service sign-up

**API Gateway**
- Cognito authorizer
- Request validation
- Rate limiting
- CORS configuration

### 3. Core Services

**Lambda Functions**
- Data ingestion (12 functions)
- Document processing
- AI analysis
- Chatbot handler
- API handler

**DynamoDB**
- Conversation storage
- User sessions
- Metadata storage
- Global secondary indexes

**Elasticsearch**
- Full-text search
- Analytics
- Competitive data indexing
- Real-time queries

### 4. AI & RAG

**Bedrock Agent with RAG**
- Claude 3.5 Haiku for processing
- Knowledge base in S3
- Retrieval-augmented generation
- Multi-turn conversations

**Knowledge Base**
- S3 bucket for documents
- Automatic indexing
- Version control
- Lifecycle policies

### 5. Event-Driven Processing

**EventBridge Rules**
- Midnight: PubMed data ingestion
- 9 AM: Digest generation and email

**SQS Queues**
- Ingestion queue (15-min visibility)
- Processing queue (10-min visibility)
- Dead-letter queues for failures

**Lambda Processors**
- PubMed ingestion handler
- Digest generation with Claude 3.5 Haiku
- Email delivery via SES

### 6. Data Storage

**S3 Buckets**
- Data Lake (raw data)
- Processed Data (transformed)
- Metadata (configurations)
- Knowledge Base (documents)

**DynamoDB Tables**
- Conversations
- User sessions
- Alerts
- Metadata

## Data Flow

### 1. User Authentication
```
User → Cognito Login → JWT Token → API Gateway → Lambda
```

### 2. API Request
```
Frontend → API Gateway (Cognito Authorizer) → Lambda → DynamoDB/Elasticsearch
```

### 3. AI Analysis
```
Lambda → Bedrock Agent → Knowledge Base (S3) → Claude 3.5 Haiku → Response
```

### 4. Event Processing
```
EventBridge → SQS → Lambda → Bedrock → SES Email
```

### 5. Data Ingestion
```
PubMed API → Lambda → Elasticsearch → DynamoDB
```

## Security

### Authentication & Authorization
- Cognito user pools
- JWT token validation
- API Gateway authorizers
- IAM roles with least privilege

### Data Protection
- S3 bucket encryption
- DynamoDB encryption
- Elasticsearch encryption
- VPC endpoints for private access

### Network Security
- VPC with public/private subnets
- NAT gateway for outbound traffic
- Security groups for access control
- ALB with HTTPS

## Scalability

### Auto-Scaling
- ECS Fargate: 2-10 instances
- Lambda: Automatic scaling
- DynamoDB: On-demand billing
- Elasticsearch: Serverless

### Performance
- CloudFront CDN for static assets
- ElastiCache for caching (optional)
- Lambda concurrency limits
- SQS for async processing

## Monitoring & Logging

### CloudWatch
- Lambda execution logs
- API Gateway logs
- ECS container logs
- Application metrics

### Alarms
- Lambda error rates
- API latency
- DynamoDB throttling
- Elasticsearch health

## Cost Estimation

| Service | Monthly Cost |
|---------|--------------|
| ECS Fargate | $50-100 |
| Lambda | $20-50 |
| DynamoDB | $10-20 |
| Elasticsearch | $50-100 |
| API Gateway | $5-10 |
| Cognito | $5-10 |
| SQS | $1-5 |
| SES | $1-5 |
| S3 | $10-20 |
| **Total** | **~$150-320** |

## Deployment

### Prerequisites
- AWS account
- AWS CLI configured
- Node.js 18+
- Python 3.11+

### Deploy
```bash
./deploy.sh dev us-east-1
```

### Stacks Deployed
1. `pharma-ci-platform-dev` - Core infrastructure
2. `pharma-ci-auth-dev` - Cognito authentication
3. `pharma-ci-frontend-dev` - ECS Fargate + ALB
4. `pharma-ci-rag-dev` - Knowledge base
5. `pharma-ci-events-dev` - Event processing
6. `pharma-ci-bedrock-dev` - Bedrock agent
7. `pharma-ci-eventbridge-dev` - EventBridge rules

## Features

### ✅ Authentication
- User registration and login
- Email verification
- JWT tokens
- Session management

### ✅ AI Analysis
- Bedrock Claude 3.5 Haiku
- RAG with knowledge base
- Multi-turn conversations
- Automatic summarization

### ✅ Event Processing
- Scheduled data ingestion
- Automated digest generation
- Email notifications
- Error handling and retries

### ✅ Data Management
- Full-text search
- Real-time analytics
- Data versioning
- Lifecycle policies

### ✅ Monitoring
- CloudWatch logs
- Performance metrics
- Error tracking
- Health checks

## Next Steps

1. Deploy infrastructure: `./deploy.sh dev us-east-1`
2. Configure API keys in Secrets Manager
3. Upload documents to knowledge base
4. Configure email settings for SES
5. Access application via ALB DNS
6. Monitor logs and metrics

## Documentation

- **[README.md](./README.md)** - Project overview
- **[QUICKSTART.md](./QUICKSTART.md)** - Quick start guide
- **[DEPLOYMENT_SUMMARY.md](./DEPLOYMENT_SUMMARY.md)** - Deployment details
- **[cdk/README.md](./cdk/README.md)** - CDK documentation

---

**Version**: 2.0.0
**Last Updated**: January 2026
**Status**: Production Ready ✅
