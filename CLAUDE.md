# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpotSweeper MCP is a Model Context Protocol server that bridges R's SpotSweeper spatial transcriptomics QC package to AI assistants. It follows a bridge architecture:

```
Claude/MCP Client → Python MCP Server (spotseeker_bridge.py) → R REST API (spotseeker_api.R) → SpotSweeper R Package
```

## Commands

### Running the MCP Server

1. Start the R API server first:
```bash
Rscript spotseeker_api.R
```

2. Then start the Python MCP bridge:
```bash
python spotseeker_bridge.py
```

### Development

- No specific build/lint/test commands are configured
- Dependencies are managed via `requirements.txt` (Python) and automatic R package installation
- The R API runs on port 8081 by default (configurable via `R_API_PORT` env var)

## Architecture

### Key Components

1. **spotseeker_bridge.py**: FastMCP server that:
   - Exposes three MCP tools: `r_status`, `r_calculate_qc_metrics`, `r_run_qc_pipeline`
   - Communicates with R API via HTTP on port 8081
   - Handles data conversion between Python/R formats

2. **spotseeker_api.R**: RestRserve R API that:
   - Provides endpoints for SpotSweeper functionality
   - Automatically installs required R packages on startup
   - Handles RDS, CSV, and TSV data formats

### MCP Tools

- **r_status**: Check if R API server is running
- **r_calculate_qc_metrics**: Calculate spatial transcriptomics QC metrics
- **r_run_qc_pipeline**: Run complete SpotSweeper QC pipeline with artifact detection

### Data Flow

1. MCP client sends request to Python bridge
2. Bridge validates parameters and forwards to R API
3. R API processes data using SpotSweeper
4. Results returned as JSON (metrics) or saved to disk (processed data)

## Important Implementation Details

- The Python bridge requires the R API to be running first
- R package installation happens automatically on first R API startup
- Supports both human and mouse mitochondrial gene patterns
- File paths must be absolute when passed to the R API
- Results can be saved as RDS or H5AD formats