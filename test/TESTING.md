# Testing Guide for SpotSeeker MCP Docker

This guide explains how to test the SpotSeeker MCP Docker image before deployment.

## Quick Test

Run the automated test script:

```bash
./test_docker.sh
```

This script will:
1. Build the Docker image
2. Test container startup
3. Verify R API health
4. Test volume mounting
5. Validate docker-compose configuration

## Manual Testing

### 1. Build the Image

```bash
docker build -t spotseeker-mcp:test .
```

### 2. Test Basic Functionality

```bash
# Test container starts
docker run --rm spotseeker-mcp:test echo "Test"

# Test interactive mode
docker run -it --rm spotseeker-mcp:test bash
# Inside container:
R --version
python --version
```

### 3. Test with Sample Data

Using the provided test data:

```bash
# Start the container with test data
docker run -i --rm \
  -v "$(pwd):$(pwd):ro" \
  -v "/tmp/spotseeker-test:/output:rw" \
  -w "$(pwd)" \
  spotseeker-mcp:test
```

In another terminal, check if the R API is running:

```bash
docker exec -it <container-id> curl http://localhost:8081/health
```

### 4. Test MCP Integration

Create a test Claude Desktop configuration:

```json
{
  "mcpServers": {
    "spotseeker-test": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-v",
        "${PWD}:${PWD}:ro",
        "-v",
        "/tmp/spotseeker-test:/output:rw",
        "-w",
        "${PWD}",
        "spotseeker-mcp:test"
      ]
    }
  }
}
```

Then test with Claude Desktop to ensure the MCP tools are available.

### 5. Test docker-compose

```bash
# Start with docker-compose
docker-compose up --build

# In another terminal, check logs
docker-compose logs -f

# Stop when done
docker-compose down
```

## Testing Checklist

- [ ] Docker image builds successfully
- [ ] Container starts without errors
- [ ] R API server starts and responds to health checks
- [ ] Python MCP bridge connects to R API
- [ ] Volume mounting works correctly
- [ ] Can read test data files
- [ ] Can write output files to /output directory
- [ ] MCP tools are visible in Claude Desktop
- [ ] QC metrics calculation works
- [ ] QC pipeline runs successfully

## Common Issues and Solutions

### Container exits immediately

Check the logs:
```bash
docker logs <container-id>
```

### R API fails to start

1. Check R package installation:
```bash
docker run --rm spotseeker-mcp:test R -e "library(SpotSweeper)"
```

2. Check for missing dependencies:
```bash
docker run --rm spotseeker-mcp:test R -e "sessionInfo()"
```

### Permission issues

Ensure the output directory is writable:
```bash
chmod 777 /tmp/spotseeker-test
```

### Memory issues

Increase Docker memory limit:
```bash
docker run -m 4g ...
```

## Performance Testing

For large datasets:

```bash
# Monitor resource usage
docker stats

# Run with resource limits
docker run -m 4g --cpus 2 ...
```

## Cleanup

After testing:

```bash
# Remove test images
docker rmi spotseeker-mcp:test

# Clean up test output
rm -rf /tmp/spotseeker-test

# Remove all stopped containers
docker container prune
```