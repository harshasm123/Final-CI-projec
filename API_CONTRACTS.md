# API Contracts for Pharmaceutical CI Platform

## Base URL
```
https://api.pharma-ci.com/v1
```

## Authentication
All endpoints require Bearer token authentication:
```
Authorization: Bearer <jwt_token>
```

## Dashboard Endpoints

### GET /dashboard/kpis
Returns key performance indicators for dashboard.

**Response:**
```json
{
  "data": {
    "brandsTracked": 47,
    "competitorsMonitored": 156,
    "criticalAlerts": 3,
    "regulatoryEvents": 12
  },
  "success": true
}
```

### GET /dashboard/trends?timeRange=30d
Returns trend data for specified time range.

**Response:**
```json
{
  "data": [
    {
      "date": "2024-01-01",
      "brand": "Keytruda",
      "activity": 85
    }
  ],
  "success": true
}
```

## Brand Intelligence Endpoints

### GET /brands/search?q={query}
Search brands by name or molecule.

**Parameters:**
- `q` (string): Search query (brand name or molecule)

**Response:**
```json
{
  "data": [
    {
      "brand": {
        "id": "keytruda-1",
        "name": "Keytruda",
        "molecule": "Pembrolizumab",
        "manufacturer": "Merck & Co.",
        "indications": ["Melanoma", "Lung Cancer"],
        "competitors": ["Opdivo", "Tecentriq"],
        "riskScore": 75,
        "lastUpdated": "2024-01-15T10:30:00Z"
      },
      "relevanceScore": 95.2
    }
  ],
  "success": true
}
```

### GET /brands/{brandId}
Get detailed brand information.

**Response:**
```json
{
  "data": {
    "id": "keytruda-1",
    "name": "Keytruda",
    "molecule": "Pembrolizumab",
    "manufacturer": "Merck & Co.",
    "indications": ["Melanoma", "Lung Cancer", "Head and Neck Cancer"],
    "competitors": ["Opdivo", "Tecentriq", "Imfinzi"],
    "riskScore": 75,
    "lastUpdated": "2024-01-15T10:30:00Z"
  },
  "success": true
}
```

### GET /brands/{brandId}/competitive-landscape
Get competitive landscape data for a brand.

**Response:**
```json
{
  "data": [
    {
      "brand": "Keytruda",
      "molecule": "Pembrolizumab",
      "indication": "Melanoma",
      "trialPhase": "Phase III",
      "trialCount": 847,
      "recentApproval": "2024-01-10",
      "riskScore": 75
    }
  ],
  "success": true
}
```

## Clinical Trials Endpoints

### GET /brands/{brandId}/trials
Get clinical trials for a specific brand.

**Response:**
```json
{
  "data": [
    {
      "id": "trial-123",
      "title": "Phase III Study of Pembrolizumab in Melanoma",
      "phase": "Phase III",
      "status": "Active",
      "indication": "Melanoma",
      "sponsor": "Merck & Co.",
      "startDate": "2023-06-01",
      "estimatedCompletion": "2025-12-31",
      "participantCount": 450
    }
  ],
  "success": true
}
```

## Alerts Endpoints

### GET /alerts
Get alerts with optional filtering.

**Query Parameters:**
- `brand` (string): Filter by brand name
- `source` (string): Filter by source (FDA, EMA, Trials, Patents, News)
- `severity` (string): Filter by severity (critical, high, medium, low)
- `startDate` (string): Filter by date range start
- `endDate` (string): Filter by date range end

**Response:**
```json
{
  "data": [
    {
      "id": "alert-1",
      "title": "FDA Approves Competitor Drug for Same Indication",
      "severity": "critical",
      "source": "FDA",
      "brandImpacted": ["Keytruda"],
      "description": "FDA has approved a new PD-1 inhibitor...",
      "whyItMatters": "This approval creates direct competition...",
      "createdAt": "2024-01-15T08:30:00Z",
      "confidenceScore": 95
    }
  ],
  "success": true
}
```

## AI Insights Endpoints

### POST /ai/insights
Ask natural language questions about competitive intelligence.

**Request Body:**
```json
{
  "question": "Compare Keytruda vs Opdivo in oncology market share",
  "context": "brand-keytruda-1"
}
```

**Response:**
```json
{
  "data": {
    "id": "insight-123",
    "question": "Compare Keytruda vs Opdivo in oncology market share",
    "answer": "Keytruda maintains market leadership...",
    "sources": ["ClinicalTrials.gov", "FDA Database", "PubMed"],
    "confidenceScore": 87,
    "createdAt": "2024-01-15T10:30:00Z"
  },
  "success": true
}
```

## Error Responses

All endpoints return errors in this format:
```json
{
  "success": false,
  "message": "Error description",
  "code": "ERROR_CODE"
}
```

## Rate Limits
- 1000 requests per hour per user
- 100 AI insight requests per hour per user

## Pagination
List endpoints support pagination:
```
GET /alerts?page=1&limit=20
```

Response includes pagination metadata:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  },
  "success": true
}
```