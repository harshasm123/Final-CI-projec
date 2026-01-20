import json
import boto3
from typing import Dict, Any
from services.opensearch_service import OpenSearchService
from services.s3_service import S3Service

class AgentTools:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.s3 = S3Service()
    
    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Handle agent tool invocations"""
        try:
            # Parse agent request
            action_group = event.get('actionGroup', '')
            action = event.get('action', '')
            parameters = event.get('parameters', [])
            
            # Convert parameters list to dict
            params_dict = {}
            for param in parameters:
                params_dict[param.get('name')] = param.get('value')
            
            # Route to appropriate handler
            if action_group == 'DataRetrieval':
                return self._handle_data_retrieval(action, params_dict)
            elif action_group == 'Analysis':
                return self._handle_analysis(action, params_dict)
            else:
                return self._error_response(f'Unknown action group: {action_group}')
                
        except Exception as e:
            return self._error_response(f'Agent tool error: {str(e)}')
    
    def _handle_data_retrieval(self, action: str, params: Dict[str, str]) -> Dict[str, Any]:
        """Handle data retrieval actions"""
        try:
            if action == 'brands/search':
                return self._search_brands(params.get('query', ''))
            elif action == 'trials/search':
                return self._search_trials(params.get('query', ''))
            elif action == 'competitive-landscape':
                return self._get_competitive_landscape(params.get('brand', ''))
            elif action == 'alerts':
                return self._get_alerts(params)
            else:
                return self._error_response(f'Unknown data retrieval action: {action}')
                
        except Exception as e:
            return self._error_response(f'Data retrieval failed: {str(e)}')
    
    def _handle_analysis(self, action: str, params: Dict[str, str]) -> Dict[str, Any]:
        """Handle analysis actions"""
        try:
            if action == 'analyze/competitive-position':
                return self._analyze_competitive_position(params)
            elif action == 'analyze/market-opportunity':
                return self._analyze_market_opportunity(params)
            elif action == 'analyze/threat-assessment':
                return self._analyze_threat_assessment(params)
            else:
                return self._error_response(f'Unknown analysis action: {action}')
                
        except Exception as e:
            return self._error_response(f'Analysis failed: {str(e)}')
    
    def _search_brands(self, query: str) -> Dict[str, Any]:
        """Search for brands"""
        try:
            search_query = {
                'query': {
                    'multi_match': {
                        'query': query,
                        'fields': ['name^2', 'molecule', 'manufacturer'],
                        'fuzziness': 'AUTO'
                    }
                },
                'size': 10
            }
            
            results = self.opensearch.search('brands', search_query)
            
            brands = []
            for hit in results.get('hits', {}).get('hits', []):
                brand = hit['_source']
                brands.append({
                    'id': brand.get('id'),
                    'name': brand.get('name'),
                    'molecule': brand.get('molecule'),
                    'manufacturer': brand.get('manufacturer'),
                    'indications': brand.get('indications', []),
                    'competitors': brand.get('competitors', []),
                    'riskScore': brand.get('riskScore', 0)
                })
            
            return self._success_response({
                'action': 'brands/search',
                'query': query,
                'results': brands,
                'count': len(brands)
            })
            
        except Exception as e:
            return self._error_response(f'Brand search failed: {str(e)}')
    
    def _search_trials(self, query: str) -> Dict[str, Any]:
        """Search for clinical trials"""
        try:
            search_query = {
                'query': {
                    'multi_match': {
                        'query': query,
                        'fields': ['title', 'condition', 'sponsor'],
                        'fuzziness': 'AUTO'
                    }
                },
                'size': 10
            }
            
            results = self.opensearch.search('trials', search_query)
            
            trials = []
            for hit in results.get('hits', {}).get('hits', []):
                trial = hit['_source']
                trials.append({
                    'id': trial.get('id'),
                    'title': trial.get('title'),
                    'phase': trial.get('phase'),
                    'status': trial.get('status'),
                    'condition': trial.get('condition'),
                    'sponsor': trial.get('sponsor'),
                    'participantCount': trial.get('participantCount', 0)
                })
            
            return self._success_response({
                'action': 'trials/search',
                'query': query,
                'results': trials,
                'count': len(trials)
            })
            
        except Exception as e:
            return self._error_response(f'Trial search failed: {str(e)}')
    
    def _get_competitive_landscape(self, brand: str) -> Dict[str, Any]:
        """Get competitive landscape for a brand"""
        try:
            # Get brand details
            brand_query = {
                'query': {
                    'match': {'name': brand}
                }
            }
            
            brand_results = self.opensearch.search('brands', brand_query)
            brand_hits = brand_results.get('hits', {}).get('hits', [])
            
            if not brand_hits:
                return self._error_response(f'Brand not found: {brand}')
            
            brand_data = brand_hits[0]['_source']
            competitors = brand_data.get('competitors', [])
            
            # Get competitive data
            landscape_query = {
                'query': {
                    'terms': {
                        'brand.keyword': [brand] + competitors
                    }
                },
                'aggs': {
                    'by_brand': {
                        'terms': {
                            'field': 'brand.keyword'
                        },
                        'aggs': {
                            'trial_count': {
                                'value_count': {
                                    'field': 'id'
                                }
                            }
                        }
                    }
                }
            }
            
            results = self.opensearch.search('competitive_landscape', landscape_query)
            
            landscape = []
            for bucket in results.get('aggregations', {}).get('by_brand', {}).get('buckets', []):
                landscape.append({
                    'brand': bucket['key'],
                    'trialCount': bucket.get('trial_count', {}).get('value', 0),
                    'docCount': bucket['doc_count']
                })
            
            return self._success_response({
                'action': 'competitive-landscape',
                'brand': brand,
                'landscape': landscape
            })
            
        except Exception as e:
            return self._error_response(f'Landscape retrieval failed: {str(e)}')
    
    def _get_alerts(self, params: Dict[str, str]) -> Dict[str, Any]:
        """Get competitive alerts"""
        try:
            filters = []
            
            if params.get('severity'):
                filters.append({
                    'term': {'severity.keyword': params['severity']}
                })
            
            if params.get('brand'):
                filters.append({
                    'term': {'brandImpacted.keyword': params['brand']}
                })
            
            if filters:
                query = {
                    'query': {
                        'bool': {'filter': filters}
                    },
                    'sort': [{'createdAt': {'order': 'desc'}}],
                    'size': 20
                }
            else:
                query = {
                    'query': {'match_all': {}},
                    'sort': [{'createdAt': {'order': 'desc'}}],
                    'size': 20
                }
            
            results = self.opensearch.search('alerts', query)
            
            alerts = []
            for hit in results.get('hits', {}).get('hits', []):
                alert = hit['_source']
                alerts.append({
                    'id': alert.get('id'),
                    'title': alert.get('title'),
                    'severity': alert.get('severity'),
                    'source': alert.get('source'),
                    'brandImpacted': alert.get('brandImpacted', []),
                    'createdAt': alert.get('createdAt'),
                    'confidenceScore': alert.get('confidenceScore', 0)
                })
            
            return self._success_response({
                'action': 'alerts',
                'filters': params,
                'results': alerts,
                'count': len(alerts)
            })
            
        except Exception as e:
            return self._error_response(f'Alert retrieval failed: {str(e)}')
    
    def _analyze_competitive_position(self, params: Dict[str, str]) -> Dict[str, Any]:
        """Analyze competitive position"""
        try:
            brand = params.get('brand', '')
            competitors = params.get('competitors', '').split(',') if params.get('competitors') else []
            timeframe = params.get('timeframe', '90d')
            
            if not brand:
                return self._error_response('Brand is required')
            
            # Get brand data
            brand_query = {
                'query': {'match': {'name': brand}}
            }
            brand_results = self.opensearch.search('brands', brand_query)
            brand_data = brand_results.get('hits', {}).get('hits', [{}])[0].get('_source', {})
            
            # Get recent trials
            trials_query = {
                'query': {
                    'range': {
                        'date': {'gte': f'now-{timeframe}'}
                    }
                },
                'size': 50
            }
            trials_results = self.opensearch.search('trials', trials_query)
            
            # Get recent alerts
            alerts_query = {
                'query': {
                    'range': {
                        'createdAt': {'gte': f'now-{timeframe}'}
                    }
                },
                'size': 20
            }
            alerts_results = self.opensearch.search('alerts', alerts_query)
            
            analysis = {
                'brand': brand,
                'competitors': competitors or brand_data.get('competitors', []),
                'riskScore': brand_data.get('riskScore', 0),
                'recentTrials': trials_results.get('hits', {}).get('total', {}).get('value', 0),
                'recentAlerts': alerts_results.get('hits', {}).get('total', {}).get('value', 0),
                'indications': brand_data.get('indications', []),
                'timeframe': timeframe
            }
            
            return self._success_response({
                'action': 'analyze/competitive-position',
                'analysis': analysis
            })
            
        except Exception as e:
            return self._error_response(f'Competitive position analysis failed: {str(e)}')
    
    def _analyze_market_opportunity(self, params: Dict[str, str]) -> Dict[str, Any]:
        """Analyze market opportunities"""
        try:
            indication = params.get('indication', '')
            brands = params.get('brands', '').split(',') if params.get('brands') else []
            
            if not indication:
                return self._error_response('Indication is required')
            
            # Search for trials in this indication
            trials_query = {
                'query': {
                    'match': {'condition': indication}
                },
                'size': 100
            }
            trials_results = self.opensearch.search('trials', trials_query)
            
            # Analyze trial phases
            phase_distribution = {}
            for hit in trials_results.get('hits', {}).get('hits', []):
                phase = hit['_source'].get('phase', 'Unknown')
                phase_distribution[phase] = phase_distribution.get(phase, 0) + 1
            
            opportunity = {
                'indication': indication,
                'totalTrials': trials_results.get('hits', {}).get('total', {}).get('value', 0),
                'phaseDistribution': phase_distribution,
                'trackedBrands': brands,
                'marketSize': 'TBD'  # Would be enriched with market data
            }
            
            return self._success_response({
                'action': 'analyze/market-opportunity',
                'opportunity': opportunity
            })
            
        except Exception as e:
            return self._error_response(f'Market opportunity analysis failed: {str(e)}')
    
    def _analyze_threat_assessment(self, params: Dict[str, str]) -> Dict[str, Any]:
        """Assess competitive threats"""
        try:
            brand = params.get('brand', '')
            threat_type = params.get('threatType', 'all')
            
            if not brand:
                return self._error_response('Brand is required')
            
            # Get brand data
            brand_query = {
                'query': {'match': {'name': brand}}
            }
            brand_results = self.opensearch.search('brands', brand_query)
            brand_data = brand_results.get('hits', {}).get('hits', [{}])[0].get('_source', {})
            
            # Get recent alerts for this brand
            alerts_query = {
                'query': {
                    'term': {'brandImpacted.keyword': brand}
                },
                'sort': [{'createdAt': {'order': 'desc'}}],
                'size': 20
            }
            alerts_results = self.opensearch.search('alerts', alerts_query)
            
            threats = []
            for hit in alerts_results.get('hits', {}).get('hits', []):
                alert = hit['_source']
                threats.append({
                    'title': alert.get('title'),
                    'severity': alert.get('severity'),
                    'source': alert.get('source'),
                    'confidenceScore': alert.get('confidenceScore', 0)
                })
            
            assessment = {
                'brand': brand,
                'threatType': threat_type,
                'riskScore': brand_data.get('riskScore', 0),
                'activeThreats': len(threats),
                'threats': threats[:10],
                'competitors': brand_data.get('competitors', [])
            }
            
            return self._success_response({
                'action': 'analyze/threat-assessment',
                'assessment': assessment
            })
            
        except Exception as e:
            return self._error_response(f'Threat assessment failed: {str(e)}')
    
    def _success_response(self, data: Dict[str, Any]) -> Dict[str, Any]:
        return {
            'statusCode': 200,
            'body': json.dumps(data)
        }
    
    def _error_response(self, message: str) -> Dict[str, Any]:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': message
            })
        }

def lambda_handler(event, context):
    tools = AgentTools()
    return tools.lambda_handler(event, context)
