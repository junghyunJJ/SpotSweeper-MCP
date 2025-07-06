# Multi-stage build for SpotSweeper MCP
FROM rocker/r-ver:4.3.0 AS r-builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages('BiocManager')"
RUN R -e "install.packages('RestRserve')"
RUN R -e "install.packages('jsonlite')"
RUN R -e "BiocManager::install('MicTott/SpotSweeper')"

# Python stage
FROM python:3.11-slim

# Install R runtime
RUN apt-get update && apt-get install -y \
    r-base \
    && rm -rf /var/lib/apt/lists/*

# Copy R libraries from builder
COPY --from=r-builder /usr/local/lib/R /usr/local/lib/R

# Set working directory
WORKDIR /app

# Copy Python requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt httpx

# Copy application files
COPY api/ ./api/
COPY spotseeker_bridge.py .
COPY start.sh .

# Make start script executable
RUN chmod +x start.sh

# Expose ports
EXPOSE 8080 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8080/health').raise_for_status()"

# Start both services
CMD ["./start.sh"]