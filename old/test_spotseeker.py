"""
Test script for SpotSeeker MCP
Tests all functionality using testdata_SpotSweeper.rds
"""

import asyncio
import httpx
from pathlib import Path
import json
import os

# Base configuration
BASE_DIR = Path(__file__).parent
TEST_DATA = str(BASE_DIR / "testdata_SpotSweeper.rds")
OUTPUT_DIR = str(BASE_DIR / "test_output")
R_API_URL = "http://localhost:8081"

# Create output directory
os.makedirs(OUTPUT_DIR, exist_ok=True)

def parse_json_response(response_text):
    """Parse potentially double-encoded JSON response"""
    try:
        # If the response is double-encoded (wrapped in quotes)
        if response_text.startswith('"') and response_text.endswith('"'):
            # First decode to get the actual JSON string
            response_text = json.loads(response_text)
        # Now parse the actual JSON
        return json.loads(response_text)
    except json.JSONDecodeError:
        # If it's not JSON, return as is
        return response_text

async def test_api_status():
    """Test if R API server is running"""
    print("\n=== Testing API Status ===")
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(f"{R_API_URL}/health")
            if response.status_code == 200:
                # Handle double-encoded JSON
                text = response.text
                if text.startswith('"') and text.endswith('"'):
                    # Remove outer quotes and unescape
                    text = json.loads(text)
                data = json.loads(text)
                print(f"✓ API Status: {data['status']}")
                print(f"  Service: {data['service']}")
                print(f"  Version: {data['version']}")
                print(f"  R Version: {data['r_version']}")
                print(f"  Packages:")
                for pkg, ver in data['packages'].items():
                    print(f"    - {pkg}: {ver}")
                return True
            else:
                print(f"✗ API returned status code: {response.status_code}")
                return False
        except Exception as e:
            print(f"✗ Failed to connect to API: {e}")
            print("  Make sure R API server is running: Rscript spotseeker_api.R")
            return False


async def test_calculate_qc_metrics():
    """Test QC metrics calculation"""
    print("\n=== Testing QC Metrics Calculation ===")
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            payload = {
                "data_path": TEST_DATA,
                "mito_string": "^MT-",
                "output_path": str(Path(OUTPUT_DIR) / "test_qc_metrics.rds")
            }
            
            response = await client.post(
                f"{R_API_URL}/api/calculate-qc-metrics",
                json=payload
            )
            
            if response.status_code == 200:
                data = parse_json_response(response.text)
                if data['success']:
                    print("✓ QC Metrics calculated successfully:")
                    print(f"  Total spots: {data['total_spots']}")
                    print(f"  Mean UMI count: {data['mean_umi_count']:.2f}")
                    print(f"  Median UMI count: {data['median_umi_count']:.2f}")
                    print(f"  Mean gene count: {data['mean_gene_count']:.2f}")
                    print(f"  Median gene count: {data['median_gene_count']:.2f}")
                    print(f"  Mean mito %: {data['mean_mito_percent']:.2f}")
                    print(f"  Median mito %: {data['median_mito_percent']:.2f}")
                    print(f"  Output saved: {data.get('output_saved', 'N/A')}")
                    return True
                else:
                    print(f"✗ API error: {data.get('error', 'Unknown error')}")
                    return False
            else:
                print(f"✗ HTTP error: {response.status_code}")
                print(f"  Response: {response.text}")
                return False
                
        except Exception as e:
            print(f"✗ Request failed: {e}")
            return False


async def test_local_outliers():
    """Test local outlier detection"""
    print("\n=== Testing Local Outlier Detection ===")
    
    # Test for both sum and detected metrics
    metrics = ["sum", "detected"]
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        for metric in metrics:
            print(f"\n--- Testing metric: {metric} ---")
            try:
                payload = {
                    "data_path": TEST_DATA,
                    "metric": metric,
                    "direction": "lower",
                    "log": True,
                    "output_path": str(Path(OUTPUT_DIR) / f"test_outliers_{metric}.rds")
                }
                
                response = await client.post(
                    f"{R_API_URL}/api/local-outliers",
                    json=payload
                )
                
                if response.status_code == 200:
                    data = parse_json_response(response.text)
                    if data['success']:
                        print(f"✓ Outliers detected for {metric}:")
                        print(f"  Number of outliers: {data['n_outliers']}")
                        print(f"  Total spots: {data['total_spots']}")
                        print(f"  Outlier percentage: {data['outlier_percentage']:.2f}%")
                        print(f"  Outlier column: {data['outlier_column']}")
                    else:
                        print(f"✗ API error: {data.get('error', 'Unknown error')}")
                        return False
                else:
                    print(f"✗ HTTP error: {response.status_code}")
                    return False
                    
            except Exception as e:
                print(f"✗ Request failed for {metric}: {e}")
                return False
    
    return True


