import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any
from opensearchpy import OpenSearch, RequestsHttpConnection
from aws_requests_auth.aws_auth import AWSRequestsAuth

class DashboardHandler:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        self.data_bucket = os.environ.get('DATA_BUCKET')
        self.opensearch_endpoint = os.environ.get('OPENSEARCH_ENDPOINT')
        
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
        """Main dashboard handler"""
        try:
            # Get dashboard data
            dashboard_data = {
                'overview': self.get_overview_metrics(),
                'recent_activity': self.get_recent_activity(),
                'competitive_landscape': self.get_competitive_metrics(),
                'clinical_trials': self.get_clinical_trial_metrics(),
                'regulatory_updates': self.get_regulatory_metrics(),
                'market_intelligence': self.get_market_intelligence(),
                'alerts': self.get_active_alerts(),
                'timestamp': datetime.now().isoformat()
            }
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type'
                },
                'body': json.dumps(dashboard_data)
            }
            
        except Exception as e:
            print(f"Dashboard error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Internal server error'})
            }
    
    def get_overview_metrics(self) -> Dict[str, Any]:
        """Get high-level overview metrics"""
        try:
            if not hasattr(self, 'opensearch_client'):
                return self.get_mock_overview()
            
            # Get document counts by source
            search_body = {
                "size": 0,
                "aggs": {
                    "sources": {
                        "terms": {"field": "source.keyword", "size": 10}
                    },
                    "document_types": {
                        "terms": {"field": "documentType.keyword", "size": 10}
                    },
                    "recent_docs": {
                        "date_range": {
                            "field": "processedAt",
                            "ranges": [
                                {"from": "now-7d", "to": "now", "key": "last_7_days"},
                                {"from": "now-30d", "to": "now", "key": "last_30_days"}
                            ]
                        }
                    }
                }
            }
            
            response = self.opensearch_client.search(
                index="pharma-ci-*,papers,trials,regulatory",
                body=search_body
            )
            
            aggs = response.get('aggregations', {})
            
            return {
                'total_documents': response['hits']['total']['value'],
                'sources': {bucket['key']: bucket['doc_count'] for bucket in aggs.get('sources', {}).get('buckets', [])},
                'document_types': {bucket['key']: bucket['doc_count'] for bucket in aggs.get('document_types', {}).get('buckets', [])},
                'recent_activity': {
                    bucket['key']: bucket['doc_count'] 
                    for bucket in aggs.get('recent_docs', {}).get('buckets', [])
                }
            }
            
        except Exception as e:
            print(f"Error getting overview metrics: {str(e)}")
            return self.get_mock_overview()
    
    def get_mock_overview(self) -> Dict[str, Any]:
        """Mock overview data for testing"""
        return {
            'total_documents': 15420,
            'sources': {
                'pubmed': 8500,
                'clinicaltrials.gov': 3200,
                'fda': 2100,
                'patents': 1620
            },
            'document_types': {
                'research_paper': 8500,
                'clinical_trial': 3200,
                'regulatory_data': 2100,
                'patent': 1620
            },
            'recent_activity': {
                'last_7_days': 245,
                'last_30_days': 1120
            }
        }
    
    def get_recent_activity(self) -> List[Dict[str, Any]]:
        """Get recent activity feed"""
        try:
            if not hasattr(self, 'opensearch_client'):
                return self.get_mock_activity()
            
            search_body = {
                "query": {
                    "range": {
                        "processedAt": {
                            "gte": "now-7d"
                        }
                    }
                },
                "sort": [{"processedAt": {"order": "desc"}}],
                "size": 20,
                "_source": ["title", "source", "documentType", "processedAt", "brandsmentioned"]
            }
            
            response = self.opensearch_client.search(
                index="pharma-ci-*,papers,trials,regulatory",
                body=search_body
            )
            
            activities = []
            for hit in response['hits']['hits']:
                source = hit['_source']
                activities.append({
                    'id': hit['_id'],
                    'title': source.get('title', 'N/A')[:100],
                    'source': source.get('source', ''),
                    'type': source.get('documentType', ''),
                    'timestamp': source.get('processedAt', ''),
                    'brands': source.get('brandsmentioned', [])
                })
            
            return activities
            
        except Exception as e:
            print(f"Error getting recent activity: {str(e)}")
            return self.get_mock_activity()
    
    def get_mock_activity(self) -> List[Dict[str, Any]]:
        """Mock activity data"""
        return [
            {
                'id': '1',
                'title': 'Phase 3 trial results for pembrolizumab in lung cancer',
                'source': 'pubmed',
                'type': 'research_paper',
                'timestamp': datetime.now().isoformat(),
                'brands': ['pembrolizumab', 'keytruda']
            },
            {
                'id': '2',
                'title': 'FDA approval for new indication - nivolumab',
                'source': 'fda',
                'type': 'regulatory_data',
                'timestamp': (datetime.now() - timedelta(hours=2)).isoformat(),
                'brands': ['nivolumab', 'opdivo']
            }
        ]
    
    def get_competitive_metrics(self) -> Dict[str, Any]:
        """Get competitive landscape metrics"""
        try:
            # Mock competitive data
            return {
                'market_leaders': [
                    {'brand': 'Keytruda', 'market_share': 35.2, 'trend': 'up'},
                    {'brand': 'Opdivo', 'market_share': 28.7, 'trend': 'stable'},
                    {'brand': 'Tecentriq', 'market_share': 15.1, 'trend': 'up'}
                ],
                'emerging_competitors': [
                    {'brand': 'Imfinzi', 'growth_rate': 45.2},
                    {'brand': 'Bavencio', 'growth_rate': 32.1}
                ],
                'competitive_intensity': 8.5,
                'market_concentration': 'moderate'
            }
            
        except Exception as e:
            print(f"Error getting competitive metrics: {str(e)}")
            return {}
    
    def get_clinical_trial_metrics(self) -> Dict[str, Any]:
        """Get clinical trial metrics"""
        try:
            # Mock trial data
            return {
                'active_trials': 1247,
                'phase_distribution': {
                    'Phase 1': 312,
                    'Phase 2': 456,
                    'Phase 3': 389,
                    'Phase 4': 90
                },
                'top_sponsors': [
                    {'name': 'Merck & Co', 'trials': 89},
                    {'name': 'Bristol Myers Squibb', 'trials': 76},
                    {'name': 'Roche', 'trials': 65}
                ],
                'success_rates': {
                    'Phase 1 to 2': 68.5,
                    'Phase 2 to 3': 42.3,
                    'Phase 3 to Approval': 78.9
                }
            }
            
        except Exception as e:
            print(f"Error getting trial metrics: {str(e)}")
            return {}
    
    def get_regulatory_metrics(self) -> Dict[str, Any]:
        """Get regulatory update metrics"""
        try:
            # Mock regulatory data
            return {
                'recent_approvals': [
                    {'drug': 'Pembrolizumab', 'indication': 'Triple-negative breast cancer', 'date': '2024-01-15'},
                    {'drug': 'Nivolumab', 'indication': 'Gastric cancer', 'date': '2024-01-10'}
                ],
                'pending_decisions': [
                    {'drug': 'Atezolizumab', 'indication': 'Bladder cancer', 'pdufa_date': '2024-03-15'},
                    {'drug': 'Durvalumab', 'indication': 'Lung cancer', 'pdufa_date': '2024-04-20'}
                ],
                'safety_alerts': 2,
                'label_updates': 5
            }
            
        except Exception as e:
            print(f"Error getting regulatory metrics: {str(e)}")
            return {}
    
    def get_market_intelligence(self) -> Dict[str, Any]:
        """Get market intelligence data"""
        try:
            # Mock market data
            return {
                'market_size': {
                    'current': 125.6,  # Billion USD
                    'projected_2025': 189.3,
                    'cagr': 8.5
                },
                'key_trends': [
                    'Combination therapies gaining traction',
                    'Biomarker-driven patient selection',
                    'Real-world evidence importance growing'
                ],
                'investment_activity': {
                    'total_funding': 12.4,  # Billion USD
                    'deals_count': 156,
                    'avg_deal_size': 79.5  # Million USD
                }
            }
            
        except Exception as e:
            print(f"Error getting market intelligence: {str(e)}")
            return {}
    
    def get_active_alerts(self) -> List[Dict[str, Any]]:
        """Get active alerts"""
        try:
            # Mock alerts data
            return [
                {
                    'id': 'alert_1',
                    'type': 'competitive_threat',
                    'severity': 'high',
                    'title': 'New competitor entering market',
                    'description': 'Biosimilar approval expected Q2 2024',
                    'timestamp': datetime.now().isoformat()
                },
                {
                    'id': 'alert_2',
                    'type': 'regulatory_update',
                    'severity': 'medium',
                    'title': 'FDA guidance update',
                    'description': 'New requirements for combination therapies',
                    'timestamp': (datetime.now() - timedelta(hours=6)).isoformat()
                }
            ]
            
        except Exception as e:
            print(f"Error getting alerts: {str(e)}")
            return []

def lambda_handler(event, context):
    """Lambda entry point"""
    handler = DashboardHandler()
    return handler.lambda_handler(event, context)