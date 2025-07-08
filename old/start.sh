#!/bin/bash

# Start R API server in background
echo "Starting R API server..."
Rscript api/spotseeker_api.R &
R_PID=$!

# Wait for R server to be ready
echo "Waiting for R API server to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8080/health > /dev/null; then
        echo "R API server is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "R API server failed to start"
        exit 1
    fi
    sleep 1
done

# Start MCP bridge server
echo "Starting MCP bridge server..."
python spotseeker_bridge.py &
MCP_PID=$!

# Handle shutdown gracefully
trap "kill $R_PID $MCP_PID" EXIT

# Wait for both processes
wait $R_PID $MCP_PID