async def test_find_artifacts():
    """Test artifact detection"""
    print("\n=== Testing Artifact Detection ===")
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            # First need to ensure QC metrics are calculated
            print("Ensuring QC metrics are present...")
            qc_payload = {
                "data_path": TEST_DATA,
                "mito_string": "^MT-"
            }
            qc_response = await client.post(
                f"{R_API_URL}/api/calculate-qc-metrics",
                json=qc_payload
            )
            
            if qc_response.status_code != 200:
                print("✗ Failed to calculate QC metrics first")
                return False
            
            # Parse QC response to ensure metrics are added
            qc_data = parse_json_response(qc_response.text)
            if not qc_data.get('success'):
                print(f"✗ QC metrics calculation failed: {qc_data.get('error')}")
                return False
            
            # Now find artifacts
            payload = {
                "data_path": TEST_DATA,
                "mito_percent": "subsets_mito_percent",
                "mito_sum": "subsets_mito_sum",
                "n_order": 5,
                "name": "artifacts",
                "output_path": str(Path(OUTPUT_DIR) / "test_artifacts.rds")
            }
            
            response = await client.post(
                f"{R_API_URL}/api/find-artifacts",
                json=payload
            )
            
            if response.status_code == 200:
                data = parse_json_response(response.text)
                if data['success']:
                    print("✓ Artifacts detected successfully:")
                    print(f"  Number of artifacts: {data['n_artifacts']}")
                    print(f"  Total spots: {data['total_spots']}")
                    print(f"  Artifact percentage: {data['artifact_percentage']:.2f}%")
                    print(f"  Artifact column: {data['artifact_column']}")
                    return True
                else:
                    print(f"✗ API error: {data.get('error', 'Unknown error')}")
                    return False
            else:
                print(f"✗ HTTP error: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"✗ Request failed: {e}")
            return False


async def test_qc_pipeline():
    """Test complete QC pipeline"""
    print("\n=== Testing Complete QC Pipeline ===")
    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            pipeline_output_dir = str(Path(OUTPUT_DIR) / "pipeline_output")
            os.makedirs(pipeline_output_dir, exist_ok=True)
            
            payload = {
                "data_path": TEST_DATA,
                "output_dir": pipeline_output_dir,
                "metrics": ["sum", "detected"],
                "directions": {"sum": "lower", "detected": "lower"},
                "log_transform": True,
                "detect_artifacts": True,
                "n_order": 5,
                "mito_string": "^MT-"
            }
            
            response = await client.post(
                f"{R_API_URL}/api/run-qc-pipeline",
                json=payload
            )
            
            if response.status_code == 200:
                data = parse_json_response(response.text)
                if data['success']:
                    print("✓ QC Pipeline completed successfully:")
                    print(f"  Total spots: {data['total_spots']}")
                    print(f"  Total outliers: {data['total_outliers']}")
                    print(f"  Number of artifacts: {data['n_artifacts']}")
                    print(f"  Outlier columns: {', '.join(data['outlier_columns'])}")
                    print(f"  Output directory: {data['output_directory']}")
                    print(f"  Files created: {', '.join(data['files_created'])}")
                    
                    # Check if files were actually created
                    for file in data['files_created']:
                        file_path = Path(pipeline_output_dir) / file
                        if file_path.exists():
                            print(f"    ✓ {file} exists")
                        else:
                            print(f"    ✗ {file} not found")
                    
                    return True
                else:
                    print(f"✗ API error: {data.get('error', 'Unknown error')}")
                    return False
            else:
                print(f"✗ HTTP error: {response.status_code}")
                print(f"  Response: {response.text}")
                return False
                
        except Exception as e:
            print(f"✗ Request failed: {e}")
            return False


async def main():
    """Run all tests"""
    print("SpotSeeker MCP Test Suite")
    print("=" * 50)
    print(f"Test data: {TEST_DATA}")
    print(f"Output directory: {OUTPUT_DIR}")
    
    # Check if test data exists
    if not Path(TEST_DATA).exists():
        print(f"\n✗ Test data not found: {TEST_DATA}")
        return
    
    # Run tests
    tests = [
        ("API Status", test_api_status),
        ("QC Metrics", test_calculate_qc_metrics),
        ("Local Outliers", test_local_outliers),
        ("Find Artifacts", test_find_artifacts),
        ("QC Pipeline", test_qc_pipeline)
    ]
    
    results = {}
    
    # First check if API is running
    if not await test_api_status():
        print("\n✗ R API server is not running!")
        print("  Please start it with: Rscript spotseeker_api.R")
        return
    
    # Run remaining tests
    for test_name, test_func in tests[1:]:  # Skip API status as we already ran it
        try:
            results[test_name] = await test_func()
        except Exception as e:
            print(f"\n✗ Test '{test_name}' crashed: {e}")
            results[test_name] = False
    
    # Summary
    print("\n" + "=" * 50)
    print("TEST SUMMARY")
    print("=" * 50)
    
    passed = sum(1 for result in results.values() if result)
    total = len(results)
    
    for test_name, result in results.items():
        status = "✓ PASSED" if result else "✗ FAILED"
        print(f"{test_name}: {status}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n✅ All tests passed!")
    else:
        print("\n❌ Some tests failed")


if __name__ == "__main__":
    asyncio.run(main())