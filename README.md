# Semantic Search Infrastructure

This Terraform configuration deploys a complete semantic search infrastructure on AWS for processing and searching large documents using vector embeddings.

## Architecture

- **S3**: Document storage with event notifications
- **Lambda**: Document processing and search functions
- **RDS PostgreSQL**: Vector database with pgvector extension
- **API Gateway**: RESTful API endpoints
- **VPC**: Secure network isolation

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. OpenAI API key for embeddings
4. Python 3.9+ for Lambda development

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone <repository>
   cd terraform
   ```

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Deploy infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Initialize database**:
   After deployment, connect to the RDS instance and run the initialization script:
   ```bash
   # Get the database endpoint from terraform output
   terraform output database_endpoint
   
   # Connect and run the init script
   psql -h <endpoint> -U postgres -d semantic_search -f modules/database/scripts/init_database.sql
   ```

## Configuration

### Required Variables

- `db_master_password`: Secure password for PostgreSQL
- `openai_api_key`: OpenAI API key for embeddings

### Optional Variables

- `project_name`: Project name for resource naming (default: "semantic-search")
- `environment`: Environment name (default: "dev")
- `aws_region`: AWS region (default: "us-west-2")
- `vpc_cidr`: VPC CIDR block (default: "10.0.0.0/16")

## Usage

### Upload Documents

Upload PDF files to the S3 bucket under the `documents/` prefix:

```bash
aws s3 cp document.pdf s3://<bucket-name>/documents/
```

### Search Documents

Use the API Gateway endpoint to search:

```bash
curl -X POST https://<api-id>.execute-api.<region>.amazonaws.com/dev/search \
  -H "Content-Type: application/json" \
  -d '{"query": "your search query", "limit": 10}'
```

## Monitoring

- CloudWatch logs for Lambda functions
- RDS performance insights
- API Gateway metrics

## Security Features

- VPC isolation with private subnets
- Encrypted S3 storage
- RDS encryption at rest and in transit
- IAM roles with least privilege

## Cost Optimization

- Use appropriate instance sizes for your workload
- Monitor OpenAI API usage
- Set up CloudWatch alarms for cost monitoring
- Consider using Reserved Instances for production

## Troubleshooting

1. **Lambda timeout errors**: Increase timeout and memory for document processing
2. **Database connection issues**: Check security groups and VPC configuration
3. **Embedding generation failures**: Verify OpenAI API key and rate limits
4. **S3 event not triggering**: Check S3 bucket notifications and Lambda permissions

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all data. Make sure to backup important documents first.