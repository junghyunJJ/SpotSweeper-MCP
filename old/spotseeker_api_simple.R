# Simplified SpotSeeker REST API Server for MCP Bridge
# Minimal version without middleware

library(RestRserve)
library(jsonlite)
library(SpotSweeper)
library(SpatialExperiment)
library(scuttle)
library(SingleCellExperiment)

# Configuration
API_PORT <- 8081
API_VERSION <- "1.0.0"
SERVICE_NAME <- "SpotSeeker R API"

# Helper function to parse request body
parse_request_body <- function(request) {
    if (is.null(request$body)) {
        return(list())
    }
    
    # RestRserve provides parsed JSON in request$body when Content-Type is application/json
    if (is.list(request$body)) {
        return(request$body)
    }
    
    # Fallback for other cases
    return(list())
}

# Helper function to create error response
error_response <- function(response, message, status_code = 500) {
    response$set_status_code(status_code)
    response$set_content_type("application/json")
    response$set_body(toJSON(list(
        success = FALSE,
        error = message,
        timestamp = as.character(Sys.time())
    ), auto_unbox = TRUE))
}

# Helper function to create success response
success_response <- function(response, data) {
    response$set_content_type("application/json")
    response$set_body(toJSON(c(
        list(
            success = TRUE,
            timestamp = as.character(Sys.time())
        ),
        data
    ), auto_unbox = TRUE))
}

# Create application
app <- Application$new()

# Health check endpoint
app$add_get(
  path = "/health",
  FUN = function(request, response) {
    success_response(response, list(
      status = "healthy",
      service = SERVICE_NAME,
      version = API_VERSION,
      r_version = R.version.string,
      packages = list(
        SpotSweeper = as.character(packageVersion("SpotSweeper")),
        SpatialExperiment = as.character(packageVersion("SpatialExperiment"))
      )
    ))
  }
)

# Local outliers endpoint
app$add_post(
  path = "/api/local-outliers",
  FUN = function(request, response) {
    tryCatch({
      body <- parse_request_body(request)
      
      # Validate required parameters
      if (is.null(body$data_path)) {
        error_response(response, "data_path is required", 400)
        return()
      }
      
      # Load data - expecting SpatialExperiment object
      if (endsWith(body$data_path, ".rds")) {
        spe <- readRDS(body$data_path)
      } else if (endsWith(body$data_path, ".h5")) {
        # Support for H5 format if needed
        stop("H5 format support not yet implemented")
      } else {
        error_response(response, "Unsupported file format. Please use .rds file with SpatialExperiment object", 400)
        return()
      }
      
      # Validate it's a SpatialExperiment object
      if (!is(spe, "SpatialExperiment")) {
        error_response(response, "Data must be a SpatialExperiment object", 400)
        return()
      }
      
      # Get parameters with defaults
      metric <- if(is.null(body$metric)) "sum" else body$metric
      direction <- if(is.null(body$direction)) "lower" else body$direction
      log_transform <- if(is.null(body$log)) TRUE else body$log
      
      # Run local outlier detection
      spe <- localOutliers(
        spe = spe,
        metric = metric,
        direction = direction,
        log = log_transform
      )
      
      # Extract outlier column name
      outlier_col <- paste0(metric, "_", direction, "_outliers")
      if (log_transform && metric %in% c("sum", "detected")) {
        outlier_col <- paste0("log_", outlier_col)
      }
      
      # Get outlier results
      outlier_status <- colData(spe)[[outlier_col]]
      n_outliers <- sum(outlier_status, na.rm = TRUE)
      total_spots <- length(outlier_status)
      
      # Save results if output path provided
      if (!is.null(body$output_path)) {
        saveRDS(spe, body$output_path)
      }
      
      # Return results
      success_response(response, list(
        n_outliers = n_outliers,
        total_spots = total_spots,
        outlier_percentage = round(n_outliers / total_spots * 100, 2),
        metric_used = metric,
        direction_used = direction,
        log_transform = log_transform,
        outlier_column = outlier_col,
        output_saved = body$output_path
      ))
      
    }, error = function(e) {
      error_response(response, e$message)
    })
  }
)

