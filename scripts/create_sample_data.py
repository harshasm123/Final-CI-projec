#!/usr/bin/env python3

import json
import boto3
import argparse
from datetime import datetime, timedelta
import sys
import os

# Add backend src to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend', 'src'))

from services.opensearch_service import OpenSearchService

def create_sample_brands():
    """Create sample brand data"""
    return [
        {
            'id': 'keytruda-1',
            'name': 'Keytruda',
            'molecule': 'Pembrolizumab',
            'manufacturer': 'Merck & Co.',
            'indications': ['Melanoma', 'Lung Cancer', 'Head and Neck Cancer', 'Bladder Cancer'],
            'competitors': ['Opdivo', 'Tecentriq', 'Imfinzi'],
            'riskScore': 75,
            'lastUpdated': datetime.now().isoformat(),
            'marketShare': 42.5,
            'approvalDate': '2014-09-04'
        },
        {
            'id': 'opdivo-1',
            'name': 'Opdivo',
            'molecule': 'Nivolumab',
            'manufacturer': 'Bristol Myers Squibb',
            'indications': ['Melanoma', 'Lung Cancer', 'Kidney Cancer', 'Hodgkin Lymphoma'],
            'competitors': ['Keytruda', 'Tecentriq', 'Imfinzi'],
            'riskScore': 68,
            'lastUpdated': datetime.now().isoformat(),
            'marketShare': 28.3,
            'approvalDate': '2014-12-22'
        },
        {
            'id': 'tecentriq-1',
            'name': 'Tecentriq',
            'molecule': 'Atezolizumab',
            'manufacturer': 'Genentech/Roche',
            'indications': ['Bladder Cancer', 'Lung Cancer', 'Breast Cancer'],
            'competitors': ['Keytruda', 'Opdivo', 'Imfinzi'],
            'riskScore': 52,
            'lastUpdated': datetime.now().isoformat(),
            'marketShare': 18.7,
            'approvalDate': '2016-05-18'
        }
    ]

def create_sample_alerts():
    """Create sample alert data"""
    return [
        {
            'id': 'alert-001',
            'title': 'FDA Approves Competitor Drug for Melanoma',
            'severity': 'critical',
            'source': 'FDA',
            'brandImpacted': ['Keytruda', 'Opdivo'],
            'description': 'FDA has approved a new PD-1 inhibitor for melanoma treatment, creating direct competition.',
            'whyItMatters': 'This approval introduces a new competitor in the melanoma market, potentially impacting market share and pricing strategies for existing PD-1 inhibitors.',
            'createdAt': (datetime.now() - timedelta(hours=2)).isoformat(),
            'confidenceScore': 95
        },
        {
            'id': 'alert-002',
            'title': 'Positive Phase III Results for Competing Immunotherapy',
            'severity': 'high',
            'source': 'Trials',
            'brandImpacted': ['Tecentriq'],
            'description': 'Competitor announced positive Phase III results in combination therapy for lung cancer.',
            'whyItMatters': 'Strong efficacy data could lead to expanded label and increased market competition in lung cancer indication.',
            'createdAt': (datetime.now() - timedelta(hours=6)).isoformat(),
            'confidenceScore': 87
        },
        {
            'id': 'alert-003',
            'title': 'Patent Challenge Filed Against Key Competitor',
            'severity': 'medium',
            'source': 'Patents',
            'brandImpacted': ['Opdivo'],
            'description': 'Generic manufacturer has filed patent challenge against Opdivo formulation patent.',
            'whyItMatters': 'Successful challenge could lead to earlier generic entry, affecting competitive dynamics and pricing.',
            'createdAt': (datetime.now() - timedelta(days=1)).isoformat(),
            'confidenceScore': 78
        }
    ]

