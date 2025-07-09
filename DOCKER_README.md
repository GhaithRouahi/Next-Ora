# NextBrain Docker Setup

This document explains how to run the NextBrain application using Docker and Docker Compose.

## Prerequisites

- Docker Desktop installed and running
- Docker Compose (usually included with Docker Desktop)

## Quick Start

1. **Clone the repository** (if not already done):
   ```bash
   git clone <repository-url>
   cd Next-brain
   ```

2. **Set up environment variables** (optional):
   ```bash
   cp .env.docker .env
   ```
   Edit the `.env` file to customize configuration if needed.

3. **Start the application**:
   ```bash
   docker-compose up -d
   ```

4. **Access the application**:
   - Frontend: http://localhost:8080
   - Backend API: http://localhost:3000
   - PostgreSQL: localhost:5432

## Services

The Docker Compose setup includes:

- **postgres**: PostgreSQL 15 database
- **ollama**: Ollama server for Llama AI models (port 11434)
- **backend**: NestJS API server (Node.js)
- **frontend**: React/Vite frontend application

## AI Services Configuration

### Llama (via Ollama)
- **Ollama server**: http://localhost:11434
- **Model**: llama3.2 (automatically downloaded on first run)
- **No API key required**

### Gemini (Google AI)
- **API key required**: Get from https://makersuite.google.com/app/apikey
- **Set environment variable**: `GEMINI_API_KEY=your_actual_key`

## Environment Variables

Key environment variables for AI services:

- `LLAMA_API_URL`: http://ollama:11434/api/chat (default)
- `GEMINI_API_KEY`: Your Gemini API key (required for Gemini functionality)

## Quick Start

1. **Set up environment variables**:
   ```bash
   cp .env.docker .env
   # Edit .env file and set your GEMINI_API_KEY
   ```

2. **Start the application**:
   ```bash
   docker-compose up -d
   ```

3. **Download Llama model** (first time only):
   ```bash
   docker-compose exec ollama ollama pull llama3.2
   ```

4. **Test AI services**:
   ```bash
   # Windows
   ./test-ai-services.bat
   
   # Linux/Mac
   ./test-ai-services.sh
   ```

## Commands

### Start all services
```bash
docker-compose up -d
```

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
```

### Stop all services
```bash
docker-compose down
```

### Rebuild and restart
```bash
docker-compose down
docker-compose up -d --build
```

### Reset database (WARNING: This will delete all data)
```bash
docker-compose down -v
docker-compose up -d
```

## Development

For development with hot-reload:

1. **Backend development**:
   ```bash
   # Stop only the backend container
   docker-compose stop backend
   
   # Run backend locally
   cd nextBrain-back
   npm install
   npm run start:dev
   ```

2. **Frontend development**:
   ```bash
   # Stop only the frontend container
   docker-compose stop frontend
   
   # Run frontend locally
   cd next-ora
   npm install
   npm run dev
   ```

## Environment Variables

Key environment variables for production:

- `JWT_SECRET`: Change this to a secure random string
- `JWT_REFRESH_SECRET`: Change this to a different secure random string
- `POSTGRES_PASSWORD`: Use a strong password
- `SMTP_*`: Configure email settings for notifications

## Troubleshooting

### Database connection issues
```bash
# Check if postgres is running
docker-compose ps

# Check postgres logs
docker-compose logs postgres

# Restart postgres
docker-compose restart postgres
```

### Backend not starting
```bash
# Check backend logs
docker-compose logs backend

# Rebuild backend
docker-compose up -d --build backend
```

### Frontend not accessible
```bash
# Check frontend logs
docker-compose logs frontend

# Check if port 8080 is available
netstat -an | findstr :8080
```

### Reset everything
```bash
# Stop all services and remove volumes
docker-compose down -v

# Remove all images
docker-compose down --rmi all

# Start fresh
docker-compose up -d --build
```

## Production Deployment

For production deployment:

1. Update environment variables in `.env` file
2. Use proper secrets management
3. Configure reverse proxy (nginx/Apache)
4. Set up SSL certificates
5. Configure database backups
6. Monitor logs and performance

## Data Persistence

- Database data is persisted in a Docker volume
- User uploads are persisted in `./nextBrain-back/uploads`
- To backup data, copy the uploads folder and export the database
