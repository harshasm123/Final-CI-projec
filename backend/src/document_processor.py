import json
import os
import boto3
from typing import Dict, Any
from datetime import datetime
from services.opensearch_service import OpenSearchService
from services.s3_service import S3Service

class DocumentProcessor:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.s3 = S3Service()
        self.bedrock = boto3.client('bedrock-runtime')
        self.sns = boto3.client('sns')
        self.alert_topic = os.environ.get('ALERT_TOPIC', '')
    
    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Process documents uploaded to S3"""
        try:
            # Handle S3 event
            if 'Records' in event:
                for record in event['Records']:
                    if record.get('eventSource') == 'aws:s3':
                        bucket = record['s3']['bucket']['name']
                        key = record['s3']['object']['key']
                        
                        return self.process_s3_document(bucket, key)
            
            # Handle direct invocation
            return self.process_document_batch()
            
        except Exception as e:
            print(f"Document processing error: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': str(e)})
            }
    
    def process_s3_document(self, bucket: str, key: str) -> Dict[str, Any]:
        """Process a single document from S3"""
        try:
            # Get document content
            document_content = self.s3.get_document(key)
            if not document_content:
                return {'statusCode': 404, 'body': 'Document not found'}
            
            # Determine document type and process accordingly
            if key.endswith('.json'):
                return self.process_json_document(key, document_content)
            elif key.endswith('.pdf'):
                return self.process_pdf_document(key, document_content)
            else:
                return self.process_text_document(key, document_content)
                
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
    
    def process_json_document(self, key: str, content: bytes) -> Dict[str, Any]:
        """Process JSON document (metadata, structured data)"""
        try:
            data = json.loads(content.decode('utf-8'))
            
            # Extract key information
            doc_type = self.determine_document_type(data)
            
            if doc_type == 'clinical_trial':
                return self.process_clinical_trial_document(data)
            elif doc_type == 'regulatory':
                return self.process_regulatory_document(data)
            elif doc_type == 'patent':
                return self.process_patent_document(data)
            elif doc_type == 'news':
                return self.process_news_document(data)
            else:
                return self.process_generic_document(data)
                
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
    
    def process_clinical_trial_document(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Process clinical trial document with AI analysis"""
        try:
            # AI analysis of clinical trial
            analysis_prompt = f"""
            Analyze this clinical trial data for competitive intelligence:
            
            Title: {data.get('title', '')}
            Phase: {data.get('phase', '')}
            Status: {data.get('status', '')}
            Sponsor: {data.get('sponsor', '')}
            Condition: {data.get('condition', '')}
            
            Provide:
            1. Competitive threat level (1-10)
            2. Key brands impacted
            3. Strategic implications
            4. Risk assessment
            """
            
            ai_analysis = self.get_ai_analysis(analysis_prompt)
            
            # Enrich document with AI insights
            enriched_data = {
                **data,
                'aiAnalysis': ai_analysis,
                'competitiveThreatLevel': self.extract_threat_level(ai_analysis),
                'brandsImpacted': self.extract_brands_from_analysis(ai_analysis),
                'processedAt': datetime.now().isoformat(),
                'documentType': 'clinical_trial'
            }
            
            # Store in OpenSearch
            doc_id = data.get('id', f"trial-{datetime.now().timestamp()}")
            self.opensearch.index_document('trials', doc_id, enriched_data)
            
            # Check for alerts
            self.check_competitive_alerts(enriched_data)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Clinical trial processed successfully',
                    'documentId': doc_id,
                    'threatLevel': enriched_data.get('competitiveThreatLevel', 0)
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
    
    def process_regulatory_document(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Process regulatory document (FDA approvals, safety alerts)"""
        try:
            # AI analysis for regulatory impact
            analysis_prompt = f"""
            Analyze this regulatory document for pharmaceutical competitive intelligence:
            
            Title: {data.get('title', '')}
            Source: {data.get('source', '')}
            Type: {data.get('type', '')}
            Content: {data.get('content', '')[:1000]}
            
            Determine:
            1. Regulatory impact score (1-10)
            2. Affected pharmaceutical brands
            3. Market implications
            4. Urgency level for competitive response
            """
            
            ai_analysis = self.get_ai_analysis(analysis_prompt)
            
            enriched_data = {
                **data,
                'aiAnalysis': ai_analysis,
                'regulatoryImpact': self.extract_impact_score(ai_analysis),
                'brandsAffected': self.extract_brands_from_analysis(ai_analysis),
                'urgencyLevel': self.extract_urgency_level(ai_analysis),
                'processedAt': datetime.now().isoformat(),
                'documentType': 'regulatory'
            }
            
            # Store in OpenSearch
            doc_id = data.get('id', f"reg-{datetime.now().timestamp()}")
            self.opensearch.index_document('regulatory', doc_id, enriched_data)
            
            # Generate alert if high impact
            if enriched_data.get('regulatoryImpact', 0) >= 7:
                self.generate_regulatory_alert(enriched_data)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Regulatory document processed',
                    'documentId': doc_id,
                    'impact': enriched_data.get('regulatoryImpact', 0)
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
    
    def get_ai_analysis(self, prompt: str) -> str:
        """Get AI analysis using Bedrock"""
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
            print(f"AI analysis error: {str(e)}")
            return "AI analysis unavailable"
    
    def extract_threat_level(self, analysis: str) -> int:
        """Extract competitive threat level from AI analysis"""
        try:
            # Simple extraction - in production, use more sophisticated NLP
            if 'threat level' in analysis.lower():
                # Look for numbers 1-10
                import re
                matches = re.findall(r'threat level[:\s]*(\d+)', analysis.lower())
                if matches:
                    return min(int(matches[0]), 10)
            
            # Default scoring based on keywords
            high_threat_keywords = ['critical', 'major', 'significant', 'breakthrough']
            medium_threat_keywords = ['moderate', 'notable', 'important']
            
            analysis_lower = analysis.lower()
            
            if any(keyword in analysis_lower for keyword in high_threat_keywords):
                return 8
            elif any(keyword in analysis_lower for keyword in medium_threat_keywords):
                return 5
            else:
                return 3
                
        except Exception:
            return 3
    
    def extract_brands_from_analysis(self, analysis: str) -> list:
        """Extract mentioned brands from AI analysis"""
        brands = [
            'keytruda', 'pembrolizumab',
            'opdivo', 'nivolumab', 
            'tecentriq', 'atezolizumab',
            'imfinzi', 'durvalumab'
        ]
        
        analysis_lower = analysis.lower()
        mentioned_brands = [brand for brand in brands if brand in analysis_lower]
        
        return mentioned_brands
    
    def check_competitive_alerts(self, document_data: Dict[str, Any]) -> None:
        """Check if document should trigger competitive alerts"""
        try:
            threat_level = document_data.get('competitiveThreatLevel', 0)
            brands_impacted = document_data.get('brandsImpacted', [])
            
            if threat_level >= 7 and brands_impacted:
                alert_data = {
                    'id': f"comp-alert-{datetime.now().timestamp()}",
                    'title': f"High Competitive Threat Detected: {document_data.get('title', '')}",
                    'severity': 'high' if threat_level >= 8 else 'medium',
                    'source': 'Trials',
                    'brandImpacted': brands_impacted,
                    'description': f"Clinical trial with threat level {threat_level} detected",
                    'whyItMatters': document_data.get('aiAnalysis', '')[:200] + '...',
                    'createdAt': datetime.now().isoformat(),
                    'confidenceScore': 90
                }
                
                self.generate_alert(alert_data)
                
        except Exception as e:
            print(f"Error checking competitive alerts: {str(e)}")
    
    def generate_alert(self, alert_data: Dict[str, Any]) -> None:
        """Generate and store alert"""
        try:
            # Store in OpenSearch
            self.opensearch.index_document('alerts', alert_data['id'], alert_data)
            
            # Send SNS notification for high/critical alerts
            if alert_data.get('severity') in ['high', 'critical']:
                self.sns.publish(
                    TopicArn=self.alert_topic,
                    Message=json.dumps(alert_data),
                    Subject=f"{alert_data['severity'].title()} Alert: {alert_data['title']}"
                )
                
        except Exception as e:
            print(f"Error generating alert: {str(e)}")
    
    def determine_document_type(self, data: Dict[str, Any]) -> str:
        """Determine document type from data structure"""
        if 'nct_id' in data or 'phase' in data:
            return 'clinical_trial'
        elif 'fda' in str(data).lower() or 'regulatory' in str(data).lower():
            return 'regulatory'
        elif 'patent' in str(data).lower():
            return 'patent'
        elif 'news' in str(data).lower() or 'article' in str(data).lower():
            return 'news'
        else:
            return 'generic'
    
    def extract_impact_score(self, analysis: str) -> int:
        """Extract regulatory impact score from analysis"""
        # Similar to threat level extraction
        try:
            import re
            matches = re.findall(r'impact score[:\s]*(\d+)', analysis.lower())
            if matches:
                return min(int(matches[0]), 10)
            return 5  # Default medium impact
        except Exception:
            return 5
    
    def extract_urgency_level(self, analysis: str) -> str:
        """Extract urgency level from analysis"""
        analysis_lower = analysis.lower()
        
        if any(word in analysis_lower for word in ['urgent', 'immediate', 'critical']):
            return 'high'
        elif any(word in analysis_lower for word in ['moderate', 'medium']):
            return 'medium'
        else:
            return 'low'

# Lambda entry point
def lambda_handler(event, context):
    processor = DocumentProcessor()
    return processor.lambda_handler(event, context)