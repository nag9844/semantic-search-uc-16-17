import json
import psycopg2
import openai
import os
import logging
from typing import List, Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda handler for semantic search
    """
    try:
        logger.info(f"Received search request: {json.dumps(event)}")
        
        # Parse request
        if event.get('httpMethod') == 'OPTIONS':
            return cors_response(200, {})
        
        body = json.loads(event.get('body', '{}'))
        query = body.get('query', '').strip()
        limit = min(body.get('limit', 10), 50)  # Cap at 50 results
        threshold = body.get('threshold', 0.7)
        
        if not query:
            return cors_response(400, {'error': 'Query parameter is required'})
        
        logger.info(f"Searching for: '{query}' with limit: {limit}, threshold: {threshold}")
        
        # Perform semantic search
        results = semantic_search(query, limit, threshold)
        
        response_data = {
            'query': query,
            'results': results,
            'count': len(results),
            'threshold': threshold
        }
        
        return cors_response(200, response_data)
        
    except Exception as e:
        logger.error(f"Error in search: {str(e)}")
        return cors_response(500, {'error': str(e)})

def semantic_search(query: str, limit: int = 10, threshold: float = 0.7) -> List[Dict[str, Any]]:
    """
    Perform semantic search using vector similarity
    """
    conn = None
    try:
        # Generate query embedding
        query_embedding = generate_embedding(query)
        logger.info("Generated query embedding")
        
        # Connect to database
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Perform vector similarity search
        cursor.execute("""
            SELECT 
                dc.id as chunk_id,
                dc.content,
                dc.chunk_index,
                dc.token_count,
                d.id as document_id,
                d.filename,
                d.s3_key,
                d.upload_date,
                1 - (dc.embedding <=> %s::vector) as similarity_score
            FROM document_chunks dc
            JOIN documents d ON dc.document_id = d.id
            WHERE d.processing_status = 'completed'
                AND 1 - (dc.embedding <=> %s::vector) > %s
            ORDER BY dc.embedding <=> %s::vector
            LIMIT %s
        """, (query_embedding, query_embedding, threshold, query_embedding, limit))
        
        results = []
        for row in cursor.fetchall():
            results.append({
                'chunk_id': row[0],
                'content': row[1][:500] + '...' if len(row[1]) > 500 else row[1],  # Truncate long content
                'chunk_index': row[2],
                'token_count': row[3],
                'document_id': row[4],
                'filename': row[5],
                's3_key': row[6],
                'upload_date': row[7].isoformat() if row[7] else None,
                'similarity_score': float(row[8])
            })
        
        logger.info(f"Found {len(results)} results")
        return results
        
    except Exception as e:
        logger.error(f"Error in semantic search: {str(e)}")
        raise e
    finally:
        if conn:
            conn.close()

def generate_embedding(text: str) -> List[float]:
    """
    Generate embedding for text using OpenAI API
    """
    try:
        client = openai.OpenAI(api_key=os.environ['OPENAI_API_KEY'])
        
        response = client.embeddings.create(
            model="text-embedding-ada-002",
            input=text
        )
        
        return response.data[0].embedding
    except Exception as e:
        logger.error(f"Error generating embedding: {str(e)}")
        raise e

def get_db_connection():
    """
    Create database connection
    """
    try:
        conn = psycopg2.connect(
            host=os.environ['DATABASE_HOST'],
            database=os.environ['DATABASE_NAME'],
            user=os.environ['DATABASE_USER'],
            password=os.environ['DATABASE_PASS'],
            port=5432
        )
        return conn
    except Exception as e:
        logger.error(f"Error connecting to database: {str(e)}")
        raise e

def cors_response(status_code: int, body: Dict[str, Any]):
    """
    Return response with CORS headers
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        'body': json.dumps(body, default=str)
    }