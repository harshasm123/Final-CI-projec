import json
import os
import boto3
import requests
from datetime import datetime, timedelta
from typing import Dict, Any, List
from services.opensearch_service import OpenSearchService
from services.s3_service import S3Service

class DataIngestionHandler:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.s3 = S3Service()
        self.sns = boto3.client('sns')
        self.alert_topic = os.environ.get('ALERT_TOPIC', '')
    
    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Main data ingestion handler"""
        try:
            # Determine data source from event
            source = event.get('source', 'scheduled')
            
            if source == 'pubmed':
                return self.ingest_pubmed_data()
            elif source == 'clinicaltrials':
                return self.ingest_clinical_trials()
            elif source == 'fda':
                return self.ingest_fda_data()
            elif source == 'patents':
                return self.ingest_patent_data()
            else:
                # Default scheduled ingestion
                return self.run_scheduled_ingestion()
                
        except Exception as e:
            print(f"Data ingestion error: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': str(e)})
            }
    
    def ingest_pubmed_data(self) -> Dict[str, Any]:
        """Ingest research papers from PubMed"""
        try:
            # PubMed search terms for pharmaceutical intelligence
            search_terms = [
                'pembrolizumab', 'nivolumab', 'atezolizumab',
                'PD-1 inhibitor', 'immunotherapy', 'cancer treatment'
            ]
            
            documents_processed = 0
            
            for term in search_terms:
                # PubMed API call (simplified)
                url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
                params = {
                    'db': 'pubmed',
                    'term': term,
                    'retmode': 'json',
                    'retmax': 20,
                    'datetype': 'pdat',
                    'reldate': 7  # Last 7 days
                }
                
                response = requests.get(url, params=params)
                if response.status_code == 200:
                    data = response.json()
                    pmids = data.get('esearchresult', {}).get('idlist', [])
                    
                    # Process each paper
                    for pmid in pmids:
                        paper_data = self.fetch_paper_details(pmid)
                        if paper_data:
                            self.process_research_paper(paper_data)
                            documents_processed += 1
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Processed {documents_processed} PubMed documents',
                    'source': 'pubmed'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
    
    def ingest_clinical_trials(self) -> Dict[str, Any]:
        """Ingest clinical trials data"""
        try:
            # ClinicalTrials.gov API
            base_url = "https://clinicaltrials.gov/api/query/study_fields"
            
            # Search for recent trials
            params = {
                'expr': 'pembrolizumab OR nivolumab OR atezolizumab',
                'fields': 'NCTId,BriefTitle,Phase,OverallStatus,Condition,Sponsor',
                'min_rnk': 1,
                'max_rnk': 50,
                'fmt': 'json'
            }
            
            response = requests.get(base_url, params=params)
            if response.status_code == 200:
                data = response.json()
                studies = data.get('StudyFieldsResponse', {}).get('StudyFields', [])
                
                for study in studies:
                    trial_data = self.process_clinical_trial(study)
                    if trial_data:
                        # Store in OpenSearch
                        self.opensearch.index_document(
                            'trials',
                            trial_data['id'],
                            trial_data
                        )
                        
                        # Check for alerts
                        self.check_trial_alerts(trial_data)
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': f'Processed {len(studies)} clinical trials',
                        'source': 'clinicaltrials'
                    })
                }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
    
    def ingest_fda_data(self) -> Dict[str, Any]:
        """Ingest FDA regulatory data"""
        try:
            # FDA API for drug approvals and safety alerts
            base_url = "https://api.fda.gov/drug/event.json"
            
            # Search for recent events
            params = {
                'search': 'patient.drug.medicinalproduct:"pembrolizumab" OR patient.drug.medicinalproduct:"nivolumab"',
                'limit': 20
            }
            
            response = requests.get(base_url, params=params)
            if response.status_code == 200:
                data = response.json()
                events = data.get('results', [])
                
                for event in events:
                    regulatory_data = self.process_fda_event(event)
                    if regulatory_data:
                        # Store in OpenSearch
                        self.opensearch.index_document(
                            'regulatory',
                            regulatory_data['id'],
                            regulatory_data
                        )
                        
                        # Generate alert if critical
                        if regulatory_data.get('severity') == 'critical':
                            self.generate_alert(regulatory_data)
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': f'Processed {len(events)} FDA events',
                        'source': 'fda'
                    })
                }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
    
    def process_research_paper(self, paper_data: Dict[str, Any]) -> None:
        """Process and store research paper data"""
        try:
            # Extract brand mentions and competitive intelligence
            brands_mentioned = self.extract_brand_mentions(paper_data.get('abstract', ''))
            
            processed_data = {
                'id': paper_data['pmid'],
                'title': paper_data.get('title', ''),
                'abstract': paper_data.get('abstract', ''),
                'authors': paper_data.get('authors', []),
                'journal': paper_data.get('journal', ''),
                'publishedDate': paper_data.get('published_date', ''),
                'brandsmentioned': brands_mentioned,
                'source': 'pubmed',
                'processedAt': datetime.now().isoformat()
            }
            
            # Store in S3 and index in OpenSearch
            self.s3.store_metadata(f"papers/{paper_data['pmid']}.json", processed_data)
            self.opensearch.index_document('papers', paper_data['pmid'], processed_data)
            
        except Exception as e:
            print(f"Error processing paper: {str(e)}")
    
    def process_clinical_trial(self, study: Dict[str, Any]) -> Dict[str, Any]:
        """Process clinical trial data"""
        try:
            nct_id = study.get('NCTId', [''])[0]
            
            return {
                'id': nct_id,
                'title': study.get('BriefTitle', [''])[0],
                'phase': study.get('Phase', [''])[0],
                'status': study.get('OverallStatus', [''])[0],
                'condition': study.get('Condition', [''])[0],
                'sponsor': study.get('Sponsor', [''])[0],
                'source': 'clinicaltrials.gov',
                'processedAt': datetime.now().isoformat()
            }
        except Exception as e:
            print(f"Error processing trial: {str(e)}")
            return {}
    
    def extract_brand_mentions(self, text: str) -> List[str]:
        """Extract pharmaceutical brand mentions from text"""
        brands = [
            'keytruda', 'pembrolizumab',
            'opdivo', 'nivolumab',
            'tecentriq', 'atezolizumab',
            'imfinzi', 'durvalumab'
        ]
        
        text_lower = text.lower()
        mentioned_brands = [brand for brand in brands if brand in text_lower]
        
        return mentioned_brands
    
    def check_trial_alerts(self, trial_data: Dict[str, Any]) -> None:
        """Check if trial data should generate alerts"""
        try:
            # Alert conditions
            alert_conditions = [
                trial_data.get('phase') == 'Phase 3',
                'completed' in trial_data.get('status', '').lower(),
                any(brand in trial_data.get('title', '').lower() 
                    for brand in ['pembrolizumab', 'nivolumab', 'atezolizumab'])
            ]
            
            if any(alert_conditions):
                alert_data = {
                    'id': f"trial-alert-{trial_data['id']}",
                    'title': f"Clinical Trial Update: {trial_data.get('title', '')}",
                    'severity': 'medium',
                    'source': 'Trials',
                    'brandImpacted': self.extract_brand_mentions(trial_data.get('title', '')),
                    'description': f"Trial {trial_data['id']} status: {trial_data.get('status', '')}",
                    'whyItMatters': 'Clinical trial progression may impact competitive landscape',
                    'createdAt': datetime.now().isoformat(),
                    'confidenceScore': 85
                }
                
                self.generate_alert(alert_data)
                
        except Exception as e:
            print(f"Error checking trial alerts: {str(e)}")
    
    def generate_alert(self, alert_data: Dict[str, Any]) -> None:
        """Generate and store alert"""
        try:
            # Store alert in OpenSearch
            self.opensearch.index_document('alerts', alert_data['id'], alert_data)
            
            # Send SNS notification for critical alerts
            if alert_data.get('severity') == 'critical':
                self.sns.publish(
                    TopicArn=self.alert_topic,
                    Message=json.dumps(alert_data),
                    Subject=f"Critical Alert: {alert_data['title']}"
                )
                
        except Exception as e:
            print(f"Error generating alert: {str(e)}")
    
    def fetch_paper_details(self, pmid: str) -> Dict[str, Any]:
        """Fetch detailed paper information from PubMed"""
        try:
            # Simplified - in production, use proper PubMed API
            return {
                'pmid': pmid,
                'title': f'Research Paper {pmid}',
                'abstract': 'Sample abstract mentioning pembrolizumab and competitive analysis',
                'authors': ['Author 1', 'Author 2'],
                'journal': 'Journal of Oncology',
                'published_date': datetime.now().isoformat()
            }
        except Exception as e:
            print(f"Error fetching paper details: {str(e)}")
            return {}
    
    def run_scheduled_ingestion(self) -> Dict[str, Any]:
        """Run all scheduled data ingestion tasks"""
        results = []
        
        # Run each ingestion source
        sources = ['pubmed', 'clinicaltrials', 'fda']
        
        for source in sources:
            try:
                if source == 'pubmed':
                    result = self.ingest_pubmed_data()
                elif source == 'clinicaltrials':
                    result = self.ingest_clinical_trials()
                elif source == 'fda':
                    result = self.ingest_fda_data()
                
                results.append({
                    'source': source,
                    'status': 'success' if result['statusCode'] == 200 else 'error',
                    'message': json.loads(result['body']).get('message', '')
                })
            except Exception as e:
                results.append({
                    'source': source,
                    'status': 'error',
                    'message': str(e)
                })
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Scheduled ingestion completed',
                'results': results
            })
        }

# Lambda entry point
def lambda_handler(event, context):
    handler = DataIngestionHandler()
    return handler.lambda_handler(event, context)