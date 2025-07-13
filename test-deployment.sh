#!/bin/bash
# Test script for NextOra deployment

echo "🧪 Testing NextOra Deployment"
echo "================================"

# Get environment configuration
env_file=".env"
if [[ -f "$env_file" ]]; then
    host_ip=$(grep "HOST_IP=" "$env_file" | cut -d'=' -f2 | tr -d '"')
    if [[ -z "$host_ip" ]]; then
        host_ip="localhost"
    fi
else
    host_ip="localhost"
fi

echo "🌐 Testing with HOST_IP: $host_ip"

# Test URLs
frontend_url="http://${host_ip}:8080"
backend_url="http://${host_ip}:3000"
api_url="http://${host_ip}:3000/api"

echo ""
echo "📋 Checking Docker containers..."

if command -v docker-compose >/dev/null 2>&1; then
    docker-compose ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}" | while IFS= read -r line; do
        if [[ "$line" == *"running"* ]]; then
            echo "  ✅ $line"
        elif [[ "$line" == *"Name"* ]]; then
            echo "  $line"
        else
            echo "  ❌ $line"
        fi
    done
else
    echo "❌ docker-compose not found"
fi

echo ""
echo "🔌 Testing connectivity..."

# Test Frontend
echo -n "  Testing Frontend ($frontend_url)..."
if curl -s --max-time 10 "$frontend_url" >/dev/null 2>&1; then
    echo " ✅"
else
    echo " ❌"
fi

# Test Backend
echo -n "  Testing Backend ($backend_url)..."
if curl -s --max-time 10 "$backend_url" >/dev/null 2>&1; then
    echo " ✅"
else
    echo " ❌"
fi

# Test API Health
echo -n "  Testing API ($api_url/health)..."
if curl -s --max-time 10 "$api_url/health" >/dev/null 2>&1; then
    echo " ✅"
else
    echo " ❌"
fi

echo ""
echo "🎯 Access URLs:"
echo "  📱 Frontend: $frontend_url"
echo "  🔧 Backend:  $backend_url"
echo "  📊 API:      $api_url"

echo ""
echo "📝 Useful commands:"
echo "  View logs:    docker-compose logs -f"
echo "  Stop:         ./deploy.sh -a down"
echo "  Restart:      ./deploy.sh -a restart"
