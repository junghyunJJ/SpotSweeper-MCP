This file is a merged representation of the entire codebase, combined into a single document by Repomix.

# File Summary

## Purpose
This file contains a packed representation of the entire repository's contents.
It is designed to be easily consumable by AI systems for analysis, code review,
or other automated processes.

## File Format
The content is organized as follows:
1. This summary section
2. Repository information
3. Directory structure
4. Repository files (if enabled)
5. Multiple file entries, each consisting of:
  a. A header with the file path (## File: path/to/file)
  b. The full contents of the file in a code block

## Usage Guidelines
- This file should be treated as read-only. Any changes should be made to the
  original repository files, not this packed version.
- When processing this file, use the file path to distinguish
  between different files in the repository.
- Be aware that this file may contain sensitive information. Handle it with
  the same level of security as you would the original repository.

## Notes
- Some files may have been excluded based on .gitignore rules and Repomix's configuration
- Binary files are not included in this packed representation. Please refer to the Repository Structure section for a complete list of file paths, including binary files
- Files matching patterns in .gitignore are excluded
- Files matching default ignore patterns are excluded
- Files are sorted by Git change count (files with more changes are at the bottom)

# Directory Structure
```
.github/
  workflows/
    docker-publish.yml
docker/
  README.md
.dockerignore
.gitignore
.python-version
build-docker-mcp.sh
DOCKER_HUB.md
Dockerfile.mcp
entrypoint.sh
LICENSE
pyproject.toml
r_api.R
r_bridge.py
README.md
requirements.txt
```

# Files

## File: .github/workflows/docker-publish.yml
````yaml
name: Docker Publish

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: docker.io
  IMAGE_NAME: ${{ secrets.DOCKER_USERNAME }}/r-mcp-bridge

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Set up QEMU
      uses: docker/setup-qemu-action@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to Docker Hub
      if: github.event_name != 'pull_request'
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        file: ./Dockerfile.mcp
        platforms: linux/amd64,linux/arm64
        push: ${{ github.event_name != 'pull_request' }}
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
````

## File: docker/README.md
````markdown
# Docker Deployment Guide

This guide explains how to deploy the R MCP Bridge using Docker.

## Quick Start

### Build and run with Docker Compose (Recommended)

```bash
# Production deployment (single container)
docker-compose -f docker-compose.prod.yml up -d

# Development deployment (separate containers)
docker-compose up -d
```

### Build and run manually

```bash
# Build the image
docker build -t r-mcp-bridge .

# Run the container
docker run -d \
  -p 8080:8080 \
  -p 8081:8081 \
  --name r-mcp-bridge \
  r-mcp-bridge
```

## Image Variants

### 1. Standard Image (Debian-based)
- **File**: `Dockerfile`
- **Size**: ~400-500MB
- **Stability**: High
- **Use case**: Production deployments

### 2. Alpine Image (Experimental)
- **File**: `Dockerfile.alpine`
- **Size**: ~200-300MB
- **Stability**: May have compatibility issues
- **Use case**: When minimal size is critical

```bash
# Build Alpine variant
docker build -f Dockerfile.alpine -t r-mcp-bridge:alpine .
```

## Configuration

### Environment Variables

- `R_API_PORT`: R API server port (default: 8081)
- `R_API_URL`: R API server URL (default: http://localhost:8081)
- `MCP_PORT`: MCP server port (default: 8080)

### Docker Compose Options

1. **Production (Single Container)**
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```
   - Both services in one container
   - Resource limits configured
   - Automatic restart
   - Log rotation

2. **Development (Separate Containers)**
   ```bash
   docker-compose up -d
   ```
   - R API and MCP bridge in separate containers
   - Easier debugging
   - Independent scaling

## Optimization Tips

### 1. Multi-stage Build
The Dockerfile uses multi-stage builds to minimize the final image size:
- Build stage: Compiles R packages and Python dependencies
- Runtime stage: Contains only necessary runtime files

### 2. Layer Caching
```bash
# Build with BuildKit for better caching
DOCKER_BUILDKIT=1 docker build -t r-mcp-bridge .
```

### 3. Slim Base Images
- Uses `python:3.11-slim` instead of full Python image
- Uses `r-base-core` for minimal R installation

### 4. Cleanup
- Removes package manager caches
- Removes documentation and man pages
- Removes build dependencies

## Health Checks

The container includes health checks for both services:

```bash
# Check container health
docker ps
docker inspect r-mcp-bridge --format='{{.State.Health.Status}}'

# View health check logs
docker inspect r-mcp-bridge --format='{{range .State.Health.Log}}{{.Output}}{{end}}'
```

## Troubleshooting

### Container won't start
```bash
# Check logs
docker logs r-mcp-bridge

# Check if ports are already in use
lsof -i :8080
lsof -i :8081
```

### R packages installation fails
```bash
# Build with no cache
docker build --no-cache -t r-mcp-bridge .

# Or use a different CRAN mirror
docker build --build-arg CRAN_MIRROR=https://cran.rstudio.com/ -t r-mcp-bridge .
```

### Out of memory
Increase Docker memory limits or use production compose file with resource limits:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Security Considerations

1. **Non-root User**: Container runs as non-root user (uid 1000)
2. **Minimal Attack Surface**: Only necessary packages installed
3. **Network Isolation**: Use Docker networks for service communication
4. **Resource Limits**: Configure CPU and memory limits in production

## Monitoring

```bash
# View resource usage
docker stats r-mcp-bridge

# View logs
docker logs -f r-mcp-bridge

# Execute commands in container
docker exec -it r-mcp-bridge /bin/bash
```

## Claude Desktop Integration

### Using Docker with Claude Desktop

The R MCP Bridge can be used with Claude Desktop through Docker:

1. **Ensure Docker Desktop is running**

2. **Use the provided run script**:
   ```json
   {
     "mcpServers": {
       "r-mcp": {
         "command": "/path/to/r-mcp-bridge/run-docker-mcp.sh"
       }
     }
   }
   ```

   For Windows:
   ```json
   {
     "mcpServers": {
       "r-mcp": {
         "command": "C:\\path\\to\\r-mcp-bridge\\run-docker-mcp.bat"
       }
     }
   }
   ```

### How it works

1. The run script starts the R API server in a background container
2. It then runs the MCP bridge in stdio mode, connected to the R API
3. Claude Desktop communicates with the MCP bridge via stdio
4. When Claude Desktop stops, the containers are automatically cleaned up

### Advanced Configuration

You can customize the Docker execution by setting environment variables:

```json
{
  "mcpServers": {
    "r-mcp": {
      "command": "/path/to/r-mcp-bridge/run-docker-mcp.sh",
      "env": {
        "R_MCP_IMAGE": "r-mcp-bridge:custom",
        "R_API_PORT": "8082"
      }
    }
  }
}
```

### Troubleshooting Claude Desktop Integration

1. **"Docker is not running" error**
   - Make sure Docker Desktop is started before launching Claude Desktop

2. **Permission denied**
   - Make the run script executable: `chmod +x run-docker-mcp.sh`

3. **Container conflicts**
   - The script uses unique container names, but you can check for conflicts:
   ```bash
   docker ps -a | grep r-mcp-claude
   ```

4. **Debugging**
   - Check the Claude Desktop logs
   - Run the script manually to see error messages:
   ```bash
   ./run-docker-mcp.sh
   ```
````

## File: .dockerignore
````
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# R
.Rhistory
.RData
.Rproj.user/
*.Rproj

# Git
.git/
.gitignore

# Documentation
*.md
docs/
LICENSE

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Project specific
old/
tmp/
*.log
.pytest_cache/
.coverage
htmlcov/

# Docker
Dockerfile*
docker-compose*.yml
.dockerignore

# Development files
Makefile
setup.py
setup.cfg
pyproject.toml
poetry.lock
Pipfile
Pipfile.lock

# Keep only essential files
!requirements.txt
!r_api.R
!r_bridge.py
````

## File: .gitignore
````
# Python-generated files
__pycache__/
*.py[oc]
build/
dist/
wheels/
*.egg-info
old
answer

# Virtual environments
.venv
````

## File: .python-version
````
3.13
````

## File: build-docker-mcp.sh
````bash
#!/bin/bash
# Build script for Docker Hub MCP image

set -e

# Configuration
DOCKER_USERNAME="${DOCKER_USERNAME:-yourusername}"
IMAGE_NAME="${DOCKER_USERNAME}/r-mcp-bridge"
VERSION="${VERSION:-latest}"

echo "Building R MCP Bridge for Docker Hub..."
echo "Image: ${IMAGE_NAME}:${VERSION}"

# Ensure Docker Buildx is available
if ! docker buildx version > /dev/null 2>&1; then
    echo "Error: Docker Buildx is required for multi-platform builds"
    echo "Please update Docker Desktop or install buildx"
    exit 1
fi

# Create builder if it doesn't exist
if ! docker buildx ls | grep -q mcp-builder; then
    echo "Creating buildx builder..."
    docker buildx create --name mcp-builder --driver docker-container --bootstrap
fi

# Use the builder
docker buildx use mcp-builder

# Build options
BUILD_ARGS=""
if [ "$1" == "--push" ]; then
    BUILD_ARGS="--push"
    echo "Will push to Docker Hub after building"
else
    BUILD_ARGS="--load"
    echo "Building locally only (use --push to publish)"
fi

# Build the image
echo "Building multi-platform image..."
docker buildx build \
    -f Dockerfile.mcp \
    --platform linux/amd64,linux/arm64 \
    -t "${IMAGE_NAME}:${VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    --cache-from "type=registry,ref=${IMAGE_NAME}:buildcache" \
    --cache-to "type=registry,ref=${IMAGE_NAME}:buildcache,mode=max" \
    ${BUILD_ARGS} \
    .

echo "Build complete!"

if [ "$1" != "--push" ]; then
    echo ""
    echo "To test locally:"
    echo "  docker run -i --rm ${IMAGE_NAME}:${VERSION}"
    echo ""
    echo "To push to Docker Hub:"
    echo "  $0 --push"
fi
````

## File: DOCKER_HUB.md
````markdown
# Docker Hub Deployment Guide

This guide explains how to build and publish the R MCP Bridge to Docker Hub.

## Prerequisites

1. Docker Hub account
2. Docker installed locally
3. Docker Buildx for multi-platform builds

## Building for Docker Hub

### 1. Build the MCP-optimized image

```bash
# Build for local testing
docker build -f Dockerfile.mcp -t r-mcp-bridge:mcp .

# Test locally
docker run -i --rm r-mcp-bridge:mcp
```

### 2. Multi-platform build

```bash
# Create a new builder instance
docker buildx create --name mcp-builder --use

# Build and push to Docker Hub
docker buildx build \
  -f Dockerfile.mcp \
  --platform linux/amd64,linux/arm64 \
  -t yourusername/r-mcp-bridge:latest \
  -t yourusername/r-mcp-bridge:1.0.0 \
  --push .
```

## Docker Hub Setup

### 1. Create Repository

1. Go to [Docker Hub](https://hub.docker.com)
2. Create a new repository named `r-mcp-bridge`
3. Set it as public for easy access

### 2. Update README on Docker Hub

Use this description for your Docker Hub repository:

```markdown
# R MCP Bridge

A Model Context Protocol server that provides R statistical computing capabilities to AI assistants like Claude.

## Quick Start

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "r-mcp": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "yourusername/r-mcp-bridge"]
    }
  }
}
```

## Features

- Statistical operations (mean, median, SD, variance)
- Linear regression analysis
- Basic arithmetic operations
- Server health monitoring

## Available Tools

- `r_status` - Check R server status
- `r_hello` - Test greeting function
- `r_add` - Add two numbers
- `r_stats` - Statistical operations
- `r_lm_simple` - Simple linear regression

## Requirements

- Docker Desktop must be running
- Claude Desktop with MCP support

## Source Code

https://github.com/yourusername/r-mcp-bridge
```

