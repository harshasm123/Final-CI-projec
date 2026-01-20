import json
import boto3
from typing import Dict, Any
from datetime import datetime
from services.opensearch_service import OpenSearchService

class EnhancedAIHandler:
    def __init__(self):
        self.bedrock_agent = boto3.client('bedrock-agent-runtime')
        self.bedrock = boto3.client('bedrock-runtime')
        self.opensearch = OpenSearchService()
        
        # Get agent configuration from environment
        self.agent_id = os.environ.get('BEDROCK_AGENT_ID', '')
        self.agent_alias_id = os.environ.get('BEDROCK_AGENT_ALIAS_ID', 'TSTALIASID')
    
    def ask_question(self, request_body: Dict[str, Any]) -> Dict[str, Any]:
        """Process natural language questions using Bedrock Agent"""
        try:
            question = request_body.get('question', '')
            session_id = request_body.get('sessionId', f'session-{int(datetime.now().timestamp())}')
            
            if not question:
                return self._error_response('Question is required')
            
            # Use Bedrock Agent for enhanced CI analysis
            if self.agent_id:
                return self._invoke_bedrock_agent(question, session_id)
            else:
                # Fallback to direct Bedrock model
                return self._invoke_direct_bedrock(question)
                
        except Exception as e:
            return self._error_response(f'AI processing failed: {str(e)}')
    
    def _invoke_bedrock_agent(self, question: str, session_id: str) -> Dict[str, Any]:
        """Invoke Bedrock Agent for CI analysis"""
        try:
            # Invoke the CI Analysis Agent
            response = self.bedrock_agent.invoke_agent(
                agentId=self.agent_id,
                agentAliasId=self.agent_alias_id,
                sessionId=session_id,
                inputText=question
            )
            
            # Process streaming response
            agent_response = ""
            citations = []
            
            for event in response['completion']:
                if 'chunk' in event:
                    chunk = event['chunk']
                    if 'bytes' in chunk:
                        agent_response += chunk['bytes'].decode('utf-8')
                elif 'trace' in event:
                    # Extract citations and sources from trace
                    trace = event['trace']
                    if 'orchestrationTrace' in trace:
                        orch_trace = trace['orchestrationTrace']
                        if 'observation' in orch_trace:
                            observation = orch_trace['observation']
                            if 'knowledgeBaseLookupOutput' in observation:
                                kb_output = observation['knowledgeBaseLookupOutput']
                                for retrieved_ref in kb_output.get('retrievedReferences', []):
                                    citations.append({
                                        'source': retrieved_ref.get('location', {}).get('s3Location', {}).get('uri', ''),
                                        'content': retrieved_ref.get('content', {}).get('text', '')[:200] + '...'
                                    })
            
            # Calculate confidence score based on agent response quality
            confidence_score = self._calculate_agent_confidence(agent_response, citations)
            
            # Create insight object
            insight = {
                'id': f'agent-insight-{int(datetime.now().timestamp())}',
                'question': question,
                'answer': agent_response,
                'sources': [citation['source'] for citation in citations] or ['CI Analysis Agent', 'Knowledge Base'],
                'citations': citations,
                'confidenceScore': confidence_score,
                'sessionId': session_id,
                'agentUsed': True,
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
            print(f"Bedrock Agent error: {str(e)}")
            # Fallback to direct model
            return self._invoke_direct_bedrock(question)
    
    def _invoke_direct_bedrock(self, question: str) -> Dict[str, Any]:
        """Fallback to direct Bedrock model invocation"""
        try:
            # Get relevant context from OpenSearch
            context_data = self._get_relevant_context(question)
            
            # Build enhanced prompt for CI analysis
            prompt = self._build_ci_analysis_prompt(question, context_data)
            
            # Call Bedrock Claude model
            response = self.bedrock.invoke_model(
                modelId='anthropic.claude-3-sonnet-20240229-v1:0',
                body=json.dumps({
                    'anthropic_version': 'bedrock-2023-05-31',
                    'max_tokens': 1500,
                    'messages': [
                        {
                            'role': 'user',
                            'content': prompt
                        }
                    ]
                })
            )
            
            # Parse response
            response_body = json.loads(response['body'].read())
            ai_answer = response_body['content'][0]['text']
            
            # Extract sources and calculate confidence
            sources = self._extract_sources(context_data)
            confidence_score = self._calculate_confidence(context_data, question)
            
            insight = {
                'id': f'insight-{int(datetime.now().timestamp())}',
                'question': question,
                'answer': ai_answer,
                'sources': sources,
                'confidenceScore': confidence_score,
                'agentUsed': False,
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
            return self._error_response(f'Direct Bedrock invocation failed: {str(e)}')
    
    def _build_ci_analysis_prompt(self, question: str, context_data: Dict[str, Any]) -> str:
        """Build specialized CI analysis prompt"""
        prompt = f"""You are a senior pharmaceutical competitive intelligence analyst with 15+ years of experience. 

Analyze the following question using the provided competitive intelligence data:

QUESTION: {question}

COMPETITIVE INTELLIGENCE DATA:
"""
        
        # Add structured context
        if 'brands' in context_data:
            prompt += "\n=== BRAND INTELLIGENCE ===\n"
            for hit in context_data['brands'].get('hits', {}).get('hits', [])[:3]:
                brand = hit['_source']
                prompt += f"""
Brand: {brand.get('name', 'Unknown')}
Molecule: {brand.get('molecule', 'Unknown')}
Manufacturer: {brand.get('manufacturer', 'Unknown')}
Market Position: Risk Score {brand.get('riskScore', 'Unknown')}/100
Key Indications: {', '.join(brand.get('indications', [])[:3])}
Main Competitors: {', '.join(brand.get('competitors', [])[:3])}
"""
        
        if 'trials' in context_data:
            prompt += "\n=== CLINICAL TRIALS INTELLIGENCE ===\n"
            for hit in context_data['trials'].get('hits', {}).get('hits', [])[:5]:
                trial = hit['_source']
                prompt += f"""
Trial: {trial.get('title', 'Unknown')[:100]}...
Phase: {trial.get('phase', 'Unknown')}
Status: {trial.get('status', 'Unknown')}
Sponsor: {trial.get('sponsor', 'Unknown')}
Indication: {trial.get('indication', 'Unknown')}
"""
        
        if 'alerts' in context_data:
            prompt += "\n=== RECENT COMPETITIVE ALERTS ===\n"
            for hit in context_data['alerts'].get('hits', {}).get('hits', [])[:3]:
                alert = hit['_source']
                prompt += f"""
Alert: {alert.get('title', 'Unknown')}
Severity: {alert.get('severity', 'Unknown')}
Brands Impacted: {', '.join(alert.get('brandImpacted', []))}
Impact: {alert.get('whyItMatters', 'Unknown')[:150]}...
"""
        
        prompt += """

ANALYSIS FRAMEWORK:
1. COMPETITIVE POSITIONING: Assess market position and competitive dynamics
2. STRATEGIC IMPLICATIONS: Identify key strategic implications and opportunities
3. RISK ASSESSMENT: Evaluate competitive threats and market risks
4. QUANTITATIVE INSIGHTS: Provide data-driven metrics and projections where possible
5. ACTIONABLE RECOMMENDATIONS: Suggest specific next steps for CI team

RESPONSE REQUIREMENTS:
- Provide executive-level strategic insights
- Include specific data points and metrics
- Cite confidence levels for key assertions
- Focus on actionable intelligence
- Highlight urgent competitive threats
- Suggest monitoring priorities

COMPETITIVE INTELLIGENCE ANALYSIS:"""
        
        return prompt
    
    def _calculate_agent_confidence(self, response: str, citations: List[Dict]) -> int:
        """Calculate confidence score for agent response"""
        base_confidence = 75  # Higher base for agent responses
        
        # Increase confidence based on citations
        if citations:
            base_confidence += min(len(citations) * 5, 20)
        
        # Adjust based on response quality indicators
        if any(indicator in response.lower() for indicator in ['data shows', 'analysis indicates', 'evidence suggests']):
            base_confidence += 5
        
        if any(indicator in response.lower() for indicator in ['uncertain', 'unclear', 'limited data']):
            base_confidence -= 10
        
        return min(max(base_confidence, 60), 95)
    
    def _get_relevant_context(self, question: str) -> Dict[str, Any]:
        """Get relevant context data (same as original implementation)"""
        try:
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
        pharma_terms = [
            'keytruda', 'opdivo', 'tecentriq', 'imfinzi',
            'pembrolizumab', 'nivolumab', 'atezolizumab',
            'melanoma', 'lung cancer', 'oncology', 'immunotherapy',
            'phase i', 'phase ii', 'phase iii', 'fda', 'approval'
        ]
        
        question_lower = question.lower()
        found_terms = [term for term in pharma_terms if term in question_lower]
        
        words = question_lower.split()
        key_words = [word for word in words if len(word) > 3 and word not in ['what', 'when', 'where', 'which', 'compare']]
        
        return found_terms + key_words[:5]
    
    def _extract_sources(self, context_data: Dict[str, Any]) -> list:
        """Extract source citations from context data"""
        sources = []
        
        if 'brands' in context_data and context_data['brands'].get('hits', {}).get('hits'):
            sources.append('Brand Intelligence Database')
        
        if 'trials' in context_data and context_data['trials'].get('hits', {}).get('hits'):
            sources.append('ClinicalTrials.gov')
        
        if 'alerts' in context_data and context_data['alerts'].get('hits', {}).get('hits'):
            sources.extend(['FDA Database', 'Patent Database', 'News Sources'])
        
        if not sources:
            sources = ['Pharmaceutical Intelligence Database']
        
        return list(set(sources))
    
    def _calculate_confidence(self, context_data: Dict[str, Any], question: str) -> int:
        """Calculate confidence score based on available data"""
        base_confidence = 60
        
        if 'brands' in context_data:
            brand_hits = len(context_data['brands'].get('hits', {}).get('hits', []))
            base_confidence += min(brand_hits * 5, 20)
        
        if 'trials' in context_data:
            trial_hits = len(context_data['trials'].get('hits', {}).get('hits', []))
            base_confidence += min(trial_hits * 2, 15)
        
        if 'alerts' in context_data:
            alert_hits = len(context_data['alerts'].get('hits', {}).get('hits', []))
            base_confidence += min(alert_hits * 3, 15)
        
        return min(max(base_confidence, 50), 95)
    
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