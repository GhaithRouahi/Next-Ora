# NextBrain - AI-Powered Chatbot Application

A full-stack application with React frontend and NestJS backend, featuring AI-powered chatbot functionality.

## 🚀 Quick Start with Docker

The easiest way to run the application is using Docker Compose:

```bash
# Start the application
docker-compose up -d

# Access the applications
# Frontend: http://localhost:8080
# Backend API: http://localhost:3000
```

## 📋 Prerequisites

- Docker Desktop
- Git

## 🐳 Docker Setup

### Production Mode

1. **Start the application**:
   ```bash
   docker-compose up -d
   ```

2. **View logs**:
   ```bash
   docker-compose logs -f
   ```

3. **Stop the application**:
   ```bash
   docker-compose down
   ```

### Development Mode

For development with hot reload:

```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f
```

### Using npm scripts

```bash
# Production
npm run docker:start    # Start containers
npm run docker:stop     # Stop containers
npm run docker:build    # Rebuild and start
npm run docker:logs     # View logs
npm run docker:reset    # Reset everything (WARNING: deletes data)

# Development
npm run docker:dev      # Start development environment
```

### Using the management script (Windows)

```bash
# Start application
./docker-manager.bat start

# Show logs
./docker-manager.bat logs

# Show logs for specific service
./docker-manager.bat logs backend

# Stop application
./docker-manager.bat stop

# Rebuild
./docker-manager.bat build

# Reset (WARNING: deletes all data)
./docker-manager.bat reset
```

## 🏗️ Project Structure

```
Next-brain/
├── docker-compose.yml          # Production Docker setup
├── docker-compose.dev.yml      # Development Docker setup
├── docker-manager.bat          # Windows management script
├── .env.docker                 # Docker environment template
├── next-ora/                   # React frontend
│   ├── Dockerfile              # Production frontend image
│   ├── Dockerfile.dev          # Development frontend image
│   └── ...
├── nextBrain-back/             # NestJS backend
│   ├── Dockerfile              # Production backend image
│   ├── Dockerfile.dev          # Development backend image
│   └── ...
└── DOCKER_README.md           # Detailed Docker documentation
```

## 🔧 Services

The application consists of three main services:

- **Frontend** (port 8080): React/Vite application
- **Backend** (port 3000): NestJS API server
- **Database** (port 5432): PostgreSQL database

## 🛠️ Development

### Local Development (without Docker)

1. **Backend**:
   ```bash
   cd nextBrain-back
   npm install
   npm run start:dev
   ```

2. **Frontend**:
   ```bash
   cd next-ora
   npm install
   npm run dev
   ```

### Database Setup

The Docker setup automatically:
- Creates a PostgreSQL database
- Runs migrations
- Seeds initial data

## 📝 Environment Variables

Key environment variables (see `.env.docker` for full list):

- `JWT_SECRET`: JWT signing secret (change in production)
- `POSTGRES_PASSWORD`: Database password
- `SMTP_*`: Email configuration for notifications

## 🔒 Security Notes

For production deployment:
1. Change default JWT secrets
2. Use strong database password
3. Configure proper SMTP settings
4. Set up SSL certificates
5. Use environment-specific configurations

## 📖 Additional Documentation

- [Detailed Docker Setup](DOCKER_README.md)
- [Chat Delete Functionality](CHAT_DELETE_FUNCTIONALITY.md)
- [Chat History Implementation](CHAT_HISTORY_IMPLEMENTATION.md)
- [Sidebar Chat Integration](SIDEBAR_CHAT_INTEGRATION.md)
- [Integration Guide](INTEGRATION_GUIDE.md)

## 🐛 Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 3000, 5432, and 8080 are available
2. **Database connection**: Check if PostgreSQL container is healthy
3. **Build failures**: Try `docker-compose down && docker-compose up -d --build`

### Reset Everything

```bash
# Stop all services and remove data
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Start fresh
docker-compose up -d --build
```

## 📞 Support

For issues and questions:
1. Check the logs: `docker-compose logs -f`
2. Review the troubleshooting section in [DOCKER_README.md](DOCKER_README.md)
3. Reset the environment if needed
