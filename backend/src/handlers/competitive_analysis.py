import json
import boto3
from typing import Dict, Any
from datetime import datetime, timedelta
from services.opensearch_service import OpenSearchService

class CompetitiveAnalysisHandler:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.bedrock = boto3.client('bedrock-runtime')
    
    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Analyze competitive landscape"""
        try:
            analysis_type = event.get('analysisType', 'competitive_landscape')
            include_historical = event.get('includeHistoricalData', False)
            
            if analysis_type == 'competitive_landscape':
                return self.analyze_competitive_landscape(include_historical)
            else:
                return self._error_response('Unknown analysis type')
                
        except Exception as e:
            return self._error_response(f'Analysis failed: {str(e)}')
    
    def analyze_competitive_landscape(self, include_historical: bool = False) -> Dict[str, Any]:
        """Perform comprehensive competitive landscape analysis"""
        try:
            # Get all brands and their competitive data
            brands_query = {
                'query': {'match_all': {}},
                'size': 100,
                '_source': ['id', 'name', 'molecule', 'competitors', 'indications', 'riskScore']
            }
            
            brands_results = self.opensearch.search('brands', brands_query)
            brands = [hit['_source'] for hit in brands_results.get('hits', {}).get('hits', [])]
            
            # Analyze each brand's competitive position
            landscape_analysis = []
            
            for brand in brands:
                # Get recent trials for this brand
                trials_query = {
                    'query': {
                        'bool': {
                            'must': [
                                {'match': {'sponsor': brand.get('manufacturer', '')}}
                            ],
                            'filter': [
                                {'range': {'date': {'gte': 'now-90d'}}} if not include_historical else {}
                            ]
                        }
                    },
                    'size': 20
                }
                
                trials_results = self.opensearch.search('trials', trials_query)
                trials = trials_results.get('hits', {}).get('hits', [])
                
                # Get competitive alerts
                alerts_query = {
                    'query': {
                        'terms': {
                            'brandImpacted.keyword': [brand['name']] + brand.get('competitors', [])
                        }
                    },
                    'size': 10
                }
                
                alerts_results = self.opensearch.search('alerts', alerts_query)
                alerts = alerts_results.get('hits', {}).get('hits', [])
                
                # Perform AI analysis
                analysis_prompt = self._build_analysis_prompt(brand, trials, alerts)
                ai_insights = self._get_ai_insights(analysis_prompt)
                
                # Compile landscape data
                landscape_entry = {
                    'brand': brand['name'],
                    'molecule': brand.get('molecule', ''),
                    'indications': brand.get('indications', []),
                    'competitors': brand.get('competitors', []),
                    'recentTrials': len(trials),
                    'competitiveAlerts': len(alerts),
                    'riskScore': brand.get('riskScore', 0),
                    'aiInsights': ai_insights,
                    'analysisDate': datetime.now().isoformat()
                }
                
                landscape_analysis.append(landscape_entry)
            
            # Store analysis results
            analysis_id = f"landscape-{datetime.now().timestamp()}"
            analysis_data = {
                'id': analysis_id,
                'type': 'competitive_landscape',
                'timestamp': datetime.now().isoformat(),
                'brands_analyzed': len(brands),
                'landscape': landscape_analysis
            }
            
            self.opensearch.index_document('competitive_analysis', analysis_id, analysis_data)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Competitive landscape analysis completed',
                    'analysisId': analysis_id,
                    'brandsAnalyzed': len(brands)
                })
            }
            
        except Exception as e:
            return self._error_response(f'Landscape analysis failed: {str(e)}')
    
    def _build_analysis_prompt(self, brand: Dict[str, Any], trials: list, alerts: list) -> str:
        """Build prompt for AI competitive analysis"""
        prompt = f"""
        Analyze the competitive position of {brand['name']} ({brand.get('molecule', 'Unknown')}):
        
        Brand Information:
        - Indications: {', '.join(brand.get('indications', []))}
        - Competitors: {', '.join(brand.get('competitors', []))}
        - Current Risk Score: {brand.get('riskScore', 0)}/100
        
        Recent Clinical Trials: {len(trials)}
        Recent Competitive Alerts: {len(alerts)}
        
        Provide:
        1. Competitive positioning assessment
        2. Key threats from competitors
        3. Market opportunity analysis
        4. Strategic recommendations
        5. Risk mitigation strategies
        """
        
        return prompt
    
    def _get_ai_insights(self, prompt: str) -> str:
        """Get AI insights using Bedrock"""
        try:
            response = self.bedrock.invoke_model(
                modelId='anthropic.claude-3-sonnet-20240229-v1:0',
                body=json.dumps({
                    'anthropic_version': 'bedrock-2023-05-31',
                    'max_tokens': 500,
                    'messages': [
                        {
                            'role': 'user',
                            'content': prompt
                        }
                    ]
                })
            )
            
            response_body = json.loads(response['body'].read())
            return response_body['content'][0]['text']
            
        except Exception as e:
            print(f"AI insights error: {str(e)}")
            return "AI insights unavailable"
    
    def _error_response(self, message: str) -> Dict[str, Any]:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': message
            })
        }

def lambda_handler(event, context):
    handler = CompetitiveAnalysisHandler()
    return handler.lambda_handler(event, context)
