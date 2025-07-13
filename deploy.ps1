#!/usr/bin/env pwsh
# NextOra Docker Deployment Script for Windows

param(
    [string]$Environment = "local",
    [string]$Action = "up",
    [switch]$Build,
    [switch]$Help
)

if ($Help) {
    Write-Host "NextOra Docker Deployment Script"
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Environment <env>  Set deployment environment: 'local' or 'vm' (default: local)"
    Write-Host "  -Action <action>    Docker action: 'up', 'down', 'restart' (default: up)"
    Write-Host "  -Build             Force rebuild of containers"
    Write-Host "  -Help              Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1                          # Start with localhost"
    Write-Host "  .\deploy.ps1 -Environment vm          # Start with VM IP"
    Write-Host "  .\deploy.ps1 -Action down             # Stop containers"
    Write-Host "  .\deploy.ps1 -Build                   # Rebuild and start"
    exit 0
}

# Set environment variables based on deployment type
if ($Environment -eq "vm") {
    $env:HOST_IP = "10.9.21.110"
    $env:NODE_ENV = "production"
    $env:DOCKERFILE = "Dockerfile"
    Write-Host "🚀 Deploying for VM environment (IP: 10.9.21.110)" -ForegroundColor Green
} else {
    $env:HOST_IP = "localhost"
    $env:NODE_ENV = "development"
    $env:DOCKERFILE = "Dockerfile.dev"
    Write-Host "🏠 Deploying for local environment (localhost)" -ForegroundColor Green
}

# Create .env file if it doesn't exist
if (-not (Test-Path ".env")) {
    Write-Host "📝 Creating .env file from .env.example..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "⚠️  Please update .env file with your specific values" -ForegroundColor Yellow
}

# Update .env file with current settings
$envContent = Get-Content ".env"
$envContent = $envContent -replace "^HOST_IP=.*", "HOST_IP=$($env:HOST_IP)"
$envContent = $envContent -replace "^NODE_ENV=.*", "NODE_ENV=$($env:NODE_ENV)"
$envContent = $envContent -replace "^DOCKERFILE=.*", "DOCKERFILE=$($env:DOCKERFILE)"
$envContent | Set-Content ".env"

Write-Host "📋 Current configuration:" -ForegroundColor Cyan
Write-Host "  Environment: $Environment" -ForegroundColor White
Write-Host "  Host IP: $($env:HOST_IP)" -ForegroundColor White
Write-Host "  Node Environment: $($env:NODE_ENV)" -ForegroundColor White
Write-Host "  Dockerfile: $($env:DOCKERFILE)" -ForegroundColor White

# Execute Docker Compose commands
try {
    switch ($Action) {
        "up" {
            if ($Build) {
                Write-Host "🔨 Building and starting containers..." -ForegroundColor Blue
                docker-compose up --build -d
            } else {
                Write-Host "▶️  Starting containers..." -ForegroundColor Blue
                docker-compose up -d
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "✅ Application started successfully!" -ForegroundColor Green
                Write-Host "🌐 Frontend: http://$($env:HOST_IP):8080" -ForegroundColor Green
                Write-Host "🔧 Backend: http://$($env:HOST_IP):3000" -ForegroundColor Green
                Write-Host "📊 Database: $($env:HOST_IP):5432" -ForegroundColor Green
            }
        }
        "down" {
            Write-Host "⏹️  Stopping containers..." -ForegroundColor Red
            docker-compose down
        }
        "restart" {
            Write-Host "🔄 Restarting containers..." -ForegroundColor Yellow
            docker-compose restart
        }
        default {
            Write-Host "❌ Unknown action: $Action" -ForegroundColor Red
            Write-Host "Use -Help for available options" -ForegroundColor Yellow
            exit 1
        }
    }
} catch {
    Write-Host "❌ Error executing Docker Compose: $_" -ForegroundColor Red
    exit 1
}

if ($Action -eq "up" -and $LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "📝 View logs with: docker-compose logs -f" -ForegroundColor Cyan
    Write-Host "🛑 Stop with: .\deploy.ps1 -Action down" -ForegroundColor Cyan
}