# Find artifacts endpoint
app$add_post(
  path = "/api/find-artifacts",
  FUN = function(request, response) {
    tryCatch({
      body <- parse_request_body(request)
      
      # Validate required parameters
      if (is.null(body$data_path)) {
        error_response(response, "data_path is required", 400)
        return()
      }
      
      # Load data - expecting SpatialExperiment object
      spe <- readRDS(body$data_path)
      
      # Validate it's a SpatialExperiment object
      if (!is(spe, "SpatialExperiment")) {
        error_response(response, "Data must be a SpatialExperiment object", 400)
        return()
      }
      
      # Get parameters with defaults
      mito_percent <- if(is.null(body$mito_percent)) "subsets_mito_percent" else body$mito_percent
      mito_sum <- if(is.null(body$mito_sum)) "subsets_mito_sum" else body$mito_sum
      n_order <- if(is.null(body$n_order)) 5 else body$n_order
      name <- if(is.null(body$name)) "artifacts" else body$name
      
      # Find artifacts
      spe <- findArtifacts(
        spe = spe,
        mito_percent = mito_percent,
        mito_sum = mito_sum,
        n_order = n_order,
        name = name
      )
      
      # Get artifact results
      artifact_status <- colData(spe)[[name]]
      n_artifacts <- sum(!artifact_status, na.rm = TRUE)  # FALSE indicates artifact
      total_spots <- length(artifact_status)
      
      # Save if requested
      if (!is.null(body$output_path)) {
        saveRDS(spe, body$output_path)
      }
      
      # Return results
      success_response(response, list(
        n_artifacts = n_artifacts,
        total_spots = total_spots,
        artifact_percentage = round(n_artifacts / total_spots * 100, 2),
        mito_percent_col = mito_percent,
        mito_sum_col = mito_sum,
        n_order = n_order,
        artifact_column = name,
        output_saved = body$output_path
      ))
      
    }, error = function(e) {
      error_response(response, e$message)
    })
  }
)

# Calculate QC metrics endpoint
app$add_post(
  path = "/api/calculate-qc-metrics",
  FUN = function(request, response) {
    tryCatch({
      body <- parse_request_body(request)
      
      # Validate required parameters
      if (is.null(body$data_path)) {
        error_response(response, "data_path is required", 400)
        return()
      }
      
      # Load data
      spe <- readRDS(body$data_path)
      
      # Validate it's a SpatialExperiment object
      if (!is(spe, "SpatialExperiment")) {
        error_response(response, "Data must be a SpatialExperiment object", 400)
        return()
      }
      
      # Get parameters
      mito_string <- if(is.null(body$mito_string)) "^MT-" else body$mito_string
      
      # Calculate QC metrics using scuttle
      is_mito <- grepl(mito_string, rowData(spe)$symbol)
      spe <- scuttle::addPerCellQCMetrics(
        spe,
        subsets = list(mito = is_mito)
      )
      
      # Save if requested
      if (!is.null(body$output_path)) {
        saveRDS(spe, body$output_path)
      }
      
      # Get summary statistics
      qc_data <- colData(spe)
      
      # Return summary
      success_response(response, list(
        total_spots = ncol(spe),
        mean_umi_count = mean(qc_data$sum),
        median_umi_count = median(qc_data$sum),
        mean_gene_count = mean(qc_data$detected),
        median_gene_count = median(qc_data$detected),
        mean_mito_percent = mean(qc_data$subsets_mito_percent),
        median_mito_percent = median(qc_data$subsets_mito_percent),
        qc_columns_added = c("sum", "detected", "subsets_mito_percent", "subsets_mito_sum"),
        output_saved = body$output_path
      ))
      
    }, error = function(e) {
      error_response(response, e$message)
    })
  }
)

