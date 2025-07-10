# Docker image for SpotSeeker MCP server
# Start with rocker/r-ver for R 4.4.0
FROM rocker/r-ver:4.4.0

# Install Python 3.11
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3-pip \
    python3.11-venv \
    && ln -s /usr/bin/python3.11 /usr/bin/python \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install additional system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsodium-dev \
    libgit2-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libfontconfig1-dev \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libglpk-dev \
    libmagick++-dev \
    cmake \
    curl \
    gcc \
    g++ \
    make \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/*

# Install BiocManager for Bioconductor packages
RUN R -e "install.packages('BiocManager', repos='https://cloud.r-project.org/')"

# Install R dependencies in steps for better caching
# Install remotes and Matrix first
RUN R -e "install.packages(c('remotes', 'Matrix'), repos='https://cloud.r-project.org/')"

# Basic packages
RUN R -e "install.packages(c('jsonlite', 'RestRserve'), repos='https://cloud.r-project.org/')"
RUN R -e "install.packages(c('ggplot2', 'cowplot'), repos='https://cloud.r-project.org/')"
RUN R -e "install.packages('reticulate', repos='https://cloud.r-project.org/')"

# Bioconductor packages - install dependencies first
RUN R -e "BiocManager::install(c('BiocGenerics', 'S4Vectors', 'IRanges'), ask=FALSE, update=FALSE)"
RUN R -e "BiocManager::install(c('GenomeInfoDb', 'GenomicRanges', 'MatrixGenerics'), ask=FALSE, update=FALSE)"
RUN R -e "BiocManager::install(c('DelayedArray', 'SummarizedExperiment'), ask=FALSE, update=FALSE)"
RUN R -e "BiocManager::install(c('SingleCellExperiment', 'SpatialExperiment'), ask=FALSE, update=FALSE)"
RUN R -e "BiocManager::install('scuttle', ask=FALSE, update=FALSE)"

# Install SpotSweeper from GitHub (it's not yet on Bioconductor)
RUN R -e "remotes::install_github('MicTott/SpotSweeper', dependencies=TRUE, upgrade='never')"


# Install Python package for R-Python interface
RUN R -e "install.packages('anndata', repos='https://cloud.r-project.org/')"

# Verify all R installations
RUN R -e "library(jsonlite); library(RestRserve); library(SpotSweeper); library(SpatialExperiment); library(scuttle); cat('All R packages installed successfully\n')"

# Install Python dependencies
COPY pyproject.toml requirements.txt* /tmp/
RUN pip install --no-cache-dir httpx fastmcp pandas numpy mcp[cli] anndata && \
    rm -f /tmp/pyproject.toml /tmp/requirements.txt

# Create app directory
WORKDIR /app

# Copy application files
COPY spotseeker_api.R spotseeker_bridge.py ./
COPY entrypoint.sh ./

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Create non-root user
RUN useradd -m -u 1000 spotseeker && chown -R spotseeker:spotseeker /app

# Create data directory
RUN mkdir -p /data && chown spotseeker:spotseeker /data

USER spotseeker

# MCP servers communicate via stdio, not network ports
# No EXPOSE needed

# Set environment variables
ENV R_API_URL=http://localhost:8081
ENV R_API_PORT=8081
ENV MCP_STDIO=true
ENV OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# Use shell form to ensure proper signal handling
ENTRYPOINT ["/app/entrypoint.sh"]