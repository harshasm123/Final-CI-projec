import json
from typing import Dict, Any
from services.opensearch_service import OpenSearchService

class AlertHandler:
    def __init__(self):
        self.opensearch = OpenSearchService()
    
    def get_alerts(self, query_params: Dict[str, str]) -> Dict[str, Any]:
        """Get alerts with filtering"""
        try:
            # Build OpenSearch query based on filters
            filters = []
            
            if query_params.get('brand'):
                filters.append({
                    'term': {
                        'brandImpacted.keyword': query_params['brand']
                    }
                })
            
            if query_params.get('source'):
                filters.append({
                    'term': {
                        'source.keyword': query_params['source']
                    }
                })
            
            if query_params.get('severity'):
                filters.append({
                    'term': {
                        'severity.keyword': query_params['severity']
                    }
                })
            
            # Date range filter
            if query_params.get('startDate') or query_params.get('endDate'):
                date_filter = {'range': {'createdAt': {}}}
                if query_params.get('startDate'):
                    date_filter['range']['createdAt']['gte'] = query_params['startDate']
                if query_params.get('endDate'):
                    date_filter['range']['createdAt']['lte'] = query_params['endDate']
                filters.append(date_filter)
            
            # Build final query
            if filters:
                search_query = {
                    'query': {
                        'bool': {
                            'filter': filters
                        }
                    },
                    'sort': [
                        {'createdAt': {'order': 'desc'}},
                        {'severity.keyword': {'order': 'asc'}}  # Critical first
                    ],
                    'size': int(query_params.get('limit', 50))
                }
            else:
                search_query = {
                    'query': {'match_all': {}},
                    'sort': [
                        {'createdAt': {'order': 'desc'}},
                        {'severity.keyword': {'order': 'asc'}}
                    ],
                    'size': int(query_params.get('limit', 50))
                }
            
            # Add pagination
            page = int(query_params.get('page', 1))
            search_query['from'] = (page - 1) * search_query['size']
            
            results = self.opensearch.search('alerts', search_query)
            
            # Transform results
            alerts = []
            for hit in results.get('hits', {}).get('hits', []):
                alert_data = hit['_source']
                alerts.append({
                    'id': alert_data['id'],
                    'title': alert_data['title'],
                    'severity': alert_data['severity'],
                    'source': alert_data['source'],
                    'brandImpacted': alert_data['brandImpacted'],
                    'description': alert_data['description'],
                    'whyItMatters': alert_data['whyItMatters'],
                    'createdAt': alert_data['createdAt'],
                    'confidenceScore': alert_data['confidenceScore']
                })
            
            # Pagination metadata
            total_hits = results.get('hits', {}).get('total', {}).get('value', 0)
            total_pages = (total_hits + search_query['size'] - 1) // search_query['size']
            
            response_data = {
                'data': alerts,
                'pagination': {
                    'page': page,
                    'limit': search_query['size'],
                    'total': total_hits,
                    'totalPages': total_pages
                },
                'success': True
            }
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(response_data)
            }
            
        except Exception as e:
            return self._error_response(f'Failed to get alerts: {str(e)}')
    
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