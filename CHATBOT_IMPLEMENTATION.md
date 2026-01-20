# Interactive Chatbot for CI Analysis - Implementation Guide

## Overview

The Interactive Chatbot is an AI-powered assistant that helps pharmaceutical CI analysts understand competitive landscapes, market dynamics, and strategic implications. It combines Bedrock Claude models with Bedrock Agents for intelligent, context-aware analysis.

## Architecture

```
Frontend (Chat UI)
    ↓
API Gateway (/chat endpoint)
    ↓
Chatbot Handler Lambda
    ↓
┌─────────────────────────────────────┐
│  Bedrock Claude 3 Sonnet            │ (Direct chat)
│  Bedrock Agent Runtime              │ (Complex analysis)
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  OpenSearch (Data retrieval)         │
│  DynamoDB (Conversation history)     │
│  S3 (Analysis storage)               │
└─────────────────────────────────────┘
```

## Components

### 1. Chatbot Handler Lambda (`ci-chatbot-handler`)

**Function**: `backend/src/handlers/chatbot_handler.py`

**Capabilities**:
- **Chat**: Interactive conversations with context awareness
- **Agent Analysis**: Complex multi-step analysis using Bedrock Agents
- **Session Management**: Conversation tracking and history
- **Insight Extraction**: Automatic extraction of key insights and recommendations

**Environment Variables**:
- `OPENSEARCH_ENDPOINT`: OpenSearch domain endpoint
- `METADATA_BUCKET`: S3 bucket for metadata
- `CONVERSATION_TABLE`: DynamoDB table for conversations
- `BEDROCK_AGENT_ID`: Bedrock Agent ID
- `BEDROCK_AGENT_ALIAS_ID`: Bedrock Agent Alias ID
- `ENVIRONMENT`: Deployment environment

**Timeout**: 120 seconds
**Memory**: 2048 MB

### 2. Agent Tools Lambda (`ci-agent-tools`)

**Function**: `backend/src/handlers/agent_tools.py`

**Provides Tools for Agent**:
- **Data Retrieval**:
  - Brand search
  - Clinical trial search
  - Competitive landscape retrieval
  - Alert retrieval

- **Analysis**:
  - Competitive position analysis
  - Market opportunity analysis
  - Threat assessment

### 3. Bedrock Agent Configuration

**File**: `backend/bedrock-agent-config.yaml`

**Agent Details**:
- **Model**: Claude 3 Sonnet
- **Name**: `ci-analysis-agent-{environment}`
- **Session TTL**: 900 seconds
- **Auto Prepare**: Enabled

**Action Groups**:
1. **DataRetrieval**: Access to CI data sources
2. **Analysis**: Perform competitive analysis

### 4. DynamoDB Conversation Table

**Table**: `ci-chatbot-conversations-{environment}`

**Schema**:
- **Partition Key**: `conversationId` (String)
- **Sort Key**: `createdAt` (String)
- **GSI**: `UserIdIndex` (userId + createdAt)
- **TTL**: 24 hours

**Attributes**:
- `conversationId`: Unique conversation identifier
- `userId`: User identifier
- `metadata`: Session metadata
- `createdAt`: Creation timestamp
- `ttl`: Time-to-live for auto-deletion

## API Endpoints

### 1. Start Conversation Session

**Endpoint**: `POST /chat/session`

**Request**:
```json
{
  "action": "start_session",
  "userId": "analyst-123",
  "context": {
    "brand": "Keytruda",
    "competitors": ["Opdivo", "Tecentriq"],
    "indication": "Melanoma",
    "timeframe": "last 90 days"
  }
}
```

**Response**:
```json
{
  "conversationId": "uuid-123",
  "message": "Conversation session started. How can I help you with your competitive intelligence analysis?",
  "success": true
}
```

### 2. Chat Message

**Endpoint**: `POST /chat/message`

**Request**:
```json
{
  "action": "chat",
  "conversationId": "uuid-123",
  "userId": "analyst-123",
  "message": "What are the key competitive threats to Keytruda in the melanoma market?",
  "context": {
    "brand": "Keytruda",
    "competitors": ["Opdivo", "Tecentriq"]
  }
}
```

**Response**:
```json
{
  "conversationId": "uuid-123",
  "message": "Based on recent data, Keytruda faces several competitive threats...",
  "insights": [
    "Opdivo has 3 new Phase III trials in melanoma",
    "Tecentriq approval rate increased 25% YoY",
    "Market share pressure from generic alternatives"
  ],
  "recommendations": [
    "Monitor Opdivo trial progression closely",
    "Analyze pricing strategy vs competitors",
    "Track regulatory developments"
  ],
  "success": true
}
```

### 3. Agent Analysis

**Endpoint**: `POST /chat/analyze`

**Request**:
```json
{
  "action": "analyze_with_agent",
  "conversationId": "uuid-123",
  "userId": "analyst-123",
  "query": "Perform a comprehensive competitive analysis of Keytruda vs Opdivo in the oncology market",
  "analysisType": "competitive"
}
```

**Response**:
```json
{
  "conversationId": "uuid-123",
  "analysis": "Comprehensive analysis results...",
  "results": {
    "summary": "Keytruda maintains market leadership...",
    "fullAnalysis": "Detailed analysis...",
    "extractedAt": "2024-01-15T10:30:00Z"
  },
  "success": true
}
```

### 4. Get Conversation History

**Endpoint**: `GET /chat/history/{conversationId}`

**Query Parameters**:
- `limit`: Number of messages to retrieve (default: 50)

**Response**:
```json
{
  "conversationId": "uuid-123",
  "messages": [
    {
      "timestamp": "2024-01-15T10:00:00Z",
      "role": "user",
      "content": "What are the key competitive threats?",
      "aiResponse": "Based on recent data...",
      "insights": ["Threat 1", "Threat 2"]
    }
  ],
  "success": true
}
```

