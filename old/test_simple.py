"""
Simple test for SpotSeeker MCP - API connectivity only
"""

import asyncio
import httpx
import json

R_API_URL = "http://localhost:8081"

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
                data = parse_json_response(response.text)
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
            return False

async def main():
    """Run simple connectivity test"""
    print("SpotSeeker MCP Simple Test")
    print("=" * 50)
    
    success = await test_api_status()
    
    if success:
        print("\n✅ API server is running successfully!")
        print("\nNOTE: The test data (testdata_SpotSweeper.rds) has a different format:")
        print("- No gene symbols (needed for mitochondrial gene detection)")
        print("- Different column names (sum_umi vs sum, sum_gene vs detected)")
        print("- Already has mitochondrial metrics (expr_chrM, expr_chrM_ratio)")
        print("\nFor full testing, you'll need a SpatialExperiment object with:")
        print("- rowData with 'symbol' column containing gene symbols")
        print("- Standard scuttle QC metric column names")
    else:
        print("\n❌ API server is not running!")
        print("  Please check if the R API server is running on port 8081")

if __name__ == "__main__":
    asyncio.run(main())