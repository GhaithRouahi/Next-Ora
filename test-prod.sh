#!/bin/bash
# Test script for NextOra Production Environment - Linux compatible

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
PROD_IP="${1:-10.9.21.110}"  # Use first argument or default
VERBOSE="${2:-false}"

echo -e "${CYAN}Testing NextOra Production Environment${NC}"
echo -e "${CYAN}=======================================${NC}"

# Test URLs
frontend_url="http://${PROD_IP}:8080"
backend_url="http://${PROD_IP}:3000"
api_url="http://${PROD_IP}:3000/api"

echo -e "${YELLOW}Testing Production at: ${PROD_IP}${NC}"
echo ""

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local timeout="${3:-10}"
    
    echo -n "  Testing $name ($url)..."
    
    if response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null); then
        if [ "$response" = "200" ]; then
            echo -e " ${GREEN}[OK]${NC}"
            return 0
        else
            echo -e " ${RED}[FAIL] Status: $response${NC}"
            return 1
        fi
    else
        echo -e " ${RED}[FAIL] Connection failed${NC}"
        return 1
    fi
}

# Function to test Llama health specifically
test_llama_health() {
    local api_url="$1"
    
    echo -n "  Testing Llama Service ($api_url/llama/health)..."
    
    if response=$(curl -s --connect-timeout 20 --max-time 20 "$api_url/llama/health" 2>/dev/null); then
        if echo "$response" | grep -q '"status"'; then
            status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            url=$(echo "$response" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
            
            echo ""
            case "$status" in
                "success")
                    echo -e "    Status: ${GREEN}$status${NC}"
                    ;;
                "warning")
                    echo -e "    Status: ${YELLOW}$status${NC}"
                    ;;
                *)
                    echo -e "    Status: ${RED}$status${NC}"
                    ;;
            esac
            echo -e "    Message: ${WHITE}$message${NC}"
            echo -e "    URL: ${GRAY}$url${NC}"
            
            [ "$status" = "success" ] && return 0 || return 1
        else
            echo -e " ${RED}[FAIL] Invalid response format${NC}"
            return 1
        fi
    else
        echo -e " ${RED}[FAIL] Connection failed${NC}"
        if [ "$VERBOSE" = "true" ]; then
            echo -e "    ${GRAY}This could mean:${NC}"
            echo -e "    ${GRAY}- Backend is not running${NC}"
            echo -e "    ${GRAY}- Ollama is not accessible from the backend${NC}"
            echo -e "    ${GRAY}- Network connectivity issues${NC}"
        fi
        return 1
    fi
}

echo -e "${BLUE}Testing connectivity...${NC}"

# Test services
frontend_ok=false
backend_ok=false
api_ok=false
llama_ok=false

if test_endpoint "Frontend" "$frontend_url"; then
    frontend_ok=true
fi

if test_endpoint "Backend" "$backend_url"; then
    backend_ok=true
fi

if test_endpoint "API Health" "$api_url/health"; then
    api_ok=true
fi

echo ""
echo -e "${BLUE}Testing AI Services...${NC}"

# Test Llama specifically
if test_llama_health "$api_url"; then
    llama_ok=true
fi

echo ""
echo -e "${CYAN}Test Results Summary:${NC}"
echo -e "  Frontend: $([ "$frontend_ok" = true ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${RED}[FAIL]${NC}")"
echo -e "  Backend:  $([ "$backend_ok" = true ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${RED}[FAIL]${NC}")"
echo -e "  API:      $([ "$api_ok" = true ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${RED}[FAIL]${NC}")"
echo -e "  Llama:    $([ "$llama_ok" = true ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${RED}[FAIL]${NC}")"

echo ""
if [ "$llama_ok" = false ]; then
    echo -e "${YELLOW}Troubleshooting Llama Issues:${NC}"
    echo -e "  ${WHITE}1. Check if Ollama is running in the VM:${NC}"
    echo -e "     ${GRAY}ssh user@$PROD_IP 'systemctl status ollama'${NC}"
    echo -e "  ${WHITE}2. Check if llama3.2 model is installed:${NC}"
    echo -e "     ${GRAY}ssh user@$PROD_IP 'ollama list'${NC}"
    echo -e "  ${WHITE}3. Test Ollama directly from VM:${NC}"
    echo -e "     ${GRAY}ssh user@$PROD_IP 'curl http://localhost:11434/api/tags'${NC}"
    echo -e "  ${WHITE}4. Check backend logs:${NC}"
    echo -e "     ${GRAY}ssh user@$PROD_IP 'cd /path/to/project && docker-compose logs backend'${NC}"
    echo -e "  ${WHITE}5. Test Ollama connectivity from backend container:${NC}"
    echo -e "     ${GRAY}ssh user@$PROD_IP 'docker-compose exec backend curl http://10.9.21.254:11434/api/tags'${NC}"
    echo ""
fi

echo -e "${CYAN}Access URLs:${NC}"
echo -e "  ${WHITE}Frontend: $frontend_url${NC}"
echo -e "  ${WHITE}Backend:  $backend_url${NC}"
echo -e "  ${WHITE}API:      $api_url${NC}"

echo ""
echo -e "${CYAN}Remote debugging commands:${NC}"
echo -e "  ${WHITE}Test Ollama:  curl http://${PROD_IP}:11434/api/tags${NC}"
echo -e "  ${WHITE}Backend logs: ssh user@${PROD_IP} 'docker-compose logs -f backend'${NC}"
echo -e "  ${WHITE}SSH to VM:    ssh user@${PROD_IP}${NC}"
echo -e "  ${WHITE}Ollama logs:  ssh user@${PROD_IP} 'journalctl -u ollama -f'${NC}"

# Exit with error code if any test failed
if [ "$frontend_ok" = false ] || [ "$backend_ok" = false ] || [ "$api_ok" = false ] || [ "$llama_ok" = false ]; then
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
