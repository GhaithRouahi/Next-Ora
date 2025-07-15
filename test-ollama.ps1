#!/usr/bin/env pwsh
# Test script for Ollama connectivity in production environment

param(
    [string]$ProdIP = "10.9.21.110",
    [string]$OllamaIP = "10.9.21.254",  # The IP where Ollama is running
    [int]$OllamaPort = 11434,
    [switch]$Verbose
)

Write-Host "🦙 Testing Ollama Connectivity" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

# Configuration
$ollama_host = $OllamaIP
$ollama_port = $OllamaPort
$ollama_api_url = "http://${ollama_host}:${ollama_port}/api"

Write-Host "Ollama URL: $ollama_api_url" -ForegroundColor Yellow
Write-Host "Production VM: $ProdIP" -ForegroundColor Yellow
Write-Host ""

Write-Host "🌐 Testing Ollama at: $ollama_api_url" -ForegroundColor Yellow
Write-Host ""

# Test 1: Basic connectivity
Write-Host "📡 Testing basic connectivity..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri "$ollama_api_url/tags" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host " ✅" -ForegroundColor Green
    } else {
        Write-Host " ❌ Status: $($response.StatusCode)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host " ❌ $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔍 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  1. Verify Ollama is running on $ollama_host" -ForegroundColor White
    Write-Host "  2. Check if port $ollama_port is accessible" -ForegroundColor White
    Write-Host "  3. Verify firewall settings" -ForegroundColor White
    Write-Host "  4. Try: ssh $ollama_host 'ollama list'" -ForegroundColor White
    exit 1
}

# Test 2: List available models
Write-Host "📋 Checking available models..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri "$ollama_api_url/tags" -TimeoutSec 10 -UseBasicParsing
    $models = ($response.Content | ConvertFrom-Json).models
    
    if ($models.Count -gt 0) {
        Write-Host " ✅ Found $($models.Count) models" -ForegroundColor Green
        
        $llamaModels = $models | Where-Object { $_.name -like "*llama*" }
        if ($llamaModels.Count -gt 0) {
            Write-Host "🦙 Llama models found:" -ForegroundColor Green
            foreach ($model in $llamaModels) {
                Write-Host "  • $($model.name) (Size: $([math]::Round($model.size / 1GB, 2)) GB)" -ForegroundColor Green
            }
        } else {
            Write-Host "⚠️  No Llama models found!" -ForegroundColor Yellow
            Write-Host "Available models:" -ForegroundColor Yellow
            foreach ($model in $models) {
                Write-Host "  • $($model.name)" -ForegroundColor White
            }
        }
    } else {
        Write-Host " ⚠️  No models available" -ForegroundColor Yellow
    }
} catch {
    Write-Host " ❌ $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Test chat completion
Write-Host ""
Write-Host "💬 Testing chat completion..." -NoNewline
try {
    $chatBody = @{
        model = "llama3.2:latest"
        messages = @(
            @{
                role = "user"
                content = "Hello! Please respond with just 'OK' to confirm you're working."
            }
        )
        stream = $false
    } | ConvertTo-Json -Depth 10

    $response = Invoke-WebRequest -Uri "$ollama_api_url/chat" -Method POST -Body $chatBody -ContentType "application/json" -TimeoutSec 30 -UseBasicParsing
    
    if ($response.StatusCode -eq 200) {
        $chatResponse = $response.Content | ConvertFrom-Json
        if ($chatResponse.message -and $chatResponse.message.content) {
            Write-Host " ✅" -ForegroundColor Green
            Write-Host "📝 Response: $($chatResponse.message.content.Trim())" -ForegroundColor Green
        } else {
            Write-Host " ❌ Invalid response format" -ForegroundColor Red
        }
    } else {
        Write-Host " ❌ Status: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host " ❌ $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Message -like "*llama3.2:latest*") {
        Write-Host "💡 Tip: Try installing the model with: ollama pull llama3.2:latest" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "🔍 Network Test Commands:" -ForegroundColor Cyan
Write-Host "  Ping host:           ping $ollama_host" -ForegroundColor White
Write-Host "  Test port:           Test-NetConnection $ollama_host -Port $ollama_port" -ForegroundColor White
Write-Host "  SSH and test:        ssh $ollama_host 'ollama list'" -ForegroundColor White
Write-Host "  Curl test:           curl -X GET $ollama_api_url/tags" -ForegroundColor White

Write-Host ""
Write-Host "📚 Docker Environment Variables:" -ForegroundColor Cyan
Write-Host "  LLAMA_API_URL=http://${ollama_host}:${ollama_port}/api/chat" -ForegroundColor White