## GitHub Actions Setup

To enable automatic Docker Hub deployment:

1. Go to your GitHub repository settings
2. Add these secrets:
   - `DOCKER_USERNAME`: Your Docker Hub username
   - `DOCKER_TOKEN`: Docker Hub access token (not password)

3. Create a Docker Hub access token:
   - Go to Docker Hub → Account Settings → Security
   - Click "New Access Token"
   - Give it a descriptive name
   - Copy the token and save it as GitHub secret

## Testing Docker Hub Image

After publishing:

```bash
# Test pulling from Docker Hub
docker pull yourusername/r-mcp-bridge

# Test with Claude Desktop config
docker run -i --rm yourusername/r-mcp-bridge
```

## Versioning

Follow semantic versioning:
- `latest`: Always points to the most recent stable version
- `1.0.0`: Specific version tags
- `1.0`: Major.minor tags for flexibility

Tag a new release:
```bash
git tag v1.0.0
git push origin v1.0.0
```

This will trigger the GitHub Action to build and push to Docker Hub.

## Advanced Usage

### With Volume Mounts

For file access:
```json
{
  "mcpServers": {
    "r-mcp": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "/path/to/data:/data:ro",
        "yourusername/r-mcp-bridge"
      ]
    }
  }
}
```

### With Environment Variables

