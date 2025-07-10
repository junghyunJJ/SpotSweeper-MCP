#!/bin/bash
# Entrypoint script for SpotSeeker MCP Docker container

# Start R API server in background
echo "Starting SpotSeeker R API server..." >&2
Rscript /app/spotseeker_api.R >&2 &
R_PID=$!

# Function to cleanup on exit
cleanup() {
    echo "Shutting down..." >&2
    kill $R_PID 2>/dev/null
    wait $R_PID
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Wait for R API to be ready
echo "Waiting for R API to start..." >&2
for i in {1..30}; do
    if curl -s http://localhost:8081/health >/dev/null 2>&1; then
        echo "R API is ready!" >&2
        break
    fi
    sleep 1
done

# Check if R API started successfully
if ! curl -s http://localhost:8081/health >/dev/null 2>&1; then
    echo "Error: R API failed to start" >&2
    exit 1
fi

# Start MCP server in stdio mode
echo "Starting SpotSeeker MCP bridge..." >&2
exec python /app/spotseeker_bridge.py