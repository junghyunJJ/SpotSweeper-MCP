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