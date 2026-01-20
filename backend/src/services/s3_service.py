import os
import json
import boto3
from typing import Dict, Any, Optional
from datetime import datetime

class S3Service:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        self.metadata_bucket = os.environ.get('METADATA_BUCKET', '')
        self.datalake_bucket = os.environ.get('DATALAKE_BUCKET', '')
    
    def store_metadata(self, key: str, metadata: Dict[str, Any]) -> bool:
        """Store metadata in S3"""
        try:
            self.s3_client.put_object(
                Bucket=self.metadata_bucket,
                Key=key,
                Body=json.dumps(metadata, default=str),
                ContentType='application/json'
            )
            return True
        except Exception as e:
            print(f"S3 store metadata error: {str(e)}")
            return False
    
    def get_metadata(self, key: str) -> Optional[Dict[str, Any]]:
        """Retrieve metadata from S3"""
        try:
            response = self.s3_client.get_object(
                Bucket=self.metadata_bucket,
                Key=key
            )
            return json.loads(response['Body'].read())
        except Exception as e:
            print(f"S3 get metadata error: {str(e)}")
            return None
    
    def store_document(self, key: str, content: bytes, content_type: str = 'application/octet-stream') -> bool:
        """Store document in data lake"""
        try:
            self.s3_client.put_object(
                Bucket=self.datalake_bucket,
                Key=key,
                Body=content,
                ContentType=content_type
            )
            return True
        except Exception as e:
            print(f"S3 store document error: {str(e)}")
            return False
    
    def get_document(self, key: str) -> Optional[bytes]:
        """Retrieve document from data lake"""
        try:
            response = self.s3_client.get_object(
                Bucket=self.datalake_bucket,
                Key=key
            )
            return response['Body'].read()
        except Exception as e:
            print(f"S3 get document error: {str(e)}")
            return None
    
    def list_objects(self, prefix: str, bucket: Optional[str] = None) -> list:
        """List objects with given prefix"""
        try:
            bucket_name = bucket or self.metadata_bucket
            response = self.s3_client.list_objects_v2(
                Bucket=bucket_name,
                Prefix=prefix
            )
            return response.get('Contents', [])
        except Exception as e:
            print(f"S3 list objects error: {str(e)}")
            return []
    
    def generate_presigned_url(self, key: str, expiration: int = 3600) -> Optional[str]:
        """Generate presigned URL for document access"""
        try:
            url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.datalake_bucket, 'Key': key},
                ExpiresIn=expiration
            )
            return url
        except Exception as e:
            print(f"S3 presigned URL error: {str(e)}")
            return None