```json
{
  "mcpServers": {
    "r-mcp": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "R_API_PORT=8082",
        "yourusername/r-mcp-bridge"
      ]
    }
  }
}
```
````

## File: Dockerfile.mcp
````
# Docker image optimized for MCP server deployment
FROM python:3.11-slim

# Install R and system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base-core \
    r-base-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsodium-dev \
    curl \
    gcc \
    g++ \
    make \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/*

# Install R packages step by step
RUN R -e "install.packages('jsonlite', repos='https://cloud.r-project.org/')"
RUN R -e "install.packages('Rserve', repos='https://cloud.r-project.org/')"
RUN R -e "install.packages('RestRserve', repos='https://cloud.r-project.org/')"

# Verify installation
RUN R -e "library(jsonlite); library(RestRserve); cat('R packages installed successfully\n')"

# Install Python dependencies
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt

# Create app directory
WORKDIR /app

# Copy application files
COPY r_api.R r_bridge.py ./
COPY entrypoint.sh ./

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Create non-root user
RUN useradd -m -u 1000 mcp && chown -R mcp:mcp /app
USER mcp

# MCP servers communicate via stdio, not network ports
# No EXPOSE needed

# Set environment variables
ENV R_API_URL=http://localhost:8081
ENV R_API_PORT=8081
ENV MCP_STDIO=true

# Use shell form to ensure proper signal handling
ENTRYPOINT ["/app/entrypoint.sh"]
````

## File: entrypoint.sh
````bash
#!/bin/bash
# Entrypoint script for R MCP Bridge Docker container

# Start R API server in background
echo "Starting R API server..." >&2
Rscript /app/r_api.R >&2 &
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
echo "Starting MCP server..." >&2
exec python /app/r_bridge.py
````

## File: LICENSE
````
MIT License

Copyright (c) 2024 R MCP Bridge Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
````

## File: pyproject.toml
````toml
[project]
name = "r-mcp-bridge"
version = "1.0.0"
description = "A Model Context Protocol bridge for R, enabling AI assistants to leverage R's statistical computing capabilities"
readme = "README.md"
requires-python = ">=3.10"
license = {text = "MIT"}
authors = [
    {name = "Your Name", email = "your.email@example.com"}
]
keywords = ["mcp", "r", "statistics", "data-analysis", "ai", "claude"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Programming Language :: Python :: 3.13",
    "Programming Language :: R",
    "Topic :: Scientific/Engineering :: Information Analysis",
    "Topic :: Software Development :: Libraries :: Python Modules",
]
dependencies = [
    "fastmcp>=2.10.2",
    "httpx>=0.28.1",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "pytest-asyncio>=0.21",
    "black>=23.0",
    "ruff>=0.1",
]

[project.urls]
Homepage = "https://github.com/yourusername/r-mcp-bridge"
Documentation = "https://github.com/yourusername/r-mcp-bridge#readme"
Repository = "https://github.com/yourusername/r-mcp-bridge.git"
Issues = "https://github.com/yourusername/r-mcp-bridge/issues"

[project.scripts]
r-mcp-bridge = "r_bridge:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["."]

[tool.ruff]
line-length = 88
target-version = "py310"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W"]
ignore = ["E501"]  # line too long

[tool.black]
line-length = 88
target-version = ['py310']
````

## File: r_api.R
````r
# Refactored Hello R API Server
# A standalone version with helper functions

library(RestRserve)
library(jsonlite)

# Configuration
API_PORT <- 8081
API_VERSION <- "1.0.0"
SERVICE_NAME <- "Hello R API (Refactored)"

# Helper function to parse request body
parse_request_body <- function(request) {
    if (is.null(request$body)) {
        return(list())
    }
    
    # RestRserve provides parsed JSON in request$body when Content-Type is application/json
    if (is.list(request$body)) {
        return(request$body)
    }
    
    # Fallback for other cases
    return(list())
}

# Helper function to create error response
error_response <- function(response, message, status_code = 500) {
    response$set_status_code(status_code)
    response$set_content_type("application/json")
    response$set_body(toJSON(list(
        success = FALSE,
        error = message,
        timestamp = as.character(Sys.time())
    ), auto_unbox = TRUE))
}

# Helper function to create success response
success_response <- function(response, data) {
    response$set_content_type("application/json")
    response$set_body(toJSON(c(
        list(
            success = TRUE,
            timestamp = as.character(Sys.time())
        ),
        data
    ), auto_unbox = TRUE))
}


# Create application
app <- Application$new()

# Health check endpoint
app$add_get(
    path = "/health",
    FUN = function(request, response) {
        success_response(response, list(
            status = "healthy",
            service = SERVICE_NAME,
            version = API_VERSION,
            r_version = R.version.string
        ))
    }
)

###########################################
###########################################
###########################################


# Hello endpoint - simplified
app$add_post(
    path = "/api/hello",
    FUN = function(request, response) {
        tryCatch({
            body <- parse_request_body(request)
            name <- if(is.null(body$name)) "World" else body$name
            
            greeting <- paste("Hello", name, "from R!")
            
            success_response(response, list(
                message = greeting,
                r_version = R.version.string
            ))
            
        }, error = function(e) {
            error_response(response, e$message)
        })
    }
)

# Addition endpoint - simplified  
app$add_post(
    path = "/api/add",
    FUN = function(request, response) {
        tryCatch({
            body <- parse_request_body(request)
            
            a <- as.numeric(if(is.null(body$a)) 0 else body$a)
            b <- as.numeric(if(is.null(body$b)) 0 else body$b)
            
            result <- a + b
            
            success_response(response, list(
                a = a,
                b = b,
                result = result,
                operation = "addition"
            ))
            
        }, error = function(e) {
            error_response(response, e$message)
        })
    }
)

# Simple stats endpoint
app$add_post(
    path = "/api/stats",
    FUN = function(request, response) {
        tryCatch({
            body <- parse_request_body(request)
            
            # Get data and operation
            data <- as.numeric(body$data)
            operation <- if(is.null(body$operation)) "mean" else body$operation
            
            if (is.null(data) || length(data) == 0) {
                error_response(response, "No data provided", 400)
                return()
            }
            
            # Perform operation
            result <- switch(operation,
                "mean" = mean(data, na.rm = TRUE),
                "median" = median(data, na.rm = TRUE),
                "sd" = sd(data, na.rm = TRUE),
                "var" = var(data, na.rm = TRUE),
                "min" = min(data, na.rm = TRUE),
                "max" = max(data, na.rm = TRUE),
                "sum" = sum(data, na.rm = TRUE),
                {
                    error_response(response, paste("Unknown operation:", operation), 400)
                    return()
                }
            )
            
            success_response(response, list(
                operation = operation,
                result = result,
                n = length(data)
            ))
            
        }, error = function(e) {
            error_response(response, e$message)
        })
    }
)


# Linear regression endpoint
app$add_post(
    path = "/api/lm",
    FUN = function(request, response) {
        tryCatch({
            body <- parse_request_body(request)
            
            # Get x and y data
            x <- as.numeric(body$x)
            y <- as.numeric(body$y)
            
            # Validate input
            if (is.null(x) || length(x) == 0) {
                error_response(response, "No x data provided", 400)
                return()
            }
            
            if (is.null(y) || length(y) == 0) {
                error_response(response, "No y data provided", 400)
                return()
            }
            
            if (length(x) != length(y)) {
                error_response(response, "x and y must have the same length", 400)
                return()
            }
            
            if (length(x) < 2) {
                error_response(response, "At least 2 data points are required", 400)
                return()
            }
            
            # Fit linear model
            model <- lm(y ~ x)
            summary_model <- summary(model)
            
            # Extract results
            coefficients <- coef(model)
            
            success_response(response, list(
                coefficients = list(
                    intercept = coefficients[1],
                    slope = coefficients[2]
                ),
                r_squared = summary_model$r.squared,
                p_value = summary_model$coefficients[2, 4],
                residual_std_error = summary_model$sigma,
                n = length(x)
            ))
            
        }, error = function(e) {
            error_response(response, e$message)
        })
    }
)


# Create backend and start server
backend <- BackendRserve$new()
cat(sprintf("Starting %s on port %s...\n", SERVICE_NAME, API_PORT))
cat(sprintf("R version: %s\n", R.version.string))
backend$start(app, http_port = API_PORT)
````

## File: r_bridge.py
````python
"""
R MCP Bridge - A clean, extensible bridge between R and MCP
"""

import asyncio
import httpx
from typing import Dict, Any, Optional, List
import os

from fastmcp import FastMCP

# Configuration
R_API_BASE_URL = os.getenv("R_API_URL", "http://localhost:8081")
R_API_PORT = os.getenv("R_API_PORT", "8081")
TIMEOUT = httpx.Timeout(30.0, connect=5.0)

# Create FastMCP server instance
server = FastMCP("r-mcp-bridge")

# Create a reusable HTTP client
http_client = httpx.AsyncClient(base_url=R_API_BASE_URL, timeout=TIMEOUT)


class RBridgeError(Exception):
    """Custom exception for R Bridge errors"""
    pass


async def check_api_health() -> bool:
    """Check if the R API server is running"""
    try:
        response = await http_client.get("/health")
        return response.status_code == 200
    except:
        return False


async def ensure_api_running():
    """Ensure the R API is running, raise error if not"""
    if not await check_api_health():
        raise RBridgeError(
            f"R API server is not running. Please start it with: Rscript r_api.R"
        )


async def call_r_api(endpoint: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    Generic function to call R API endpoints
    
    Args:
        endpoint: API endpoint path
        payload: Request payload
        
    Returns:
        Response data as dictionary
    """
    await ensure_api_running()
    
    try:
        response = await http_client.post(endpoint, json=payload)
        response.raise_for_status()
        
        data = response.json()
        if isinstance(data, dict):
            return data
        else:
            # Handle non-dict responses
            import json
            return json.loads(data) if isinstance(data, str) else {"data": data}
            
    except httpx.HTTPStatusError as e:
        return {
            "success": False,
            "error": f"API error: {e.response.text}"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


# MCP Tools

@server.tool()
async def r_status() -> Dict[str, Any]:
    """
    Check the status of the R API server
    
    Returns:
        Server status information
    """
    try:
        response = await http_client.get("/health")
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {
            "status": "offline",
            "error": str(e),
            "message": "R API server is not running"
        }


@server.tool()
async def r_hello(name: Optional[str] = None) -> Dict[str, Any]:
    """
    Send a greeting to R
    
    Args:
        name: Name to greet (default: "World")
        
    Returns:
        Greeting message from R
    """
    payload = {}
    if name is not None:
        payload["name"] = name
    
    return await call_r_api("/api/hello", payload)


@server.tool()
async def r_add(a: float = 0, b: float = 0) -> Dict[str, Any]:
    """
    Add two numbers using R
    
    Args:
        a: First number (default: 0)
        b: Second number (default: 0)
        
    Returns:
        Addition result
    """
    return await call_r_api("/api/add", {"a": a, "b": b})


@server.tool()
async def r_stats(
    data: List[float],
    operation: str = "mean"
) -> Dict[str, Any]:
    """
    Perform statistical operations on data
    
    Args:
        data: Numeric data
        operation: One of: mean, median, sd, var, min, max, sum
        
    Returns:
        Statistical results
    """
    return await call_r_api("/api/stats", {
        "data": data,
        "operation": operation
    })


@server.tool()
async def r_lm_simple(
    x: List[float],
    y: List[float]
) -> Dict[str, Any]:
    """
    Perform simple linear regression (y ~ x)
    
    Args:
        x: Independent variable values
        y: Dependent variable values
        
    Returns:
        Regression results including coefficients, R-squared, p-values
    """
    return await call_r_api("/api/lm", {"x": x, "y": y})


# Cleanup function
async def cleanup():
    """Cleanup resources on shutdown"""
    await http_client.aclose()


# Main entry point
def main():
    """Run the MCP server"""
    import atexit
    atexit.register(lambda: asyncio.run(cleanup()))
    
    print(f"Starting R MCP Bridge Server...")
    print(f"Connecting to R API at: {R_API_BASE_URL}")
    print(f"Make sure the R API server is running: Rscript r_api.R")
    
    server.run()


if __name__ == "__main__":
    main()
````

## File: README.md
````markdown
# R MCP Bridge

A clean, extensible bridge that exposes R functionality through the Model Context Protocol (MCP), allowing AI assistants like Claude to leverage R's powerful statistical and data analysis capabilities.

## Features

- 🔍 **Server Status** - Check if the R API is running and healthy
- 👋 **Greetings** - Simple interaction with R
- 🧮 **Basic Math** - Perform calculations using R
- 📊 **Statistical Operations** - Mean, median, SD, variance, min, max, sum
- 📈 **Linear Regression** - Simple linear regression analysis
- 🔬 **Extensible** - Easy to add new endpoints and functions

## Quick Start

### Prerequisites

- Python 3.10+
- R 4.0+
- R packages: `RestRserve`, `jsonlite`

### Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/r-mcp-bridge.git
cd r-mcp-bridge
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
# or with uv:
uv sync
```

3. Install R dependencies:
```R
install.packages(c("RestRserve", "jsonlite"))
```

### Running the Bridge

1. Start the R API server:
```bash
Rscript r_api.R
```

2. In a new terminal, start the MCP bridge:
```bash
python r_bridge.py
```

### Configure Claude Desktop

Add to your Claude Desktop configuration (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

**Option 1: Using Docker Hub (Easiest)**
```json
{
  "mcpServers": {
    "r-mcp": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "yourusername/r-mcp-bridge"]
    }
  }
}
```

**Option 2: Using Local Docker Build**
```json
{
  "mcpServers": {
    "r-mcp": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "--pull", "always", "r-mcp-bridge:latest"]
    }
  }
}
```

**Option 3: Using uv (For Development)**
```json
{
  "mcpServers": {
    "r-mcp": {
      "command": "/path/to/uv",
      "args": [
        "--directory",
        "/path/to/r-mcp-bridge/",
        "run",
        "r_bridge.py"
      ]
    }
  }
}
```

**Option 4: Using Python directly**
```json
{
  "mcpServers": {
    "r-mcp": {
      "command": "python",
      "args": [
        "/path/to/r-mcp-bridge/r_bridge.py"
      ],
      "env": {}
    }
  }
}
```

Note: 
- Docker options require Docker Desktop to be running
- Use `--pull always` to ensure you have the latest version
- For development, use uv or Python options

## Available MCP Tools

### r_status
Check the status of the R API server:
```
Tool: r_status
Returns: Server status, version info, and health status
```

### r_hello
Send a greeting to R:
```
Tool: r_hello
Arguments:
  - name (optional): Name to greet (default: "World")
Returns: Greeting message from R
```

### r_add
Add two numbers using R:
```
Tool: r_add
Arguments:
  - a: First number (default: 0)
  - b: Second number (default: 0)
Returns: Sum of a and b
```

### r_stats
Perform statistical operations on data:
```
Tool: r_stats
Arguments:
  - data: List of numbers
  - operation: One of "mean", "median", "sd", "var", "min", "max", "sum" (default: "mean")
Returns: Statistical result
```

### r_lm_simple
Perform simple linear regression:
```
Tool: r_lm_simple
Arguments:
  - x: List of x values (independent variable)
  - y: List of y values (dependent variable)
Returns: Regression coefficients, R-squared, p-value, and more
```

## Example Usage in Claude

Once configured, you can ask Claude to:

- "Check if the R server is running"
- "Calculate the mean of [1, 2, 3, 4, 5] using R"
- "Perform a linear regression on x=[1,2,3,4,5] and y=[2,4,5,4,5]"
- "Add 42 and 17 using R"

## Adding New Functions

### 1. Add R API Endpoint

Edit `r_api.R` to add a new endpoint:

```r
app$add_post(
    path = "/api/your_function",
    FUN = function(request, response) {
        tryCatch({
            body <- parse_request_body(request)
            
            # Your R logic here
            result <- your_r_function(body$param1, body$param2)
            
            success_response(response, list(
                result = result
            ))
            
        }, error = function(e) {
            error_response(response, e$message)
        })
    }
)
```

### 2. Add MCP Tool

Edit `r_bridge.py` to expose the function:

```python
@server.tool()
async def r_your_function(param1: str, param2: int) -> Dict[str, Any]:
    """
    Your function description
    
    Args:
        param1: Description
        param2: Description
        
    Returns:
        Description of return value
    """
    return await call_r_api("/api/your_function", {
        "param1": param1,
        "param2": param2
    })
```

## Environment Variables

- `R_API_PORT`: Port for R API server (default: 8081)
- `R_API_URL`: Full URL for R API (default: http://localhost:8081)

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌────────────┐
│ Claude Desktop  │────▶│  r_bridge.py │────▶│  r_api.R   │
│   (MCP Client)  │◀────│ (MCP Server) │◀────│(R REST API)│
└─────────────────┘     └──────────────┘     └────────────┘
```

## Troubleshooting

### R API server not running
Make sure the R server is running before starting the Python bridge:
```bash
Rscript r_api.R
```

### Port already in use
Change the port using environment variable:
```bash
R_API_PORT=8082 Rscript r_api.R
R_API_PORT=8082 python r_bridge.py
```

### Missing R packages
Install required packages:
```R
install.packages(c("RestRserve", "jsonlite"))
```

## Future Enhancements

The following features are planned for future releases:

- 🚀 **Execute arbitrary R code** - Run any R expression and get results
- 🧮 **Function calls** - Call any R function with arguments
- 📋 **Data frame operations** - Work with structured data
- 📊 **Advanced statistics** - Correlation, t-tests, ANOVA
- 📈 **Multiple regression** - Support for formula-based regression

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your endpoint to `r_api.R`
4. Add corresponding MCP tool to `r_bridge.py`
5. Update this README
6. Submit a pull request

## Docker Deployment

### Quick Start with Docker Hub

The easiest way to use R MCP Bridge is through Docker Hub:

```bash
# Pull and run directly (no installation needed!)
docker run -i --rm yourusername/r-mcp-bridge
```

That's it! No need to install R, Python, or any dependencies.

### Building Your Own Docker Image

```bash
# Clone the repository
git clone https://github.com/yourusername/r-mcp-bridge.git
cd r-mcp-bridge

# Build the Docker image
docker build -f Dockerfile.mcp -t r-mcp-bridge .

# Test locally
docker run -i --rm r-mcp-bridge
```

### Publishing to Docker Hub

Use the provided build script for multi-platform support:

```bash
# Build and push to Docker Hub
./build-docker-mcp.sh --push
```

### Docker Image Features

- **Optimized for MCP**: Designed specifically for Claude Desktop integration
- **Multi-platform**: Supports both Intel and ARM (M1/M2) Macs
- **Lightweight**: ~400-500MB (optimized from ~800MB)
- **Self-contained**: Includes both R and Python environments
- **Secure**: Runs as non-root user with minimal attack surface

See [DOCKER_HUB.md](DOCKER_HUB.md) for detailed Docker Hub deployment guide.

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built with [FastMCP](https://github.com/jlowin/fastmcp) for Python
- Uses [RestRserve](https://restrserve.org/) for R REST API
- Inspired by the Model Context Protocol specification
````

## File: requirements.txt
````
fastmcp>=2.10.2
httpx>=0.28.1
````
