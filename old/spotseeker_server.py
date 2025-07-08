"""
SpotSweeper MCP Server

This server provides access to SpotSweeper R package functionality through the Model Context Protocol.
SpotSweeper is a spatial transcriptomics quality control package for detecting and addressing
quality issues in spot-based datasets.
"""

import os
import tempfile
import json
from typing import Dict, Any, List, Optional
from pathlib import Path

from fastmcp import FastMCP, Context
from fastmcp.tools import tool
import rpy2.robjects as ro
from rpy2.robjects import pandas2ri
from rpy2.robjects.packages import importr, isinstalled
import pandas as pd
import numpy as np

# Enable automatic conversion between pandas and R dataframes
pandas2ri.activate()

# Create FastMCP server instance
server = FastMCP("spotseeker-mcp")


def ensure_r_packages():
    """Ensure required R packages are installed"""
    # Check if BiocManager is installed
    if not isinstalled('BiocManager'):
        utils = importr('utils')
        utils.install_packages('BiocManager', repos='https://cloud.r-project.org')
    
    # Check if SpotSweeper is installed
    if not isinstalled('SpotSweeper'):
        biocmanager = importr('BiocManager')
        biocmanager.install('MicTott/SpotSweeper')


# Initialize R environment and load SpotSweeper
try:
    ensure_r_packages()
    spotseeker = importr('SpotSweeper')
    base = importr('base')
    utils = importr('utils')
except Exception as e:
    print(f"Error loading R packages: {e}")
    print("Please ensure R is installed and SpotSweeper package is available")
    raise


@tool()
async def detect_local_outliers(
    data_path: str,
    output_path: Optional[str] = None,
    threshold: float = 3.0,
    metric: str = "count"
) -> Dict[str, Any]:
    """
    Detect local outliers in spatial transcriptomics data.
    
    Args:
        data_path: Path to the input data file (CSV, TSV, or RDS format)
        output_path: Optional path to save the results
        threshold: Threshold for outlier detection (default: 3.0)
        metric: Metric to use for outlier detection (e.g., 'count', 'mitochondrial')
    
    Returns:
        Dictionary containing outlier detection results and statistics
    """
    try:
        # Load data
        if data_path.endswith('.rds'):
            ro.r(f'data <- readRDS("{data_path}")')
        elif data_path.endswith('.csv'):
            ro.r(f'data <- read.csv("{data_path}")')
        elif data_path.endswith('.tsv'):
            ro.r(f'data <- read.table("{data_path}", sep="\\t", header=TRUE)')
        else:
            return {"error": "Unsupported file format. Please use CSV, TSV, or RDS."}
        
        # Run local outlier detection
        ro.r(f'''
        results <- SpotSweeper::detectLocalOutliers(
            data,
            threshold = {threshold},
            metric = "{metric}"
        )
        ''')
        
        # Extract results
        n_outliers = ro.r('sum(results$is_outlier)')[0]
        total_spots = ro.r('length(results$is_outlier)')[0]
        
        result = {
            "success": True,
            "n_outliers": int(n_outliers),
            "total_spots": int(total_spots),
            "outlier_percentage": float(n_outliers / total_spots * 100),
            "threshold_used": threshold,
            "metric_used": metric
        }
        
        # Save results if output path is provided
        if output_path:
            ro.r(f'saveRDS(results, "{output_path}")')
            result["output_saved"] = output_path
        
        return result
        
    except Exception as e:
        return {"error": str(e), "success": False}


@tool()
async def detect_artifacts(
    data_path: str,
    artifact_type: str = "all",
    output_path: Optional[str] = None,
    min_region_size: int = 10
) -> Dict[str, Any]:
    """
    Detect regional artifacts in spatial transcriptomics data.
    
    Args:
        data_path: Path to the input data file
        artifact_type: Type of artifacts to detect ('all', 'edge', 'tissue_fold', 'bubble')
        output_path: Optional path to save the results
        min_region_size: Minimum size of region to consider as artifact
    
    Returns:
        Dictionary containing artifact detection results
    """
    try:
        # Load data
        if data_path.endswith('.rds'):
            ro.r(f'data <- readRDS("{data_path}")')
        elif data_path.endswith('.csv'):
            ro.r(f'data <- read.csv("{data_path}")')
        else:
            return {"error": "Unsupported file format"}
        
        # Run artifact detection
        ro.r(f'''
        artifacts <- SpotSweeper::detectArtifacts(
            data,
            type = "{artifact_type}",
            min_region_size = {min_region_size}
        )
        ''')
        
        # Extract results
        n_artifacts = ro.r('length(artifacts$artifact_regions)')[0]
        affected_spots = ro.r('sum(artifacts$is_artifact)')[0]
        
        result = {
            "success": True,
            "n_artifacts": int(n_artifacts),
            "affected_spots": int(affected_spots),
            "artifact_type": artifact_type,
            "min_region_size": min_region_size
        }
        
        if output_path:
            ro.r(f'saveRDS(artifacts, "{output_path}")')
            result["output_saved"] = output_path
        
        return result
        
    except Exception as e:
        return {"error": str(e), "success": False}


