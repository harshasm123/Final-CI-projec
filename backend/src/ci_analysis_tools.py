import json
import os
import boto3
from typing import Dict, Any, List
from datetime import datetime, timedelta
import sys

# Add services to path
sys.path.append('/opt/python')
from services.opensearch_service import OpenSearchService
from services.s3_service import S3Service

class CIAnalysisTools:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.s3 = S3Service()
        self.bedrock = boto3.client('bedrock-runtime')
    
    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Handle Bedrock Agent action requests"""
        try:
            # Extract action details from Bedrock Agent event
            action_group = event.get('actionGroup', '')
            function_name = event.get('function', '')
            parameters = event.get('parameters', {})
            
            print(f"Action: {action_group}.{function_name}")
            print(f"Parameters: {parameters}")
            
            # Route to appropriate analysis function
            if function_name == 'analyze_brand_competition':
                return self.analyze_brand_competition(parameters)
            elif function_name == 'assess_clinical_trials':
                return self.assess_clinical_trials(parameters)
            elif function_name == 'regulatory_impact_analysis':
                return self.regulatory_impact_analysis(parameters)
            elif function_name == 'patent_landscape_analysis':
                return self.patent_landscape_analysis(parameters)
            else:
                return self._error_response(f"Unknown function: {function_name}")
                
        except Exception as e:
            print(f"CI Analysis error: {str(e)}")
            return self._error_response(str(e))
    
    def analyze_brand_competition(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze competitive landscape for a pharmaceutical brand"""
        try:
            brand_name = params.get('brand_name', '')
            indication = params.get('indication', '')
            
            if not brand_name:
                return self._error_response("Brand name is required")
            
            # Get brand details
            brand_data = self._get_brand_data(brand_name)
            if not brand_data:
                return self._error_response(f"Brand '{brand_name}' not found")
            
            # Get competitive landscape
            competitors = self._get_competitors(brand_name, indication)
            
            # Analyze market positioning
            market_analysis = self._analyze_market_position(brand_name, competitors)
            
            # Generate competitive threats assessment
            threats = self._assess_competitive_threats(brand_name, competitors)
            
            # Calculate competitive strength score
            strength_score = self._calculate_competitive_strength(brand_data, competitors)
            
            analysis_result = {
                'brand': brand_name,
                'indication': indication or 'All indications',
                'market_position': market_analysis,
                'competitive_strength_score': strength_score,
                'key_competitors': competitors[:5],  # Top 5 competitors
                'competitive_threats': threats,
                'recommendations': self._generate_competitive_recommendations(brand_name, threats),
                'analysis_timestamp': datetime.now().isoformat()
            }
            
            return {
                'actionGroup': 'competitive-analysis',
                'function': 'analyze_brand_competition',
                'functionResponse': {
                    'responseBody': {
                        'TEXT': {
                            'body': json.dumps(analysis_result, indent=2)
                        }
                    }
                }
            }
            
        except Exception as e:
            return self._error_response(f"Competition analysis failed: {str(e)}")
    
    def assess_clinical_trials(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Assess clinical trial competitive threats"""
        try:
            brand_name = params.get('brand_name', '')
            phase = params.get('phase', '')
            
            # Query clinical trials
            query = {
                'query': {
                    'bool': {
                        'must': [
                            {'multi_match': {
                                'query': brand_name,
                                'fields': ['title', 'sponsor', 'brand']
                            }}
                        ]
                    }
                },
                'size': 50,
                'sort': [{'startDate': {'order': 'desc'}}]
            }
            
            if phase:
                query['query']['bool']['filter'] = [
                    {'term': {'phase.keyword': phase}}
                ]
            
            trials_data = self.opensearch.search('trials', query)
            trials = trials_data.get('hits', {}).get('hits', [])
            
            # Analyze trial landscape
            trial_analysis = {
                'total_trials': len(trials),
                'phase_distribution': self._analyze_trial_phases(trials),
                'competitive_trials': self._identify_competitive_trials(trials, brand_name),
                'threat_assessment': self._assess_trial_threats(trials, brand_name),
                'timeline_analysis': self._analyze_trial_timeline(trials),
                'recommendations': self._generate_trial_recommendations(trials, brand_name)
            }
            
            return {
                'actionGroup': 'competitive-analysis',
                'function': 'assess_clinical_trials',
                'functionResponse': {
                    'responseBody': {
                        'TEXT': {
                            'body': json.dumps(trial_analysis, indent=2)
                        }
                    }
                }
            }
            
        except Exception as e:
            return self._error_response(f"Clinical trials assessment failed: {str(e)}")
    
    def regulatory_impact_analysis(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze regulatory events impact on competition"""
        try:
            event_type = params.get('event_type', '')
            timeframe = params.get('timeframe', '90d')
            
            # Query regulatory events
            query = {
                'query': {
                    'bool': {
                        'must': [
                            {'range': {
                                'createdAt': {
                                    'gte': f'now-{timeframe}'
                                }
                            }}
                        ]
                    }
                },
                'size': 100,
                'sort': [{'createdAt': {'order': 'desc'}}]
            }
            
            if event_type:
                query['query']['bool']['must'].append({
                    'match': {'type': event_type}
                })
            
            regulatory_data = self.opensearch.search('regulatory', query)
            events = regulatory_data.get('hits', {}).get('hits', [])
            
            # Analyze regulatory impact
            impact_analysis = {
                'total_events': len(events),
                'event_types': self._categorize_regulatory_events(events),
                'brand_impact_summary': self._analyze_brand_impacts(events),
                'market_implications': self._assess_market_implications(events),
                'urgency_assessment': self._assess_regulatory_urgency(events),
                'strategic_recommendations': self._generate_regulatory_recommendations(events)
            }
            
            return {
                'actionGroup': 'competitive-analysis',
                'function': 'regulatory_impact_analysis',
                'functionResponse': {
                    'responseBody': {
                        'TEXT': {
                            'body': json.dumps(impact_analysis, indent=2)
                        }
                    }
                }
            }
            
        except Exception as e:
            return self._error_response(f"Regulatory analysis failed: {str(e)}")
    
    def patent_landscape_analysis(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze patent landscape and IP risks"""
        try:
            brand_name = params.get('brand_name', '')
            expiration_window = params.get('expiration_window', '2y')
            
            # Query patent data
            query = {
                'query': {
                    'multi_match': {
                        'query': brand_name,
                        'fields': ['title', 'assignee', 'claims']
                    }
                },
                'size': 50,
                'sort': [{'filingDate': {'order': 'desc'}}]
            }
            
            patent_data = self.opensearch.search('patents', query)
            patents = patent_data.get('hits', {}).get('hits', [])
            
            # Analyze patent landscape
            patent_analysis = {
                'total_patents': len(patents),
                'expiration_timeline': self._analyze_patent_expirations(patents, expiration_window),
                'competitive_patents': self._identify_competitive_patents(patents, brand_name),
                'ip_risk_assessment': self._assess_ip_risks(patents, brand_name),
                'freedom_to_operate': self._assess_freedom_to_operate(patents, brand_name),
                'strategic_recommendations': self._generate_patent_recommendations(patents, brand_name)
            }
            
            return {
                'actionGroup': 'competitive-analysis',
                'function': 'patent_landscape_analysis',
                'functionResponse': {
                    'responseBody': {
                        'TEXT': {
                            'body': json.dumps(patent_analysis, indent=2)
                        }
                    }
                }
            }
            
        except Exception as e:
            return self._error_response(f"Patent analysis failed: {str(e)}")
    
    def _get_brand_data(self, brand_name: str) -> Dict[str, Any]:
        """Get brand data from OpenSearch"""
        query = {
            'query': {
                'match': {
                    'name.keyword': brand_name
                }
            }
        }
        
        result = self.opensearch.search('brands', query)
        hits = result.get('hits', {}).get('hits', [])
        
        return hits[0]['_source'] if hits else None
    
    def _get_competitors(self, brand_name: str, indication: str = '') -> List[Dict[str, Any]]:
        """Get competitor brands"""
        query = {
            'query': {
                'bool': {
                    'must_not': [
                        {'term': {'name.keyword': brand_name}}
                    ]
                }
            },
            'size': 10
        }
        
        if indication:
            query['query']['bool']['must'] = [
                {'match': {'indications': indication}}
            ]
        
        result = self.opensearch.search('brands', query)
        hits = result.get('hits', {}).get('hits', [])
        
        return [hit['_source'] for hit in hits]
    
    def _analyze_market_position(self, brand_name: str, competitors: List[Dict]) -> Dict[str, Any]:
        """Analyze market position relative to competitors"""
        # Simplified market position analysis
        return {
            'position': 'Market Leader',
            'market_share_estimate': '35%',
            'competitive_advantage': 'First-mover advantage and broad indication coverage',
            'vulnerabilities': 'Patent expiration approaching, new entrants'
        }
    
    def _assess_competitive_threats(self, brand_name: str, competitors: List[Dict]) -> List[Dict[str, Any]]:
        """Assess competitive threats"""
        threats = []
        
        for competitor in competitors[:3]:  # Top 3 threats
            threat_level = competitor.get('riskScore', 50)
            
            threats.append({
                'competitor': competitor.get('name', 'Unknown'),
                'threat_level': threat_level,
                'threat_type': 'Direct Competition' if threat_level > 70 else 'Moderate Competition',
                'key_differentiators': competitor.get('indications', [])[:2],
                'estimated_impact': 'High' if threat_level > 70 else 'Medium'
            })
        
        return threats
    
    def _calculate_competitive_strength(self, brand_data: Dict, competitors: List[Dict]) -> int:
        """Calculate competitive strength score"""
        base_score = brand_data.get('riskScore', 50)
        
        # Adjust based on competitive landscape
        competitor_avg = sum(c.get('riskScore', 50) for c in competitors) / len(competitors) if competitors else 50
        
        if base_score > competitor_avg:
            return min(base_score + 10, 100)
        else:
            return max(base_score - 5, 0)
    
    def _generate_competitive_recommendations(self, brand_name: str, threats: List[Dict]) -> List[str]:
        """Generate strategic recommendations"""
        recommendations = [
            f"Monitor {threats[0]['competitor']} closely due to high threat level" if threats else "Continue market monitoring",
            "Strengthen differentiation in key therapeutic areas",
            "Accelerate pipeline development to maintain competitive edge",
            "Consider strategic partnerships to expand market reach"
        ]
        
        return recommendations
    
    def _error_response(self, message: str) -> Dict[str, Any]:
        """Return error response in Bedrock Agent format"""
        return {
            'actionGroup': 'competitive-analysis',
            'function': 'error',
            'functionResponse': {
                'responseBody': {
                    'TEXT': {
                        'body': json.dumps({'error': message})
                    }
                }
            }
        }

# Lambda entry point
def lambda_handler(event, context):
    tools = CIAnalysisTools()
    return tools.lambda_handler(event, context)