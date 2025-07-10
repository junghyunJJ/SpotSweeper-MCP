#!/bin/bash
# Minimal test for SpotSeeker MCP

echo "Testing basic Docker functionality..."

# Test 1: Can we run Python?
echo -n "Python test: "
docker run --rm python:3.11-slim python -c "print('OK')"

# Test 2: Can we run R?
echo -n "R test: "
docker run --rm rocker/r-ver:4.3.2 R --version | head -1

# Test 3: Check if test data exists
echo -n "Test data: "
if [ -f "test/data/testdata_SpotSweeper.rds" ]; then
    echo "Found"
else
    echo "Not found"
fi

echo "Basic tests complete."