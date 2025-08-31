import os
import uuid
from qdrant_client import QdrantClient
from qdrant_client.http import models as qmodels
from langchain.text_splitter import RecursiveCharacterTextSplitter
from PyPDF2 import PdfReader
from PIL import Image
import pytesseract
import docx
import numpy as np
from pathlib import Path

# Simple embedding function using basic text features
def simple_text_embedding(text, vector_size=384):
    """Create a simple embedding from text using character and word features"""
    import hashlib
    import math

    # Create features from text
    features = []

    # Character-level features
    for i in range(min(len(text), 100)):
        features.append(ord(text[i]) / 255.0)

    # Word-level features
    words = text.lower().split()
    for i in range(min(len(words), 50)):
        # Hash word to get consistent numeric value
        word_hash = int(hashlib.md5(words[i].encode()).hexdigest()[:8], 16)
        features.append((word_hash % 1000) / 1000.0)

    # Pad or truncate to vector_size
    if len(features) < vector_size:
        features.extend([0.0] * (vector_size - len(features)))
    else:
        features = features[:vector_size]

    return features

# Initialize Qdrant client and embeddings model
def initialize_vector_db(collection_name="file_vectors"):
    client = QdrantClient(host="qdrant", port=6333)
    try:
        client.get_collection(collection_name)
    except:
        client.recreate_collection(
            collection_name=collection_name,
            vectors_config=qmodels.VectorParams(size=384, distance=qmodels.Distance.COSINE)
        )

    # Use simple embedding function
    embedding_model = simple_text_embedding
    print("Using simple text embedding (no external dependencies)")

    return client, embedding_model# Text extraction functions for different file types
def extract_text_from_txt(file_path):
    with open(file_path, 'r', encoding='utf-8') as file:
        return file.read()

def extract_text_from_pdf(file_path):
    """Enhanced PDF text extraction with multiple fallback methods"""
    text = ""

    # Method 1: Try PyPDF2 (most reliable, always available)
    try:
        from PyPDF2 import PdfReader
        print(f"Extracting PDF using PyPDF2: {file_path}")

        with open(file_path, 'rb') as file:
            reader = PdfReader(file)
            print(f"PDF has {len(reader.pages)} pages")

            for i, page in enumerate(reader.pages):
                page_text = page.extract_text() or ""
                text += page_text + "\n"
                if i < 3:  # Log first few pages
                    print(f"Page {i+1}: {len(page_text)} characters extracted")

        if len(text.strip()) > 100:  # If we got substantial text, use it
            print(f"Successfully extracted {len(text)} characters using PyPDF2")
            return clean_extracted_text(text)

    except Exception as e:
        print(f"PyPDF2 extraction failed: {e}")

    # Method 2: Try pdfminer.six (better text extraction)
    try:
        from pdfminer.high_level import extract_text as pdfminer_extract
        print("Trying pdfminer.six for better extraction")

        text = pdfminer_extract(file_path)
        if len(text.strip()) > 100:
            print(f"Successfully extracted {len(text)} characters using pdfminer")
            return clean_extracted_text(text)

    except Exception as e:
        print(f"pdfminer extraction failed: {e}")

    # Method 3: Try PyMuPDF if available
    try:
        import fitz
        print("Trying PyMuPDF for extraction")

        doc = fitz.open(file_path)
        text = ""

        for page_num in range(min(len(doc), 20)):  # Limit to first 20 pages
            page = doc.load_page(page_num)
            page_text = page.get_text()
            text += page_text + "\n"

        doc.close()

        if len(text.strip()) > 100:
            print(f"Successfully extracted {len(text)} characters using PyMuPDF")
            return clean_extracted_text(text)

    except Exception as e:
        print(f"PyMuPDF extraction failed: {e}")

    # Method 4: OCR fallback for image-based PDFs
    try:
        from PIL import Image
        import pytesseract
        print("Attempting OCR extraction")

        # Convert PDF pages to images and OCR
        try:
            from pdf2image import convert_from_path
            images = convert_from_path(file_path, dpi=300, first_page=1, last_page=10)  # First 10 pages

            text = ""
            for i, image in enumerate(images):
                page_text = pytesseract.image_to_string(image)
                text += page_text + "\n"
                print(f"OCR Page {i+1}: {len(page_text)} characters")

            if len(text.strip()) > 50:
                print(f"Successfully extracted {len(text)} characters using OCR")
                return clean_extracted_text(text)

        except ImportError:
            print("pdf2image not available for OCR")

    except Exception as e:
        print(f"OCR extraction failed: {e}")

    # Final fallback: return whatever we got
    if len(text.strip()) < 10:
        print(f"WARNING: Very little text extracted from {file_path} ({len(text)} characters)")
        return "PDF content could not be extracted properly. The document may be image-based or corrupted."

    return clean_extracted_text(text)

