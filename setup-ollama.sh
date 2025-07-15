#!/bin/bash
# Setup script for Ollama on VM - Linux version

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_HOST="${1:-10.9.21.110}"
OLLAMA_PORT="${2:-11434}"
OLLAMA_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}"

echo -e "${CYAN}Setting up Ollama connection to VM and checking required models...${NC}"
echo -e "${YELLOW}Ollama Host: $OLLAMA_HOST${NC}"
echo -e "${YELLOW}Ollama Port: $OLLAMA_PORT${NC}"

# Test connection to Ollama on VM
echo -e "${YELLOW}Testing connection to Ollama on VM...${NC}"
if response=$(curl -s --connect-timeout 10 --max-time 10 "$OLLAMA_URL/api/tags" 2>/dev/null); then
    if echo "$response" | grep -q "models"; then
        echo -e "${GREEN}✅ Successfully connected to Ollama on VM${NC}"
    else
        echo -e "${RED}❌ Invalid response from Ollama${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to connect to Ollama on VM${NC}"
    echo -e "${YELLOW}Please ensure:${NC}"
    echo -e "${WHITE}  1. Ollama is running on $OLLAMA_HOST${NC}"
    echo -e "${WHITE}  2. Port $OLLAMA_PORT is accessible${NC}"
    echo -e "${WHITE}  3. Firewall allows connections${NC}"
    exit 1
fi

# Check if llama3.2 model is available
echo -e "${YELLOW}Checking for llama3.2 model...${NC}"
if models_response=$(curl -s --connect-timeout 10 --max-time 10 "$OLLAMA_URL/api/tags" 2>/dev/null); then
    if echo "$models_response" | grep -q "llama3.2"; then
        llama_model=$(echo "$models_response" | grep -o '"name":"[^"]*llama3.2[^"]*"' | head -1 | cut -d'"' -f4)
        echo -e "${GREEN}✅ Found llama3.2 model: $llama_model${NC}"
        
        # Test the model with a simple request
        echo -e "${CYAN}Testing model with a simple chat...${NC}"
        test_payload='{
            "model": "'$llama_model'",
            "messages": [
                {
                    "role": "user",
                    "content": "Hello! Please respond with just '\''OK'\'' to confirm you'\''re working."
                }
            ],
            "stream": false
        }'
        
        if chat_response=$(curl -s --connect-timeout 30 --max-time 30 \
            -H "Content-Type: application/json" \
            -d "$test_payload" \
            "$OLLAMA_URL/api/chat" 2>/dev/null); then
            
            if echo "$chat_response" | grep -q '"content"'; then
                content=$(echo "$chat_response" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
                echo -e "${GREEN}✅ Model test successful: $content${NC}"
            else
                echo -e "${YELLOW}⚠️ Model responded but format unexpected${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ Model test failed, but model is available${NC}"
        fi
    else
        echo -e "${RED}❌ llama3.2 model not found on VM${NC}"
        echo -e "${YELLOW}Available models:${NC}"
        echo "$models_response" | grep -o '"name":"[^"]*"' | while read -r line; do
            model_name=$(echo "$line" | cut -d'"' -f4)
            echo -e "${WHITE}  - $model_name${NC}"
        done
        echo -e "${YELLOW}Please install llama3.2 on the VM with:${NC}"
        echo -e "${WHITE}  ssh user@$OLLAMA_HOST 'ollama pull llama3.2:latest'${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to check models${NC}"
    exit 1
fi

echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo -e "${CYAN}Configuration for Docker Compose:${NC}"
echo -e "${WHITE}  LLAMA_API_URL=$OLLAMA_URL/api/chat${NC}"
echo ""
echo -e "${CYAN}You can now test the integration with:${NC}"
echo -e "${WHITE}  curl http://localhost:3000/api/llama/health${NC}"