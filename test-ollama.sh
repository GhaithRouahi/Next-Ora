#!/bin/bash
# Test script for Ollama connectivity in production environment - Linux compatible

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_HOST="${1:-10.9.21.110}"
OLLAMA_PORT="${2:-11434}"
OLLAMA_API_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}/api"

echo -e "${CYAN}Testing Ollama Connectivity${NC}"
echo -e "${CYAN}===========================${NC}"

echo -e "${YELLOW}Testing Ollama at: $OLLAMA_API_URL${NC}"
echo ""

# Test 1: Basic connectivity
echo -n "Testing basic connectivity..."
if response=$(curl -s --connect-timeout 10 --max-time 10 "$OLLAMA_API_URL/tags" 2>/dev/null); then
    if echo "$response" | grep -q "models"; then
        echo -e " ${GREEN}[OK]${NC}"
    else
        echo -e " ${RED}[FAIL] Invalid response${NC}"
        echo "Response: $response"
        exit 1
    fi
else
    echo -e " ${RED}[FAIL] Connection failed${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting tips:${NC}"
    echo -e "  ${WHITE}1. Verify Ollama is running on $OLLAMA_HOST${NC}"
    echo -e "  ${WHITE}2. Check if port $OLLAMA_PORT is accessible${NC}"
    echo -e "  ${WHITE}3. Verify firewall settings${NC}"
    echo -e "  ${WHITE}4. Try: ssh $OLLAMA_HOST 'ollama list'${NC}"
    exit 1
fi

# Test 2: List available models
echo -n "Checking available models..."
if response=$(curl -s --connect-timeout 10 --max-time 10 "$OLLAMA_API_URL/tags" 2>/dev/null); then
    model_count=$(echo "$response" | grep -o '"name"' | wc -l)
    
    if [ "$model_count" -gt 0 ]; then
        echo -e " ${GREEN}[OK] Found $model_count models${NC}"
        
        # Check for Llama models
        if echo "$response" | grep -q "llama"; then
            echo -e "${GREEN}Llama models found:${NC}"
            echo "$response" | grep -o '"name":"[^"]*llama[^"]*"' | while read -r line; do
                model_name=$(echo "$line" | cut -d'"' -f4)
                echo -e "  ${GREEN}• $model_name${NC}"
            done
        else
            echo -e "${YELLOW}WARNING: No Llama models found!${NC}"
            echo -e "${YELLOW}Available models:${NC}"
            echo "$response" | grep -o '"name":"[^"]*"' | while read -r line; do
                model_name=$(echo "$line" | cut -d'"' -f4)
                echo -e "  ${WHITE}• $model_name${NC}"
            done
        fi
    else
        echo -e " ${YELLOW}[WARN] No models available${NC}"
    fi
else
    echo -e " ${RED}[FAIL] Failed to list models${NC}"
fi

# Test 3: Test chat completion
echo ""
echo -n "Testing chat completion..."

chat_payload='{
    "model": "llama3.2:latest",
    "messages": [
        {
            "role": "user",
            "content": "Hello! Please respond with just '\''OK'\'' to confirm you'\''re working."
        }
    ],
    "stream": false
}'

if response=$(curl -s --connect-timeout 30 --max-time 30 \
    -H "Content-Type: application/json" \
    -d "$chat_payload" \
    "$OLLAMA_API_URL/chat" 2>/dev/null); then
    
    if echo "$response" | grep -q '"content"'; then
        content=$(echo "$response" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
        echo -e " ${GREEN}[OK]${NC}"
        echo -e "${GREEN}Response: $content${NC}"
    else
        echo -e " ${RED}[FAIL] Invalid response format${NC}"
        echo "Response: $response"
    fi
else
    echo -e " ${RED}[FAIL] Chat completion failed${NC}"
    echo -e "${YELLOW}TIP: Try installing the model with: ollama pull llama3.2:latest${NC}"
fi

echo ""
echo -e "${CYAN}Network Test Commands:${NC}"
echo -e "  ${WHITE}Ping host:           ping $OLLAMA_HOST${NC}"
echo -e "  ${WHITE}Test port:           nc -zv $OLLAMA_HOST $OLLAMA_PORT${NC}"
echo -e "  ${WHITE}SSH and test:        ssh user@$OLLAMA_HOST 'ollama list'${NC}"
echo -e "  ${WHITE}Curl test:           curl -X GET $OLLAMA_API_URL/tags${NC}"

echo ""
echo -e "${CYAN}Docker Environment Variables:${NC}"
echo -e "  ${WHITE}LLAMA_API_URL=http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/chat${NC}"

echo ""
echo -e "${CYAN}Usage Examples:${NC}"
echo -e "  ${WHITE}Test from local:     ./test-ollama.sh${NC}"
echo -e "  ${WHITE}Test custom host:    ./test-ollama.sh 192.168.1.100${NC}"
echo -e "  ${WHITE}Test custom port:    ./test-ollama.sh 192.168.1.100 11435${NC}"
