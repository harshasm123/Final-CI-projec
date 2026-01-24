import json
import boto3
import os
from datetime import datetime
from typing import Dict, List, Any, Optional
from opensearchpy import OpenSearch, RequestsHttpConnection
from aws_requests_auth.aws_auth import AWSRequestsAuth

class EnhancedAIHandler:
    def __init__(self):
        self.bedrock_client = boto3.client('bedrock-runtime')
        self.dynamodb = boto3.resource('dynamodb')
        self.s3_client = boto3.client('s3')
        
        # Environment variables
        self.conversation_table_name = os.environ.get('CONVERSATION_TABLE')
        self.knowledge_bucket = os.environ.get('KNOWLEDGE_BUCKET')
        self.opensearch_endpoint = os.environ.get('OPENSEARCH_ENDPOINT')
        
        # Initialize conversation table
        if self.conversation_table_name:
            self.conversation_table = self.dynamodb.Table(self.conversation_table_name)
        
        # Initialize OpenSearch client
        if self.opensearch_endpoint:
            host = self.opensearch_endpoint.replace('https://', '')
            region = os.environ.get('AWS_REGION', 'us-east-1')
            credentials = boto3.Session().get_credentials()
            awsauth = AWSRequestsAuth(credentials, region, 'es')
            
            self.opensearch_client = OpenSearch(
                hosts=[{'host': host, 'port': 443}],
                http_auth=awsauth,
                use_ssl=True,
                verify_certs=True,
                connection_class=RequestsHttpConnection
            )
    
    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Main Lambda handler for AI chatbot"""
        try:
            # Parse request
            body = json.loads(event.get('body', '{}'))
            user_message = body.get('message', '')
            conversation_id = body.get('conversationId', f"conv_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
            user_id = body.get('userId', 'anonymous')
            
            if not user_message:
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'error': 'Message is required'})
                }
            
            # Get conversation history
            conversation_history = self.get_conversation_history(conversation_id)
            
            # Perform RAG search
            relevant_context = self.search_knowledge_base(user_message)
            
            # Generate AI response
            ai_response = self.generate_ai_response(
                user_message, 
                conversation_history, 
                relevant_context
            )
            
            # Save conversation
            self.save_conversation_turn(
                conversation_id, 
                user_id, 
                user_message, 
                ai_response
            )
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                },
                'body': json.dumps({
                    'response': ai_response,
                    'conversationId': conversation_id,
                    'timestamp': datetime.now().isoformat()
                })
            }
            
        except Exception as e:
            print(f"Error in AI handler: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Internal server error'})
            }
    
    def search_knowledge_base(self, query: str, max_results: int = 5) -> List[Dict[str, Any]]:
        """Search knowledge base using OpenSearch"""
        try:
            if not hasattr(self, 'opensearch_client'):
                return []
            
            # Enhanced search query
            search_body = {
                "query": {
                    "bool": {
                        "should": [
                            {
                                "multi_match": {
                                    "query": query,
                                    "fields": ["content^2", "title^3", "abstract^2"],
                                    "type": "best_fields",
                                    "fuzziness": "AUTO"
                                }
                            },
                            {
                                "match": {
                                    "brandsmentioned": {
                                        "query": query,
                                        "boost": 1.5
                                    }
                                }
                            }
                        ],
                        "minimum_should_match": 1
                    }
                },
                "highlight": {
                    "fields": {
                        "content": {},
                        "title": {},
                        "abstract": {}
                    }
                },
                "size": max_results,
                "_source": [
                    "title", "content", "abstract", "source", 
                    "brandsmentioned", "competitiveInsights", "documentType"
                ]
            }
            
            # Search across all indices
            indices = ["pharma-ci-*", "papers", "trials", "regulatory"]
            
            results = []
            for index in indices:
                try:
                    response = self.opensearch_client.search(
                        index=index,
                        body=search_body
                    )
                    
                    for hit in response['hits']['hits']:
                        source = hit['_source']
                        highlights = hit.get('highlight', {})
                        
                        result = {
                            'id': hit['_id'],
                            'score': hit['_score'],
                            'source': source.get('source', ''),
                            'documentType': source.get('documentType', ''),
                            'title': source.get('title', ''),
                            'content': source.get('content', '')[:500],  # Limit content
                            'abstract': source.get('abstract', '')[:300],
                            'brandsmentioned': source.get('brandsmentioned', []),
                            'highlights': highlights
                        }
                        results.append(result)
                        
                except Exception as e:
                    print(f"Error searching index {index}: {str(e)}")
                    continue
            
            # Sort by relevance score and return top results
            results.sort(key=lambda x: x['score'], reverse=True)
            return results[:max_results]
            
        except Exception as e:
            print(f"Error in knowledge base search: {str(e)}")
            return []
    
    def generate_ai_response(
        self, 
        user_message: str, 
        conversation_history: List[Dict], 
        context: List[Dict]
    ) -> str:
        """Generate AI response using Bedrock Claude"""
        try:
            # Build context from search results
            context_text = ""
            if context:
                context_text = "\\n\\nRelevant information from pharmaceutical database:\\n"
                for item in context:
                    context_text += f"- {item.get('title', 'N/A')}: {item.get('content', '')[:200]}...\\n"
                    if item.get('brandsmentioned'):
                        context_text += f"  Brands mentioned: {', '.join(item['brandsmentioned'])}\\n"
            
            # Build conversation history
            history_text = ""
            if conversation_history:
                history_text = "\\n\\nConversation history:\\n"
                for turn in conversation_history[-3:]:  # Last 3 turns
                    history_text += f"User: {turn.get('user_message', '')}\\n"
                    history_text += f"Assistant: {turn.get('ai_response', '')}\\n"
            
            # Create comprehensive prompt
            system_prompt = """You are an expert pharmaceutical competitive intelligence analyst. 
            You help users understand market dynamics, competitive landscapes, clinical trials, 
            regulatory developments, and strategic insights in the pharmaceutical industry.
            
            Key capabilities:
            - Analyze clinical trial data and competitive implications
            - Interpret FDA regulatory information
            - Assess market opportunities and threats
            - Provide strategic recommendations
            - Explain complex pharmaceutical concepts clearly
            
            Always provide accurate, evidence-based responses using the provided context.
            If you don't have sufficient information, clearly state the limitations."""
            
            user_prompt = f"""
            {system_prompt}
            
            User question: {user_message}
            {context_text}
            {history_text}
            
            Please provide a comprehensive, professional response that addresses the user's question 
            using the available pharmaceutical intelligence data. Include specific insights, 
            competitive implications, and actionable recommendations where appropriate.
            """
            
            # Call Bedrock Claude
            response = self.bedrock_client.invoke_model(
                modelId='anthropic.claude-3-sonnet-20240229-v1:0',
                body=json.dumps({
                    'anthropic_version': 'bedrock-2023-05-31',
                    'max_tokens': 1000,
                    'temperature': 0.7,
                    'messages': [
                        {
                            'role': 'user',
                            'content': user_prompt
                        }
                    ]
                })
            )
            
            response_body = json.loads(response['body'].read())
            ai_response = response_body['content'][0]['text']
            
            return ai_response
            
        except Exception as e:
            print(f"Error generating AI response: {str(e)}")
            return "I apologize, but I'm experiencing technical difficulties. Please try again later."
    
    def get_conversation_history(self, conversation_id: str) -> List[Dict[str, Any]]:
        """Retrieve conversation history from DynamoDB"""
        try:
            if not hasattr(self, 'conversation_table'):
                return []
            
            response = self.conversation_table.query(
                KeyConditionExpression='conversationId = :conv_id',
                ExpressionAttributeValues={':conv_id': conversation_id},
                ScanIndexForward=True,  # Sort by timestamp ascending
                Limit=10  # Last 10 turns
            )
            
            return response.get('Items', [])
            
        except Exception as e:
            print(f"Error retrieving conversation history: {str(e)}")
            return []
    
    def save_conversation_turn(
        self, 
        conversation_id: str, 
        user_id: str, 
        user_message: str, 
        ai_response: str
    ) -> None:
        """Save conversation turn to DynamoDB"""
        try:
            if not hasattr(self, 'conversation_table'):
                return
            
            timestamp = int(datetime.now().timestamp() * 1000)
            
            self.conversation_table.put_item(
                Item={
                    'conversationId': conversation_id,
                    'timestamp': timestamp,
                    'userId': user_id,
                    'user_message': user_message,
                    'ai_response': ai_response,
                    'created_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            print(f"Error saving conversation: {str(e)}")
    
    def analyze_competitive_landscape(self, query: str) -> Dict[str, Any]:
        """Specialized competitive landscape analysis"""
        try:
            # Search for competitive intelligence
            competitive_data = self.search_knowledge_base(
                f"competitive analysis {query}", 
                max_results=10
            )
            
            # Extract brands and competitive insights
            brands_mentioned = set()
            key_insights = []
            
            for item in competitive_data:
                if item.get('brandsmentioned'):
                    brands_mentioned.update(item['brandsmentioned'])
                
                if item.get('competitiveInsights'):
                    key_insights.append(item['competitiveInsights'])
            
            return {
                'brands_in_landscape': list(brands_mentioned),
                'key_insights': key_insights,
                'data_sources': len(competitive_data),
                'analysis_timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Error in competitive analysis: {str(e)}")
            return {}
    
    def get_clinical_trial_insights(self, indication: str) -> Dict[str, Any]:
        """Get clinical trial insights for specific indication"""
        try:
            # Search clinical trials
            trial_data = self.search_knowledge_base(
                f"clinical trial {indication}",
                max_results=15
            )
            
            # Filter for clinical trial documents
            trials = [item for item in trial_data if item.get('documentType') == 'clinical_trial']
            
            # Analyze trial phases, sponsors, etc.
            phases = {}
            sponsors = {}
            
            for trial in trials:
                # Extract phase information (would need to parse from content)
                # Extract sponsor information
                pass
            
            return {
                'total_trials': len(trials),
                'phase_distribution': phases,
                'top_sponsors': sponsors,
                'indication': indication
            }
            
        except Exception as e:
            print(f"Error getting trial insights: {str(e)}")
            return {}

def lambda_handler(event, context):
    """Lambda entry point"""
    handler = EnhancedAIHandler()
    return handler.lambda_handler(event, context)