graph TD
    subgraph Use Case 16: Ingestion & Indexing
        A[Large Text Files (e.g., PDFs, Logs)] --> B(AWS S3)

        B -- File Download (boto3) --> C[Application Server / Processing Service]
        C -- Parse & Chunk (tiktoken/nltk) --> D[Text Chunks]
        D -- Generate Embeddings (OpenAI/Cohere/HuggingFace) --> E[Vector Embeddings]

        E -- Store (pgvector) --> F[PostgreSQL Database]
        D -- Store (chunk text) --> F
    end

    subgraph Use Case 17: Semantic Search API
        G[User / Client Application] --> H[API Gateway (POST /search)]

        H -- Trigger --> I[AWS Lambda Function]

        I -- Convert Query to Embedding (OpenAI/HuggingFace) --> J[Query Embedding]
        J -- Query (pgvector similarity search) --> F

        F -- Top N Results --> I
        I -- Return Results --> H
        H -- Response --> G
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#87CEEB,stroke:#333,stroke-width:2px
    style C fill:#90EE90,stroke:#333,stroke-width:2px
    style D fill:#FFFACD,stroke:#333,stroke-width:2px
    style E fill:#ADD8E6,stroke:#333,stroke-width:2px
    style F fill:#DAA520,stroke:#333,stroke-width:2px
    style G fill:#f9f,stroke:#333,stroke-width:2px
    style H fill:#87CEEB,stroke:#333,stroke-width:2px
    style I fill:#90EE90,stroke:#333,stroke-width:2px
    style J fill:#ADD8E6,stroke:#333,stroke-width:2px

    linkStyle 0 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 1 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 2 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 3 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 4 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 5 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 6 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 7 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 8 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 9 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 10 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 11 stroke:#666,stroke-width:2px,fill:none;
    linkStyle 12 stroke:#666,stroke-width:2px,fill:none;