#!/usr/bin/env pwsh
# Setup script for Ollama in Docker Compose - PowerShell version

Write-Host "Setting up Ollama with required models..." -ForegroundColor Cyan

# Wait for Ollama to be ready
Write-Host "Waiting for Ollama service to start..." -ForegroundColor Yellow
$timeout = 60
$count = 0

do {
    if ($count -ge $timeout) {
        Write-Host "ERROR: Ollama service did not start within $timeout seconds" -ForegroundColor Red
        exit 1
    }
    Write-Host "Waiting... ($count/$timeout)" -ForegroundColor Gray
    Start-Sleep 1
    $count++
    
    try {
        docker compose exec ollama curl -s http://localhost:11434/api/tags 2>$null | Out-Null
        $ready = $?
    } catch {
        $ready = $false
    }
} while (-not $ready)

Write-Host "Ollama is ready!" -ForegroundColor Green

# Pull the required Llama model
Write-Host "Pulling llama3.2:latest model (this may take a while)..." -ForegroundColor Yellow
docker compose exec ollama ollama pull llama3.2:latest

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully pulled llama3.2:latest" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to pull llama3.2:latest" -ForegroundColor Red
    Write-Host "Trying to pull llama3.2:1b as fallback..." -ForegroundColor Yellow
    docker compose exec ollama ollama pull llama3.2:1b
}

# List available models
Write-Host "Available models:" -ForegroundColor Cyan
docker compose exec ollama ollama list

# Test the model
Write-Host "Testing model with a simple chat..." -ForegroundColor Cyan
docker compose exec ollama ollama run llama3.2:latest "Hello! Please respond with just 'OK' to confirm you're working."

Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now test the integration with:" -ForegroundColor Cyan
Write-Host "  curl http://localhost:3000/api/llama/health" -ForegroundColor White
