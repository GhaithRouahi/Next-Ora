from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import os
from pathlib import Path
import uvicorn
from app.ingest import initialize_vector_db, extract_content, split_text, ingest_file_to_vector_db, simple_text_embedding, clear_vector_db
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
    file: UploadFile = File(...),
    category_id: Optional[str] = None
):
    try:
        # Save uploaded file temporarily
        file_path = f"./temp/{file.filename}"
        os.makedirs("./temp", exist_ok=True)
        with open(file_path, "wb") as f:
            f.write(await file.read())

        # Initialize vector DB and embeddings
        client, embedding_model = initialize_vector_db()

        # Use existing ingestion function with category_id
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

        # Add category filter if specified
        if request.category_id:
            search_query["query_filter"] = {
                "must": [
                    {
                        "key": "category_id",
                        "match": {
                            "value": request.category_id
                        }
                    }
                ]
            }

        # Search for similar documents
        search_result = client.search(**search_query)

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

        # Generate answer using retrieved context
        context = "\n\n".join(context_chunks)
        answer = generate_answer(request.question, context)

        return JSONResponse(content={
            "question": request.question,
            "answer": answer,
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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)