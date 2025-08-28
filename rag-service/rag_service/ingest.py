import os
from pathlib import Path
from typing import List, Optional
from .utils import read_txt, read_pdf, read_docx, chunk_text
from sentence_transformers import SentenceTransformer
import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions
import uuid

MODEL_NAME = os.environ.get('EMBEDDING_MODEL', 'all-MiniLM-L6-v2')


class Ingestor:
    def __init__(self, chroma_dir: str = './chroma_db', vector_db: str = None, vector_db_url: Optional[str] = None):
        self.vector_db = (vector_db or os.environ.get('VECTOR_DB', 'chroma')).lower()
        self.embedding_model = SentenceTransformer(MODEL_NAME)
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
            # use chroma's embedding wrapper for consistency when using chroma-python collection add
            self.embed_fn = embedding_functions.SentenceTransformerEmbeddingFunction(model_name=MODEL_NAME)
        else:
            raise ValueError(f"Unsupported VECTOR_DB: {self.vector_db}")

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

