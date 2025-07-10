# Quick Test Example for SpotSeeker MCP

This example shows how to quickly test the SpotSeeker MCP Docker image with the provided test data.

## Prerequisites

- Docker installed and running
- Current directory is the SpotSeeker MCP repository root

## Step 1: Build the Docker Image

```bash
docker build -t spotseeker-mcp:test .
```

## Step 2: Run a Quick Test

### Option A: Using docker-compose (Easiest)

```bash
# Start the test container
docker-compose up spotseeker-test

# In another terminal, check if it's working:
docker exec spotseeker-test curl http://localhost:8081/health

# Stop when done
docker-compose down
```

### Option B: Direct Docker Run

```bash
# Run with test data mounted
docker run -d --name spotseeker-quick-test \
  -v "$(pwd)/test/data:/data:ro" \
  -v "/tmp/spotseeker-test:/output:rw" \
  spotseeker-mcp:test

# Wait a few seconds for R API to start
sleep 10

# Check health
docker exec spotseeker-quick-test curl http://localhost:8081/health

# Check logs
docker logs spotseeker-quick-test

# Clean up
docker stop spotseeker-quick-test
docker rm spotseeker-quick-test
```

## Step 3: Test with MCP Tools

Create a temporary test script:

```bash
cat > test_mcp.py << 'EOF'
import asyncio
import sys
sys.path.append('/app')

async def test_mcp():
    from spotseeker_bridge import r_status, r_calculate_qc_metrics
    
    # Test 1: Check status
    print("Testing r_status...")
    status = await r_status()
    print(f"Status: {status}")
    
    # Test 2: Calculate QC metrics
    print("\nTesting r_calculate_qc_metrics...")
    result = await r_calculate_qc_metrics(
        data_path="/data/testdata_SpotSweeper.rds",
        species="mouse",
        output_path="/output/test_qc_metrics.rds"
    )
    print(f"QC Result: {result}")

if __name__ == "__main__":
    asyncio.run(test_mcp())
EOF

# Run the test
docker run -i --rm \
  -v "$(pwd)/test/data:/data:ro" \
  -v "/tmp/spotseeker-test:/output:rw" \
  -v "$(pwd)/test_mcp.py:/test_mcp.py:ro" \
  spotseeker-mcp:test \
  python /test_mcp.py

# Clean up
rm test_mcp.py
```

## Expected Results

1. **Health Check** should return:
```json
{
  "status": "healthy",
  "service": "SpotSeeker R API",
  "version": "1.0.0",
  "r_version": "R version X.X.X",
  "packages": {
    "SpotSweeper": "X.X.X",
    "SpatialExperiment": "X.X.X"
  }
}
```

2. **QC Metrics** should return:
```json
{
  "success": true,
  "total_spots": XXXX,
  "mean_umi_count": XXX.XX,
  "median_umi_count": XXX,
  "mean_gene_count": XXX.XX,
  "median_gene_count": XXX,
  "mean_mito_percent": X.XX,
  "median_mito_percent": X.XX,
  "mito_pattern_used": "^Mt-",
  "output_saved": "/output/test_qc_metrics.rds"
}
```

3. **Output File** should be created at `/tmp/spotseeker-test/test_qc_metrics.rds`

## Troubleshooting

If tests fail:

1. Check Docker logs:
```bash
docker logs spotseeker-quick-test
```

2. Enter the container for debugging:
```bash
docker run -it --rm \
  -v "$(pwd)/test/data:/data:ro" \
  spotseeker-mcp:test \
  bash

# Inside container:
Rscript /app/spotseeker_api.R  # Test R API directly
python /app/spotseeker_bridge.py  # Test Python bridge
```

3. Check file permissions:
```bash
ls -la /tmp/spotseeker-test/
```

## Success Criteria

- [ ] Docker image builds without errors
- [ ] R API responds to health checks
- [ ] MCP tools can be called successfully
- [ ] Test data can be read from mounted volume
- [ ] Output files are created in the output directory
- [ ] No error messages in container logs