# Combined QC pipeline endpoint
app$add_post(
  path = "/api/run-qc-pipeline",
  FUN = function(request, response) {
    tryCatch({
      body <- parse_request_body(request)
      
      # Validate required parameters
      if (is.null(body$data_path)) {
        error_response(response, "data_path is required", 400)
        return()
      }
      
      if (is.null(body$output_dir)) {
        error_response(response, "output_dir is required", 400)
        return()
      }
      
      # Create output directory
      dir.create(body$output_dir, recursive = TRUE, showWarnings = FALSE)
      
      # Load data
      spe <- readRDS(body$data_path)
      
      # Validate it's a SpatialExperiment object
      if (!is(spe, "SpatialExperiment")) {
        error_response(response, "Data must be a SpatialExperiment object", 400)
        return()
      }
      
      # Step 1: Calculate QC metrics if not already present
      if (!"sum" %in% colnames(colData(spe))) {
        mito_string <- if(is.null(body$mito_string)) "^MT-" else body$mito_string
        is_mito <- grepl(mito_string, rowData(spe)$symbol)
        spe <- scuttle::addPerCellQCMetrics(spe, subsets = list(mito = is_mito))
      }
      
      # Step 2: Run local outlier detection for multiple metrics
      metrics <- if(is.null(body$metrics)) c("sum", "detected") else body$metrics
      directions <- if(is.null(body$directions)) list(sum = "lower", detected = "lower") else body$directions
      log_transform <- if(is.null(body$log_transform)) TRUE else body$log_transform
      
      outlier_columns <- character()
      total_outliers <- 0
      
      for (metric in metrics) {
        direction <- if(is.null(directions[[metric]])) "lower" else directions[[metric]]
        spe <- localOutliers(
          spe = spe,
          metric = metric,
          direction = direction,
          log = log_transform
        )
        
        # Track outlier columns
        col_name <- paste0(metric, "_", direction, "_outliers")
        if (log_transform && metric %in% c("sum", "detected")) {
          col_name <- paste0("log_", col_name)
        }
        outlier_columns <- c(outlier_columns, col_name)
        total_outliers <- total_outliers + sum(colData(spe)[[col_name]], na.rm = TRUE)
      }
      
      # Step 3: Find artifacts if requested
      detect_artifacts <- if(is.null(body$detect_artifacts)) TRUE else body$detect_artifacts
      if (detect_artifacts) {
        spe <- findArtifacts(
          spe = spe,
          mito_percent = "subsets_mito_percent",
          mito_sum = "subsets_mito_sum",
          n_order = if(is.null(body$n_order)) 5 else body$n_order,
          name = "artifacts"
        )
      }
      
      # Save results
      saveRDS(spe, file.path(body$output_dir, "qc_results.rds"))
      
      # Create summary report
      qc_summary <- list(
        total_spots = ncol(spe),
        qc_metrics = list(
          mean_umi = mean(colData(spe)$sum),
          mean_genes = mean(colData(spe)$detected),
          mean_mito_percent = mean(colData(spe)$subsets_mito_percent)
        ),
        outliers = list(
          total = total_outliers,
          columns = outlier_columns
        ),
        artifacts = if("artifacts" %in% colnames(colData(spe))) 
          sum(!colData(spe)$artifacts, na.rm = TRUE) else 0
      )
      
      saveRDS(qc_summary, file.path(body$output_dir, "qc_summary.rds"))
      
      # Return summary
      success_response(response, list(
        total_spots = qc_summary$total_spots,
        total_outliers = qc_summary$outliers$total,
        n_artifacts = qc_summary$artifacts,
        outlier_columns = qc_summary$outliers$columns,
        output_directory = body$output_dir,
        files_created = c("qc_results.rds", "qc_summary.rds")
      ))
      
    }, error = function(e) {
      error_response(response, e$message)
    })
  }
)

# Create backend and start server
backend <- BackendRserve$new()
cat(sprintf("Starting %s on port %s...\n", SERVICE_NAME, API_PORT))
cat(sprintf("R version: %s\n", R.version.string))
cat(sprintf("SpotSweeper version: %s\n", as.character(packageVersion("SpotSweeper"))))
backend$start(app, http_port = API_PORT)