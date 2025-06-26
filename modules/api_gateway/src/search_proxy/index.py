import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Proxy function to handle CORS and invoke search Lambda
    """
    try:
        # Handle CORS preflight
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': ''
            }
        
        # Invoke the actual search Lambda
        lambda_client = boto3.client('lambda')
        
        response = lambda_client.invoke(
            FunctionName=os.environ['SEARCH_LAMBDA_NAME'],
            Payload=json.dumps(event)
        )
        
        # Parse response
        response_payload = json.loads(response['Payload'].read())
        
        return response_payload
        
    except Exception as e:
        logger.error(f"Error in search proxy: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': str(e)})
        }