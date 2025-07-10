#!/bin/bash

# SpotSweeper 설치 문제를 디버깅하기 위한 스크립트

echo "Building debug container with interactive shell..."

# 빌드 단계별로 진행하되, SpotSweeper 설치 전까지만 진행
docker build --target debug-stage -t spotseeker-debug . 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Debug stage not found. Creating temporary Dockerfile..."
    
    # 임시 Dockerfile 생성 (SpotSweeper 설치 직전까지)
    cat > Dockerfile.debug <<EOF
FROM python:3.11-slim

# Install R and system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base-core \
    r-base-dev \
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
    cmake \
    curl \
    gcc \
    g++ \
    make \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install BiocManager
RUN R -e "install.packages('BiocManager', repos='https://cloud.r-project.org/')"

# Install R dependencies
RUN R -e "install.packages(c('remotes', 'Matrix'), repos='https://cloud.r-project.org/')"
RUN R -e "install.packages(c('jsonlite', 'RestRserve'), repos='https://cloud.r-project.org/')"
RUN R -e "install.packages(c('ggplot2', 'cowplot'), repos='https://cloud.r-project.org/')"
RUN R -e "install.packages('reticulate', repos='https://cloud.r-project.org/')"

# Bioconductor packages
RUN R -e "BiocManager::install(c('BiocGenerics', 'S4Vectors', 'IRanges'), ask=FALSE, update=FALSE)"
RUN R -e "BiocManager::install(c('GenomeInfoDb', 'GenomicRanges', 'MatrixGenerics'), ask=FALSE, update=FALSE)"
RUN R -e "BiocManager::install(c('DelayedArray', 'SummarizedExperiment'), ask=FALSE, update=FALSE)"
RUN R -e "BiocManager::install(c('SingleCellExperiment', 'SpatialExperiment'), ask=FALSE, update=FALSE)"
RUN R -e "BiocManager::install('scuttle', ask=FALSE, update=FALSE)"

# 디버깅을 위한 셸
CMD ["/bin/bash"]
EOF

    docker build -f Dockerfile.debug -t spotseeker-debug .
    rm -f Dockerfile.debug
fi

echo ""
echo "Starting interactive container..."
echo "You can now debug SpotSweeper installation manually."
echo ""
echo "Try these commands inside the container:"
echo "  # Check Bioconductor version"
echo "  R -e \"BiocManager::version()\""
echo ""
echo "  # Check available packages"
echo "  R -e \"BiocManager::available('SpotSweeper')\""
echo ""
echo "  # Try installing with verbose output"
echo "  R -e \"BiocManager::install('SpotSweeper', ask=FALSE, update=FALSE, force=TRUE)\""
echo ""
echo "  # Check for specific errors"
echo "  R -e \"sessionInfo()\""
echo ""

docker run -it --rm spotseeker-debug