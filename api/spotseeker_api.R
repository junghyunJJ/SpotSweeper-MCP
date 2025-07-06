# SpotSweeper REST API Server using RestRserve
# High-performance production-ready R API

library(RestRserve)
library(SpotSweeper)
library(jsonlite)

# Create application
app <- Application$new()

# Add middleware for CORS and logging
app$add_middleware(
  Middleware$new(
    process_request = function(request, response) {
      cat(sprintf("%s %s %s\n", 
                  Sys.time(), 
                  request$method, 
                  request$path))
    },
    process_response = function(request, response) {
      response$set_header("Access-Control-Allow-Origin", "*")
      response$set_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      response$set_header("Access-Control-Allow-Headers", "Content-Type")
    }
  )
)

# Health check endpoint
app$add_get(
  path = "/health",
  FUN = function(request, response) {
    response$set_content_type("application/json")
    response$set_body(toJSON(list(
      status = "healthy",
      service = "SpotSweeper API",
      version = "1.0.0",
      timestamp = as.character(Sys.time())
    ), auto_unbox = TRUE))
  }
)

# Detect outliers endpoint
app$add_post(
  path = "/api/detect-outliers",
  FUN = function(request, response) {
    tryCatch({
      # Parse request body
      body <- fromJSON(request$body)
      
      # Validate required parameters
      if (is.null(body$data_path)) {
        response$set_status_code(400)
        response$set_body(toJSON(list(error = "data_path is required")))
        return(response)
      }
      
      # Load data
      if (endsWith(body$data_path, ".rds")) {
        data <- readRDS(body$data_path)
      } else if (endsWith(body$data_path, ".csv")) {
        data <- read.csv(body$data_path)
      } else {
        response$set_status_code(400)
        response$set_body(toJSON(list(error = "Unsupported file format")))
        return(response)
      }
      
      # Run outlier detection
      results <- SpotSweeper::detectLocalOutliers(
        data,
        threshold = body$threshold %||% 3.0,
        metric = body$metric %||% "count"
      )
      
      # Save results if output path provided
      if (!is.null(body$output_path)) {
        saveRDS(results, body$output_path)
      }
      
      # Return results
      response$set_content_type("application/json")
      response$set_body(toJSON(list(
        success = TRUE,
        n_outliers = sum(results$is_outlier),
        total_spots = length(results$is_outlier),
        outlier_percentage = round(sum(results$is_outlier) / length(results$is_outlier) * 100, 2),
        threshold_used = body$threshold %||% 3.0,
        metric_used = body$metric %||% "count",
        output_saved = body$output_path
      ), auto_unbox = TRUE))
      
    }, error = function(e) {
      response$set_status_code(500)
      response$set_content_type("application/json")
      response$set_body(toJSON(list(
        success = FALSE,
        error = e$message
      ), auto_unbox = TRUE))
    })
  }
)

# Detect artifacts endpoint
app$add_post(
  path = "/api/detect-artifacts",
  FUN = function(request, response) {
    tryCatch({
      body <- fromJSON(request$body)
      
      # Load data
      data <- readRDS(body$data_path)
      
      # Detect artifacts
      artifacts <- SpotSweeper::detectArtifacts(
        data,
        type = body$artifact_type %||% "all",
        min_region_size = body$min_region_size %||% 10
      )
      
      # Save if requested
      if (!is.null(body$output_path)) {
        saveRDS(artifacts, body$output_path)
      }
      
      # Return results
      response$set_content_type("application/json")
      response$set_body(toJSON(list(
        success = TRUE,
        n_artifacts = length(artifacts$artifact_regions),
        affected_spots = sum(artifacts$is_artifact),
        artifact_type = body$artifact_type %||% "all",
        min_region_size = body$min_region_size %||% 10,
        output_saved = body$output_path
      ), auto_unbox = TRUE))
      
    }, error = function(e) {
      response$set_status_code(500)
      response$set_content_type("application/json")
      response$set_body(toJSON(list(
        success = FALSE,
        error = e$message
      ), auto_unbox = TRUE))
    })
  }
)

# QC pipeline endpoint
app$add_post(
  path = "/api/run-qc",
  FUN = function(request, response) {
    tryCatch({
      body <- fromJSON(request$body)
      
      # Create output directory
      dir.create(body$output_dir, recursive = TRUE, showWarnings = FALSE)
      
      # Load data
      data <- readRDS(body$data_path)
      
      # Run QC pipeline
      qc_results <- SpotSweeper::runQCPipeline(
        data,
        metrics = body$qc_metrics %||% c("counts", "genes", "mitochondrial"),
        outlier_threshold = body$outlier_threshold %||% 3.0,
        detect_artifacts = body$detect_artifacts %||% TRUE
      )
      
      # Save results
      saveRDS(qc_results, file.path(body$output_dir, "qc_results.rds"))
      
      # Return summary
      response$set_content_type("application/json")
      response$set_body(toJSON(list(
        success = TRUE,
        total_spots = nrow(qc_results$metadata),
        n_outliers = sum(qc_results$outliers),
        n_artifacts = if(!is.null(qc_results$artifacts)) sum(qc_results$artifacts) else 0,
        qc_metrics_calculated = body$qc_metrics %||% c("counts", "genes", "mitochondrial"),
        output_directory = body$output_dir,
        files_created = list("qc_results.rds")
      ), auto_unbox = TRUE))
      
    }, error = function(e) {
      response$set_status_code(500)
      response$set_content_type("application/json")
      response$set_body(toJSON(list(
        success = FALSE,
        error = e$message
      ), auto_unbox = TRUE))
    })
  }
)

# Create backend
backend <- BackendRserve$new()

# Start server
cat("Starting SpotSweeper API server on port 8080...\n")
backend$start(app, http_port = 8080)