FROM --platform=linux/amd64 python:3.11-slim

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application code
COPY rag_service/ ./rag_service/
COPY . .

EXPOSE 8001

CMD ["uvicorn", "rag_service.main:app", "--host", "0.0.0.0", "--port", "8001"]
