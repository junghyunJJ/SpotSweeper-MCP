#!/usr/bin/env python3
"""Test the updated R API with automatic gene symbol detection"""

import requests
import json
import os

# API base URL
BASE_URL = "http://localhost:8081"

def test_calculate_qc_metrics():
    """Test calculate QC metrics with testdata_SpotSweeper2.rds"""
    
    # Get absolute path
    data_path = os.path.abspath("testdata_SpotSweeper2.rds")
    
    print("Testing calculate QC metrics with automatic gene symbol detection...")
    print(f"Data path: {data_path}")
    
    response = requests.post(
        f"{BASE_URL}/api/calculate-qc-metrics",
        json={
            "data_path": data_path,
            "species": "auto"  # Let it auto-detect
        }
    )
    
    print(f"\nStatus code: {response.status_code}")
    
    if response.status_code == 200:
        result = response.json()
        print("\nResult:")
        print(json.dumps(result, indent=2))
        
        # Check key results
        if result.get("success"):
            print("\n✓ QC metrics calculated successfully!")
            print(f"  - Gene symbol column used: {result.get('gene_symbol_column', 'Not found')}")
            print(f"  - Mito pattern used: {result.get('mito_pattern_used')}")
            print(f"  - Mean mito percent: {result.get('mean_mito_percent'):.2f}%")
            print(f"  - Median mito percent: {result.get('median_mito_percent'):.2f}%")
    else:
        print(f"Error: {response.text}")

def test_run_qc_pipeline():
    """Test full QC pipeline with automatic gene detection"""
    
    data_path = os.path.abspath("testdata_SpotSweeper2.rds")
    output_dir = os.path.abspath("test_qc_output_auto")
    
    print("\n\nTesting full QC pipeline with automatic gene symbol detection...")
    
    response = requests.post(
        f"{BASE_URL}/api/run-qc-pipeline",
        json={
            "data_path": data_path,
            "output_dir": output_dir,
            "species": "auto",
            "metrics": ["sum", "detected"],
            "detect_artifacts": True
        }
    )
    
    print(f"\nStatus code: {response.status_code}")
    
    if response.status_code == 200:
        result = response.json()
        print("\nResult:")
        print(json.dumps(result, indent=2))
        
        if result.get("success"):
            print("\n✓ QC pipeline completed successfully!")
            print(f"  - Total spots: {result.get('total_spots')}")
            print(f"  - Total outliers: {result.get('total_outliers')}")
            print(f"  - Artifacts detected: {result.get('n_artifacts')}")
    else:
        print(f"Error: {response.text}")

def main():
    # Check if API is running
    try:
        response = requests.get(f"{BASE_URL}/health")
        if response.status_code != 200:
            print("Error: R API server is not running!")
            print("Please start it with: Rscript spotseeker_api.R")
            return
    except requests.exceptions.ConnectionError:
        print("Error: Cannot connect to R API server!")
        print("Please start it with: Rscript spotseeker_api.R")
        return
    
    # Run tests
    test_calculate_qc_metrics()
    test_run_qc_pipeline()

if __name__ == "__main__":
    main()