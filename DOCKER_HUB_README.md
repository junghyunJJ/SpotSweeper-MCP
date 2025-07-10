# SpotSeeker MCP

A Model Context Protocol server that provides SpotSweeper spatial transcriptomics quality control capabilities to AI assistants like Claude.

## Quick Start

### With Claude Desktop

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "spotseeker": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-v",
        "${PWD}:${PWD}:ro",
        "-v",
        "/tmp/spotseeker-output:/output:rw",
        "-w",
        "${PWD}",
        "DOCKERHUB_USERNAME/spotseeker-mcp:latest"
      ]
    }
  }
}
```

Replace `DOCKERHUB_USERNAME` with the actual Docker Hub username.

This configuration automatically:
- Mounts your current directory for read-only file access
- Creates a writable output directory at `/tmp/spotseeker-output`
- Works from any directory containing your spatial data

## Features

- **Quality Control Metrics**: Calculate UMI counts, gene counts, and mitochondrial percentages
- **Local Outlier Detection**: Identify spots with unusual expression patterns
- **Artifact Detection**: Find technical artifacts in spatial data
- **Complete QC Pipeline**: Run comprehensive quality control analysis
- **Multi-species Support**: Automatic detection of human/mouse mitochondrial genes

## Available MCP Tools

- `r_status` - Check server health and installed packages
- `r_calculate_qc_metrics` - Calculate QC metrics for spatial data
- `r_run_qc_pipeline` - Run complete SpotSweeper QC pipeline

## Supported Data Formats

- RDS files (SpatialExperiment objects)
- CSV/TSV files with spatial coordinates
- Outputs: RDS, H5AD formats

## Requirements

- Docker Desktop installed and running
- Claude Desktop with MCP support
- Spatial transcriptomics data in supported format

## Volume Mounts

### Dynamic Current Directory Access (Recommended)

```bash
docker run -i --rm \
  -v "${PWD}:${PWD}:ro" \
  -v "/tmp/spotseeker-output:/output:rw" \
  -w "${PWD}" \
  DOCKERHUB_USERNAME/spotseeker-mcp:latest
```

### Custom Data Directories

```bash
docker run -i --rm \
  -v /path/to/input/data:/data:ro \
  -v /path/to/output:/output:rw \
  DOCKERHUB_USERNAME/spotseeker-mcp:latest
```

## Source Code

https://github.com/YOUR_GITHUB_USERNAME/spotsweeper-mcp

## License

MIT License - See repository for details