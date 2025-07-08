#!/usr/bin/env python3
"""Test script for SpotSeeker MCP Bridge"""

import asyncio
import os
from spotseeker_bridge import r_status, r_calculate_qc_metrics, r_run_qc_pipeline

async def test_bridge():
    print("Testing SpotSeeker MCP Bridge...")
    
    # Test 1: Check R API status
    print("\n1. Testing r_status()...")
    status = await r_status()
    print(f"Status: {status}")
    
    # Test 2: Test calculate_qc_metrics if we have test data
    test_data = "/Users/jungj2/Dropbox/Metadata/mcp/spotsweeper-mcp/testdata_SpotSweeper.rds"
    if os.path.exists(test_data):
        print(f"\n2. Testing r_calculate_qc_metrics() with {test_data}...")
        try:
            result = await r_calculate_qc_metrics(
                data_path=test_data,
                species="auto",
                output_path="test_output/qc_metrics_result.rds"
            )
            print(f"QC Metrics Result: {result}")
        except Exception as e:
            print(f"Error: {e}")
    
    # Test 3: Test run_qc_pipeline
    print(f"\n3. Testing r_run_qc_pipeline()...")
    if os.path.exists(test_data):
        try:
            # Create output directory
            os.makedirs("test_output/pipeline", exist_ok=True)
            
            result = await r_run_qc_pipeline(
                data_path=test_data,
                output_dir="test_output/pipeline",
                species="auto"
            )
            print(f"Pipeline Result: {result}")
        except Exception as e:
            print(f"Error: {e}")
    
    print("\n✅ Bridge testing complete!")

if __name__ == "__main__":
    asyncio.run(test_bridge())