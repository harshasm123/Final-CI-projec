import json
from typing import Dict, Any, List
from services.opensearch_service import OpenSearchService
from services.s3_service import S3Service

class BrandHandler:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.s3 = S3Service()
    
    def search_brands(self, query: str) -> Dict[str, Any]:
        """Search brands by name or molecule"""
        try:
            if not query or len(query) < 2:
                return self._success_response([])
            
            # Multi-field search in OpenSearch
            search_query = {
                'query': {
                    'multi_match': {
                        'query': query,
                        'fields': ['name^2', 'molecule', 'manufacturer'],
                        'type': 'best_fields',
                        'fuzziness': 'AUTO'
                    }
                },
                'size': 10,
                '_source': ['id', 'name', 'molecule', 'manufacturer', 'indications', 'competitors', 'riskScore', 'lastUpdated']
            }
            
            results = self.opensearch.search('brands', search_query)
            
            # Transform to frontend format
            search_results = []
            for hit in results.get('hits', {}).get('hits', []):
                brand_data = hit['_source']
                search_results.append({
                    'brand': {
                        'id': brand_data['id'],
                        'name': brand_data['name'],
                        'molecule': brand_data['molecule'],
                        'manufacturer': brand_data['manufacturer'],
                        'indications': brand_data.get('indications', []),
                        'competitors': brand_data.get('competitors', []),
                        'riskScore': brand_data.get('riskScore', 0),
                        'lastUpdated': brand_data.get('lastUpdated', '')
                    },
                    'relevanceScore': hit['_score']
                })
            
            return self._success_response(search_results)
            
        except Exception as e:
            return self._error_response(f'Search failed: {str(e)}')
    
    def get_brand_details(self, brand_id: str) -> Dict[str, Any]:
        """Get detailed brand information"""
        try:
            # Query OpenSearch for brand details
            query = {
                'query': {
                    'term': {
                        'id.keyword': brand_id
                    }
                }
            }
            
            results = self.opensearch.search('brands', query)
            hits = results.get('hits', {}).get('hits', [])
            
            if not hits:
                return {
                    'statusCode': 404,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'success': False,
                        'message': 'Brand not found'
                    })
                }
            
            brand_data = hits[0]['_source']
            
            return self._success_response(brand_data)
            
        except Exception as e:
            return self._error_response(f'Failed to get brand details: {str(e)}')
    
    def get_competitive_landscape(self, brand_id: str) -> Dict[str, Any]:
        """Get competitive landscape for a brand"""
        try:
            # First get the brand to find its competitors
            brand_query = {
                'query': {
                    'term': {
                        'id.keyword': brand_id
                    }
                }
            }
            
            brand_results = self.opensearch.search('brands', brand_query)
            brand_hits = brand_results.get('hits', {}).get('hits', [])
            
            if not brand_hits:
                return self._error_response('Brand not found')
            
            brand = brand_hits[0]['_source']
            competitors = brand.get('competitors', [])
            
            # Query competitive landscape data
            landscape_query = {
                'query': {
                    'terms': {
                        'brand.keyword': [brand['name']] + competitors
                    }
                },
                'aggs': {
                    'by_brand': {
                        'terms': {
                            'field': 'brand.keyword'
                        },
                        'aggs': {
                            'trial_phases': {
                                'terms': {
                                    'field': 'trialPhase.keyword'
                                }
                            },
                            'avg_risk_score': {
                                'avg': {
                                    'field': 'riskScore'
                                }
                            }
                        }
                    }
                }
            }
            
            results = self.opensearch.search('competitive_landscape', landscape_query)
            
            # Transform results
            landscape_data = []
            for bucket in results.get('aggregations', {}).get('by_brand', {}).get('buckets', []):
                brand_name = bucket['key']
                trial_count = bucket['doc_count']
                avg_risk = bucket.get('avg_risk_score', {}).get('value', 0)
                
                # Get most advanced trial phase
                phases = bucket.get('trial_phases', {}).get('buckets', [])
                trial_phase = phases[0]['key'] if phases else 'Unknown'
                
                landscape_data.append({
                    'brand': brand_name,
                    'molecule': 'TBD',  # Would be enriched from brand data
                    'indication': 'Multiple',
                    'trialPhase': trial_phase,
                    'trialCount': trial_count,
                    'recentApproval': None,
                    'riskScore': int(avg_risk)
                })
            
            return self._success_response(landscape_data)
            
        except Exception as e:
            return self._error_response(f'Failed to get competitive landscape: {str(e)}')
    
    def _success_response(self, data: Any) -> Dict[str, Any]:
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'data': data,
                'success': True
            })
        }
    
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