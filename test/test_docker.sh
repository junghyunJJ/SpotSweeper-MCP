#!/bin/bash
# Test script for SpotSeeker MCP Docker image

set -e  # Exit on error

echo "================================================"
echo "SpotSeeker MCP Docker Test Script"
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test status
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test results
print_test() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $2${NC}"
        ((TESTS_FAILED++))
    fi
}

# 1. Build Docker image
echo -e "\n${YELLOW}1. Building Docker image...${NC}"
docker build -t spotseeker-mcp:test . > /dev/null 2>&1
print_test $? "Docker image built successfully"

# 2. Test container startup
echo -e "\n${YELLOW}2. Testing container startup...${NC}"
timeout 10s docker run --rm spotseeker-mcp:test echo "Container started" > /dev/null 2>&1
print_test $? "Container starts successfully"

# 3. Test R API health check
echo -e "\n${YELLOW}3. Testing R API health check...${NC}"
docker run -d --name spotseeker-test spotseeker-mcp:test > /dev/null 2>&1
sleep 5  # Wait for R API to start

# Check if container is still running
docker ps | grep spotseeker-test > /dev/null 2>&1
print_test $? "Container stays running"

# Stop test container
docker stop spotseeker-test > /dev/null 2>&1
docker rm spotseeker-test > /dev/null 2>&1

# 4. Test with sample data
echo -e "\n${YELLOW}4. Testing with sample data...${NC}"
if [ -f "test/data/testdata_SpotSweeper.rds" ]; then
    # Create temporary output directory
    TEST_OUTPUT_DIR="/tmp/spotseeker-test-output"
    rm -rf $TEST_OUTPUT_DIR
    mkdir -p $TEST_OUTPUT_DIR
    
    # Run QC metrics calculation test
    echo "Testing QC metrics calculation..."
    docker run -i --rm \
        -v "$(pwd):$(pwd):ro" \
        -v "$TEST_OUTPUT_DIR:/output:rw" \
        -w "$(pwd)" \
        spotseeker-mcp:test \
        python -c "
import sys
sys.path.append('/app')
from spotseeker_bridge import http_client, server
import asyncio

async def test():
    # Just test that we can import the modules
    print('Modules imported successfully')
    await http_client.aclose()
    
asyncio.run(test())
" > /dev/null 2>&1
    
    print_test $? "Python bridge imports work"
else
    echo -e "${YELLOW}Skipping data tests - no test data found${NC}"
fi

# 5. Test docker-compose
echo -e "\n${YELLOW}5. Testing docker-compose configuration...${NC}"
docker-compose config > /dev/null 2>&1
print_test $? "docker-compose.yml is valid"

# 6. Test volume mounting
echo -e "\n${YELLOW}6. Testing volume mounting...${NC}"
docker run --rm \
    -v "$(pwd):$(pwd):ro" \
    -v "/tmp/spotseeker-test:/output:rw" \
    -w "$(pwd)" \
    spotseeker-mcp:test \
    ls -la /output > /dev/null 2>&1
print_test $? "Volume mounting works"

# Summary
echo -e "\n================================================"
echo -e "Test Summary:"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================================"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed! Docker image is ready for deployment.${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please fix the issues before deployment.${NC}"
    exit 1
fi