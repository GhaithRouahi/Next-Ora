#!/bin/bash
# NextOra Docker Deployment Script

set -e

# Default values
ENVIRONMENT="local"
ACTION="up"
BUILD=false
HELP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -b|--build)
            BUILD=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

if [[ "$HELP" == true ]]; then
    echo "NextOra Docker Deployment Script"
    echo ""
    echo "Usage: ./deploy.sh [options]"
    echo ""
    echo "Options:"
    echo "  -e, --environment <env>  Set deployment environment: 'local' or 'vm' (default: local)"
    echo "  -a, --action <action>    Docker action: 'up', 'down', 'restart' (default: up)"
    echo "  -b, --build             Force rebuild of containers"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh                          # Start with localhost"
    echo "  ./deploy.sh -e vm                    # Start with VM IP"
    echo "  ./deploy.sh -a down                  # Stop containers"
    echo "  ./deploy.sh -b                       # Rebuild and start"
    exit 0
fi

# Set environment variables based on deployment type
if [[ "$ENVIRONMENT" == "vm" ]]; then
    export HOST_IP="10.9.21.110"
    export NODE_ENV="production"
    export DOCKERFILE="Dockerfile"
    echo "🚀 Deploying for VM environment (IP: 10.9.21.110)"
else
    export HOST_IP="localhost"
    export NODE_ENV="development"
    export DOCKERFILE="Dockerfile.dev"
    echo "🏠 Deploying for local environment (localhost)"
fi

# Create .env file if it doesn't exist
if [[ ! -f ".env" ]]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "⚠️  Please update .env file with your specific values"
fi

# Update .env file with current settings
if command -v sed >/dev/null 2>&1; then
    sed -i "s/^HOST_IP=.*/HOST_IP=$HOST_IP/" .env
    sed -i "s/^NODE_ENV=.*/NODE_ENV=$NODE_ENV/" .env
    sed -i "s/^DOCKERFILE=.*/DOCKERFILE=$DOCKERFILE/" .env
fi

echo "📋 Current configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Host IP: $HOST_IP"
echo "  Node Environment: $NODE_ENV"
echo "  Dockerfile: $DOCKERFILE"

# Execute Docker Compose commands
case $ACTION in
    up)
        if [[ "$BUILD" == true ]]; then
            echo "🔨 Building and starting containers..."
            docker-compose up --build -d
        else
            echo "▶️  Starting containers..."
            docker-compose up -d
        fi
        
        if [[ $? -eq 0 ]]; then
            echo ""
            echo "✅ Application started successfully!"
            echo "🌐 Frontend: http://$HOST_IP:8080"
            echo "🔧 Backend: http://$HOST_IP:3000"
            echo "📊 Database: $HOST_IP:5432"
        fi
        ;;
    down)
        echo "⏹️  Stopping containers..."
        docker-compose down
        ;;
    restart)
        echo "🔄 Restarting containers..."
        docker-compose restart
        ;;
    *)
        echo "❌ Unknown action: $ACTION"
        echo "Use --help for available options"
        exit 1
        ;;
esac

if [[ "$ACTION" == "up" && $? -eq 0 ]]; then
    echo ""
    echo "📝 View logs with: docker-compose logs -f"
    echo "🛑 Stop with: ./deploy.sh -a down"
fi
