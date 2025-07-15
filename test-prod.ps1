#!/usr/bin/env pwsh
# Test script for NextOra Production Environment

param(
    [string]$ProdIP = "10.9.21.110",  # Change this to your production VM IP
    [switch]$Verbose
)

Write-Host "ðŸš€ Testing NextOra Production Environment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Test URLs
$frontend_url = "http://${ProdIP}:8080"
$backend_url = "http://${ProdIP}:3000"
$api_url = "http://${ProdIP}:3000/api"

Write-Host "ðŸŒ Testing Production at: $ProdIP" -ForegroundColor Yellow
Write-Host ""

# Function to test endpoint
function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [int]$Timeout = 10
    )
    
    Write-Host "  Testing $Name ($Url)..." -NoNewline
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $Timeout -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host " âœ…" -ForegroundColor Green
            if ($Verbose) {
                Write-Host "    Response: $($response.Content.Substring(0, [Math]::Min(100, $response.Content.Length)))..." -ForegroundColor Gray
            }
            return $true
        } else {
            Write-Host " âŒ Status: $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host " âŒ $($_.Exception.Message)" -ForegroundColor Red
        if ($Verbose) {
            Write-Host "    Full Error: $_" -ForegroundColor Gray
        }
        return $false
    }
}

# Function to test Llama health specifically
function Test-LlamaHealth {
    param([string]$ApiUrl)
    
    Write-Host "  Testing Llama Service ($ApiUrl/llama/health)..." -NoNewline
    try {
        $response = Invoke-WebRequest -Uri "$ApiUrl/llama/health" -TimeoutSec 20 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $healthData = $response.Content | ConvertFrom-Json
            
            Write-Host ""
            Write-Host "    Status: $($healthData.status)" -ForegroundColor $(
                switch ($healthData.status) {
                    "success" { "Green" }
                    "warning" { "Yellow" }
                    default { "Red" }
                }
            )
            Write-Host "    Message: $($healthData.message)" -ForegroundColor White
            Write-Host "    URL: $($healthData.url)" -ForegroundColor Gray
            
            return $healthData.status -eq "success"
        } else {
            Write-Host " âŒ Status: $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host " âŒ $($_.Exception.Message)" -ForegroundColor Red
        if ($Verbose) {
            Write-Host "    This could mean:" -ForegroundColor Gray
            Write-Host "    - Backend is not running" -ForegroundColor Gray
            Write-Host "    - Ollama is not accessible from the backend" -ForegroundColor Gray
            Write-Host "    - Network connectivity issues" -ForegroundColor Gray
        }
        return $false
    }
}

Write-Host "ðŸ”Œ Testing connectivity..." -ForegroundColor Blue

# Test services
$frontend_ok = Test-Endpoint "Frontend" $frontend_url
$backend_ok = Test-Endpoint "Backend" $backend_url
$api_ok = Test-Endpoint "API Health" "$api_url/health"

Write-Host ""
Write-Host "ðŸ¤– Testing AI Services..." -ForegroundColor Blue

# Test Llama specifically
$llama_ok = Test-LlamaHealth $api_url

Write-Host ""
Write-Host "ðŸ“Š Test Results Summary:" -ForegroundColor Cyan
Write-Host "  Frontend: $(if($frontend_ok) { 'âœ…' } else { 'âŒ' })"
Write-Host "  Backend:  $(if($backend_ok) { 'âœ…' } else { 'âŒ' })"
Write-Host "  API:      $(if($api_ok) { 'âœ…' } else { 'âŒ' })"
Write-Host "  Llama:    $(if($llama_ok) { 'âœ…' } else { 'âŒ' })"

Write-Host ""
if (-not $llama_ok) {
    Write-Host "ðŸ”§ Troubleshooting Llama Issues:" -ForegroundColor Yellow
    Write-Host "  1. Check if Ollama is running in the VM:" -ForegroundColor White
    Write-Host "     ssh user@$ProdIP 'systemctl status ollama'" -ForegroundColor Gray
    Write-Host "  2. Check if llama3.2 model is installed:" -ForegroundColor White
    Write-Host "     ssh user@$ProdIP 'ollama list'" -ForegroundColor Gray
    Write-Host "  3. Test Ollama directly from VM:" -ForegroundColor White
    Write-Host "     ssh user@$ProdIP 'curl http://localhost:11434/api/tags'" -ForegroundColor Gray
    Write-Host "  4. Check backend logs:" -ForegroundColor White
    Write-Host "     docker-compose -H ssh://user@$ProdIP logs backend" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "ðŸŽ¯ Access URLs:" -ForegroundColor Cyan
Write-Host "  ðŸ“± Frontend: $frontend_url" -ForegroundColor White
Write-Host "  ðŸ”§ Backend:  $backend_url" -ForegroundColor White
Write-Host "  ðŸ“Š API:      $api_url" -ForegroundColor White

Write-Host ""
Write-Host "ðŸ“ Remote debugging commands:" -ForegroundColor Cyan
Write-Host "  Test Ollama:  curl http://${ProdIP}:11434/api/tags" -ForegroundColor White
Write-Host "  Backend logs: docker-compose -H ssh://user@${ProdIP} logs -f backend" -ForegroundColor White
Write-Host "  SSH to VM:    ssh user@${ProdIP}" -ForegroundColor White