@tool()
async def run_qc_pipeline(
    data_path: str,
    output_dir: str,
    qc_metrics: List[str] = ["counts", "genes", "mitochondrial"],
    outlier_threshold: float = 3.0,
    detect_artifacts: bool = True
) -> Dict[str, Any]:
    """
    Run complete quality control pipeline on spatial transcriptomics data.
    
    Args:
        data_path: Path to the input data file
        output_dir: Directory to save all QC results
        qc_metrics: List of QC metrics to calculate
        outlier_threshold: Threshold for outlier detection
        detect_artifacts: Whether to detect regional artifacts
    
    Returns:
        Dictionary containing comprehensive QC results
    """
    try:
        # Create output directory if it doesn't exist
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        # Load data
        ro.r(f'data <- readRDS("{data_path}")')
        
        # Run QC pipeline
        metrics_str = ', '.join([f'"{m}"' for m in qc_metrics])
        ro.r(f'''
        qc_results <- SpotSweeper::runQCPipeline(
            data,
            metrics = c({metrics_str}),
            outlier_threshold = {outlier_threshold},
            detect_artifacts = {str(detect_artifacts).upper()}
        )
        ''')
        
        # Save comprehensive results
        ro.r(f'saveRDS(qc_results, file.path("{output_dir}", "qc_results.rds"))')
        
        # Extract summary statistics
        total_spots = ro.r('nrow(qc_results$metadata)')[0]
        n_outliers = ro.r('sum(qc_results$outliers)')[0]
        
        result = {
            "success": True,
            "total_spots": int(total_spots),
            "n_outliers": int(n_outliers),
            "qc_metrics_calculated": qc_metrics,
            "output_directory": output_dir,
            "files_created": [
                f"{output_dir}/qc_results.rds"
            ]
        }
        
        if detect_artifacts:
            n_artifacts = ro.r('sum(qc_results$artifacts)')[0]
            result["n_artifacts"] = int(n_artifacts)
        
        return result
        
    except Exception as e:
        return {"error": str(e), "success": False}


@tool()
async def visualize_qc(
    data_path: str,
    plot_type: str = "overview",
    output_path: str = "qc_plot.png",
    highlight_outliers: bool = True,
    width: int = 800,
    height: int = 600
) -> Dict[str, Any]:
    """
    Create quality control visualizations for spatial transcriptomics data.
    
    Args:
        data_path: Path to the QC results or original data
        plot_type: Type of plot ('overview', 'spatial', 'metrics', 'outliers')
        output_path: Path to save the plot
        highlight_outliers: Whether to highlight outliers in the plot
        width: Plot width in pixels
        height: Plot height in pixels
    
    Returns:
        Dictionary containing plot information
    """
    try:
        # Load data
        ro.r(f'data <- readRDS("{data_path}")')
        
        # Create plot based on type
        ro.r(f'''
        library(ggplot2)
        
        p <- SpotSweeper::plotQC(
            data,
            type = "{plot_type}",
            highlight_outliers = {str(highlight_outliers).upper()}
        )
        
        ggsave(
            "{output_path}",
            plot = p,
            width = {width/100},
            height = {height/100},
            dpi = 100
        )
        ''')
        
        result = {
            "success": True,
            "plot_type": plot_type,
            "output_path": output_path,
            "dimensions": f"{width}x{height}px"
        }
        
        return result
        
    except Exception as e:
        return {"error": str(e), "success": False}


@tool()
async def remove_outliers(
    data_path: str,
    outlier_results_path: str,
    output_path: str,
    remove_artifacts: bool = True
) -> Dict[str, Any]:
    """
    Remove detected outliers and artifacts from the dataset.
    
    Args:
        data_path: Path to the original data
        outlier_results_path: Path to the outlier detection results
        output_path: Path to save the cleaned data
        remove_artifacts: Whether to also remove regional artifacts
    
    Returns:
        Dictionary containing cleaning results
    """
    try:
        # Load data and results
        ro.r(f'data <- readRDS("{data_path}")')
        ro.r(f'outlier_results <- readRDS("{outlier_results_path}")')
        
        # Remove outliers
        ro.r(f'''
        cleaned_data <- SpotSweeper::removeOutliers(
            data,
            outlier_results,
            remove_artifacts = {str(remove_artifacts).upper()}
        )
        ''')
        
        # Save cleaned data
        ro.r(f'saveRDS(cleaned_data, "{output_path}")')
        
        # Get statistics
        original_spots = ro.r('nrow(data)')[0]
        remaining_spots = ro.r('nrow(cleaned_data)')[0]
        removed_spots = original_spots - remaining_spots
        
        result = {
            "success": True,
            "original_spots": int(original_spots),
            "remaining_spots": int(remaining_spots),
            "removed_spots": int(removed_spots),
            "removal_percentage": float(removed_spots / original_spots * 100),
            "output_path": output_path
        }
        
        return result
        
    except Exception as e:
        return {"error": str(e), "success": False}


# Run the server
if __name__ == "__main__":
    server.run()