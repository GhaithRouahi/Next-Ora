from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.responses import JSONResponse
import os
from pathlib import Path
import uvicorn
from app.ingest import initialize_vector_db, extract_content, split_text, ingest_file_to_vector_db, simple_text_embedding, clear_vector_db
from app.ingest import list_indexed_files, is_file_indexed
from pydantic import BaseModel
from typing import Optional
import google.generativeai as genai

app = FastAPI(title="Vector DB and RAG API")

# Configure Gemini AI
GEMINI_API_KEY = "AIzaSyAdAHeqCDiRMocDEAp9vwX-prA5IcQ4Oqg"
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-1.5-flash')
else:
    model = None
    print("Warning: GEMINI_API_KEY not set. Answer generation will be disabled.")

# Function to generate answer using Gemini
def generate_answer(question: str, context: str) -> str:
    if not model:
        return "AI answer generation is not available. Please set GEMINI_API_KEY environment variable."

    try:
        prompt = f"""
        Based on the following context, please answer the question in a clear and concise manner.
        If the context doesn't contain enough information to fully answer the question, say so.

        Context:
        {context}

        Question: {question}

        Answer:"""

        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        return f"Error generating answer: {str(e)}"

# Root endpoint
@app.get("/")
async def root():
    return {
        "message": "RAG API is running",
        "endpoints": {
            "POST /ingest": "Upload and process documents (supports category_id parameter)",
            "POST /query": "Query documents with natural language questions (supports category_id filter)",
            "POST /clear": "Clear the vector database"
        },
        "ingest_example": {
            "method": "POST",
            "url": "/ingest",
            "form_data": {
                "file": "your_file.pdf",
                "category_id": "optional_category_id"
            }
        },
        "query_example": {
            "question": "What are the key elements?",
            "limit": 5,
            "category_id": "optional_filter_by_category"
        }
    }

# Pydantic models
class QueryRequest(BaseModel):
    question: str
    limit: int = 5
    category_id: Optional[str] = None

class IngestRequest(BaseModel):
    category_id: Optional[str] = None

# Initialize language model for RAG (commented out for now)
# generator = pipeline("text-generation", model="distilgpt2")

# Ingestion endpoint
@app.post("/ingest")
async def ingest_file(
    request: Request,
    file: UploadFile = File(...),
    category_id: Optional[str] = None
):
    try:
        # If category_id wasn't provided explicitly, try common alternate form keys
        if not category_id:
            try:
                form = await request.form()
                # check common alternatives
                for key in ("category_id", "categoryId", "category"):
                    if key in form and form.get(key) is not None:
                        category_id = str(form.get(key))
                        break
            except Exception:
                # ignore form parsing errors and proceed
                pass

        # Save uploaded file temporarily
        file_path = f"./temp/{file.filename}"
        os.makedirs("./temp", exist_ok=True)
        with open(file_path, "wb") as f:
            f.write(await file.read())

        # Initialize vector DB and embeddings
        client, embedding_model = initialize_vector_db()

        # Use existing ingestion function with category_id
        print(f"Ingest endpoint detected category_id: {category_id}")
        result = ingest_file_to_vector_db(file_path, client, embedding_model, category_id=category_id)

        # Clean up
        os.remove(file_path)

        if "error" in result:
            raise HTTPException(status_code=400, detail=result["error"])

        return JSONResponse(content=result, status_code=200)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error processing file: {str(e)}")

