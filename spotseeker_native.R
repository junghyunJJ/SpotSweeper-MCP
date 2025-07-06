# SpotSweeper Native R MCP Server
# Using mcpr package for native R MCP implementation

library(mcpr)
library(SpotSweeper)

# Tool 1: Detect Local Outliers
detect_outliers_tool <- new_tool(
  name = "detect_local_outliers",
  description = "Detect local outliers in spatial transcriptomics data",
  input_schema = schema(
    properties = properties(
      data_path = property_string("data_path", "Path to input data file"),
      threshold = property_number("threshold", "Detection threshold", default = 3.0),
      metric = property_enum("metric", "Metric to use", 
                           values = c("count", "mitochondrial"), 
                           default = "count")
    ),
    required = c("data_path")
  ),
  handler = function(params) {
    tryCatch({
      # Load data
      if (endsWith(params$data_path, ".rds")) {
        data <- readRDS(params$data_path)
      } else if (endsWith(params$data_path, ".csv")) {
        data <- read.csv(params$data_path)
      } else {
        return(response_error("Unsupported file format"))
      }
      
      # Run outlier detection
      results <- SpotSweeper::detectLocalOutliers(
        data,
        threshold = params$threshold %||% 3.0,
        metric = params$metric %||% "count"
      )
      
      # Return results
      response_text(paste0(
        "Detected ", sum(results$is_outlier), " outliers out of ",
        length(results$is_outlier), " total spots (",
        round(sum(results$is_outlier) / length(results$is_outlier) * 100, 2),
        "% outlier rate)"
      ))
    }, error = function(e) {
      response_error(paste("Error:", e$message))
    })
  }
)

# Tool 2: Detect Artifacts
detect_artifacts_tool <- new_tool(
  name = "detect_artifacts",
  description = "Detect regional artifacts in spatial transcriptomics data",
  input_schema = schema(
    properties = properties(
      data_path = property_string("data_path", "Path to input data file"),
      artifact_type = property_enum("artifact_type", "Type of artifacts to detect",
                                  values = c("all", "edge", "tissue_fold", "bubble"),
                                  default = "all"),
      min_region_size = property_number("min_region_size", "Minimum artifact region size", 
                                      default = 10)
    ),
    required = c("data_path")
  ),
  handler = function(params) {
    tryCatch({
      # Load data
      data <- readRDS(params$data_path)
      
      # Detect artifacts
      artifacts <- SpotSweeper::detectArtifacts(
        data,
        type = params$artifact_type %||% "all",
        min_region_size = params$min_region_size %||% 10
      )
      
      # Return results
      response_text(paste0(
        "Found ", length(artifacts$artifact_regions), " artifact regions affecting ",
        sum(artifacts$is_artifact), " spots"
      ))
    }, error = function(e) {
      response_error(paste("Error:", e$message))
    })
  }
)

# Tool 3: Run QC Pipeline
run_qc_tool <- new_tool(
  name = "run_qc_pipeline",
  description = "Run complete quality control pipeline",
  input_schema = schema(
    properties = properties(
      data_path = property_string("data_path", "Path to input data file"),
      output_dir = property_string("output_dir", "Directory to save results"),
      outlier_threshold = property_number("outlier_threshold", "Outlier detection threshold", 
                                        default = 3.0)
    ),
    required = c("data_path", "output_dir")
  ),
  handler = function(params) {
    tryCatch({
      # Create output directory
      dir.create(params$output_dir, recursive = TRUE, showWarnings = FALSE)
      
      # Load data
      data <- readRDS(params$data_path)
      
      # Run QC pipeline
      qc_results <- SpotSweeper::runQCPipeline(
        data,
        metrics = c("counts", "genes", "mitochondrial"),
        outlier_threshold = params$outlier_threshold %||% 3.0,
        detect_artifacts = TRUE
      )
      
      # Save results
      saveRDS(qc_results, file.path(params$output_dir, "qc_results.rds"))
      
      # Return summary
      response_text(paste0(
        "QC pipeline completed. Found ",
        sum(qc_results$outliers), " outliers and ",
        sum(qc_results$artifacts), " artifacts. ",
        "Results saved to ", params$output_dir
      ))
    }, error = function(e) {
      response_error(paste("Error:", e$message))
    })
  }
)

# Create MCP server
mcp <- new_mcp(
  name = "SpotSweeper MCP Server",
  version = "1.0.0",
  description = "Spatial transcriptomics quality control tools"
)

# Add tools to server
mcp <- add_capability(mcp, detect_outliers_tool)
mcp <- add_capability(mcp, detect_artifacts_tool)
mcp <- add_capability(mcp, run_qc_tool)

# Serve the MCP server
serve_io(mcp)