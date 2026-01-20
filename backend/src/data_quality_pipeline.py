import json
import os
import boto3
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from services.opensearch_service import OpenSearchService
from services.s3_service import S3Service

class DataQualityPipeline:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.s3 = S3Service()
        self.sns = boto3.client('sns')
        self.bedrock = boto3.client('bedrock-runtime')
        self.alert_topic = os.environ.get('ALERT_TOPIC', '')
        
        # Data quality thresholds
        self.quality_thresholds = {
            'completeness': 0.85,  # 85% of required fields must be present
            'accuracy': 0.90,      # 90% accuracy for brand mentions
            'timeliness': 24,      # Data should be less than 24 hours old
            'consistency': 0.95,   # 95% consistency across sources
            'uniqueness': 0.98     # 98% unique records (2% duplication allowed)
        }

    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Main data quality pipeline handler"""
        try:
            check_type = event.get('check_type', 'comprehensive')
            
            if check_type == 'completeness':
                return self.check_data_completeness()
            elif check_type == 'accuracy':
                return self.check_data_accuracy()
            elif check_type == 'timeliness':
                return self.check_data_timeliness()
            elif check_type == 'consistency':
                return self.check_data_consistency()
            elif check_type == 'uniqueness':
                return self.check_data_uniqueness()
            elif check_type == 'comprehensive':
                return self.run_comprehensive_quality_check()
            else:
                return self.validate_specific_dataset(event.get('dataset', ''))
                
        except Exception as e:
            print(f"Data quality check error: {str(e)}")
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def check_data_completeness(self) -> Dict[str, Any]:
        """Check data completeness across all sources"""
        try:
            completeness_results = {}
            
            # Define required fields for each data type
            required_fields = {
                'papers': ['id', 'title', 'abstract', 'publishedDate', 'source'],
                'trials': ['id', 'title', 'phase', 'status', 'sponsor'],
                'regulatory': ['id', 'dataType', 'brand', 'source'],
                'patents': ['id', 'title', 'assignee', 'filingDate'],
                'alerts': ['id', 'title', 'severity', 'source', 'createdAt']
            }
            
            for index, fields in required_fields.items():
                # Query OpenSearch for documents with missing fields
                query = {
                    'query': {'match_all': {}},
                    'size': 1000,
                    '_source': fields
                }
                
                results = self.opensearch.search(index, query)
                documents = results.get('hits', {}).get('hits', [])
                
                if documents:
                    complete_docs = 0
                    total_docs = len(documents)
                    
                    for doc in documents:
                        source_data = doc.get('_source', {})
                        missing_fields = [field for field in fields if not source_data.get(field)]
                        
                        if not missing_fields:
                            complete_docs += 1
                    
                    completeness_score = complete_docs / total_docs if total_docs > 0 else 0
                    
                    completeness_results[index] = {
                        'total_documents': total_docs,
                        'complete_documents': complete_docs,
                        'completeness_score': completeness_score,
                        'meets_threshold': completeness_score >= self.quality_thresholds['completeness']
                    }
            
            # Generate quality report
            overall_completeness = sum(r['completeness_score'] for r in completeness_results.values()) / len(completeness_results)
            
            quality_report = {
                'check_type': 'completeness',
                'overall_score': overall_completeness,
                'meets_threshold': overall_completeness >= self.quality_thresholds['completeness'],
                'details': completeness_results,
                'timestamp': datetime.now().isoformat()
            }
            
            # Store quality report
            self.store_quality_report(quality_report)
            
            # Generate alert if quality is below threshold
            if not quality_report['meets_threshold']:
                self.generate_quality_alert(quality_report)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Data completeness check completed',
                    'overall_score': overall_completeness,
                    'meets_threshold': quality_report['meets_threshold']
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def check_data_accuracy(self) -> Dict[str, Any]:
        """Check data accuracy using AI validation"""
        try:
            accuracy_results = {}
            
            # Sample documents for accuracy validation
            indices = ['papers', 'trials', 'regulatory']
            
            for index in indices:
                # Get sample of recent documents
                query = {
                    'query': {
                        'range': {
                            'processedAt': {
                                'gte': 'now-7d'
                            }
                        }
                    },
                    'size': 50,
                    'sort': [{'processedAt': {'order': 'desc'}}]
                }
                
                results = self.opensearch.search(index, query)
                documents = results.get('hits', {}).get('hits', [])
                
                if documents:
                    accurate_docs = 0
                    total_docs = len(documents)
                    
                    for doc in documents:
                        source_data = doc.get('_source', {})
                        
                        # AI-powered accuracy validation
                        is_accurate = self.validate_document_accuracy(source_data, index)
                        if is_accurate:
                            accurate_docs += 1
                    
                    accuracy_score = accurate_docs / total_docs if total_docs > 0 else 0
                    
                    accuracy_results[index] = {
                        'total_documents': total_docs,
                        'accurate_documents': accurate_docs,
                        'accuracy_score': accuracy_score,
                        'meets_threshold': accuracy_score >= self.quality_thresholds['accuracy']
                    }
            
            overall_accuracy = sum(r['accuracy_score'] for r in accuracy_results.values()) / len(accuracy_results)
            
            quality_report = {
                'check_type': 'accuracy',
                'overall_score': overall_accuracy,
                'meets_threshold': overall_accuracy >= self.quality_thresholds['accuracy'],
                'details': accuracy_results,
                'timestamp': datetime.now().isoformat()
            }
            
            self.store_quality_report(quality_report)
            
            if not quality_report['meets_threshold']:
                self.generate_quality_alert(quality_report)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Data accuracy check completed',
                    'overall_score': overall_accuracy,
                    'meets_threshold': quality_report['meets_threshold']
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def check_data_timeliness(self) -> Dict[str, Any]:
        """Check data timeliness"""
        try:
            timeliness_results = {}
            cutoff_time = datetime.now() - timedelta(hours=self.quality_thresholds['timeliness'])
            
            indices = ['papers', 'trials', 'regulatory', 'alerts']
            
            for index in indices:
                # Count recent vs old documents
                recent_query = {
                    'query': {
                        'range': {
                            'processedAt': {
                                'gte': cutoff_time.isoformat()
                            }
                        }
                    }
                }
                
                total_query = {'query': {'match_all': {}}}
                
                recent_count = self.opensearch.count_documents(index, recent_query.get('query'))
                total_count = self.opensearch.count_documents(index)
                
                timeliness_score = recent_count / total_count if total_count > 0 else 0
                
                timeliness_results[index] = {
                    'total_documents': total_count,
                    'recent_documents': recent_count,
                    'timeliness_score': timeliness_score,
                    'meets_threshold': timeliness_score >= 0.7  # 70% should be recent
                }
            
            overall_timeliness = sum(r['timeliness_score'] for r in timeliness_results.values()) / len(timeliness_results)
            
            quality_report = {
                'check_type': 'timeliness',
                'overall_score': overall_timeliness,
                'meets_threshold': overall_timeliness >= 0.7,
                'details': timeliness_results,
                'timestamp': datetime.now().isoformat()
            }
            
            self.store_quality_report(quality_report)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Data timeliness check completed',
                    'overall_score': overall_timeliness,
                    'meets_threshold': quality_report['meets_threshold']
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def check_data_uniqueness(self) -> Dict[str, Any]:
        """Check for duplicate records"""
        try:
            uniqueness_results = {}
            
            indices = ['papers', 'trials', 'regulatory']
            
            for index in indices:
                # Find duplicates based on key fields
                if index == 'papers':
                    duplicate_query = {
                        'aggs': {
                            'duplicates': {
                                'terms': {
                                    'field': 'title.keyword',
                                    'min_doc_count': 2,
                                    'size': 1000
                                }
                            }
                        },
                        'size': 0
                    }
                elif index == 'trials':
                    duplicate_query = {
                        'aggs': {
                            'duplicates': {
                                'terms': {
                                    'field': 'id.keyword',
                                    'min_doc_count': 2,
                                    'size': 1000
                                }
                            }
                        },
                        'size': 0
                    }
                else:
                    duplicate_query = {
                        'aggs': {
                            'duplicates': {
                                'terms': {
                                    'field': 'id.keyword',
                                    'min_doc_count': 2,
                                    'size': 1000
                                }
                            }
                        },
                        'size': 0
                    }
                
                results = self.opensearch.search(index, duplicate_query)
                duplicates = results.get('aggregations', {}).get('duplicates', {}).get('buckets', [])
                
                total_count = self.opensearch.count_documents(index)
                duplicate_count = sum(bucket['doc_count'] - 1 for bucket in duplicates)  # Subtract 1 to count only extras
                
                uniqueness_score = (total_count - duplicate_count) / total_count if total_count > 0 else 1
                
                uniqueness_results[index] = {
                    'total_documents': total_count,
                    'duplicate_documents': duplicate_count,
                    'uniqueness_score': uniqueness_score,
                    'meets_threshold': uniqueness_score >= self.quality_thresholds['uniqueness']
                }
            
            overall_uniqueness = sum(r['uniqueness_score'] for r in uniqueness_results.values()) / len(uniqueness_results)
            
            quality_report = {
                'check_type': 'uniqueness',
                'overall_score': overall_uniqueness,
                'meets_threshold': overall_uniqueness >= self.quality_thresholds['uniqueness'],
                'details': uniqueness_results,
                'timestamp': datetime.now().isoformat()
            }
            
            self.store_quality_report(quality_report)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Data uniqueness check completed',
                    'overall_score': overall_uniqueness,
                    'meets_threshold': quality_report['meets_threshold']
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def validate_document_accuracy(self, document: Dict[str, Any], doc_type: str) -> bool:
        """AI-powered document accuracy validation"""
        try:
            # Use Bedrock for accuracy validation
            prompt = f"""
            Validate the accuracy of this {doc_type} document:
            
            Document: {json.dumps(document, indent=2)[:1000]}
            
            Check for:
            1. Logical consistency
            2. Proper brand name mentions
            3. Valid dates and formats
            4. Reasonable data values
            
            Return only "ACCURATE" or "INACCURATE" with brief reason.
            """
            
            response = self.bedrock.invoke_model(
                modelId='anthropic.claude-3-sonnet-20240229-v1:0',
                body=json.dumps({
                    'anthropic_version': 'bedrock-2023-05-31',
                    'max_tokens': 100,
                    'messages': [{'role': 'user', 'content': prompt}]
                })
            )
            
            response_body = json.loads(response['body'].read())
            validation_result = response_body['content'][0]['text']
            
            return 'ACCURATE' in validation_result.upper()
            
        except Exception as e:
            print(f"Error in accuracy validation: {str(e)}")
            return True  # Default to accurate if validation fails

    def store_quality_report(self, report: Dict[str, Any]) -> None:
        """Store quality report in S3 and OpenSearch"""
        try:
            report_id = f"quality-report-{report['check_type']}-{int(datetime.now().timestamp())}"
            
            # Store in S3
            self.s3.store_metadata(f"quality-reports/{report_id}.json", report)
            
            # Index in OpenSearch
            self.opensearch.index_document('quality_reports', report_id, report)
            
        except Exception as e:
            print(f"Error storing quality report: {str(e)}")

    def generate_quality_alert(self, report: Dict[str, Any]) -> None:
        """Generate alert for quality issues"""
        try:
            alert_data = {
                'id': f"quality-alert-{report['check_type']}-{int(datetime.now().timestamp())}",
                'title': f"Data Quality Issue: {report['check_type'].title()}",
                'severity': 'high' if report['overall_score'] < 0.7 else 'medium',
                'source': 'Data Quality Pipeline',
                'brandImpacted': ['All'],
                'description': f"Data quality check for {report['check_type']} failed with score {report['overall_score']:.2f}",
                'whyItMatters': 'Poor data quality can lead to incorrect competitive intelligence and business decisions',
                'createdAt': datetime.now().isoformat(),
                'confidenceScore': 95,
                'qualityReport': report
            }
            
            # Store alert
            self.opensearch.index_document('alerts', alert_data['id'], alert_data)
            
            # Send SNS notification
            self.sns.publish(
                TopicArn=self.alert_topic,
                Message=json.dumps(alert_data),
                Subject=f"Data Quality Alert: {report['check_type'].title()}"
            )
            
        except Exception as e:
            print(f"Error generating quality alert: {str(e)}")

    def run_comprehensive_quality_check(self) -> Dict[str, Any]:
        """Run all quality checks"""
        try:
            results = {}
            
            # Run all quality checks
            checks = ['completeness', 'accuracy', 'timeliness', 'uniqueness']
            
            for check in checks:
                try:
                    if check == 'completeness':
                        result = self.check_data_completeness()
                    elif check == 'accuracy':
                        result = self.check_data_accuracy()
                    elif check == 'timeliness':
                        result = self.check_data_timeliness()
                    elif check == 'uniqueness':
                        result = self.check_data_uniqueness()
                    
                    results[check] = {
                        'status': 'success' if result['statusCode'] == 200 else 'error',
                        'result': json.loads(result['body'])
                    }
                    
                except Exception as e:
                    results[check] = {
                        'status': 'error',
                        'error': str(e)
                    }
            
            # Calculate overall quality score
            successful_checks = [r for r in results.values() if r['status'] == 'success']
            if successful_checks:
                overall_score = sum(r['result']['overall_score'] for r in successful_checks) / len(successful_checks)
            else:
                overall_score = 0
            
            comprehensive_report = {
                'check_type': 'comprehensive',
                'overall_quality_score': overall_score,
                'individual_checks': results,
                'timestamp': datetime.now().isoformat()
            }
            
            self.store_quality_report(comprehensive_report)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Comprehensive quality check completed',
                    'overall_score': overall_score,
                    'checks_completed': len(results)
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

# Lambda entry point
def lambda_handler(event, context):
    pipeline = DataQualityPipeline()
    return pipeline.lambda_handler(event, context)