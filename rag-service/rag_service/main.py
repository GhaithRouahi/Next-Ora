import os
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from sqlalchemy import insert, select
from .db import engine, metadata, categories, files, SessionLocal, get_category_by_name
from .schemas import CategoryCreate, FileCreateResponse, QueryRequest, QueryResponse
from .ingest import Ingestor
from dotenv import load_dotenv
import shutil
import uuid
from .schemas import IngestRequest
import google.generativeai as genai

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

app = FastAPI(title="RAG Service")

UPLOAD_DIR = os.environ.get('UPLOAD_DIR', './uploads')
CHROMA_DIR = os.environ.get('CHROMA_DB_DIR', './chroma_db')
VECTOR_DB = os.environ.get('VECTOR_DB', 'chroma')
VECTOR_DB_URL = os.environ.get('VECTOR_DB_URL')
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

os.makedirs(UPLOAD_DIR, exist_ok=True)

# Configure Gemini AI
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

# initialize ingestor with vector DB selection
ingestor = Ingestor(chroma_dir=CHROMA_DIR, vector_db=VECTOR_DB, vector_db_url=VECTOR_DB_URL)

def generate_answer_with_gemini(question: str, context: str) -> str:
    """Generate answer using Gemini AI based on the provided context."""
    if not GEMINI_API_KEY:
        return f"AI answer generation not available. Raw context:\n{context[:1000]}..."
    
    try:
        # Create the prompt for Gemini
        prompt = f"""Based on the following context, please provide a comprehensive and accurate answer to the question.

Context:
{context}

Question: {question}

Please provide a detailed answer based only on the information provided in the context. If the context doesn't contain enough information to fully answer the question, please say so and provide what information is available. if the user is talking normal answer him directely

Answer:"""

        # Use Gemini to generate the answer
        model = genai.GenerativeModel('gemini-pro')
        response = model.generate_content(prompt)
        
        return response.text
    
    except Exception as e:
        # Fallback to basic context if Gemini fails
        return f"AI generation failed ({str(e)}). Based on the available context:\n\n{context[:1500]}..."

@app.post('/categories')
async def create_category(payload: CategoryCreate):
    conn = engine.connect()
    existing = get_category_by_name(conn, payload.name)
    if existing:
        raise HTTPException(status_code=400, detail='Category already exists')
    res = conn.execute(insert(categories).values(name=payload.name))
    conn.commit()
    return {'id': res.lastrowid, 'name': payload.name}

@app.get('/categories')
async def list_categories():
    conn = engine.connect()
    rows = conn.execute(select(categories)).fetchall()
    return [dict(r) for r in rows]

@app.post('/files')
async def upload_file(category_id: int = Form(...), upload: UploadFile = File(...)):
    # save file
    fname = f"{uuid.uuid4()}_{upload.filename}"
    dest = os.path.join(UPLOAD_DIR, fname)
    with open(dest, 'wb') as f:
        shutil.copyfileobj(upload.file, f)
    # insert metadata
    conn = engine.connect()
    res = conn.execute(insert(files).values(name=upload.filename, path=dest, category_id=category_id))
    conn.commit()
    file_id = res.lastrowid
    # ingest
    ingestor.ingest_file(dest, file_id=file_id, category_id=category_id)
    return {'id': file_id, 'name': upload.filename, 'path': dest, 'category_id': category_id}


@app.post('/ingest')
async def ingest_existing(req: IngestRequest):
    # path should be the server-local path under uploads
    if not os.path.exists(req.path):
        raise HTTPException(status_code=404, detail='File not found')
    ingestor.ingest_file(req.path, file_id=req.file_id, category_id=req.category_id)
    return {'status': 'ingested', 'file_id': req.file_id}

@app.post('/query')
async def query(req: QueryRequest):
    # embed query and search chroma
    # We will use the collection 'knowledge'
    # search in vector DB
    client = ingestor.client
    sources = []
    if ingestor.vector_db == 'chroma':
        try:
            col = client.get_collection('knowledge')
        except Exception:
            raise HTTPException(status_code=404, detail='No knowledge collection found')
        q_emb = ingestor.get_embeddings(req.question)
        results = col.query(query_embeddings=[q_emb], n_results=req.top_k, where={"category_id": req.category_id})
        docs = results['documents'][0]
        metadatas = results['metadatas'][0]
        for d, m in zip(docs, metadatas):
            sources.append({'text': d, 'meta': m})
    else:
        raise HTTPException(status_code=500, detail='Unsupported VECTOR_DB for querying')
    
    # Generate AI-powered answer using Gemini with the retrieved context
    context = "\n\n".join([s['text'] for s in sources])
    answer = generate_answer_with_gemini(req.question, context)
    
    return QueryResponse(answer=answer, source_chunks=sources)