def create_sample_trials():
    """Create sample clinical trial data"""
    return [
        {
            'id': 'NCT04567890',
            'title': 'Phase III Study of Pembrolizumab in Advanced Melanoma',
            'phase': 'Phase III',
            'status': 'Active, not recruiting',
            'indication': 'Melanoma',
            'sponsor': 'Merck Sharp & Dohme Corp.',
            'startDate': '2023-01-15',
            'estimatedCompletion': '2025-12-31',
            'participantCount': 450,
            'primaryEndpoint': 'Overall Survival',
            'brand': 'Keytruda',
            'molecule': 'Pembrolizumab'
        },
        {
            'id': 'NCT04123456',
            'title': 'Nivolumab Plus Ipilimumab in Lung Cancer',
            'phase': 'Phase III',
            'status': 'Recruiting',
            'indication': 'Non-Small Cell Lung Cancer',
            'sponsor': 'Bristol-Myers Squibb',
            'startDate': '2023-06-01',
            'estimatedCompletion': '2026-03-31',
            'participantCount': 600,
            'primaryEndpoint': 'Progression-free Survival',
            'brand': 'Opdivo',
            'molecule': 'Nivolumab'
        }
    ]

def create_sample_competitive_landscape():
    """Create sample competitive landscape data"""
    return [
        {
            'brand': 'Keytruda',
            'molecule': 'Pembrolizumab',
            'indication': 'Melanoma',
            'trialPhase': 'Phase III',
            'trialCount': 847,
            'recentApproval': '2024-01-10',
            'riskScore': 75,
            'marketPosition': 'Leader',
            'competitiveStrength': 85
        },
        {
            'brand': 'Opdivo',
            'molecule': 'Nivolumab',
            'indication': 'Lung Cancer',
            'trialPhase': 'Phase III',
            'trialCount': 623,
            'recentApproval': '2023-12-15',
            'riskScore': 68,
            'marketPosition': 'Strong Challenger',
            'competitiveStrength': 78
        },
        {
            'brand': 'Tecentriq',
            'molecule': 'Atezolizumab',
            'indication': 'Bladder Cancer',
            'trialPhase': 'Phase II',
            'trialCount': 412,
            'riskScore': 52,
            'marketPosition': 'Follower',
            'competitiveStrength': 65
        }
    ]

def main():
    parser = argparse.ArgumentParser(description='Create sample data for Pharma CI Platform')
    parser.add_argument('--environment', default='dev', help='Environment (dev/staging/prod)')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    
    args = parser.parse_args()
    
    # Set environment variables for services
    os.environ['AWS_REGION'] = args.region
    
    # Get OpenSearch endpoint from CloudFormation
    try:
        cf_client = boto3.client('cloudformation', region_name=args.region)
        stack_name = f'pharma-ci-backend-{args.environment}'
        
        response = cf_client.describe_stacks(StackName=stack_name)
        outputs = response['Stacks'][0]['Outputs']
        
        opensearch_endpoint = None
        for output in outputs:
            if output['OutputKey'] == 'OpenSearchEndpoint':
                opensearch_endpoint = output['OutputValue']
                break
        
        if not opensearch_endpoint:
            print("Error: Could not find OpenSearch endpoint in CloudFormation outputs")
            return
        
        os.environ['OPENSEARCH_ENDPOINT'] = opensearch_endpoint
        
    except Exception as e:
        print(f"Error getting CloudFormation outputs: {e}")
        print("Using mock data mode...")
        return
    
    # Initialize OpenSearch service
    opensearch = OpenSearchService()
    
    print(f"Creating sample data for environment: {args.environment}")
    
    # Create indices and sample data
    datasets = [
        ('brands', create_sample_brands()),
        ('alerts', create_sample_alerts()),
        ('trials', create_sample_trials()),
        ('competitive_landscape', create_sample_competitive_landscape())
    ]
    
    for index_name, data in datasets:
        print(f"Creating sample data for {index_name}...")
        
        # Create index mapping (simplified)
        mapping = {
            'properties': {
                'id': {'type': 'keyword'},
                'name': {'type': 'text'},
                'title': {'type': 'text'},
                'description': {'type': 'text'},
                'createdAt': {'type': 'date'},
                'lastUpdated': {'type': 'date'}
            }
        }
        
        opensearch.create_index(index_name, mapping)
        
        # Index sample documents
        for doc in data:
            doc_id = doc.get('id', f"{index_name}-{datetime.now().timestamp()}")
            success = opensearch.index_document(index_name, doc_id, doc)
            if success:
                print(f"  ✓ Indexed {doc_id}")
            else:
                print(f"  ✗ Failed to index {doc_id}")
    
    print("\nSample data creation completed!")
    print(f"Data available in OpenSearch at: {opensearch_endpoint}")

if __name__ == '__main__':
    main()