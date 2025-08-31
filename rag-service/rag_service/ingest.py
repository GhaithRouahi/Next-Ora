import os
from pathlib import Path
from typing import List, Optional
from .utils import read_txt, read_pdf, read_docx, chunk_text
import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions
import uuid
import hashlib
import json

print("Using ultra-lightweight built-in embeddings (no external ML models)")

class SimpleEmbedding:
    """Ultra-simple text embedding using TF-IDF-like approach with built-in libraries only"""
    
    def __init__(self):
        self.vocab = {}
        self.dimension = 384  # Standard embedding dimension
    
    def _get_words(self, text: str) -> List[str]:
        """Simple tokenization"""
        import re
        words = re.findall(r'\w+', text.lower())
        return [w for w in words if len(w) > 2]  # Filter short words
    
    def encode(self, text: str) -> List[float]:
        """Create embedding vector from text"""
        words = self._get_words(text)
        
        # Create a simple hash-based embedding
        embedding = [0.0] * self.dimension
        
        for i, word in enumerate(words[:50]):  # Limit to first 50 words
            # Use word hash to determine position in embedding vector
            hash_val = hash(word)
            positions = [abs(hash_val + j) % self.dimension for j in range(3)]
            
            # Set values at those positions (simple TF-like weighting)
            weight = 1.0 / (i + 1)  # Give higher weight to earlier words
            for pos in positions:
                embedding[pos] += weight
        
        # Normalize the vector
        magnitude = sum(x*x for x in embedding) ** 0.5
        if magnitude > 0:
            embedding = [x/magnitude for x in embedding]
        
        return embedding


class Ingestor:
    def __init__(self, chroma_dir: str = './chroma_db', vector_db: str = None, vector_db_url: Optional[str] = None):
        self.vector_db = (vector_db or os.environ.get('VECTOR_DB', 'chroma')).lower()
        
        # Use simple built-in embedding
        self.embedding_model = SimpleEmbedding()
            
        if self.vector_db == 'chroma':
            # If a remote Chroma server URL was provided, configure client to use it
            url = vector_db_url or os.environ.get('VECTOR_DB_URL')
            if url:
                # expect url like http://chroma:8000
                host = url.replace('http://', '').replace('https://', '').split(':')[0]
                port = int(url.split(':')[-1]) if ':' in url else 8000
                self.client = chromadb.Client(Settings(chroma_server_host=host, chroma_server_http_port=port))
            else:
                # local chroma using duckdb+parquet
                self.client = chromadb.Client(Settings(chroma_db_impl="duckdb+parquet", persist_directory=chroma_dir))
            # use chroma's default embedding function (no external dependencies)
            self.embed_fn = embedding_functions.DefaultEmbeddingFunction()
        else:
            raise ValueError(f"Unsupported VECTOR_DB: {self.vector_db}")
    
    def get_embeddings(self, text: str) -> List[float]:
        """Get embeddings for text using our simple built-in approach"""
        return self.embedding_model.encode(text)

    def _read(self, path: str) -> str:
        p = Path(path)
        if p.suffix.lower() == '.pdf':
            return read_pdf(path)
        if p.suffix.lower() in ['.docx', '.doc']:
            return read_docx(path)
        return read_txt(path)

    def ingest_file(self, file_path: str, file_id: int, category_id: int, collection_name: str = 'knowledge'):
        text = self._read(file_path)
        chunks = chunk_text(text)

        # ensure collection
        col = None
        try:
            col = self.client.get_collection(collection_name)
        except Exception:
            # if remote chroma, create_collection signature may differ; attempt create
            col = self.client.create_collection(collection_name, embedding_function=self.embed_fn)

        ids = []
        metadatas = []
        documents = []
        for c in chunks:
            rid = str(uuid.uuid4())
            ids.append(rid)
            metadatas.append({'category_id': category_id, 'file_id': file_id})
            documents.append(c)
        col.add(ids=ids, documents=documents, metadatas=metadatas)
        # persist only for local chroma
        try:
            self.client.persist()
        except Exception:
            pass

