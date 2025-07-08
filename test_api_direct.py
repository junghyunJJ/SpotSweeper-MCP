#!/usr/bin/env python3
"""Direct test of R API endpoints"""

import httpx
import json
import os

# Base URL for the R API
BASE_URL = "http://localhost:8081"

def test_health():
    """Test the health endpoint"""
    print("Testing /health endpoint...")
    response = httpx.get(f"{BASE_URL}/health")
    print(f"Status code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def test_calculate_qc_metrics():
    """Test calculate-qc-metrics endpoint"""
    test_data = "/Users/jungj2/Dropbox/Metadata/mcp/spotsweeper-mcp/testdata_SpotSweeper.rds"
    
    if not os.path.exists(test_data):
        print(f"Test data not found: {test_data}")
        return False
    
    print("\nTesting /api/calculate-qc-metrics endpoint...")
    payload = {
        "data_path": test_data,
        "species": "auto",
        "output_path": "test_output/qc_metrics_result.rds"
    }
    
    os.makedirs("test_output", exist_ok=True)
    
    response = httpx.post(
        f"{BASE_URL}/api/calculate-qc-metrics",
        json=payload,
        timeout=30.0
    )
    
    print(f"Status code: {response.status_code}")
    if response.status_code == 200:
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    else:
        print(f"Error: {response.text}")
    
    return response.status_code == 200

def test_run_qc_pipeline():
    """Test run-qc-pipeline endpoint"""
    test_data = "/Users/jungj2/Dropbox/Metadata/mcp/spotsweeper-mcp/testdata_SpotSweeper.rds"
    
    if not os.path.exists(test_data):
        print(f"Test data not found: {test_data}")
        return False
    
    print("\nTesting /api/run-qc-pipeline endpoint...")
    payload = {
        "data_path": test_data,
        "output_dir": "test_output/pipeline",
        "species": "auto"
    }
    
    os.makedirs("test_output/pipeline", exist_ok=True)
    
    response = httpx.post(
        f"{BASE_URL}/api/run-qc-pipeline",
        json=payload,
        timeout=60.0
    )
    
    print(f"Status code: {response.status_code}")
    if response.status_code == 200:
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    else:
        print(f"Error: {response.text}")
    
    return response.status_code == 200

if __name__ == "__main__":
    print("=== Testing SpotSeeker R API directly ===\n")
    
    # Test 1: Health check
    health_ok = test_health()
    print(f"✅ Health check: {'PASSED' if health_ok else 'FAILED'}")
    
    # Test 2: Calculate QC metrics
    qc_ok = test_calculate_qc_metrics()
    print(f"✅ Calculate QC metrics: {'PASSED' if qc_ok else 'FAILED'}")
    
    # Test 3: Run QC pipeline
    pipeline_ok = test_run_qc_pipeline()
    print(f"✅ Run QC pipeline: {'PASSED' if pipeline_ok else 'FAILED'}")
    
    print("\n=== All tests completed ===")