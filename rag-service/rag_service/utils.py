import os
from typing import List
from pathlib import Path
from pdfminer.high_level import extract_text
import docx


def read_txt(file_path: str) -> str:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        return f.read()


def read_pdf(file_path: str) -> str:
    return extract_text(file_path)


def read_docx(file_path: str) -> str:
    doc = docx.Document(file_path)
    return "\n".join([p.text for p in doc.paragraphs])


def chunk_text(text: str, chunk_size: int = 500, overlap: int = 50) -> List[str]:
    tokens = text.split()
    chunks = []
    i = 0
    while i < len(tokens):
        chunk = tokens[i:i+chunk_size]
        chunks.append(' '.join(chunk))
        i += chunk_size - overlap
    return chunks

