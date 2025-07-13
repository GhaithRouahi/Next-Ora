# NextOra Docker Deployment Guide

This guide explains how to deploy NextOra using Docker, with automatic configuration for both local development and VM deployment.

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Git (to clone the repository)

### Local Development
```bash
# Windows PowerShell
.\deploy.ps1

# Linux/Unix
./deploy.sh
```

### VM Deployment
```bash
# Windows PowerShell
.\deploy.ps1 -Environment vm

# Linux/Unix
./deploy.sh -e vm
```

## 📋 Configuration

### Environment Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` file:**
   ```bash
   # For Local Development
   HOST_IP=localhost
   NODE_ENV=development
   DOCKERFILE=Dockerfile.dev

   # For VM Deployment
   HOST_IP=10.9.21.110  # Your VM IP
   NODE_ENV=production
   DOCKERFILE=Dockerfile
   ```

### Key Environment Variables

| Variable | Description | Local Value | VM Value |
|----------|-------------|-------------|----------|
| `HOST_IP` | Server IP address | `localhost` | Your VM IP (e.g., `10.9.21.110`) |
| `NODE_ENV` | Environment mode | `development` | `production` |
| `DOCKERFILE` | Docker file to use | `Dockerfile.dev` | `Dockerfile` |

## 🛠 Deployment Commands

### Using Deployment Scripts (Recommended)

#### Windows PowerShell
```powershell
# Local development
.\deploy.ps1

# VM deployment
.\deploy.ps1 -Environment vm

# Build and start
.\deploy.ps1 -Build

# Stop containers
.\deploy.ps1 -Action down

# Restart containers
.\deploy.ps1 -Action restart

# Show help
.\deploy.ps1 -Help
```

#### Linux/Unix Bash
```bash
# Local development
./deploy.sh

# VM deployment
./deploy.sh -e vm

# Build and start
./deploy.sh -b

# Stop containers
./deploy.sh -a down

# Restart containers
./deploy.sh -a restart

# Show help
./deploy.sh -h
```

### Manual Docker Compose

#### For Local Development
```bash
# Set environment variables
export HOST_IP=localhost
export NODE_ENV=development
export DOCKERFILE=Dockerfile.dev

# Start services
docker-compose up -d

# With development overrides
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

#### For VM Deployment
```bash
# Set environment variables
export HOST_IP=10.9.21.110  # Your VM IP
export NODE_ENV=production
export DOCKERFILE=Dockerfile

# Start services
docker-compose up -d
```

## 🌐 Access URLs

After successful deployment:

### Local Development
- **Frontend:** http://localhost:8080
- **Backend API:** http://localhost:3000
- **Database:** localhost:5432

### VM Deployment
- **Frontend:** http://10.9.21.110:8080
- **Backend API:** http://10.9.21.110:3000
- **Database:** 10.9.21.110:5432

## 📊 Service Architecture

The application consists of three main services:

1. **PostgreSQL Database**
   - Port: 5432
   - Health checks enabled
   - Persistent data storage

2. **Backend API (NestJS)**
   - Port: 3000
   - JWT authentication
   - Prisma ORM
   - AI services integration

3. **Frontend (React/Vite)**
   - Port: 8080
   - Environment-aware API connections
   - Hot reload in development

## 🔧 Development Features

### Development Mode Benefits
- **Hot Reload:** Code changes reflect immediately
- **Debug Ports:** Backend debugging on port 9229
- **Volume Mounts:** Live code editing
- **Enhanced Logging:** Detailed development logs

### Production Mode Benefits
- **Optimized Builds:** Minified and optimized code
- **Health Checks:** Container health monitoring
- **Security:** Production-ready JWT secrets
- **Performance:** Optimized container images

## 📝 Monitoring and Logs

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f postgres
```

### Health Checks
```bash
# Check container status
docker-compose ps

# Health check status
docker inspect nextbrain-postgres --format='{{.State.Health.Status}}'
```

## 🛑 Stopping Services

```bash
# Using deployment script
.\deploy.ps1 -Action down  # Windows
./deploy.sh -a down        # Linux

# Using Docker Compose
docker-compose down

# Remove volumes (⚠️ This will delete database data)
docker-compose down -v
```

## 🔍 Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check if ports are in use
   netstat -an | grep :8080
   netstat -an | grep :3000
   netstat -an | grep :5432
   ```

2. **Environment Variables**
   ```bash
   # Verify .env file exists and has correct values
   cat .env
   ```

3. **Container Health**
   ```bash
   # Check container status
   docker-compose ps
   
   # Check logs for errors
   docker-compose logs backend
   ```

4. **Network Connectivity**
   ```bash
   # Test backend connection
   curl http://localhost:3000/api/health
   
   # For VM deployment
   curl http://10.9.21.110:3000/api/health
   ```

### Reset Everything
```bash
# Stop and remove everything
docker-compose down -v --remove-orphans

# Remove built images
docker-compose build --no-cache

# Start fresh
.\deploy.ps1 -Build  # Windows
./deploy.sh -b       # Linux
```

## 🔐 Security Considerations

### For Production VM Deployment

1. **Change Default Secrets:**
   ```bash
   # Update in .env file
   JWT_SECRET=your_secure_jwt_secret
   JWT_REFRESH_SECRET=your_secure_refresh_secret
   POSTGRES_PASSWORD=your_secure_db_password
   ```

2. **Firewall Configuration:**
   ```bash
   # Allow specific ports only
   ufw allow 8080/tcp  # Frontend
   ufw allow 3000/tcp  # Backend
   ufw deny 5432/tcp   # Database (internal only)
   ```

3. **SSL/TLS (Recommended):**
   - Use reverse proxy (nginx, traefik)
   - Configure SSL certificates
   - Update URLs to use HTTPS

## 📱 Mobile Development

For mobile app development, ensure the VM IP is accessible from mobile devices:

```bash
# Test from mobile device browser
http://10.9.21.110:8080
```

## 🆘 Support

If you encounter issues:

1. Check the logs: `docker-compose logs -f`
2. Verify environment variables in `.env`
3. Ensure Docker and Docker Compose are updated
4. Check network connectivity between services
5. Review the troubleshooting section above
