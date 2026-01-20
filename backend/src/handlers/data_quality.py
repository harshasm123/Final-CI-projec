import json
import os
import boto3
from typing import Dict, Any, List
from datetime import datetime
from services.opensearch_service import OpenSearchService

class DataQualityHandler:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.sns = boto3.client('sns')
        self.alert_topic = os.environ.get('ALERT_TOPIC', '')
    
    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Run data quality checks"""
        try:
            check_type = event.get('checkType', 'comprehensive')
            
            if check_type == 'comprehensive':
                return self.run_comprehensive_checks()
            elif check_type == 'quick':
                return self.run_quick_checks()
            else:
                return self._error_response('Unknown check type')
                
        except Exception as e:
            return self._error_response(f'Data quality check failed: {str(e)}')
    
    def run_comprehensive_checks(self) -> Dict[str, Any]:
        """Run comprehensive data quality checks"""
        try:
            check_results = {
                'timestamp': datetime.now().isoformat(),
                'checks': []
            }
            
            # Check 1: Completeness
            completeness_check = self.check_data_completeness()
            check_results['checks'].append(completeness_check)
            
            # Check 2: Consistency
            consistency_check = self.check_data_consistency()
            check_results['checks'].append(consistency_check)
            
            # Check 3: Accuracy
            accuracy_check = self.check_data_accuracy()
            check_results['checks'].append(accuracy_check)
            
            # Check 4: Timeliness
            timeliness_check = self.check_data_timeliness()
            check_results['checks'].append(timeliness_check)
            
            # Check 5: Uniqueness
            uniqueness_check = self.check_data_uniqueness()
            check_results['checks'].append(uniqueness_check)
            
            # Calculate overall quality score
            overall_score = self._calculate_overall_score(check_results['checks'])
            check_results['overallQualityScore'] = overall_score
            
            # Store results
            check_id = f"quality-check-{datetime.now().timestamp()}"
            self.opensearch.index_document('data_quality_checks', check_id, check_results)
            
            # Alert if quality score is low
            if overall_score < 70:
                self._generate_quality_alert(check_results)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Comprehensive data quality check completed',
                    'checkId': check_id,
                    'overallScore': overall_score
                })
            }
            
        except Exception as e:
            return self._error_response(f'Comprehensive check failed: {str(e)}')
    
    def check_data_completeness(self) -> Dict[str, Any]:
        """Check data completeness across indices"""
        try:
            indices = ['brands', 'trials', 'alerts', 'regulatory']
            completeness_results = {}
            
            for index in indices:
                # Get total documents
                total_query = {'query': {'match_all': {}}}
                total_results = self.opensearch.search(index, total_query)
                total_docs = total_results.get('hits', {}).get('total', {}).get('value', 0)
                
                # Check for documents with missing required fields
                missing_fields_query = {
                    'query': {
                        'bool': {
                            'must_not': [
                                {'exists': {'field': 'id'}},
                                {'exists': {'field': 'createdAt'}}
                            ]
                        }
                    }
                }
                
                missing_results = self.opensearch.search(index, missing_fields_query)
                missing_docs = missing_results.get('hits', {}).get('total', {}).get('value', 0)
                
                completeness_pct = ((total_docs - missing_docs) / total_docs * 100) if total_docs > 0 else 100
                
                completeness_results[index] = {
                    'totalDocuments': total_docs,
                    'missingFields': missing_docs,
                    'completenessPercentage': completeness_pct
                }
            
            return {
                'checkName': 'Data Completeness',
                'status': 'passed' if all(v['completenessPercentage'] > 95 for v in completeness_results.values()) else 'warning',
                'results': completeness_results
            }
            
        except Exception as e:
            return {
                'checkName': 'Data Completeness',
                'status': 'failed',
                'error': str(e)
            }
    
    def check_data_consistency(self) -> Dict[str, Any]:
        """Check data consistency across related documents"""
        try:
            consistency_issues = []
            
            # Check brand-trial consistency
            brands_query = {'query': {'match_all': {}}, 'size': 100}
            brands_results = self.opensearch.search('brands', brands_query)
            brands = [hit['_source'] for hit in brands_results.get('hits', {}).get('hits', [])]
            
            for brand in brands:
                # Verify trials reference valid brands
                trials_query = {
                    'query': {'match': {'sponsor': brand.get('manufacturer', '')}}
                }
                trials_results = self.opensearch.search('trials', trials_query)
                
                if trials_results.get('hits', {}).get('total', {}).get('value', 0) == 0:
                    consistency_issues.append({
                        'type': 'missing_trials',
                        'brand': brand['name'],
                        'issue': 'No trials found for manufacturer'
                    })
            
            consistency_pct = ((len(brands) - len(consistency_issues)) / len(brands) * 100) if brands else 100
            
            return {
                'checkName': 'Data Consistency',
                'status': 'passed' if consistency_pct > 95 else 'warning',
                'consistencyPercentage': consistency_pct,
                'issues': consistency_issues
            }
            
        except Exception as e:
            return {
                'checkName': 'Data Consistency',
                'status': 'failed',
                'error': str(e)
            }
    
    def check_data_accuracy(self) -> Dict[str, Any]:
        """Check data accuracy and validity"""
        try:
            accuracy_issues = []
            
            # Check for invalid risk scores
            brands_query = {
                'query': {
                    'bool': {
                        'should': [
                            {'range': {'riskScore': {'lt': 0}}},
                            {'range': {'riskScore': {'gt': 100}}}
                        ]
                    }
                }
            }
            
            invalid_scores = self.opensearch.search('brands', brands_query)
            invalid_count = invalid_scores.get('hits', {}).get('total', {}).get('value', 0)
            
            if invalid_count > 0:
                accuracy_issues.append({
                    'type': 'invalid_risk_score',
                    'count': invalid_count,
                    'issue': 'Risk scores outside 0-100 range'
                })
            
            # Check for invalid confidence scores
            alerts_query = {
                'query': {
                    'bool': {
                        'should': [
                            {'range': {'confidenceScore': {'lt': 0}}},
                            {'range': {'confidenceScore': {'gt': 100}}}
                        ]
                    }
                }
            }
            
            invalid_confidence = self.opensearch.search('alerts', alerts_query)
            invalid_conf_count = invalid_confidence.get('hits', {}).get('total', {}).get('value', 0)
            
            if invalid_conf_count > 0:
                accuracy_issues.append({
                    'type': 'invalid_confidence_score',
                    'count': invalid_conf_count,
                    'issue': 'Confidence scores outside 0-100 range'
                })
            
            accuracy_pct = 100 - (len(accuracy_issues) * 10)  # Deduct 10% per issue type
            
            return {
                'checkName': 'Data Accuracy',
                'status': 'passed' if accuracy_pct > 95 else 'warning',
                'accuracyPercentage': max(accuracy_pct, 0),
                'issues': accuracy_issues
            }
            
        except Exception as e:
            return {
                'checkName': 'Data Accuracy',
                'status': 'failed',
                'error': str(e)
            }
    
    def check_data_timeliness(self) -> Dict[str, Any]:
        """Check data freshness and timeliness"""
        try:
            timeliness_results = {}
            
            indices = ['brands', 'trials', 'alerts', 'regulatory']
            
            for index in indices:
                # Get documents updated in last 24 hours
                recent_query = {
                    'query': {
                        'range': {
                            'lastUpdated': {'gte': 'now-24h'}
                        }
                    }
                }
                
                recent_results = self.opensearch.search(index, recent_query)
                recent_count = recent_results.get('hits', {}).get('total', {}).get('value', 0)
                
                # Get total documents
                total_query = {'query': {'match_all': {}}}
                total_results = self.opensearch.search(index, total_query)
                total_count = total_results.get('hits', {}).get('total', {}).get('value', 0)
                
                freshness_pct = (recent_count / total_count * 100) if total_count > 0 else 0
                
                timeliness_results[index] = {
                    'recentDocuments': recent_count,
                    'totalDocuments': total_count,
                    'freshnessPercentage': freshness_pct
                }
            
            avg_freshness = sum(v['freshnessPercentage'] for v in timeliness_results.values()) / len(timeliness_results)
            
            return {
                'checkName': 'Data Timeliness',
                'status': 'passed' if avg_freshness > 70 else 'warning',
                'averageFreshness': avg_freshness,
                'results': timeliness_results
            }
            
        except Exception as e:
            return {
                'checkName': 'Data Timeliness',
                'status': 'failed',
                'error': str(e)
            }
    
    def check_data_uniqueness(self) -> Dict[str, Any]:
        """Check for duplicate records"""
        try:
            uniqueness_results = {}
            
            indices = ['brands', 'trials', 'alerts']
            
            for index in indices:
                # Check for duplicate IDs
                duplicates_query = {
                    'aggs': {
                        'duplicate_ids': {
                            'terms': {
                                'field': 'id.keyword',
                                'min_doc_count': 2
                            }
                        }
                    }
                }
                
                duplicates_results = self.opensearch.search(index, duplicates_query)
                duplicate_count = len(duplicates_results.get('aggregations', {}).get('duplicate_ids', {}).get('buckets', []))
                
                uniqueness_results[index] = {
                    'duplicateRecords': duplicate_count,
                    'status': 'passed' if duplicate_count == 0 else 'warning'
                }
            
            total_duplicates = sum(v['duplicateRecords'] for v in uniqueness_results.values())
            
            return {
                'checkName': 'Data Uniqueness',
                'status': 'passed' if total_duplicates == 0 else 'warning',
                'totalDuplicates': total_duplicates,
                'results': uniqueness_results
            }
            
        except Exception as e:
            return {
                'checkName': 'Data Uniqueness',
                'status': 'failed',
                'error': str(e)
            }
    
    def run_quick_checks(self) -> Dict[str, Any]:
        """Run quick data quality checks"""
        try:
            # Just check completeness and consistency
            check_results = {
                'timestamp': datetime.now().isoformat(),
                'checks': [
                    self.check_data_completeness(),
                    self.check_data_consistency()
                ]
            }
            
            overall_score = self._calculate_overall_score(check_results['checks'])
            check_results['overallQualityScore'] = overall_score
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Quick data quality check completed',
                    'overallScore': overall_score
                })
            }
            
        except Exception as e:
            return self._error_response(f'Quick check failed: {str(e)}')
    
    def _calculate_overall_score(self, checks: List[Dict[str, Any]]) -> float:
        """Calculate overall quality score from individual checks"""
        scores = []
        
        for check in checks:
            if check['status'] == 'passed':
                scores.append(100)
            elif check['status'] == 'warning':
                # Extract percentage if available
                for key in ['completenessPercentage', 'consistencyPercentage', 'accuracyPercentage', 'averageFreshness']:
                    if key in check:
                        scores.append(check[key])
                        break
                else:
                    scores.append(75)
            else:
                scores.append(0)
        
        return sum(scores) / len(scores) if scores else 0
    
    def _generate_quality_alert(self, check_results: Dict[str, Any]) -> None:
        """Generate alert for low data quality"""
        try:
            alert_data = {
                'id': f"quality-alert-{datetime.now().timestamp()}",
                'title': 'Data Quality Alert',
                'severity': 'high',
                'source': 'Data Quality Check',
                'description': f"Overall data quality score: {check_results['overallQualityScore']:.1f}%",
                'details': check_results['checks'],
                'createdAt': datetime.now().isoformat()
            }
            
            self.sns.publish(
                TopicArn=self.alert_topic,
                Message=json.dumps(alert_data),
                Subject='Data Quality Alert'
            )
            
        except Exception as e:
            print(f"Error generating quality alert: {str(e)}")
    
    def _error_response(self, message: str) -> Dict[str, Any]:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': message
            })
        }

def lambda_handler(event, context):
    handler = DataQualityHandler()
    return handler.lambda_handler(event, context)
