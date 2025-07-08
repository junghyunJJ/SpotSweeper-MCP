"""
SpotSeeker MCP Bridge - A clean, extensible bridge for SpotSweeper R package
"""

import asyncio
import httpx
from typing import Dict, Any, Optional, List
import os
from pathlib import Path

from fastmcp import FastMCP

# Configuration
R_API_BASE_URL = os.getenv("R_API_URL", "http://localhost:8081")
R_API_PORT = os.getenv("R_API_PORT", "8081")
TIMEOUT = httpx.Timeout(30.0, connect=5.0)

# Create FastMCP server instance
server = FastMCP("spotseeker-mcp")

# Create a reusable HTTP client
http_client = httpx.AsyncClient(base_url=R_API_BASE_URL, timeout=TIMEOUT)


class SpotSeekerError(Exception):
    """Custom exception for SpotSeeker errors"""
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
        raise SpotSeekerError(
            f"R API server is not running. Please start it with: Rscript spotseeker_api.R"
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
    Check the status of the SpotSeeker R API server
    
    Returns:
        Server status information including version and package info
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
async def r_local_outliers(
    data_path: str,
    metric: Optional[str] = None,
    direction: Optional[str] = None,
    log: Optional[bool] = None,
    run_all_metrics: bool = True,
    output_path: Optional[str] = None
) -> Dict[str, Any]:
    """
    Detect local outliers in spatial transcriptomics data using SpotSweeper
    
    Args:
        data_path: Path to SpatialExperiment object saved as RDS file
        metric: QC metric to analyze ('sum' for UMI count, 'detected' for gene count, or column name)
                Only used when run_all_metrics=False
        direction: Direction to check for outliers ('lower' or 'higher')
                   Only used when run_all_metrics=False
        log: Whether to log-transform the metric (recommended for sum and detected)
             Only used when run_all_metrics=False
        run_all_metrics: If True, runs all 3 standard metrics (sum, detected, mito%) and combines results
        output_path: Optional path to save the updated SpatialExperiment object
    
    Returns:
        Dictionary containing outlier detection results and statistics
        If run_all_metrics=True, includes details for each metric and combined results
    """
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "run_all_metrics": run_all_metrics
    }
    
    if not run_all_metrics:
        # Use defaults for single metric mode if not specified
        payload["metric"] = metric if metric is not None else "sum"
        payload["direction"] = direction if direction is not None else "lower"
        payload["log"] = log if log is not None else True
    
    if output_path:
        payload["output_path"] = str(Path(output_path).absolute())
    
    return await call_r_api("/api/local-outliers", payload)


@server.tool()
async def r_find_artifacts(
    data_path: str,
    mito_percent: str = "subsets_mito_percent",
    mito_sum: str = "subsets_mito_sum",
    n_order: int = 5,
    name: str = "artifacts",
    output_path: Optional[str] = None
) -> Dict[str, Any]:
    """
    Find technical artifacts in spatial transcriptomics data using mitochondrial metrics
    
    Args:
        data_path: Path to SpatialExperiment object saved as RDS file
        mito_percent: Column name for mitochondrial percentage in colData
        mito_sum: Column name for mitochondrial sum in colData
        n_order: Size of neighborhood to consider (default: 5)
        name: Name for the output column in colData (default: 'artifacts')
        output_path: Optional path to save the updated SpatialExperiment object
    
    Returns:
        Dictionary containing artifact detection results
    """
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "mito_percent": mito_percent,
        "mito_sum": mito_sum,
        "n_order": n_order,
        "name": name
    }
    
    if output_path:
        payload["output_path"] = str(Path(output_path).absolute())
    
    return await call_r_api("/api/find-artifacts", payload)


@server.tool()
async def r_calculate_qc_metrics(
    data_path: str,
    mito_string: Optional[str] = None,
    species: str = "auto",
    run_outliers: bool = True,
    output_path: Optional[str] = None
) -> Dict[str, Any]:
    """
    Calculate quality control metrics for spatial transcriptomics data using scuttle
    and optionally detect local outliers
    
    Args:
        data_path: Path to SpatialExperiment object saved as RDS file
        mito_string: Regex pattern to identify mitochondrial genes. If None, auto-detect based on species
        species: Species type - "human" (^MT-), "mouse" (^Mt-), or "auto" (auto-detect)
        run_outliers: If True (default), also runs local outlier detection for sum, detected, and mito%
                      and creates a combined "local_outliers" column
        output_path: Optional path to save the updated SpatialExperiment object
    
    Returns:
        Dictionary containing:
        - QC metric summary statistics (mean/median UMI, genes, mito%)
        - Mito pattern used for detection
        - If run_outliers=True: outlier detection results including total outliers,
          details per metric, and the combined "local_outliers" column
    """
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "species": species,
        "run_outliers": run_outliers
    }
    
    if mito_string is not None:
        payload["mito_string"] = mito_string
    
    if output_path:
        payload["output_path"] = str(Path(output_path).absolute())
    
    return await call_r_api("/api/calculate-qc-metrics", payload)


@server.tool()
async def r_run_qc_pipeline(
    data_path: str,
    output_dir: str,
    metrics: List[str] = ["sum", "detected"],
    directions: Optional[Dict[str, str]] = None,
    log_transform: bool = True,
    detect_artifacts: bool = True,
    n_order: int = 5,
    mito_string: Optional[str] = None,
    species: str = "auto"
) -> Dict[str, Any]:
    """
    Run complete SpotSweeper quality control pipeline on spatial transcriptomics data
    
    Args:
        data_path: Path to SpatialExperiment object saved as RDS file
        output_dir: Directory to save all QC results
        metrics: List of metrics for outlier detection (default: ['sum', 'detected'])
        directions: Dictionary mapping metrics to directions (default: {'sum': 'lower', 'detected': 'lower'})
        log_transform: Whether to log-transform metrics (default: True)
        detect_artifacts: Whether to detect technical artifacts (default: True)
        n_order: Neighborhood size for artifact detection (default: 5)
        mito_string: Regex pattern for mitochondrial genes. If None, auto-detect based on species
        species: Species type - "human" (^MT-), "mouse" (^Mt-), or "auto" (auto-detect)
    
    Returns:
        Dictionary containing comprehensive QC results
    """
    # Set default directions if not provided
    if directions is None:
        directions = {"sum": "lower", "detected": "lower"}
    
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "output_dir": str(Path(output_dir).absolute()),
        "metrics": metrics,
        "directions": directions,
        "log_transform": log_transform,
        "detect_artifacts": detect_artifacts,
        "n_order": n_order,
        "species": species
    }
    
    if mito_string is not None:
        payload["mito_string"] = mito_string
    
    return await call_r_api("/api/run-qc-pipeline", payload)


# Cleanup function
async def cleanup():
    """Cleanup resources on shutdown"""
    await http_client.aclose()


# Main entry point
def main():
    """Run the MCP server"""
    import atexit
    atexit.register(lambda: asyncio.run(cleanup()))
    
    print(f"Starting SpotSeeker MCP Bridge Server...")
    print(f"Connecting to R API at: {R_API_BASE_URL}")
    print(f"Make sure the R API server is running: Rscript spotseeker_api.R")
    
    server.run()


if __name__ == "__main__":
    main()