# Comprehensive Medical Pharmaceutical Data Sources

## Overview

This document outlines all medical pharmaceutical data sources integrated into the CI Alert System, their ingestion frequencies, and API configurations.

## Data Sources Summary

| Source | Frequency | Data Type | API Endpoint | Key Fields |
|--------|-----------|-----------|--------------|------------|
| PubMed | 2 hours | Research Papers | eutils.ncbi.nlm.nih.gov | PMID, Title, Abstract, Authors |
| ClinicalTrials.gov | 6 hours | Clinical Trials | clinicaltrials.gov/api/v2 | NCT ID, Phase, Status, Sponsor |
| FDA | 4 hours | Regulatory Data | api.fda.gov | Drug Events, Labels, Approvals |
| EMA | Daily | EU Regulatory | ema.europa.eu | Medicine Data, Approvals |
| USPTO | Daily | Patents | developer.uspto.gov | Patent ID, Assignee, Claims |
| News Sources | 3 hours | Market Intelligence | Various APIs | Headlines, Content, Sentiment |
| Conferences | Weekly | Medical Abstracts | Conference APIs | Abstracts, Presentations |
| SEC | Daily | Financial Filings | sec.gov/edgar | 10-K, 10-Q, 8-K Filings |

## Detailed Source Configurations

### 1. PubMed (NCBI E-utilities)

**Endpoint:** `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/`

**Search Strategy:**
```python
search_queries = [
    # Brand-specific searches
    "(pembrolizumab OR nivolumab OR atezolizumab OR durvalumab)",
    
    # Therapeutic area searches  
    "(oncology OR immunotherapy OR cancer) AND (clinical trial OR phase)",
    
    # Competitive intelligence
    "competitive analysis AND pharmaceutical",
    "market share AND oncology drugs",
    "biosimilar AND competition",
    
    # Safety and efficacy
    "adverse events AND immunotherapy",
    "real world evidence AND cancer drugs"
]
```

**API Parameters:**
- `db`: pubmed
- `retmode`: json/xml
- `retmax`: 100 per query
- `datetype`: pdat (publication date)
- `reldate`: 30 (last 30 days)
- `sort`: relevance

**Rate Limits:** 3 requests/second (10 requests/second with API key)

**Data Processing:**
- Extract PMID, title, abstract, authors, journal
- AI-powered competitive impact analysis
- Brand mention extraction
- Store in OpenSearch `papers` index

### 2. ClinicalTrials.gov

**Endpoint:** `https://clinicaltrials.gov/api/v2/studies`

**Search Expressions:**
```python
expressions = [
    # Brand-specific trials
    "pembrolizumab OR nivolumab OR atezolizumab",
    
    # Phase-specific searches
    "(pembrolizumab OR nivolumab) AND Phase 3",
    
    # Indication-specific
    "immunotherapy AND (oncology OR cancer)",
    
    # Competitive trials
    "biosimilar AND oncology",
    "combination therapy AND cancer"
]
```

**API Parameters:**
- `query.term`: search expression
- `query.locn`: United States
- `filter.overallStatus`: RECRUITING|ACTIVE_NOT_RECRUITING|COMPLETED
- `filter.lastUpdatePostDate`: last 90 days
- `pageSize`: 100
- `format`: json

**Rate Limits:** No official limit, but recommended 1 request/second

**Data Processing:**
- Extract NCT ID, title, phase, status, conditions, interventions
- Competitive impact assessment
- Brand involvement analysis
- Store in OpenSearch `trials` index

### 3. FDA openFDA API

**Endpoints:**
- Drug Events: `https://api.fda.gov/drug/event.json`
- Drug Labels: `https://api.fda.gov/drug/label.json`  
- Drug Approvals: `https://api.fda.gov/drug/drugsfda.json`

**Search Parameters:**
```python
# Adverse Events
params = {
    'search': 'patient.drug.medicinalproduct:"pembrolizumab"',
    'limit': 100
}

# Drug Labels
params = {
    'search': 'openfda.brand_name:"keytruda"',
    'limit': 100
}

# Drug Approvals
params = {
    'search': 'products.brand_name:"opdivo"',
    'limit': 100
}
```

**Rate Limits:** 240 requests/minute (1000 requests/minute with API key)

**Data Processing:**
- Process adverse events, label changes, approvals
- Competitive impact scoring
- Safety signal detection
- Store in OpenSearch `regulatory` index

### 4. European Medicines Agency (EMA)

**Data Sources:**
- Medicine Data: Web scraping of public data
- RSS Feeds: Press releases and announcements
- EPAR Database: European Public Assessment Reports

**Processing:**
- Manual data collection (no public API)
- Focus on EU approvals and regulatory actions
- Competitive impact on EU market

### 5. USPTO Patent Database

**Endpoint:** `https://developer.uspto.gov/ptab-api/trials`

