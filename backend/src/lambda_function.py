import json
import os
from typing import Dict, Any
from handlers.dashboard_handler import DashboardHandler
from handlers.brand_handler import BrandHandler
from handlers.alert_handler import AlertHandler
from handlers.ai_handler import AIHandler

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Main API Gateway Lambda handler with routing"""
    
    try:
        # Extract request details
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        query_params = event.get('queryStringParameters') or {}
        body = event.get('body')
        
        # Parse body if present
        request_body = {}
        if body:
            try:
                request_body = json.loads(body)
            except json.JSONDecodeError:
                pass
        
        # Route to appropriate handler
        if path.startswith('/dashboard'):
            handler = DashboardHandler()
            if path == '/dashboard/kpis':
                return handler.get_kpis()
            elif path == '/dashboard/trends':
                return handler.get_trends(query_params.get('timeRange', '30d'))
                
        elif path.startswith('/brands'):
            handler = BrandHandler()
            if path == '/brands/search':
                return handler.search_brands(query_params.get('q', ''))
            elif '/competitive-landscape' in path:
                brand_id = path.split('/')[2]
                return handler.get_competitive_landscape(brand_id)
            elif len(path.split('/')) == 3:  # /brands/{brandId}
                brand_id = path.split('/')[2]
                return handler.get_brand_details(brand_id)
                
        elif path.startswith('/alerts'):
            handler = AlertHandler()
            return handler.get_alerts(query_params)
            
        elif path.startswith('/ai'):
            handler = AIHandler()
            if path == '/ai/insights' and http_method == 'POST':
                return handler.ask_question(request_body)
        
        # Default 404 response
        return {
            'statusCode': 404,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'message': 'Endpoint not found'
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'message': f'Internal server error: {str(e)}'
            })
        }