# Test Directory

This directory contains all testing resources for the SpotSeeker MCP Docker image.

## Contents

- **test_docker.sh** - Automated test script for Docker image validation
- **TESTING.md** - Comprehensive testing documentation
- **test_example.md** - Quick test examples with sample data
- **data/** - Test data files for SpotSweeper

## Quick Start

Run the automated tests:

```bash
cd .. # Go to project root
./test/test_docker.sh
```

## Test Data

The `data/` subdirectory contains sample spatial transcriptomics data files:
- `testdata_SpotSweeper.rds` - Sample mouse brain data
- `testdata_SpotSweeper2.rds` - Additional test dataset

## Docker Testing

For detailed Docker testing instructions, see [TESTING.md](TESTING.md).

For quick examples, see [test_example.md](test_example.md).