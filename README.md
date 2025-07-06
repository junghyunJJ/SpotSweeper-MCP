# SpotSweeper MCP Server

This MCP server provides access to the SpotSweeper R package functionality through the Model Context Protocol. SpotSweeper is a spatial transcriptomics quality control package for detecting and addressing quality issues in spot-based datasets.

## Features

- **Local Outlier Detection**: Identify spots with unusual expression patterns compared to their neighbors
- **Artifact Detection**: Find regional artifacts like edge effects, tissue folds, or bubbles
- **QC Pipeline**: Run comprehensive quality control analysis
- **Visualization**: Generate QC plots and spatial visualizations
- **Data Cleaning**: Remove outliers and artifacts from datasets

## Prerequisites

1. **R Installation**: Ensure R (>= 4.0) is installed on your system
2. **SpotSweeper Package**: The server will automatically install SpotSweeper from GitHub

## Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd spotsweeper-mcp
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

3. The server will automatically install required R packages on first run.

## Usage

### Starting the Server

```bash
python spotseeker_server.py
```

### Available Tools

#### 1. `detect_local_outliers`
Detect spots with unusual expression patterns.

**Parameters:**
- `data_path`: Path to input data (CSV, TSV, or RDS)
- `output_path`: Optional path to save results
- `threshold`: Detection threshold (default: 3.0)
- `metric`: Metric to use ('count', 'mitochondrial')

#### 2. `detect_artifacts`
Find regional artifacts in the data.

**Parameters:**
- `data_path`: Path to input data
- `artifact_type`: Type to detect ('all', 'edge', 'tissue_fold', 'bubble')
- `output_path`: Optional output path
- `min_region_size`: Minimum artifact size

#### 3. `run_qc_pipeline`
Run complete QC analysis.

**Parameters:**
- `data_path`: Path to input data
- `output_dir`: Directory for results
- `qc_metrics`: List of metrics to calculate
- `outlier_threshold`: Detection threshold
- `detect_artifacts`: Whether to detect artifacts

#### 4. `visualize_qc`
Create QC visualizations.

**Parameters:**
- `data_path`: Path to QC results
- `plot_type`: Type of plot ('overview', 'spatial', 'metrics', 'outliers')
- `output_path`: Where to save plot
- `highlight_outliers`: Highlight outliers in plot
- `width`, `height`: Plot dimensions

#### 5. `remove_outliers`
Remove detected outliers from dataset.

**Parameters:**
- `data_path`: Original data path
- `outlier_results_path`: Path to detection results
- `output_path`: Where to save cleaned data
- `remove_artifacts`: Also remove artifacts

## Data Format

The server accepts spatial transcriptomics data in:
- RDS format (R data files)
- CSV format
- TSV format

Data should contain:
- Spatial coordinates (x, y)
- Gene expression counts
- Quality metrics (optional)

## Example Workflow

```python
# 1. Detect outliers
result = await detect_local_outliers(
    data_path="data/spatial_data.rds",
    output_path="results/outliers.rds",
    threshold=3.0
)

# 2. Run full QC pipeline
qc_result = await run_qc_pipeline(
    data_path="data/spatial_data.rds",
    output_dir="results/qc",
    qc_metrics=["counts", "genes", "mitochondrial"],
    detect_artifacts=True
)

# 3. Visualize results
plot_result = await visualize_qc(
    data_path="results/qc/qc_results.rds",
    plot_type="overview",
    output_path="plots/qc_overview.png"
)

# 4. Clean data
clean_result = await remove_outliers(
    data_path="data/spatial_data.rds",
    outlier_results_path="results/outliers.rds",
    output_path="data/cleaned_data.rds"
)
```

## Integration with LLMs

This MCP server can be used with:
- Claude Desktop
- Continue.dev
- Any MCP-compatible client

### Claude Desktop Configuration

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "spotseeker": {
      "command": "python",
      "args": ["/path/to/spotseeker_server.py"]
    }
  }
}
```

## Troubleshooting

1. **R Package Installation Issues**: 
   - Ensure BiocManager is installed
   - Check R version compatibility
   - Install manually: `BiocManager::install("MicTott/SpotSweeper")`

2. **Memory Issues**:
   - Large datasets may require increased memory
   - Consider processing in chunks

3. **Visualization Errors**:
   - Ensure ggplot2 is installed
   - Check output directory permissions

## License

This MCP server is provided under the MIT License. SpotSweeper itself is licensed separately.