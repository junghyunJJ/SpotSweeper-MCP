"""
SpotSweeper MCP Bridge Server
Production-ready implementation using REST API bridge to R service
"""

import asyncio
import httpx
from typing import Dict, Any, List, Optional
from pathlib import Path

from fastmcp import FastMCP
from fastmcp.tools import tool

# Configuration
R_API_BASE_URL = "http://localhost:8080"
TIMEOUT = httpx.Timeout(30.0, connect=5.0)

# Create FastMCP server instance
server = FastMCP("spotseeker-mcp-production")

# Create a reusable HTTP client
http_client = httpx.AsyncClient(base_url=R_API_BASE_URL, timeout=TIMEOUT)


async def check_api_health() -> bool:
    """Check if the R API server is running"""
    try:
        response = await http_client.get("/health")
        return response.status_code == 200
    except:
        return False


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
    # Check API health
    if not await check_api_health():
        return {
            "error": "R API server is not running. Please start the server first.",
            "success": False
        }
    
    # Prepare request payload
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "threshold": threshold,
        "metric": metric
    }
    
    if output_path:
        payload["output_path"] = str(Path(output_path).absolute())
    
    try:
        # Make API request
        response = await http_client.post("/api/detect-outliers", json=payload)
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        return {"error": f"API error: {e.response.text}", "success": False}
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
    if not await check_api_health():
        return {
            "error": "R API server is not running. Please start the server first.",
            "success": False
        }
    
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "artifact_type": artifact_type,
        "min_region_size": min_region_size
    }
    
    if output_path:
        payload["output_path"] = str(Path(output_path).absolute())
    
    try:
        response = await http_client.post("/api/detect-artifacts", json=payload)
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        return {"error": f"API error: {e.response.text}", "success": False}
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
    if not await check_api_health():
        return {
            "error": "R API server is not running. Please start the server first.",
            "success": False
        }
    
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "output_dir": str(Path(output_dir).absolute()),
        "qc_metrics": qc_metrics,
        "outlier_threshold": outlier_threshold,
        "detect_artifacts": detect_artifacts
    }
    
    try:
        response = await http_client.post("/api/run-qc", json=payload)
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        return {"error": f"API error: {e.response.text}", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


@tool()
async def check_server_status() -> Dict[str, Any]:
    """
    Check the status of the R API server.
    
    Returns:
        Dictionary containing server status information
    """
    try:
        response = await http_client.get("/health")
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {
            "status": "offline",
            "error": str(e),
            "message": "R API server is not running. Please start it with: Rscript api/spotseeker_api.R"
        }


# Cleanup function
async def cleanup():
    """Cleanup resources on shutdown"""
    await http_client.aclose()


# Run the server
if __name__ == "__main__":
    import atexit
    atexit.register(lambda: asyncio.run(cleanup()))
    
    print("Starting SpotSweeper MCP Bridge Server...")
    print("Make sure the R API server is running: Rscript api/spotseeker_api.R")
    server.run()