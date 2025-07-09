"""
SpotSeeker MCP Bridge - A clean, extensible bridge for SpotSweeper R package
"""

import asyncio
import httpx
from typing import Dict, Any, Optional
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
async def r_calculate_qc_metrics(
    data_path: str,
    species: str = "auto",
    output_path: Optional[str] = None
) -> Dict[str, Any]:
    """
    Calculate quality control metrics for spatial transcriptomics data using scuttle
    
    Args:
        data_path: Path to SpatialExperiment object saved as RDS file
        species: Species type - "human" (^MT-), "mouse" (^Mt-), or "auto" (auto-detect)
        output_path: Optional path to save the updated SpatialExperiment object
    
    Returns:
        Dictionary containing:
        - QC metric summary statistics (mean/median UMI, genes, mito%)
        - Mito pattern used for detection
        - Total number of spots
        - QC columns added to colData
    """
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "species": species
    }
    
    if output_path:
        payload["output_path"] = str(Path(output_path).absolute())
    
    return await call_r_api("/api/calculate-qc-metrics", payload)


@server.tool()
async def r_run_qc_pipeline(
    data_path: str,
    output_dir: str,
    species: str = "auto"
) -> Dict[str, Any]:
    """
    Run complete SpotSweeper quality control pipeline on spatial transcriptomics data
    
    This pipeline:
    1. Calculates QC metrics (sum, detected, subsets_mito_percent)
    2. Detects local outliers using all 3 metrics combined with logical OR
    3. Finds technical artifacts based on mitochondrial metrics
    4. Saves filtered clean data excluding outliers and artifacts
    
    Args:
        data_path: Path to SpatialExperiment object saved as RDS file
        output_dir: Directory to save all QC results
        species: Species type - "human" (^MT-), "mouse" (^Mt-), or "auto" (auto-detect)
    
    Returns:
        Dictionary containing:
        - total_spots: Total number of spots in the dataset
        - filtered_local_outliers: Number of local outliers detected
        - filtered_artifacts: Number of artifacts detected
        - tot_filtered_spot: Total number of spots filtered (outliers + artifacts)
        - output_directory: Path to output directory
        - files_created: List of files created (qc_results.rds, qc_summary.rds, qc_results.h5ad if conversion successful)
    """
    payload = {
        "data_path": str(Path(data_path).absolute()),
        "output_dir": str(Path(output_dir).absolute()),
        "species": species
    }
    
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