-- Database initialization script for semantic search
-- This script sets up the pgvector extension and creates the necessary tables

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create documents table
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    s3_key VARCHAR(500) NOT NULL UNIQUE,
    content_type VARCHAR(100),
    file_size BIGINT,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_status VARCHAR(50) DEFAULT 'pending',
    processed_at TIMESTAMP,
    error_message TEXT,
    metadata JSONB
);

-- Create document_chunks table
CREATE TABLE IF NOT EXISTS document_chunks (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    token_count INTEGER,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(document_id, chunk_index)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(processing_status);
CREATE INDEX IF NOT EXISTS idx_documents_upload_date ON documents(upload_date);
CREATE INDEX IF NOT EXISTS idx_document_chunks_document_id ON document_chunks(document_id);

-- Create vector similarity search index
-- Note: This index should be created after inserting some data for better performance
CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding 
ON document_chunks USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

-- Create search function for semantic search
CREATE OR REPLACE FUNCTION semantic_search(
    query_embedding vector(1536),
    similarity_threshold float DEFAULT 0.8,
    max_results integer DEFAULT 10
)
RETURNS TABLE (
    chunk_id integer,
    document_id integer,
    filename varchar,
    content text,
    similarity_score float
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dc.id as chunk_id,
        dc.document_id,
        d.filename,
        dc.content,
        1 - (dc.embedding <=> query_embedding) as similarity_score
    FROM document_chunks dc
    JOIN documents d ON dc.document_id = d.id
    WHERE d.processing_status = 'completed'
        AND 1 - (dc.embedding <=> query_embedding) > similarity_threshold
    ORDER BY dc.embedding <=> query_embedding
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

-- Create function to get document statistics
CREATE OR REPLACE FUNCTION get_document_stats()
RETURNS TABLE (
    total_documents bigint,
    processed_documents bigint,
    pending_documents bigint,
    total_chunks bigint,
    avg_chunks_per_document numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_documents,
        COUNT(*) FILTER (WHERE processing_status = 'completed') as processed_documents,
        COUNT(*) FILTER (WHERE processing_status = 'pending') as pending_documents,
        (SELECT COUNT(*) FROM document_chunks) as total_chunks,
        CASE 
            WHEN COUNT(*) FILTER (WHERE processing_status = 'completed') > 0 
            THEN (SELECT COUNT(*)::numeric FROM document_chunks) / COUNT(*) FILTER (WHERE processing_status = 'completed')
            ELSE 0
        END as avg_chunks_per_document
    FROM documents;
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup old failed processing attempts
CREATE OR REPLACE FUNCTION cleanup_failed_documents(older_than_hours integer DEFAULT 24)
RETURNS integer AS $$
DECLARE
    deleted_count integer;
BEGIN
    DELETE FROM documents 
    WHERE processing_status = 'failed' 
        AND upload_date < NOW() - INTERVAL '1 hour' * older_than_hours;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON documents TO your_app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON document_chunks TO your_app_user;
-- GRANT USAGE, SELECT ON SEQUENCE documents_id_seq TO your_app_user;
-- GRANT USAGE, SELECT ON SEQUENCE document_chunks_id_seq TO your_app_user;