**Search Strategy:**
```python
# Patent searches by brand/molecule
search_terms = [
    "pembrolizumab", "nivolumab", "atezolizumab",
    "PD-1", "PD-L1", "checkpoint inhibitor"
]
```

**Data Processing:**
- Patent applications and grants
- Patent challenges and oppositions
- IP landscape analysis
- Store in OpenSearch `patents` index

### 6. Pharmaceutical News Sources

**Sources:**
- BioPharma Dive API
- FiercePharma RSS
- STAT News API
- Reuters Health API
- Bloomberg Terminal API

**Processing:**
- Sentiment analysis
- Brand mention extraction
- Market impact assessment
- Store in OpenSearch `news` index

### 7. Medical Conference Data

**Conferences Monitored:**
- ASCO (American Society of Clinical Oncology)
- ESMO (European Society for Medical Oncology)
- AACR (American Association for Cancer Research)
- ASH (American Society of Hematology)
- SITC (Society for Immunotherapy of Cancer)

**Data Sources:**
- Abstract databases
- Presentation slides
- Press releases

### 8. SEC Financial Filings

**Endpoint:** `https://www.sec.gov/Archives/edgar/data/`

**Filing Types:**
- 10-K: Annual reports
- 10-Q: Quarterly reports
- 8-K: Current reports
- DEF 14A: Proxy statements

**Companies Monitored:**
- Merck & Co. (Keytruda)
- Bristol Myers Squibb (Opdivo)
- Genentech/Roche (Tecentriq)
- AstraZeneca (Imfinzi)

## Data Quality Metrics

### Completeness Thresholds
- Papers: 85% of required fields (title, abstract, date)
- Trials: 90% of required fields (NCT ID, phase, status)
- Regulatory: 95% of required fields (ID, type, brand)

### Accuracy Validation
- AI-powered content validation using Bedrock Claude
- Brand mention accuracy: 90% threshold
- Date format validation: 100% requirement

### Timeliness Requirements
- Real-time sources: < 2 hours delay
- Daily sources: < 24 hours delay
- Weekly sources: < 7 days delay

### Uniqueness Standards
- Duplicate detection: 98% uniqueness required
- Cross-source deduplication
- Content similarity analysis

## API Key Management

API keys are stored in AWS Secrets Manager:

```bash
# Create secret
aws secretsmanager create-secret \
    --name ci-api-keys \
    --secret-string '{
        "FDA_API_KEY": "your-fda-key",
        "PUBMED_API_KEY": "your-pubmed-key",
        "CLINICALTRIALS_API_KEY": "your-ct-key",
        "NEWS_API_KEY": "your-news-key"
    }'

# Update secret
aws secretsmanager update-secret \
    --secret-id ci-api-keys \
    --secret-string '{...}'
```

## Monitoring and Alerting

### CloudWatch Metrics
- Ingestion success/failure rates
- Processing latency
- Data quality scores
- API rate limit usage

### SNS Alerts
- Data quality threshold breaches
- API failures or rate limiting
- Processing errors
- Critical competitive intelligence

### Dashboard Widgets
- Real-time ingestion status
- Data volume trends
- Quality score trends
- Source availability

## Competitive Intelligence Processing

### AI-Powered Analysis
Each data source is processed through Bedrock Claude for:
- Competitive impact scoring (1-10)
- Brand mention extraction and context
- Strategic implications assessment
- Risk and opportunity identification

### Alert Generation
Automated alerts for:
- High-impact research publications (score > 7)
- Phase III trial completions
- FDA approvals and safety alerts
- Patent expirations and challenges
- Significant market news

### Cross-Source Correlation
- Link related documents across sources
- Identify emerging competitive themes
- Track competitive response patterns
- Generate strategic recommendations

## Deployment and Scaling

### Infrastructure
- Lambda functions for each data source
- EventBridge for scheduling
- OpenSearch for indexing and search
- S3 for raw data storage
- SNS for alerting

### Scaling Considerations
- Auto-scaling Lambda concurrency
- OpenSearch cluster sizing
- S3 lifecycle policies
- Rate limit management

### Cost Optimization
- Efficient API usage patterns
- Data archiving strategies
- Serverless architecture benefits
- Pay-per-use pricing model

## Security and Compliance

### Data Protection
- Encryption at rest and in transit
- VPC isolation for sensitive data
- IAM role-based access control
- Audit logging for all operations

### Compliance Requirements
- GDPR compliance for EU data
- HIPAA considerations for health data
- SOC 2 Type II for enterprise customers
- Data retention policies

### Access Control
- Multi-tenant data isolation
- Role-based permissions
- API authentication and authorization
- Audit trail for all data access

This comprehensive data ingestion pipeline provides pharmaceutical companies with real-time competitive intelligence across all major data sources, enabling data-driven strategic decisions and competitive advantage.