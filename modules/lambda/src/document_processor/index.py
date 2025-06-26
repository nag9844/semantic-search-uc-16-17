import json
import boto3
import psycopg2
import openai
import PyPDF2
import tiktoken
import os
import logging
from io import BytesIO
from typing import List, Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda handler for processing documents uploaded to S3
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Parse S3 event
        for record in event['Records']:
            s3_bucket = record['s3']['bucket']['name']
            s3_key = record['s3']['object']['key']
            
            logger.info(f"Processing file: {s3_key} from bucket: {s3_bucket}")
            
            # Process the document
            process_document(s3_bucket, s3_key)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Documents processed successfully',
                'processed_files': len(event['Records'])
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing documents: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def process_document(s3_bucket: str, s3_key: str):
    """
    Process a single document: extract text, chunk, generate embeddings, and store
    """
    conn = None
    try:
        # Download file from S3
        s3_client = boto3.client('s3')
        response = s3_client.get_object(Bucket=s3_bucket, Key=s3_key)
        file_content = response['Body'].read()
        file_size = len(file_content)
        content_type = response.get('ContentType', 'application/pdf')
        
        logger.info(f"Downloaded file: {s3_key}, size: {file_size} bytes")
        
        # Extract text from PDF
        text_content = extract_text_from_pdf(file_content)
        logger.info(f"Extracted text length: {len(text_content)} characters")
        
        # Chunk the text
        chunks = chunk_text(text_content, max_tokens=500)
        logger.info(f"Created {len(chunks)} chunks")
        
        # Store document and chunks in database
        conn = get_db_connection()
        document_id = store_document_record(
            conn, s3_key, content_type, file_size, 'processing'
        )
        
        # Generate embeddings and store chunks
        store_document_chunks(conn, document_id, chunks)
        
        # Update document status
        update_document_status(conn, document_id, 'completed')
        
        logger.info(f"Successfully processed document {s3_key} with {len(chunks)} chunks")
        
    except Exception as e:
        logger.error(f"Error processing document {s3_key}: {str(e)}")
        if conn:
            try:
                update_document_status(conn, document_id, 'failed', str(e))
            except:
                pass
        raise e
    finally:
        if conn:
            conn.close()

def extract_text_from_pdf(file_content: bytes) -> str:
    """
    Extract text from PDF file content
    """
    try:
        pdf_reader = PyPDF2.PdfReader(BytesIO(file_content))
        text = ""
        
        for page_num, page in enumerate(pdf_reader.pages):
            try:
                page_text = page.extract_text()
                text += page_text + "\n"
            except Exception as e:
                logger.warning(f"Error extracting text from page {page_num}: {str(e)}")
                continue
        
        return text.strip()
    except Exception as e:
        logger.error(f"Error extracting text from PDF: {str(e)}")
        raise e

def chunk_text(text: str, max_tokens: int = 500, overlap_tokens: int = 50) -> List[Dict[str, Any]]:
    """
    Chunk text into smaller pieces with overlap
    """
    try:
        encoding = tiktoken.encoding_for_model("text-embedding-ada-002")
        tokens = encoding.encode(text)
        
        chunks = []
        start = 0
        
        while start < len(tokens):
            end = min(start + max_tokens, len(tokens))
            chunk_tokens = tokens[start:end]
            chunk_text = encoding.decode(chunk_tokens)
            
            chunks.append({
                'content': chunk_text,
                'token_count': len(chunk_tokens),
                'start_token': start,
                'end_token': end
            })
            
            # Move start position with overlap
            start = end - overlap_tokens if end < len(tokens) else end
        
        return chunks
    except Exception as e:
        logger.error(f"Error chunking text: {str(e)}")
        raise e

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

def store_document_record(conn, s3_key: str, content_type: str, file_size: int, status: str) -> int:
    """
    Store document record in database
    """
    try:
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO documents (filename, s3_key, content_type, file_size, processing_status)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (s3_key) DO UPDATE SET
                content_type = EXCLUDED.content_type,
                file_size = EXCLUDED.file_size,
                processing_status = EXCLUDED.processing_status,
                upload_date = CURRENT_TIMESTAMP
            RETURNING id
        """, (s3_key.split('/')[-1], s3_key, content_type, file_size, status))
        
        document_id = cursor.fetchone()[0]
        conn.commit()
        
        return document_id
    except Exception as e:
        conn.rollback()
        logger.error(f"Error storing document record: {str(e)}")
        raise e
    finally:
        cursor.close()

def store_document_chunks(conn, document_id: int, chunks: List[Dict[str, Any]]):
    """
    Store document chunks with embeddings
    """
    cursor = None
    try:
        cursor = conn.cursor()
        
        # Delete existing chunks for this document
        cursor.execute("DELETE FROM document_chunks WHERE document_id = %s", (document_id,))
        
        # Process each chunk
        for idx, chunk in enumerate(chunks):
            # Generate embedding
            embedding = generate_embedding(chunk['content'])
            
            # Store chunk with embedding
            cursor.execute("""
                INSERT INTO document_chunks 
                (document_id, chunk_index, content, token_count, embedding)
                VALUES (%s, %s, %s, %s, %s)
            """, (
                document_id,
                idx,
                chunk['content'],
                chunk['token_count'],
                embedding
            ))
            
            logger.info(f"Stored chunk {idx + 1}/{len(chunks)} for document {document_id}")
        
        conn.commit()
        
    except Exception as e:
        conn.rollback()
        logger.error(f"Error storing document chunks: {str(e)}")
        raise e
    finally:
        if cursor:
            cursor.close()

def update_document_status(conn, document_id: int, status: str, error_message: str = None):
    """
    Update document processing status
    """
    cursor = None
    try:
        cursor = conn.cursor()
        
        if error_message:
            cursor.execute("""
                UPDATE documents 
                SET processing_status = %s, processed_at = CURRENT_TIMESTAMP, error_message = %s
                WHERE id = %s
            """, (status, error_message, document_id))
        else:
            cursor.execute("""
                UPDATE documents 
                SET processing_status = %s, processed_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (status, document_id))
        
        conn.commit()
        
    except Exception as e:
        conn.rollback()
        logger.error(f"Error updating document status: {str(e)}")
        raise e
    finally:
        if cursor:
            cursor.close()