# Query endpoint
@app.post("/query")
async def query_documents(request: QueryRequest):
    try:
        # Initialize vector DB client
        client, embedding_model = initialize_vector_db()

        # Convert question to embedding
        question_embedding = embedding_model(request.question)

        # Prepare search query
        search_query = {
            "collection_name": "file_vectors",
            "query_vector": question_embedding,
            "limit": request.limit,
            "with_payload": True
        }

        # Add category filter if specified. Try to coerce numeric category IDs to int so
        # they match payloads that may have been stored as integers.
        if request.category_id:
            match_value = request.category_id
            # If the category_id looks like an integer, use int type for matching
            try:
                if isinstance(request.category_id, str) and request.category_id.isdigit():
                    match_value = int(request.category_id)
                elif isinstance(request.category_id, (int,)):
                    match_value = request.category_id
            except Exception:
                match_value = request.category_id

            search_query["query_filter"] = {
                "must": [
                    {
                        "key": "category_id",
                        "match": {
                            "value": match_value
                        }
                    }
                ]
            }

        # Debug: log incoming request and search query
        print(f"RAG query: question={request.question!r}, limit={request.limit}, category_id={request.category_id!r}")
        print(f"Using search_query: {search_query}")

        # Search for similar documents
        search_result = client.search(**search_query)

        # If we filtered by category and got no hits, try a fallback:
        # perform the same search without the query_filter and post-filter by payload values
        if request.category_id and (not search_result or len(search_result) == 0):
            print("No hits for filtered query, attempting fallback search without filter and post-filtering payloads")
            # prepare search without filter
            fallback_query = dict(search_query)
            if "query_filter" in fallback_query:
                del fallback_query["query_filter"]

            try:
                fallback_hits = client.search(**fallback_query)
                print(f"Fallback search returned {len(fallback_hits)} total hits; post-filtering by category_id={request.category_id!r}")

                # Determine acceptable match values (int and string forms)
                match_values = {request.category_id}
                try:
                    if isinstance(request.category_id, str) and request.category_id.isdigit():
                        match_values.add(int(request.category_id))
                except Exception:
                    pass

                filtered_hits = []
                for hit in fallback_hits:
                    payload = hit.payload or {}
                    pval = payload.get("category_id")
                    if pval in match_values or (isinstance(pval, str) and pval in match_values) or (isinstance(pval, int) and str(pval) in match_values):
                        filtered_hits.append(hit)

                print(f"After post-filtering fallback hits, {len(filtered_hits)} hits match the category metadata")
                # If we found matches, use them
                if filtered_hits:
                    search_result = filtered_hits
                else:
                    print("Fallback post-filtering found 0 matching hits; returning empty results for the category filter")
            except Exception as e:
                print(f"Fallback search failed: {e}")

        # Format results
        results = []
        context_chunks = []
        for hit in search_result:
            result = {
                "score": hit.score,
                "content": hit.payload.get("content", ""),
                "file_path": hit.payload.get("file_path", ""),
                "chunk_id": hit.payload.get("chunk_id", 0),
                "category_id": hit.payload.get("category_id", None)
            }
            results.append(result)
            # Collect context for answer generation
            if hit.score > 0.1:  # Only include relevant chunks
                context_chunks.append(hit.payload.get("content", ""))

        # Return retrieved chunks and metadata; do NOT generate a final answer here.
        # The backend LLM services (Llama/Gemini) will use these chunks to produce the final response.
        source_chunks = []
        for r in results:
            source_chunks.append({
                "text": r.get("content", ""),
                "score": r.get("score"),
                "file_path": r.get("file_path"),
                "chunk_id": r.get("chunk_id"),
                "category_id": r.get("category_id"),
            })

        return JSONResponse(content={
            "question": request.question,
            "source_chunks": source_chunks,
            "results": results,
            "total_results": len(results),
            "context_used": len(context_chunks),
            "category_filter": request.category_id
        }, status_code=200)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error querying documents: {str(e)}")

# Clear vector database endpoint
@app.post("/clear")
async def clear_database():
    try:
        result = clear_vector_db()
        if "error" in result:
            raise HTTPException(status_code=400, detail=result["error"])
        return JSONResponse(content=result, status_code=200)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error clearing database: {str(e)}")


# Endpoint: list indexed files and categories
@app.get("/indexed/files")
async def indexed_files():
    try:
        client, _ = initialize_vector_db()
        info = list_indexed_files(client)
        return JSONResponse(content=info, status_code=200)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Endpoint: check if a file is indexed
@app.get("/indexed/files/check")
async def check_file_indexed(file_path: Optional[str] = None):
    if not file_path:
        raise HTTPException(status_code=400, detail="file_path query parameter is required")
    try:
        client, _ = initialize_vector_db()
        result = is_file_indexed(client, file_path)
        # If function returned a dict with error, bubble it up
        if isinstance(result, dict) and 'error' in result:
            raise Exception(result['error'])
        return JSONResponse(content={'file_path': file_path, 'indexed': bool(result)}, status_code=200)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/indexed/files/by-category")
async def indexed_files_by_category():
    """Return files grouped by category with counts.

    Response shape:
    {
      "total_categories": N,
      "categories": [
         { "category_id": <id|null>, "file_count": X, "files": [{"file_path":..., "chunks":...}, ...] },
         ...
      ]
    }
    """
    try:
        client, _ = initialize_vector_db()
        info = list_indexed_files(client)
        if isinstance(info, dict) and 'error' in info:
            raise Exception(info['error'])

        categories = {}
        for f in info.get('files', []):
            cats = f.get('categories') or []
            # If file has no category, treat as uncategorized (None)
            if not cats:
                cats = [None]

            for c in cats:
                key = str(c) if c is not None else 'null'
                entry = categories.get(key)
                if not entry:
                    entry = { 'category_id': c, 'files': [] }
                    categories[key] = entry
                entry['files'].append({ 'file_path': f.get('file_path'), 'chunks': f.get('chunks') })

        out = []
        for v in categories.values():
            out.append({ 'category_id': v['category_id'], 'file_count': len(v['files']), 'files': v['files'] })

        return JSONResponse(content={ 'total_categories': len(out), 'categories': out }, status_code=200)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)