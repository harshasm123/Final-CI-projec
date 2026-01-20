# System Architecture - Service Names & Data Flow

## Overview

Complete pharmaceutical CI platform architecture with all services, their interactions, and data flow.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHARMACEUTICAL CI PLATFORM                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND LAYER                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    React Frontend Application                       │   │
│  │  (ci-alert-frontend-dev / ci-alert-frontend-prod)                 │   │
│  │                                                                     │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │   │
│  │  │  Dashboard   │  │  Brand Intel │  │  Alerts      │             │   │
│  │  │  Component   │  │  Component   │  │  Component   │             │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘             │   │
│  │                                                                     │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │   │
│  │  │  Trials      │  │  Regulatory  │  │  Chatbot     │             │   │
│  │  │  Component   │  │  Component   │  │  Component   │             │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘             │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Nginx Reverse Proxy                              │   │
│  │              (Port 80/443 → Port 3000)                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│                            API GATEWAY LAYER                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              AWS API Gateway (REST API)                             │   │
│  │                                                                     │   │
│  │  /dashboard/*  /brands/*  /trials/*  /alerts/*  /chat/*           │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│                          LAMBDA FUNCTIONS LAYER                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PHASE 1 & 2: Data Ingestion & Processing                                  │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-data-ingestion-{env}                                         │      │
│  │  - PubMed ingestion                                              │      │
│  │  - Clinical trials ingestion                                     │      │
│  │  - FDA data ingestion                                            │      │
│  │  - Patent data ingestion                                         │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                    ↓                                        │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-process-document-{env}                                      │      │
│  │  - Document processing                                           │      │
│  │  - AI analysis with Bedrock                                      │      │
│  │  - Alert generation                                              │      │
│  │  - Competitive threat detection                                  │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  PHASE 3: AI & Data Pipelines                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-ai-handler-{env}                                             │      │
│  │  - Natural language processing                                   │      │
│  │  - Bedrock Claude integration                                    │      │
│  │  - Context-aware responses                                       │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-alert-handler-{env}                                          │      │
│  │  - Alert filtering & retrieval                                   │      │
│  │  - Severity-based prioritization                                 │      │
│  │  - Brand impact tracking                                         │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-competitive-analysis-{env}                                   │      │
│  │  - Competitive landscape analysis                                │      │
│  │  - Threat assessment                                             │      │
│  │  - Market opportunity identification                             │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-brand-handler-{env}                                          │      │
│  │  - Brand search & retrieval                                      │      │
│  │  - Competitive landscape for brands                              │      │
│  │  - Brand intelligence aggregation                                │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-dashboard-handler-{env}                                      │      │
│  │  - KPI calculations                                              │      │
│  │  - Trend analysis                                                │      │
│  │  - Real-time metrics                                             │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-data-quality-{env}                                           │      │
│  │  - Data completeness checks                                      │      │
│  │  - Data consistency validation                                   │      │
│  │  - Data accuracy verification                                    │      │
│  │  - Data timeliness checks                                        │      │
│  │  - Duplicate detection                                           │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-chatbot-handler-{env}                                        │      │
│  │  - Interactive chat management                                   │      │
│  │  - Bedrock Agent integration                                     │      │
│  │  - Conversation history tracking                                 │      │
│  │  - Insight extraction                                            │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-agent-tools-{env}                                            │      │
│  │  - Brand search tool                                             │      │
│  │  - Trial search tool                                             │      │
│  │  - Competitive analysis tool                                     │      │
│  │  - Threat assessment tool                                        │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  ci-api-{env}                                                    │      │
│  │  - REST API handler                                              │      │
│  │  - Request routing                                               │      │
│  │  - Response formatting                                           │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│                          DATA STORAGE LAYER                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  OpenSearch Domain (ci-search-{env})                             │      │
│  │  - Brands index                                                  │      │
│  │  - Trials index                                                  │      │
│  │  - Alerts index                                                  │      │
│  │  - Regulatory index                                              │      │
│  │  - Conversations index                                           │      │
│  │  - Competitive analysis index                                    │      │
│  │  - Data quality checks index                                     │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  DynamoDB Tables                                                 │      │
│  │  - ci-chatbot-conversations-{env}                                │      │
│  │    (Conversation history & metadata)                             │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  S3 Buckets                                                      │      │
│  │  - ci-alert-datalake-{env}                                       │      │
│  │    (Raw data from external sources)                              │      │
│  │  - ci-alert-processed-{env}                                      │      │
│  │    (Processed documents)                                         │      │
│  │  - ci-metadata-{env}                                             │      │
│  │    (Metadata & analysis results)                                 │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│                        ORCHESTRATION LAYER                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  EventBridge Rules                                               │      │
│  │                                                                  │      │
│  │  PHASE 1 & 2: Data Ingestion Rules                              │      │
│  │  - pubmed-ingestion-{env}        (every 6 hours)                │      │
│  │  - trials-ingestion-{env}        (daily)                        │      │
│  │  - fda-ingestion-{env}           (every 4 hours)                │      │
│  │                                                                  │      │
│  │  PHASE 3: AI & Data Pipeline Rules                              │      │
│  │  - ai-insights-generation-{env}  (on document processed)        │      │
│  │  - alert-generation-{env}        (on AI analysis complete)      │      │
│  │  - competitive-analysis-{env}    (daily at 2 AM)               │      │
│  │  - brand-intelligence-aggregation-{env} (every 12 hours)        │      │
│  │  - dashboard-data-refresh-{env}  (every 4 hours)                │      │
│  │  - data-quality-check-{env}      (every 6 hours)                │      │
│  │                                                                  │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  SNS Topics                                                      │      │
│  │  - ci-alerts-{env}                                               │      │
│  │    (Alert notifications)                                         │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │  Bedrock Services                                                │      │
│  │  - Claude 3 Sonnet Model                                         │      │
│  │    (AI insights & analysis)                                      │      │
│  │  - Bedrock Agent Runtime                                         │      │
│  │    (Complex multi-step analysis)                                 │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagrams

### Flow 1: Data Ingestion Pipeline

```
External Data Sources
├── PubMed API
├── ClinicalTrials.gov API
├── FDA API
└── Patent Databases
        ↓
EventBridge Rules (Scheduled)
├── pubmed-ingestion-{env}
├── trials-ingestion-{env}
└── fda-ingestion-{env}
        ↓
ci-data-ingestion-{env} Lambda
├── Fetch data from APIs
├── Transform data
└── Store in S3 (DataLake)
        ↓
S3 Trigger Event
        ↓
ci-process-document-{env} Lambda
├── Process documents
├── Extract entities
├── Call Bedrock for AI analysis
└── Generate alerts
        ↓
OpenSearch
├── Index processed data
├── Store alerts
└── Store analysis results
        ↓
SNS Topic (ci-alerts-{env})
        ↓
Alert Notifications
```

### Flow 2: AI Analysis Pipeline

```
User Question / Document
        ↓
API Gateway
        ↓
ci-chatbot-handler-{env} or ci-ai-handler-{env}
        ↓
Bedrock Claude 3 Sonnet
├── Process natural language
├── Generate insights
└── Extract recommendations
        ↓
OpenSearch
├── Retrieve context data
├── Search brands
├── Search trials
└── Search alerts
        ↓
Response to User
├── AI insights
├── Recommendations
└── Source citations
        ↓
DynamoDB
└── Store conversation history
```

### Flow 3: Competitive Analysis Pipeline

```
EventBridge Rule
└── competitive-analysis-{env} (daily at 2 AM)
        ↓
ci-competitive-analysis-{env} Lambda
        ↓
OpenSearch
├── Query all brands
├── Get competitor data
├── Retrieve trials
└── Get alerts
        ↓
Bedrock Claude 3 Sonnet
├── Analyze competitive position
├── Identify threats
└── Find opportunities
        ↓
OpenSearch
└── Store analysis results
        ↓
ci-dashboard-handler-{env}
└── Update KPIs
```

### Flow 4: Chatbot Agent Pipeline

```
User Chat Message
        ↓
API Gateway (/chat/message)
        ↓
ci-chatbot-handler-{env}
        ↓
Bedrock Agent Runtime
        ↓
ci-agent-tools-{env} Lambda
├── Brand search tool
├── Trial search tool
├── Competitive analysis tool
└── Threat assessment tool
        ↓
OpenSearch
├── Search brands
├── Search trials
├── Get competitive data
└── Retrieve alerts
        ↓
Bedrock Claude 3 Sonnet
├── Process results
├── Generate response
└── Extract insights
        ↓
DynamoDB
└── Store conversation
        ↓
Response to User
```

### Flow 5: Dashboard Data Pipeline

```
EventBridge Rule
└── dashboard-data-refresh-{env} (every 4 hours)
        ↓
ci-dashboard-handler-{env}
        ↓
OpenSearch
├── Count brands
├── Count competitors
├── Count critical alerts
└── Get regulatory events
        ↓
Calculate KPIs
├── Brands tracked
├── Competitors monitored
├── Critical alerts
└── Regulatory events
        ↓
Frontend Dashboard
└── Display metrics
```

### Flow 6: Data Quality Pipeline

```
EventBridge Rule
└── data-quality-check-{env} (every 6 hours)
        ↓
ci-data-quality-{env}
        ↓
OpenSearch
├── Check completeness
├── Check consistency
├── Check accuracy
├── Check timeliness
└── Check uniqueness
        ↓
Generate Quality Report
├── Quality score
├── Issues found
└── Recommendations
        ↓
SNS Topic (if low quality)
        ↓
Alert Notifications
```

---

## Service Dependencies

```
Frontend (React)
    ↓
API Gateway
    ↓
Lambda Functions
    ├── ci-data-ingestion-{env}
    │   ├── S3 (DataLake)
    │   ├── OpenSearch
    │   └── SNS
    │
    ├── ci-process-document-{env}
    │   ├── S3 (Processed)
    │   ├── Bedrock
    │   ├── OpenSearch
    │   └── SNS
    │
    ├── ci-ai-handler-{env}
    │   ├── Bedrock
    │   └── OpenSearch
    │
    ├── ci-alert-handler-{env}
    │   └── OpenSearch
    │
    ├── ci-competitive-analysis-{env}
    │   ├── OpenSearch
    │   └── Bedrock
    │
    ├── ci-brand-handler-{env}
    │   └── OpenSearch
    │
    ├── ci-dashboard-handler-{env}
    │   └── OpenSearch
    │
    ├── ci-data-quality-{env}
    │   ├── OpenSearch
    │   └── SNS
    │
    ├── ci-chatbot-handler-{env}
    │   ├── Bedrock
    │   ├── OpenSearch
    │   └── DynamoDB
    │
    ├── ci-agent-tools-{env}
    │   └── OpenSearch
    │
    └── ci-api-{env}
        └── OpenSearch

EventBridge
    ├── Scheduled Rules
    └── Event-driven Rules
        └── Lambda Functions

Storage
    ├── S3 (DataLake, Processed, Metadata)
    ├── OpenSearch (Indices)
    └── DynamoDB (Conversations)

AI/ML
    ├── Bedrock Claude 3 Sonnet
    └── Bedrock Agent Runtime

Notifications
    └── SNS Topics
```

---

## Environment Variables by Service

### All Lambda Functions

```
ENVIRONMENT=dev|staging|prod
OPENSEARCH_ENDPOINT=<opensearch-domain-endpoint>
METADATA_BUCKET=ci-metadata-{env}-{account-id}
ALERT_TOPIC=arn:aws:sns:region:account:ci-alerts-{env}
```

### Data Ingestion

```
DATALAKE_BUCKET=ci-alert-datalake-{env}-{account-id}
```

### Document Processor

```
PROCESSED_BUCKET=ci-alert-processed-{env}-{account-id}
```

### Chatbot Handler

```
CONVERSATION_TABLE=ci-chatbot-conversations-{env}
BEDROCK_AGENT_ID=<agent-id>
BEDROCK_AGENT_ALIAS_ID=<alias-id>
```

---

## Service Naming Convention

```
ci-{service-type}-{environment}

Examples:
- ci-data-ingestion-dev
- ci-process-document-staging
- ci-ai-handler-prod
- ci-alert-handler-dev
- ci-competitive-analysis-prod
- ci-brand-handler-dev
- ci-dashboard-handler-staging
- ci-data-quality-prod
- ci-chatbot-handler-dev
- ci-agent-tools-prod
- ci-api-dev
- ci-frontend-dev
```

---

## Resource Naming Convention

```
S3 Buckets:
- ci-alert-datalake-{env}-{account-id}
- ci-alert-processed-{env}-{account-id}
- ci-metadata-{env}-{account-id}

OpenSearch Domain:
- ci-search-{env}

DynamoDB Tables:
- ci-chatbot-conversations-{env}

SNS Topics:
- ci-alerts-{env}

EventBridge Rules:
- {rule-name}-{env}

IAM Roles:
- ci-lambda-execution-role-{env}
- ci-eventbridge-invoke-role-{env}
- ci-bedrock-agent-role-{env}
```

---

## API Endpoints

```
Base URL: https://api.pharma-ci.com/v1

Dashboard:
- GET /dashboard/kpis
- GET /dashboard/trends

Brands:
- GET /brands/search?q={query}
- GET /brands/{brandId}
- GET /brands/{brandId}/competitive-landscape
- GET /brands/{brandId}/trials

Alerts:
- GET /alerts?brand={brand}&severity={severity}

AI Insights:
- POST /ai/insights

Chatbot:
- POST /chat/session
- POST /chat/message
- POST /chat/analyze
- GET /chat/history/{conversationId}
```

---

## Deployment Architecture

```
Local Development
    ↓
GitHub Repository
    ↓
EC2 Instance
    ├── Nginx (Reverse Proxy)
    ├── Node.js (Frontend)
    └── Systemd (Service Management)
    ↓
AWS Services
    ├── Lambda Functions
    ├── API Gateway
    ├── EventBridge
    ├── OpenSearch
    ├── DynamoDB
    ├── S3
    ├── SNS
    ├── Bedrock
    └── CloudWatch
```

---

## Monitoring & Logging

```
CloudWatch Logs:
- /aws/lambda/ci-data-ingestion-{env}
- /aws/lambda/ci-process-document-{env}
- /aws/lambda/ci-ai-handler-{env}
- /aws/lambda/ci-alert-handler-{env}
- /aws/lambda/ci-competitive-analysis-{env}
- /aws/lambda/ci-brand-handler-{env}
- /aws/lambda/ci-dashboard-handler-{env}
- /aws/lambda/ci-data-quality-{env}
- /aws/lambda/ci-chatbot-handler-{env}
- /aws/lambda/ci-agent-tools-{env}
- /aws/lambda/ci-api-{env}

CloudWatch Metrics:
- Lambda invocations
- Lambda duration
- Lambda errors
- API Gateway requests
- OpenSearch queries
- DynamoDB operations
```

---

## Summary

| Component | Service Name | Type | Purpose |
|-----------|--------------|------|---------|
| Frontend | ci-alert-frontend-{env} | React App | User interface |
| API | ci-api-{env} | Lambda | REST API handler |
| Data Ingestion | ci-data-ingestion-{env} | Lambda | External data fetching |
| Document Processing | ci-process-document-{env} | Lambda | Document analysis |
| AI Handler | ci-ai-handler-{env} | Lambda | AI insights |
| Alert Handler | ci-alert-handler-{env} | Lambda | Alert management |
| Competitive Analysis | ci-competitive-analysis-{env} | Lambda | Market analysis |
| Brand Handler | ci-brand-handler-{env} | Lambda | Brand intelligence |
| Dashboard Handler | ci-dashboard-handler-{env} | Lambda | KPI calculations |
| Data Quality | ci-data-quality-{env} | Lambda | Quality checks |
| Chatbot Handler | ci-chatbot-handler-{env} | Lambda | Chat management |
| Agent Tools | ci-agent-tools-{env} | Lambda | Agent tools |
| Search | ci-search-{env} | OpenSearch | Data indexing |
| Conversations | ci-chatbot-conversations-{env} | DynamoDB | Chat history |
| Alerts | ci-alerts-{env} | SNS | Notifications |
| Orchestration | EventBridge | Service | Scheduling |
| AI/ML | Bedrock | Service | Claude models |

---

## Next Steps

1. Review service architecture
2. Understand data flows
3. Deploy services
4. Monitor performance
5. Scale as needed
