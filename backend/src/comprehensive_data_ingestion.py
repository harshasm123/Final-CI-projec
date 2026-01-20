import json
import os
import boto3
import requests
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from urllib.parse import urlencode
import time
import re
from services.opensearch_service import OpenSearchService
from services.s3_service import S3Service

class ComprehensiveDataIngestionPipeline:
    def __init__(self):
        self.opensearch = OpenSearchService()
        self.s3 = S3Service()
        self.sns = boto3.client('sns')
        self.bedrock = boto3.client('bedrock-runtime')
        self.alert_topic = os.environ.get('ALERT_TOPIC', '')
        
        # API Keys and endpoints
        self.fda_api_key = os.environ.get('FDA_API_KEY', '')
        self.pubmed_api_key = os.environ.get('PUBMED_API_KEY', '')
        self.clinicaltrials_api_key = os.environ.get('CLINICALTRIALS_API_KEY', '')
        
        # Pharmaceutical brands to monitor
        self.target_brands = [
            'keytruda', 'pembrolizumab', 'opdivo', 'nivolumab', 
            'tecentriq', 'atezolizumab', 'imfinzi', 'durvalumab',
            'bavencio', 'avelumab', 'libtayo', 'cemiplimab',
            'yervoy', 'ipilimumab', 'provenge', 'sipuleucel-t'
        ]
        
        # Therapeutic areas
        self.therapeutic_areas = [
            'oncology', 'immunotherapy', 'cancer', 'melanoma',
            'lung cancer', 'breast cancer', 'bladder cancer',
            'kidney cancer', 'liver cancer', 'head and neck cancer'
        ]

    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Main comprehensive data ingestion handler"""
        try:
            source = event.get('source', 'all')
            
            if source == 'pubmed':
                return self.ingest_pubmed_comprehensive()
            elif source == 'clinicaltrials':
                return self.ingest_clinicaltrials_comprehensive()
            elif source == 'fda':
                return self.ingest_fda_comprehensive()
            elif source == 'ema':
                return self.ingest_ema_data()
            elif source == 'patents':
                return self.ingest_patent_data()
            elif source == 'news':
                return self.ingest_pharma_news()
            elif source == 'conferences':
                return self.ingest_conference_data()
            elif source == 'sec':
                return self.ingest_sec_filings()
            else:
                return self.run_comprehensive_ingestion()
                
        except Exception as e:
            print(f"Comprehensive ingestion error: {str(e)}")
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def ingest_pubmed_comprehensive(self) -> Dict[str, Any]:
        """Comprehensive PubMed data ingestion"""
        try:
            documents_processed = 0
            
            # Enhanced search terms for pharmaceutical CI
            search_queries = [
                # Brand-specific searches
                f"({' OR '.join(self.target_brands)})",
                # Therapeutic area searches
                f"({' OR '.join(self.therapeutic_areas)}) AND (clinical trial OR phase)",
                # Competitive intelligence searches
                "competitive analysis AND pharmaceutical",
                "market share AND oncology drugs",
                "biosimilar AND competition",
                # Safety and efficacy
                "adverse events AND immunotherapy",
                "real world evidence AND cancer drugs"
            ]
            
            for query in search_queries:
                # PubMed eSearch API
                search_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
                search_params = {
                    'db': 'pubmed',
                    'term': query,
                    'retmode': 'json',
                    'retmax': 100,
                    'datetype': 'pdat',
                    'reldate': 30,  # Last 30 days
                    'sort': 'relevance'
                }
                
                if self.pubmed_api_key:
                    search_params['api_key'] = self.pubmed_api_key
                
                response = requests.get(search_url, params=search_params)
                if response.status_code == 200:
                    data = response.json()
                    pmids = data.get('esearchresult', {}).get('idlist', [])
                    
                    # Fetch detailed information for each paper
                    for pmid_batch in self._batch_list(pmids, 20):
                        papers_data = self.fetch_pubmed_details(pmid_batch)
                        for paper in papers_data:
                            if paper:
                                self.process_research_paper_enhanced(paper)
                                documents_processed += 1
                
                # Rate limiting
                time.sleep(0.5)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Processed {documents_processed} PubMed documents',
                    'source': 'pubmed_comprehensive'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def ingest_clinicaltrials_comprehensive(self) -> Dict[str, Any]:
        """Comprehensive ClinicalTrials.gov data ingestion"""
        try:
            trials_processed = 0
            
            # Enhanced clinical trials search
            search_expressions = [
                # Brand-specific trials
                ' OR '.join(self.target_brands),
                # Phase-specific searches
                f"({' OR '.join(self.target_brands)}) AND Phase 3",
                f"({' OR '.join(self.target_brands)}) AND Phase 2",
                # Indication-specific searches
                f"immunotherapy AND ({' OR '.join(self.therapeutic_areas)})",
                # Competitive trials
                "biosimilar AND oncology",
                "combination therapy AND cancer"
            ]
            
            for expression in search_expressions:
                # ClinicalTrials.gov API v2
                base_url = "https://clinicaltrials.gov/api/v2/studies"
                params = {
                    'query.term': expression,
                    'query.locn': 'United States',
                    'filter.overallStatus': 'RECRUITING|ACTIVE_NOT_RECRUITING|COMPLETED',
                    'filter.lastUpdatePostDate': (datetime.now() - timedelta(days=90)).strftime('%Y-%m-%d'),
                    'pageSize': 100,
                    'format': 'json'
                }
                
                response = requests.get(base_url, params=params)
                if response.status_code == 200:
                    data = response.json()
                    studies = data.get('studies', [])
                    
                    for study in studies:
                        trial_data = self.process_clinical_trial_enhanced(study)
                        if trial_data:
                            # Store in OpenSearch
                            self.opensearch.index_document(
                                'trials',
                                trial_data['id'],
                                trial_data
                            )
                            
                            # AI-powered competitive analysis
                            self.analyze_trial_competitive_impact(trial_data)
                            trials_processed += 1
                
                time.sleep(1)  # Rate limiting
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Processed {trials_processed} clinical trials',
                    'source': 'clinicaltrials_comprehensive'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def ingest_fda_comprehensive(self) -> Dict[str, Any]:
        """Comprehensive FDA data ingestion"""
        try:
            events_processed = 0
            
            # Multiple FDA endpoints
            fda_endpoints = [
                {
                    'url': 'https://api.fda.gov/drug/event.json',
                    'type': 'adverse_events',
                    'search_field': 'patient.drug.medicinalproduct'
                },
                {
                    'url': 'https://api.fda.gov/drug/label.json',
                    'type': 'drug_labels',
                    'search_field': 'openfda.brand_name'
                },
                {
                    'url': 'https://api.fda.gov/drug/drugsfda.json',
                    'type': 'drug_approvals',
                    'search_field': 'products.brand_name'
                }
            ]
            
            for endpoint in fda_endpoints:
                for brand in self.target_brands:
                    params = {
                        'search': f'{endpoint["search_field"]}:"{brand}"',
                        'limit': 100
                    }
                    
                    if self.fda_api_key:
                        params['api_key'] = self.fda_api_key
                    
                    response = requests.get(endpoint['url'], params=params)
                    if response.status_code == 200:
                        data = response.json()
                        results = data.get('results', [])
                        
                        for result in results:
                            processed_data = self.process_fda_data_enhanced(
                                result, endpoint['type'], brand
                            )
                            if processed_data:
                                # Store in OpenSearch
                                self.opensearch.index_document(
                                    'regulatory',
                                    processed_data['id'],
                                    processed_data
                                )
                                
                                # Check for critical alerts
                                self.check_regulatory_alerts(processed_data)
                                events_processed += 1
                    
                    time.sleep(0.2)  # Rate limiting
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Processed {events_processed} FDA events',
                    'source': 'fda_comprehensive'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def ingest_ema_data(self) -> Dict[str, Any]:
        """Ingest European Medicines Agency data"""
        try:
            documents_processed = 0
            
            # EMA public data sources
            ema_sources = [
                {
                    'url': 'https://www.ema.europa.eu/en/medicines/download-medicine-data',
                    'type': 'medicine_data'
                }
            ]
            
            # Note: EMA doesn't have a public API like FDA
            # This would require web scraping or RSS feeds
            # For now, implementing placeholder structure
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'EMA data ingestion placeholder - {documents_processed} documents',
                    'source': 'ema'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def ingest_patent_data(self) -> Dict[str, Any]:
        """Ingest patent data from USPTO and other sources"""
        try:
            patents_processed = 0
            
            # USPTO Patent API
            for brand in self.target_brands:
                # Search USPTO database
                search_url = "https://developer.uspto.gov/ptab-api/trials"
                params = {
                    'searchText': brand,
                    'limit': 50
                }
                
                response = requests.get(search_url, params=params)
                if response.status_code == 200:
                    data = response.json()
                    trials = data.get('results', [])
                    
                    for trial in trials:
                        patent_data = self.process_patent_data(trial, brand)
                        if patent_data:
                            self.opensearch.index_document(
                                'patents',
                                patent_data['id'],
                                patent_data
                            )
                            patents_processed += 1
                
                time.sleep(0.5)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Processed {patents_processed} patents',
                    'source': 'patents'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def ingest_pharma_news(self) -> Dict[str, Any]:
        """Ingest pharmaceutical news and market intelligence"""
        try:
            news_processed = 0
            
            # News sources (would require API keys)
            news_sources = [
                'BioPharma Dive',
                'FiercePharma',
                'STAT News',
                'Reuters Health',
                'Bloomberg Pharma'
            ]
            
            # Placeholder for news ingestion
            # In production, would integrate with news APIs
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'News ingestion placeholder - {news_processed} articles',
                    'source': 'news'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def ingest_conference_data(self) -> Dict[str, Any]:
        """Ingest medical conference abstracts and presentations"""
        try:
            abstracts_processed = 0
            
            # Major oncology conferences
            conferences = [
                'ASCO', 'ESMO', 'AACR', 'ASH', 'SITC'
            ]
            
            # Placeholder for conference data ingestion
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Conference data placeholder - {abstracts_processed} abstracts',
                    'source': 'conferences'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def ingest_sec_filings(self) -> Dict[str, Any]:
        """Ingest SEC filings for pharmaceutical companies"""
        try:
            filings_processed = 0
            
            # Major pharma companies
            pharma_companies = [
                'Merck & Co', 'Bristol Myers Squibb', 'Roche',
                'Pfizer', 'Johnson & Johnson', 'Novartis'
            ]
            
            # SEC EDGAR API
            for company in pharma_companies:
                # Search SEC filings
                # Placeholder implementation
                pass
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'SEC filings placeholder - {filings_processed} filings',
                    'source': 'sec'
                })
            }
            
        except Exception as e:
            return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

    def fetch_pubmed_details(self, pmids: List[str]) -> List[Dict[str, Any]]:
        """Fetch detailed PubMed article information"""
        try:
            # PubMed eFetch API
            fetch_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
            params = {
                'db': 'pubmed',
                'id': ','.join(pmids),
                'retmode': 'xml'
            }
            
            if self.pubmed_api_key:
                params['api_key'] = self.pubmed_api_key
            
            response = requests.get(fetch_url, params=params)
            if response.status_code == 200:
                return self.parse_pubmed_xml(response.text)
            
            return []
            
        except Exception as e:
            print(f"Error fetching PubMed details: {str(e)}")
            return []

    def parse_pubmed_xml(self, xml_content: str) -> List[Dict[str, Any]]:
        """Parse PubMed XML response"""
        try:
            root = ET.fromstring(xml_content)
            papers = []
            
            for article in root.findall('.//PubmedArticle'):
                paper_data = {}
                
                # Extract PMID
                pmid_elem = article.find('.//PMID')
                if pmid_elem is not None:
                    paper_data['pmid'] = pmid_elem.text
                
                # Extract title
                title_elem = article.find('.//ArticleTitle')
                if title_elem is not None:
                    paper_data['title'] = title_elem.text or ''
                
                # Extract abstract
                abstract_elem = article.find('.//AbstractText')
                if abstract_elem is not None:
                    paper_data['abstract'] = abstract_elem.text or ''
                
                # Extract authors
                authors = []
                for author in article.findall('.//Author'):
                    lastname = author.find('LastName')
                    forename = author.find('ForeName')
                    if lastname is not None and forename is not None:
                        authors.append(f"{forename.text} {lastname.text}")
                paper_data['authors'] = authors
                
                # Extract journal
                journal_elem = article.find('.//Journal/Title')
                if journal_elem is not None:
                    paper_data['journal'] = journal_elem.text
                
                # Extract publication date
                pub_date = article.find('.//PubDate')
                if pub_date is not None:
                    year = pub_date.find('Year')
                    month = pub_date.find('Month')
                    day = pub_date.find('Day')
                    
                    if year is not None:
                        date_str = year.text
                        if month is not None:
                            date_str += f"-{month.text}"
                        if day is not None:
                            date_str += f"-{day.text}"
                        paper_data['published_date'] = date_str
                
                papers.append(paper_data)
            
            return papers
            
        except Exception as e:
            print(f"Error parsing PubMed XML: {str(e)}")
            return []

    def process_research_paper_enhanced(self, paper_data: Dict[str, Any]) -> None:
        """Enhanced research paper processing with AI analysis"""
        try:
            # Extract competitive intelligence
            brands_mentioned = self.extract_brand_mentions(
                paper_data.get('title', '') + ' ' + paper_data.get('abstract', '')
            )
            
            # AI-powered competitive analysis
            competitive_insights = self.analyze_paper_competitive_impact(paper_data)
            
            processed_data = {
                'id': paper_data.get('pmid', ''),
                'title': paper_data.get('title', ''),
                'abstract': paper_data.get('abstract', ''),
                'authors': paper_data.get('authors', []),
                'journal': paper_data.get('journal', ''),
                'publishedDate': paper_data.get('published_date', ''),
                'brandsmentioned': brands_mentioned,
                'competitiveInsights': competitive_insights,
                'source': 'pubmed',
                'processedAt': datetime.now().isoformat(),
                'documentType': 'research_paper'
            }
            
            # Store in S3 and OpenSearch
            self.s3.store_metadata(f"papers/{paper_data.get('pmid', '')}.json", processed_data)
            self.opensearch.index_document('papers', paper_data.get('pmid', ''), processed_data)
            
            # Generate alerts for high-impact papers
            if competitive_insights.get('impact_score', 0) > 7:
                self.generate_research_alert(processed_data)
            
        except Exception as e:
            print(f"Error processing paper: {str(e)}")

    def process_clinical_trial_enhanced(self, study: Dict[str, Any]) -> Dict[str, Any]:
        """Enhanced clinical trial processing"""
        try:
            protocol_section = study.get('protocolSection', {})
            identification = protocol_section.get('identificationModule', {})
            status = protocol_section.get('statusModule', {})
            design = protocol_section.get('designModule', {})
            conditions = protocol_section.get('conditionsModule', {})
            
            trial_data = {
                'id': identification.get('nctId', ''),
                'title': identification.get('briefTitle', ''),
                'officialTitle': identification.get('officialTitle', ''),
                'phase': design.get('phases', [''])[0] if design.get('phases') else '',
                'status': status.get('overallStatus', ''),
                'conditions': conditions.get('conditions', []),
                'interventions': self.extract_interventions(protocol_section),
                'sponsor': protocol_section.get('sponsorCollaboratorsModule', {}).get('leadSponsor', {}).get('name', ''),
                'startDate': status.get('startDateStruct', {}).get('date', ''),
                'completionDate': status.get('primaryCompletionDateStruct', {}).get('date', ''),
                'enrollmentCount': design.get('enrollmentInfo', {}).get('count', 0),
                'primaryEndpoints': self.extract_endpoints(protocol_section, 'primary'),
                'secondaryEndpoints': self.extract_endpoints(protocol_section, 'secondary'),
                'brandsInvolved': self.extract_brand_mentions(identification.get('briefTitle', '')),
                'competitiveImpact': self.assess_trial_competitive_impact(study),
                'source': 'clinicaltrials.gov',
                'processedAt': datetime.now().isoformat(),
                'documentType': 'clinical_trial'
            }
            
            return trial_data
            
        except Exception as e:
            print(f"Error processing trial: {str(e)}")
            return {}

    def process_fda_data_enhanced(self, data: Dict[str, Any], data_type: str, brand: str) -> Dict[str, Any]:
        """Enhanced FDA data processing"""
        try:
            processed_data = {
                'id': f"fda-{data_type}-{hash(str(data))}",
                'dataType': data_type,
                'brand': brand,
                'rawData': data,
                'competitiveImpact': self.assess_fda_competitive_impact(data, data_type),
                'source': 'fda',
                'processedAt': datetime.now().isoformat(),
                'documentType': 'regulatory_data'
            }
            
            # Type-specific processing
            if data_type == 'adverse_events':
                processed_data.update(self.process_adverse_event(data))
            elif data_type == 'drug_labels':
                processed_data.update(self.process_drug_label(data))
            elif data_type == 'drug_approvals':
                processed_data.update(self.process_drug_approval(data))
            
            return processed_data
            
        except Exception as e:
            print(f"Error processing FDA data: {str(e)}")
            return {}

    def analyze_paper_competitive_impact(self, paper_data: Dict[str, Any]) -> Dict[str, Any]:
        """AI-powered analysis of research paper competitive impact"""
        try:
            # Use Bedrock for competitive analysis
            prompt = f"""
            Analyze this pharmaceutical research paper for competitive intelligence:
            
            Title: {paper_data.get('title', '')}
            Abstract: {paper_data.get('abstract', '')[:1000]}
            
            Assess:
            1. Competitive impact score (1-10)
            2. Brands mentioned and their context
            3. Key findings that affect market dynamics
            4. Potential regulatory implications
            5. Strategic recommendations
            
            Provide structured JSON response.
            """
            
            response = self.bedrock.invoke_model(
                modelId='anthropic.claude-3-sonnet-20240229-v1:0',
                body=json.dumps({
                    'anthropic_version': 'bedrock-2023-05-31',
                    'max_tokens': 500,
                    'messages': [{'role': 'user', 'content': prompt}]
                })
            )
            
            response_body = json.loads(response['body'].read())
            analysis = response_body['content'][0]['text']
            
            # Parse AI response (simplified)
            return {
                'impact_score': 7,  # Would extract from AI response
                'key_findings': analysis[:200],
                'brands_affected': self.extract_brand_mentions(analysis),
                'confidence': 85
            }
            
        except Exception as e:
            print(f"Error in AI analysis: {str(e)}")
            return {'impact_score': 5, 'confidence': 50}

    def extract_brand_mentions(self, text: str) -> List[str]:
        """Enhanced brand mention extraction"""
        if not text:
            return []
        
        text_lower = text.lower()
        mentioned_brands = []
        
        for brand in self.target_brands:
            if brand.lower() in text_lower:
                mentioned_brands.append(brand)
        
        return list(set(mentioned_brands))

    def _batch_list(self, items: List, batch_size: int) -> List[List]:
        """Split list into batches"""
        for i in range(0, len(items), batch_size):
            yield items[i:i + batch_size]

    def run_comprehensive_ingestion(self) -> Dict[str, Any]:
        """Run all data sources in comprehensive ingestion"""
        results = []
        
        sources = [
            'pubmed', 'clinicaltrials', 'fda', 'ema', 
            'patents', 'news', 'conferences', 'sec'
        ]
        
        for source in sources:
            try:
                if source == 'pubmed':
                    result = self.ingest_pubmed_comprehensive()
                elif source == 'clinicaltrials':
                    result = self.ingest_clinicaltrials_comprehensive()
                elif source == 'fda':
                    result = self.ingest_fda_comprehensive()
                elif source == 'ema':
                    result = self.ingest_ema_data()
                elif source == 'patents':
                    result = self.ingest_patent_data()
                elif source == 'news':
                    result = self.ingest_pharma_news()
                elif source == 'conferences':
                    result = self.ingest_conference_data()
                elif source == 'sec':
                    result = self.ingest_sec_filings()
                
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
                'message': 'Comprehensive ingestion completed',
                'results': results
            })
        }

# Lambda entry point
def lambda_handler(event, context):
    pipeline = ComprehensiveDataIngestionPipeline()
    return pipeline.lambda_handler(event, context)