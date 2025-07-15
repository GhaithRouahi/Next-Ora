#!/usr/bin/env pwsh
# Test script for NextOra deployment

Write-Host "🧪 Testing NextOra Deployment" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Get environment configuration
$env_file = ".env"
if (Test-Path $env_file) {
    $env_content = Get-Content $env_file
    $host_ip = ($env_content | Where-Object { $_ -like "HOST_IP=*" } | ForEach-Object { $_.Split("=")[1] }) -replace '"',''
    if (-not $host_ip) { $host_ip = "localhost" }
} else {
    $host_ip = "localhost"
}

Write-Host "🌐 Testing with HOST_IP: $host_ip" -ForegroundColor Yellow

# Test URLs
$frontend_url = "http://${host_ip}:8080"
$backend_url = "http://${host_ip}:3000"
$api_url = "http://${host_ip}:3000/api"

Write-Host ""
Write-Host "📋 Checking Docker containers..." -ForegroundColor Blue

try {
    $containers = docker-compose ps --format json | ConvertFrom-Json
    foreach ($container in $containers) {
        $status = if ($container.State -eq "running") { "✅" } else { "❌" }
        Write-Host "  $status $($container.Name): $($container.State)" -ForegroundColor $(if ($container.State -eq "running") { "Green" } else { "Red" })
    }
} catch {
    Write-Host "❌ Failed to check containers: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔌 Testing connectivity..." -ForegroundColor Blue

# Test Frontend
Write-Host "  Testing Frontend ($frontend_url)..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri $frontend_url -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host " ✅" -ForegroundColor Green
    } else {
        Write-Host " ❌ Status: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host " ❌ $($_.Exception.Message)" -ForegroundColor Red
}

# Test Backend Health
Write-Host "  Testing Backend ($backend_url)..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri $backend_url -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host " ✅" -ForegroundColor Green
    } else {
        Write-Host " ❌ Status: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host " ❌ $($_.Exception.Message)" -ForegroundColor Red
}

# Test API Health
Write-Host "  Testing API ($api_url/health)..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri "$api_url/health" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host " ✅" -ForegroundColor Green
    } else {
        Write-Host " ❌ Status: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host " ❌ $($_.Exception.Message)" -ForegroundColor Red
}

# Test Llama Service
Write-Host "  Testing Llama Service ($api_url/llama/health)..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri "$api_url/llama/health" -TimeoutSec 15 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        $healthData = $response.Content | ConvertFrom-Json
        if ($healthData.status -eq "success") {
            Write-Host " ✅" -ForegroundColor Green
        } elseif ($healthData.status -eq "warning") {
            Write-Host " ⚠️  $($healthData.message)" -ForegroundColor Yellow
        } else {
            Write-Host " ❌ $($healthData.message)" -ForegroundColor Red
        }
    } else {
        Write-Host " ❌ Status: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host " ❌ $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 Access URLs:" -ForegroundColor Cyan
Write-Host "  📱 Frontend: $frontend_url" -ForegroundColor White
Write-Host "  🔧 Backend:  $backend_url" -ForegroundColor White
Write-Host "  📊 API:      $api_url" -ForegroundColor White

Write-Host ""
Write-Host "📝 Useful commands:" -ForegroundColor Cyan
Write-Host "  View logs:    docker-compose logs -f" -ForegroundColor White
Write-Host "  Stop:         .\deploy.ps1 -Action down" -ForegroundColor White
Write-Host "  Restart:      .\deploy.ps1 -Action restart" -ForegroundColor White
