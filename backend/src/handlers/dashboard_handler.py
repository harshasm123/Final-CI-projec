import json
import boto3
from typing import Dict, Any
from services.opensearch_service import OpenSearchService
from services.s3_service import S3Service

class DashboardHandler:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.s3 = S3Service()
    
    def get_kpis(self) -> Dict[str, Any]:
        """Get dashboard KPIs"""
        try:
            # Query OpenSearch for real-time metrics
            brands_tracked = self.opensearch.count_documents('brands')
            competitors_monitored = self.opensearch.count_documents('competitors')
            critical_alerts = self.opensearch.count_documents('alerts', {'severity': 'critical'})
            regulatory_events = self.opensearch.count_documents('regulatory', {'date_range': 'last_30_days'})
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'data': {
                        'brandsTracked': brands_tracked,
                        'competitorsMonitored': competitors_monitored,
                        'criticalAlerts': critical_alerts,
                        'regulatoryEvents': regulatory_events
                    },
                    'success': True
                })
            }
        except Exception as e:
            return self._error_response(f'Failed to get KPIs: {str(e)}')
    
    def get_trends(self, time_range: str) -> Dict[str, Any]:
        """Get trend data for specified time range"""
        try:
            # Query OpenSearch for trend data
            query = {
                'query': {
                    'range': {
                        'date': {
                            'gte': f'now-{time_range}'
                        }
                    }
                },
                'aggs': {
                    'daily_activity': {
                        'date_histogram': {
                            'field': 'date',
                            'calendar_interval': 'day'
                        },
                        'aggs': {
                            'brands': {
                                'terms': {
                                    'field': 'brand.keyword'
                                }
                            }
                        }
                    }
                }
            }
            
            results = self.opensearch.search('activity', query)
            
            # Transform results to frontend format
            trend_data = []
            for bucket in results.get('aggregations', {}).get('daily_activity', {}).get('buckets', []):
                date = bucket['key_as_string'][:10]  # Extract date part
                for brand_bucket in bucket.get('brands', {}).get('buckets', []):
                    trend_data.append({
                        'date': date,
                        'brand': brand_bucket['key'],
                        'activity': brand_bucket['doc_count']
                    })
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'data': trend_data,
                    'success': True
                })
            }
        except Exception as e:
            return self._error_response(f'Failed to get trends: {str(e)}')
    
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