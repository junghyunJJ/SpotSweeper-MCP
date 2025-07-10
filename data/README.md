# Data Directory

This directory is for storing your spatial transcriptomics data files.

## Usage

Place your SpatialExperiment objects (as RDS files) or other supported data formats in this directory.

## Supported Formats

- **RDS files** - R data files containing SpatialExperiment objects
- **CSV files** - Comma-separated values with spatial coordinates
- **TSV files** - Tab-separated values with spatial coordinates

## Test Data

Test data files have been moved to the `test/data/` directory. If you're looking for sample data to test SpotSeeker MCP, please check:

```
../test/data/
├── testdata_SpotSweeper.rds
└── testdata_SpotSweeper2.rds
```

## Docker Volume Mounting

When using Docker, this directory can be mounted to access your data:

```bash
docker run -i --rm \
  -v "$(pwd):$(pwd):ro" \
  -v "/tmp/spotseeker-output:/output:rw" \
  -w "$(pwd)" \
  spotseeker-mcp:latest
```

This will make all files in your current directory (including this data folder) accessible to the SpotSeeker MCP server.