#!/bin/bash

echo "🧪 Testing SpotSeeker MCP Docker image..."

# Image name
IMAGE_NAME="spotseeker-mcp:test"

# Test 1: Check if image exists
echo "1️⃣ Checking if Docker image exists..."
if docker images | grep -q "$IMAGE_NAME"; then
    echo "✅ Image found"
else
    echo "❌ Image not found. Please build first."
    exit 1
fi

# Test 2: Run container and check if it starts
echo "2️⃣ Starting container..."
CONTAINER_ID=$(docker run -d --name spotseeker-test-$$ $IMAGE_NAME)
sleep 5

# Test 3: Check container status
echo "3️⃣ Checking container status..."
if docker ps | grep -q "spotseeker-test-$$"; then
    echo "✅ Container is running"
else
    echo "❌ Container failed to start"
    docker logs spotseeker-test-$$
    docker rm -f spotseeker-test-$$ 2>/dev/null
    exit 1
fi

# Test 4: Check R API
echo "4️⃣ Testing R API..."
docker exec spotseeker-test-$$ bash -c "curl -s http://localhost:8081/status || echo 'R API not ready yet'"

# Test 5: Check Python MCP
echo "5️⃣ Testing Python MCP bridge..."
docker exec spotseeker-test-$$ python -c "import spotseeker_bridge; print('✅ Python bridge loaded')"

# Cleanup
echo "🧹 Cleaning up..."
docker stop spotseeker-test-$$ >/dev/null
docker rm spotseeker-test-$$ >/dev/null

echo "✅ All tests completed!"