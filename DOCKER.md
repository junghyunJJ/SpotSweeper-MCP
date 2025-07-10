# Docker Deployment Guide for SpotSeeker MCP

This guide explains how to build and run the SpotSeeker MCP server using Docker.

## Prerequisites

1. Docker installed on your system
2. Docker Compose (optional, for easier deployment)
3. Claude Desktop with MCP support

## Quick Start

### Using Docker Compose (Recommended)

1. Build and start the container:
```bash
docker-compose up --build
```

2. For background operation:
```bash
docker-compose up -d --build
```

3. Stop the container:
```bash
docker-compose down
```

### Using Docker CLI

1. Build the image:
```bash
docker build -t spotseeker-mcp:latest .
```

2. Run the container:
```bash
docker run -i --rm \
  -v $(pwd)/data:/data \
  spotseeker-mcp:latest
```

## Integration with Claude Desktop

### Method 1: Using Wrapper Script (Easiest)

First, add the wrapper script to your PATH:
```bash
ln -s /path/to/spotseeker-mcp-docker /usr/local/bin/
```

Then use in Claude Desktop:
```json
{
  "mcpServers": {
    "spotseeker": {
      "command": "spotseeker-mcp-docker"
    }
  }
}
```

Configure mounting mode via environment variables:
- `SPOTSEEKER_MOUNT_MODE=pwd` (default) - Mount current directory
- `SPOTSEEKER_MOUNT_MODE=home` - Mount entire home directory
- `SPOTSEEKER_MOUNT_MODE=custom` with `SPOTSEEKER_WORKSPACE=/path/to/workspace`

### Method 2: Current Directory Access (Default)

This configuration allows SpotSeeker to access files from your current working directory:

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
        "${HOME}/.spotseeker/output:/output:rw",
        "-w",
        "${PWD}",
        "-e",
        "HOST_PWD=${PWD}",
        "spotseeker-mcp:latest"
      ]
    }
  }
}
```

### Method 3: Home Directory Access (Broader Access)

For accessing files anywhere in your home directory:

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
        "${HOME}:${HOME}:ro",
        "-v",
        "${HOME}/.spotseeker/output:/output:rw",
        "-w",
        "${PWD}",
        "-e",
        "HOST_HOME=${HOME}",
        "spotseeker-mcp:latest"
      ]
    }
  }
}
```

### Method 4: Project-Specific Workspace

For a specific project directory:

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
        "/path/to/your/project:/workspace:ro",
        "-v",
        "/path/to/your/project/output:/output:rw",
        "-w",
        "/workspace",
        "spotseeker-mcp:latest"
      ]
    }
  }
}
```

### File Path Handling

- **Input files**: Use absolute paths as they appear on your host system
- **Output files**: 
  - Save to `/output/` for persistent storage
  - Files saved to `/output/` appear in `~/.spotseeker/output/` on host
  - Example: `/output/results.rds` → `~/.spotseeker/output/results.rds`

### Security Considerations

- Input directories are mounted read-only (`:ro`) for safety
- Only the output directory is writable (`:rw`)
- Consider which directories you expose to the container

## Advanced Usage

### With Multiple Data Directories

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
        "/path/to/input/data:/input:ro",
        "-v",
        "/path/to/output/data:/output:rw",
        "spotseeker-mcp:latest"
      ]
    }
  }
}
```

### With Custom Environment Variables

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
        "/path/to/data:/data",
        "-e",
        "R_API_PORT=8082",
        "spotseeker-mcp:latest"
      ]
    }
  }
}
```

## Building for Multiple Platforms

To build for both AMD64 and ARM64 architectures:

```bash
# Create a new builder instance
docker buildx create --name spotseeker-builder --use

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t spotseeker-mcp:latest \
  --load .
```

## Publishing to Docker Hub

### Manual Publishing

1. Tag your image:
```bash
docker tag spotseeker-mcp:latest yourusername/spotseeker-mcp:latest
docker tag spotseeker-mcp:latest yourusername/spotseeker-mcp:1.0.0
```

2. Push to Docker Hub:
```bash
docker push yourusername/spotseeker-mcp:latest
docker push yourusername/spotseeker-mcp:1.0.0
```

### Automatic Publishing with GitHub Actions

1. **Set up Docker Hub**:
   - Create a repository on Docker Hub named `spotseeker-mcp`
   - Generate an access token: Account Settings → Security → New Access Token

2. **Configure GitHub Secrets**:
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Add these secrets:
     - `DOCKER_USERNAME`: Your Docker Hub username
     - `DOCKER_TOKEN`: Your Docker Hub access token

3. **Create a Release**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

   This will automatically:
   - Build multi-platform images (AMD64 and ARM64)
   - Push to Docker Hub with appropriate tags
   - Update the Docker Hub description

### Using the Published Image

Update Claude Desktop config to use Docker Hub image:
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
        "yourusername/spotseeker-mcp:latest"
      ]
    }
  }
}
```

## Troubleshooting

### Container fails to start

1. Check Docker logs:
```bash
docker-compose logs
# or
docker logs <container-id>
```

2. Verify R API is starting:
```bash
docker run -it --rm spotseeker-mcp:latest bash
# Inside container:
Rscript /app/spotseeker_api.R
```

### Permission issues with data files

Ensure your data files are readable by the container user (UID 1000):
```bash
chmod -R 755 /path/to/your/data
```

### Memory issues

Increase Docker memory limits in docker-compose.yml or use:
```bash
docker run -i --rm \
  -m 8g \
  -v /path/to/data:/data \
  spotseeker-mcp:latest
```

## Development

To develop with live code changes:

1. Mount your source code:
```bash
docker run -i --rm \
  -v $(pwd):/app \
  -v $(pwd)/data:/data \
  spotseeker-mcp:latest
```

2. Or update docker-compose.yml:
```yaml
volumes:
  - ./:/app:ro
  - ./data:/data:rw
```

## Security Considerations

- The container runs as a non-root user (spotseeker, UID 1000)
- Only necessary ports are exposed internally
- Use read-only mounts (`:ro`) for input data when possible
- Regularly update the base images for security patches

## Performance Optimization

- The Dockerfile uses multi-stage builds to minimize image size
- R packages are installed in separate layers for better caching
- Consider using a volume for R package cache:
  ```bash
  docker run -i --rm \
    -v r-packages:/usr/local/lib/R/site-library \
    -v /path/to/data:/data \
    spotseeker-mcp:latest
  ```