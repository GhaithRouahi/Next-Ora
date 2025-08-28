from pydantic import BaseModel
from typing import Optional

class CategoryCreate(BaseModel):
    name: str

class FileCreateResponse(BaseModel):
    id: int
    name: str
    path: str
    category_id: int

class QueryRequest(BaseModel):
    category_id: int
    question: str
    top_k: Optional[int] = 5

class QueryResponse(BaseModel):
    answer: str
    source_chunks: list


class IngestRequest(BaseModel):
    file_id: int
    path: str
    category_id: int