def clean_extracted_text(text):
    """Clean and normalize extracted text"""
    import re

    if not text:
        return ""

    # Remove excessive whitespace and newlines
    text = re.sub(r'\n\s*\n\s*\n+', '\n\n', text)  # Multiple newlines to double
    text = re.sub(r'[ \t]+', ' ', text)  # Multiple spaces/tabs to single space

    # Fix common PDF extraction issues
    text = re.sub(r'([a-z])([A-Z])', r'\1 \2', text)  # Add space between concatenated words
    text = re.sub(r'(\w)-\s*\n\s*(\w)', r'\1\2', text)  # Fix hyphenated words split across lines
    text = re.sub(r'(\w)\s*\n\s*(\w)', r'\1 \2', text)  # Fix words improperly split across lines

    # Remove page headers/footers that are often repeated
    lines = text.split('\n')
    cleaned_lines = []

    for line in lines:
        line = line.strip()
        # Skip very short lines that might be artifacts
        if len(line) > 2 or line.isdigit():
            cleaned_lines.append(line)

    text = '\n'.join(cleaned_lines)

    return text.strip()

def extract_text_from_docx(file_path):
    doc = docx.Document(file_path)
    return " ".join([para.text for para in doc.paragraphs])

def extract_text_from_image(file_path):
    image = Image.open(file_path)
    text = pytesseract.image_to_string(image)
    return text

# File type handler
def extract_content(file_path):
    ext = Path(file_path).suffix.lower()
    if ext == '.txt':
        return extract_text_from_txt(file_path)
    elif ext == '.pdf':
        return extract_text_from_pdf(file_path)
    elif ext == '.docx':
        return extract_text_from_docx(file_path)
    elif ext in ['.png', '.jpg', '.jpeg']:
        return extract_text_from_image(file_path)
    else:
        raise ValueError(f"Unsupported file type: {ext}")

# Split text into chunks for processing
def split_text(text, chunk_size=1000, chunk_overlap=200):
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        length_function=len
    )
    return text_splitter.split_text(text)

# Ingest file into vector database
def ingest_file_to_vector_db(file_path, client, embedding_model, collection_name="file_vectors", category_id=None):
    try:
        print(f"Starting ingestion of: {file_path}")
        if category_id:
            print(f"Category ID: {category_id}")

        # Extract content based on file type
        content = extract_content(file_path)
        print(f"Extracted content length: {len(content)} characters")

        if len(content.strip()) < 50:
            return {"error": f"Extracted content too short ({len(content)} chars). File may be empty or extraction failed."}

        # Show preview of extracted content
        preview = content[:500] + "..." if len(content) > 500 else content
        print(f"Content preview: {preview}")

        # Split content into chunks
        chunks = split_text(content)
        print(f"Split into {len(chunks)} chunks")

        # Show chunk sizes
        for i, chunk in enumerate(chunks[:3]):  # Show first 3 chunks
            print(f"Chunk {i}: {len(chunk)} characters")

        # Generate embeddings using simple function
        print("Generating embeddings...")
        vectors = [embedding_model(chunk) for chunk in chunks]

        # Store in Qdrant
        points = []
        for i, (chunk, vector) in enumerate(zip(chunks, vectors)):
            point_id = str(uuid.uuid4())
            payload = {
                "file_path": str(file_path),
                "chunk_id": i,
                "content": chunk,
                "content_length": len(chunk)
            }

            # Add category_id to payload if provided
            if category_id:
                payload["category_id"] = category_id

            points.append(qmodels.PointStruct(id=point_id, vector=vector, payload=payload))

        print(f"Storing {len(points)} points in vector database...")
        client.upsert(collection_name=collection_name, points=points)

        result_message = f"Successfully ingested {file_path} into vector database with {len(chunks)} chunks"
        if category_id:
            result_message += f" (Category: {category_id})"

        print(result_message)
        return {"message": result_message, "chunks": len(chunks), "category_id": category_id}

    except Exception as e:
        error_msg = f"Error processing {file_path}: {str(e)}"
        print(error_msg)
        return {"error": error_msg}

# Clear vector database collection
def clear_vector_db(collection_name="file_vectors"):
    """Clear all data from the vector database collection"""
    try:
        client, _ = initialize_vector_db(collection_name)
        client.delete_collection(collection_name)
        print(f"Cleared collection: {collection_name}")

        # Recreate the collection
        client.recreate_collection(
            collection_name=collection_name,
            vectors_config=qmodels.VectorParams(size=384, distance=qmodels.Distance.COSINE)
        )
        print(f"Recreated collection: {collection_name}")
        return {"message": f"Successfully cleared and recreated collection {collection_name}"}

    except Exception as e:
        print(f"Error clearing vector database: {e}")
        return {"error": f"Error clearing vector database: {str(e)}"}

# Main function to process multiple files
def process_files(directory_path, collection_name="file_vectors", category_id=None):
    client, embedding_model = initialize_vector_db(collection_name)

    # Supported file extensions
    supported_extensions = {'.txt', '.pdf', '.docx', '.png', '.jpg', '.jpeg'}

    # Process all files in directory
    for file_path in Path(directory_path).rglob('*'):
        if file_path.suffix.lower() in supported_extensions:
            print(f"Processing {file_path}...")
            if category_id:
                print(f"Using category_id: {category_id}")
            result = ingest_file_to_vector_db(file_path, client, embedding_model, collection_name, category_id)
            if "error" in result:
                print(f"Error processing {file_path}: {result['error']}")

# Example usage
if __name__ == "__main__":
    directory_path = "./input_files"  # Replace with your directory path
    category_id = None  # Set to a category ID if needed
    process_files(directory_path, category_id=category_id)