# RAG Service with Category Support

## Overview
The RAG service now supports categorizing documents with `category_id` for better organization and filtering.

## API Endpoints

### 1. Ingest Document with Category
```bash
# Using curl with form data
curl -X POST "http://localhost:8001/ingest" \
  -F "file=@your_document.pdf" \
  -F "category_id=hr_policies"

# Or using Python requests
import requests

files = {'file': open('your_document.pdf', 'rb')}
data = {'category_id': 'hr_policies'}
response = requests.post('http://localhost:8001/ingest', files=files, data=data)
```

### 2. Query with Category Filter
```bash
# Query only documents in specific category
curl -X POST "http://localhost:8001/query" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are the key policies?",
    "limit": 5,
    "category_id": "hr_policies"
  }'

# Query across all categories (omit category_id)
curl -X POST "http://localhost:8001/query" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are the key policies?",
    "limit": 5
  }'
```

### 3. Clear Database
```bash
curl -X POST "http://localhost:8001/clear"
```

## Use Cases

### Example: HR Document Management
```bash
# Ingest HR policies
curl -X POST "http://localhost:8001/ingest" \
  -F "file=@employee_handbook.pdf" \
  -F "category_id=hr_policies"

# Ingest IT policies
curl -X POST "http://localhost:8001/ingest" \
  -F "file=@it_security.pdf" \
  -F "category_id=it_policies"

# Query HR-specific questions
curl -X POST "http://localhost:8001/query" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What is the vacation policy?",
    "category_id": "hr_policies"
  }'

# Query IT-specific questions
curl -X POST "http://localhost:8001/query" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are the password requirements?",
    "category_id": "it_policies"
  }'
```

## Response Format

### Query Response with Category
```json
{
  "question": "What are the key policies?",
  "answer": "Based on the HR policies document...",
  "results": [
    {
      "score": 0.85,
      "content": "Policy content here...",
      "file_path": "./temp/employee_handbook.pdf",
      "chunk_id": 0,
      "category_id": "hr_policies"
    }
  ],
  "total_results": 1,
  "context_used": 1,
  "category_filter": "hr_policies"
}
```

## Benefits

1. **Organized Knowledge Base**: Documents are categorized for better management
2. **Targeted Queries**: Search within specific categories for more relevant results
3. **Scalability**: Support multiple document categories in the same system
4. **Flexibility**: Optional category filtering - works with or without categories

## Implementation Details

- `category_id` is stored in the vector database payload for each chunk
- Query filtering uses Qdrant's built-in filtering capabilities
- Backward compatible - existing documents without categories still work
- Category filtering is optional - omit `category_id` to search all documents
