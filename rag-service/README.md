# RAG Service (FastAPI)

This service implements a simple Retrieval-Augmented Generation (RAG) backend.

Features
- Categories and Files (SQLite)
- File ingestion: PDF, TXT, DOCX
- Chunking + embeddings (sentence-transformers)
- Vector store: Chroma (local)
- Query endpoint that retrieves top-K chunks filtered by category and (optionally) calls OpenAI to generate an answer

Quick start

1. Create a virtual environment and install dependencies:

```powershell
python -m venv .venv; .\.venv\Scripts\Activate; pip install -r rag-service/requirements.txt
```

2. (Optional) Set `OPENAI_API_KEY` if you want the service to call OpenAI for generation.

3. Run the app:

```powershell
uvicorn rag_service.main:app --reload --port 8001
```

API endpoints
- `POST /categories` - create category {name}
- `GET /categories` - list categories
- `POST /files` - multipart upload: file + category_id
- `POST /query` - JSON {category_id, question, top_k}

Notes
- Chroma stores data under `rag-service/chroma_db` by default.
- Uploaded files are saved under `rag-service/uploads`.