## Chatbot Capabilities

### 1. Competitive Intelligence Analysis
- Brand positioning analysis
- Competitor tracking
- Market share analysis
- Threat assessment
- Opportunity identification

### 2. Clinical Trial Analysis
- Trial phase distribution
- Sponsor analysis
- Indication-specific insights
- Trial progression tracking

### 3. Regulatory Intelligence
- FDA approval tracking
- Regulatory alert analysis
- Compliance monitoring
- Market impact assessment

### 4. Strategic Recommendations
- Competitive positioning strategies
- Market entry/exit recommendations
- Risk mitigation strategies
- Growth opportunity identification

### 5. Data-Driven Insights
- Confidence scoring
- Source citation
- Trend analysis
- Historical comparison

## System Prompt

The chatbot operates with a specialized system prompt that:

1. **Establishes Expertise**: Positions as pharmaceutical CI expert
2. **Defines Capabilities**: Lists available analysis types
3. **Sets Guidelines**: Ensures data-driven, professional responses
4. **Provides Context**: Includes brand, competitor, and indication information
5. **Ensures Quality**: Requires actionable, executive-level insights

## Conversation Flow

```
1. User starts session
   ↓
2. Chatbot provides welcome message
   ↓
3. User asks question
   ↓
4. Chatbot retrieves relevant data
   ↓
5. Chatbot generates response with insights
   ↓
6. Conversation stored in DynamoDB
   ↓
7. User can continue conversation or request agent analysis
   ↓
8. Agent performs complex multi-step analysis if needed
```

## Integration with Existing Components

### With Phase 3 Components
- Uses OpenSearch for data retrieval
- Leverages existing handlers (brand, alert, competitive analysis)
- Integrates with data quality checks
- Accesses AI insights from AI handler

### With Frontend
- Provides chat interface via API Gateway
- Supports real-time conversation
- Displays insights and recommendations
- Shows conversation history

### With Bedrock
- Uses Claude 3 Sonnet for chat
- Uses Bedrock Agent for complex analysis
- Supports multi-turn conversations
- Maintains conversation context

## Deployment

### Prerequisites
1. Bedrock access enabled
2. Claude 3 Sonnet model available
3. OpenSearch domain configured
4. DynamoDB table created
5. S3 buckets for storage

### CloudFormation Deployment

**Step 1: Deploy Main Stack**
```bash
aws cloudformation create-stack \
  --stack-name ci-alert-main \
  --template-body file://architecture.yaml \
  --parameters ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_IAM
```

**Step 2: Deploy Bedrock Agent**
```bash
aws cloudformation create-stack \
  --stack-name ci-bedrock-agent \
  --template-body file://backend/bedrock-agent-config.yaml \
  --parameters ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_IAM
```

**Step 3: Get Agent IDs**
```bash
aws cloudformation describe-stacks \
  --stack-name ci-bedrock-agent \
  --query 'Stacks[0].Outputs'
```

**Step 4: Update EventBridge Rules**
```bash
aws cloudformation update-stack \
  --stack-name ci-alert-eventbridge \
  --template-body file://eventbridge-rules.yaml \
  --parameters \
    ParameterKey=BedrockAgentId,ParameterValue=<agent-id> \
    ParameterKey=BedrockAgentAliasId,ParameterValue=<alias-id>
```

## Performance Characteristics

| Metric | Value |
|--------|-------|
| Chat Response Time | 5-15 seconds |
| Agent Analysis Time | 30-60 seconds |
| Conversation History Retrieval | <1 second |
| Session Creation | <500ms |
| Max Concurrent Conversations | 1000+ |

## Monitoring & Logging

### CloudWatch Metrics
- Chat request count
- Average response time
- Error rate
- Agent invocation count
- Conversation duration

### CloudWatch Logs
- Chat interactions
- Agent analysis results
- Error messages
- Performance metrics

### DynamoDB Monitoring
- Conversation table size
- Read/write capacity
- Query performance
- TTL cleanup

## Security Considerations

1. **Authentication**: Implement API Gateway authentication
2. **Authorization**: Validate user access to brands/data
3. **Data Privacy**: Encrypt conversations in transit and at rest
4. **Rate Limiting**: Implement per-user rate limits
5. **Audit Logging**: Track all chatbot interactions

## Future Enhancements

1. **Multi-Language Support**: Support for multiple languages
2. **Custom Models**: Integration with custom ML models
3. **Real-time Streaming**: WebSocket support for real-time chat
4. **Advanced Analytics**: Conversation analytics and insights
5. **Knowledge Base**: Integration with external knowledge bases
6. **Sentiment Analysis**: Analyze user sentiment and satisfaction
7. **Recommendation Engine**: Personalized recommendations based on history
8. **Export Capabilities**: Export analysis results in multiple formats

## Troubleshooting

### Common Issues

**Issue**: Chatbot not responding
- Check Bedrock model availability
- Verify OpenSearch connectivity
- Check Lambda execution role permissions

**Issue**: Agent analysis failing
- Verify Bedrock Agent ID and Alias ID
- Check agent action group configuration
- Review agent tools Lambda permissions

**Issue**: Conversation history not loading
- Verify DynamoDB table exists
- Check table permissions
- Verify conversation ID format

**Issue**: Slow response times
- Check OpenSearch query performance
- Monitor Lambda memory usage
- Review Bedrock model latency

## Support & Documentation

- Bedrock Documentation: https://docs.aws.amazon.com/bedrock/
- Claude API Guide: https://docs.anthropic.com/
- OpenSearch Documentation: https://opensearch.org/docs/
- DynamoDB Guide: https://docs.aws.amazon.com/dynamodb/
