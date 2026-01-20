import json
import boto3
from typing import Dict, Any
from datetime import datetime
from services.opensearch_service import OpenSearchService

class AIHandler:
    def __init__(self):
        self.bedrock = boto3.client('bedrock-runtime')
        self.opensearch = OpenSearchService()
    
    def ask_question(self, request_body: Dict[str, Any]) -> Dict[str, Any]:
        """Process natural language questions about competitive intelligence"""
        try:
            question = request_body.get('question', '')
            context = request_body.get('context', '')
            
            if not question:
                return self._error_response('Question is required')
            
            # Get relevant context from OpenSearch
            context_data = self._get_relevant_context(question)
            
            # Prepare prompt for Bedrock
            prompt = self._build_prompt(question, context_data)
            
            # Call Bedrock Claude model
            response = self.bedrock.invoke_model(
                modelId='anthropic.claude-3-sonnet-20240229-v1:0',
                body=json.dumps({
                    'anthropic_version': 'bedrock-2023-05-31',
                    'max_tokens': 1000,
                    'messages': [
                        {
                            'role': 'user',
                            'content': prompt
                        }
                    ]
                })
            )
            
            # Parse Bedrock response
            response_body = json.loads(response['body'].read())
            ai_answer = response_body['content'][0]['text']
            
            # Extract sources from context
            sources = self._extract_sources(context_data)
            
            # Calculate confidence score based on data availability
            confidence_score = self._calculate_confidence(context_data, question)
            
            # Create insight object
            insight = {
                'id': f'insight-{int(datetime.now().timestamp())}',
                'question': question,
                'answer': ai_answer,
                'sources': sources,
                'confidenceScore': confidence_score,
                'createdAt': datetime.now().isoformat()
            }
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'data': insight,
                    'success': True
                })
            }
            
        except Exception as e:
            return self._error_response(f'AI processing failed: {str(e)}')
    
    def _get_relevant_context(self, question: str) -> Dict[str, Any]:
        """Retrieve relevant data from OpenSearch based on question"""
        try:
            # Extract key terms from question
            key_terms = self._extract_key_terms(question)
            
            context = {}
            
            # Search for relevant brands
            if any(term in question.lower() for term in ['brand', 'drug', 'compare']):
                brand_query = {
                    'query': {
                        'multi_match': {
                            'query': ' '.join(key_terms),
                            'fields': ['name', 'molecule', 'indications']
                        }
                    },
                    'size': 5
                }
                context['brands'] = self.opensearch.search('brands', brand_query)
            
            # Search for clinical trials
            if any(term in question.lower() for term in ['trial', 'phase', 'clinical']):
                trial_query = {
                    'query': {
                        'multi_match': {
                            'query': ' '.join(key_terms),
                            'fields': ['title', 'indication', 'sponsor']
                        }
                    },
                    'size': 10
                }
                context['trials'] = self.opensearch.search('trials', trial_query)
            
            # Search for recent alerts
            if any(term in question.lower() for term in ['alert', 'news', 'recent', 'update']):
                alert_query = {
                    'query': {
                        'bool': {
                            'must': [
                                {
                                    'multi_match': {
                                        'query': ' '.join(key_terms),
                                        'fields': ['title', 'description', 'brandImpacted']
                                    }
                                }
                            ],
                            'filter': [
                                {
                                    'range': {
                                        'createdAt': {
                                            'gte': 'now-30d'
                                        }
                                    }
                                }
                            ]
                        }
                    },
                    'size': 5
                }
                context['alerts'] = self.opensearch.search('alerts', alert_query)
            
            return context
            
        except Exception as e:
            return {}
    
    def _extract_key_terms(self, question: str) -> list:
        """Extract key pharmaceutical terms from question"""
        # Simple keyword extraction - in production, use NLP
        pharma_terms = [
            'keytruda', 'opdivo', 'tecentriq', 'imfinzi',
            'pembrolizumab', 'nivolumab', 'atezolizumab',
            'melanoma', 'lung cancer', 'oncology', 'immunotherapy',
            'phase i', 'phase ii', 'phase iii', 'fda', 'approval'
        ]
        
        question_lower = question.lower()
        found_terms = [term for term in pharma_terms if term in question_lower]
        
        # Add general terms
        words = question_lower.split()
        key_words = [word for word in words if len(word) > 3 and word not in ['what', 'when', 'where', 'which', 'compare']]
        
        return found_terms + key_words[:5]  # Limit to avoid too broad search
    
    def _build_prompt(self, question: str, context_data: Dict[str, Any]) -> str:
        """Build prompt for Bedrock with context"""
        prompt = f"""You are a pharmaceutical competitive intelligence expert. Answer the following question based on the provided data context.

Question: {question}

Context Data:
"""
        
        # Add brand context
        if 'brands' in context_data:
            prompt += "\nBrand Information:\n"
            for hit in context_data['brands'].get('hits', {}).get('hits', [])[:3]:
                brand = hit['_source']
                prompt += f"- {brand.get('name', 'Unknown')}: {brand.get('molecule', 'Unknown')} by {brand.get('manufacturer', 'Unknown')}\n"
        
        # Add trial context
        if 'trials' in context_data:
            prompt += "\nClinical Trials:\n"
            for hit in context_data['trials'].get('hits', {}).get('hits', [])[:5]:
                trial = hit['_source']
                prompt += f"- {trial.get('title', 'Unknown')}: {trial.get('phase', 'Unknown')} - {trial.get('status', 'Unknown')}\n"
        
        # Add alert context
        if 'alerts' in context_data:
            prompt += "\nRecent Alerts:\n"
            for hit in context_data['alerts'].get('hits', {}).get('hits', [])[:3]:
                alert = hit['_source']
                prompt += f"- {alert.get('title', 'Unknown')}: {alert.get('description', 'Unknown')}\n"
        
        prompt += """

Instructions:
1. Provide a comprehensive answer based on the context data
2. Be specific about competitive positioning and market dynamics
3. Include quantitative insights when available
4. Mention any limitations in the data
5. Keep the response professional and actionable for pharmaceutical executives
6. Do not make up information not present in the context

Answer:"""
        
        return prompt
    
    def _extract_sources(self, context_data: Dict[str, Any]) -> list:
        """Extract source citations from context data"""
        sources = []
        
        if 'brands' in context_data and context_data['brands'].get('hits', {}).get('hits'):
            sources.append('Brand Database')
        
        if 'trials' in context_data and context_data['trials'].get('hits', {}).get('hits'):
            sources.append('ClinicalTrials.gov')
        
        if 'alerts' in context_data and context_data['alerts'].get('hits', {}).get('hits'):
            sources.extend(['FDA Database', 'Patent Database', 'News Sources'])
        
        # Default sources
        if not sources:
            sources = ['Pharmaceutical Intelligence Database']
        
        return list(set(sources))  # Remove duplicates
    
    def _calculate_confidence(self, context_data: Dict[str, Any], question: str) -> int:
        """Calculate confidence score based on available data"""
        base_confidence = 60
        
        # Increase confidence based on available data
        if 'brands' in context_data:
            brand_hits = len(context_data['brands'].get('hits', {}).get('hits', []))
            base_confidence += min(brand_hits * 5, 20)
        
        if 'trials' in context_data:
            trial_hits = len(context_data['trials'].get('hits', {}).get('hits', []))
            base_confidence += min(trial_hits * 2, 15)
        
        if 'alerts' in context_data:
            alert_hits = len(context_data['alerts'].get('hits', {}).get('hits', []))
            base_confidence += min(alert_hits * 3, 15)
        
        # Adjust based on question specificity
        if any(term in question.lower() for term in ['specific', 'exact', 'precise']):
            base_confidence -= 10
        
        return min(max(base_confidence, 50), 95)  # Keep between 50-95%
    
    def _error_response(self, message: str) -> Dict[str, Any]:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'message': message
            })
        }