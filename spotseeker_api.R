# SpotSeeker REST API Server for MCP Bridge
# Provides SpotSweeper functionality through RestRserve

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

# Add CORS headers to each response
add_cors_headers <- function(response) {
  response$set_header("Access-Control-Allow-Origin", "*")
  response$set_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  response$set_header("Access-Control-Allow-Headers", "Content-Type")
}

# Log requests manually
log_request <- function(request) {
  cat(sprintf("%s %s %s\n", 
              Sys.time(), 
              request$method, 
              request$path))
}

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
    add_cors_headers(response)
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
    add_cors_headers(response)
    response$set_content_type("application/json")
    response$set_body(toJSON(c(
        list(
            success = TRUE,
            timestamp = as.character(Sys.time())
        ),
        data
    ), auto_unbox = TRUE))
}

# Helper function to detect and set gene symbols as rownames
detect_and_set_gene_symbols <- function(spe) {
    # Common gene symbol column names in priority order
    gene_symbol_columns <- c(
        "symbol", "Symbol", "SYMBOL",
        "gene_name", "gene_symbol", "gene.name", "Gene.name",
        "feature_name", "feature", "gene",
        "hgnc_symbol", "mgi_symbol"
    )
    
    # Check if rowData exists and has columns
    if (!is.null(rowData(spe)) && ncol(rowData(spe)) > 0) {
        available_cols <- colnames(rowData(spe))
        
        # First, look for a gene symbol column
        for (col in gene_symbol_columns) {
            if (col %in% available_cols) {
                gene_symbols <- rowData(spe)[[col]]
                if (!is.null(gene_symbols) && !all(is.na(gene_symbols))) {
                    cat(sprintf("Found gene symbols in column '%s'\n", col))
                    
                    # Only set as rownames if unique
                    if (length(unique(gene_symbols)) == length(gene_symbols)) {
                        rownames(spe) <- gene_symbols
                        cat(sprintf("Set gene symbols from column '%s' as rownames\n", col))
                        break
                    } else {
                        cat(sprintf("Column '%s' contains duplicates, checking for unique ID columns\n", col))
                    }
                }
            }
        }
        
        # If no gene symbols set as rownames, try gene_id or ensembl_id
        current_rownames <- rownames(spe)
        if (is.null(current_rownames) || all(current_rownames == as.character(seq_len(nrow(spe))))) {
            if ("gene_id" %in% available_cols || "ensembl_id" %in% available_cols) {
                id_col <- if("gene_id" %in% available_cols) "gene_id" else "ensembl_id"
                gene_ids <- rowData(spe)[[id_col]]
                if (!is.null(gene_ids) && !all(is.na(gene_ids)) && 
                    length(unique(gene_ids)) == length(gene_ids)) {
                    rownames(spe) <- gene_ids
                    cat(sprintf("Set gene IDs from column '%s' as rownames\n", id_col))
                }
            }
        }
    }
    
    return(spe)
}

# Create application
app <- Application$new()

# Health check endpoint
app$add_get(
  path = "/health",
  FUN = function(request, response) {
    log_request(request)
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

#######################################################
### Functions #########################################
#######################################################

# Local outliers endpoint
app$add_post(
  path = "/api/local-outliers",
  FUN = function(request, response) {
    log_request(request)
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
      run_all_metrics <- if(is.null(body$run_all_metrics)) TRUE else body$run_all_metrics
      
      if (run_all_metrics) {
        # Run all 3 metrics as specified
        
        # 1. Library size (sum)
        spe <- localOutliers(
          spe = spe,
          metric = "sum",
          direction = "lower",
          log = TRUE
        )
        
        # 2. Unique genes (detected)
        spe <- localOutliers(
          spe = spe,
          metric = "detected",
          direction = "lower",
          log = TRUE
        )
        
        # 3. Mitochondrial percent
        # Check if mito percent column exists
        mito_col <- if("subsets_mito_percent" %in% colnames(colData(spe))) {
          "subsets_mito_percent"
        } else if("subsets_Mito_percent" %in% colnames(colData(spe))) {
          "subsets_Mito_percent"
        } else {
          NULL
        }
        
        if (!is.null(mito_col)) {
          spe <- localOutliers(
            spe = spe,
            metric = mito_col,
            direction = "higher",
            log = FALSE
          )
        } else {
          warning("No mitochondrial percent column found. Skipping mito outlier detection.")
        }
        
        # Combine all outliers into local_outliers column
        # Using the exact pattern from the user's request
        if (!is.null(mito_col)) {
          colData(spe)$local_outliers <- as.logical(colData(spe)$log_sum_lower_outliers) |
            as.logical(colData(spe)$log_detected_lower_outliers) |
            as.logical(colData(spe)[[paste0(mito_col, "_higher_outliers")]])
          
          outlier_columns <- c("log_sum_lower_outliers", "log_detected_lower_outliers", 
                              paste0(mito_col, "_higher_outliers"))
        } else {
          colData(spe)$local_outliers <- as.logical(colData(spe)$log_sum_lower_outliers) |
            as.logical(colData(spe)$log_detected_lower_outliers)
          
          outlier_columns <- c("log_sum_lower_outliers", "log_detected_lower_outliers")
        }
        
        # Get detailed results
        outlier_details <- list()
        for (col in outlier_columns) {
          if (col %in% colnames(colData(spe))) {
            outlier_details[[col]] <- sum(colData(spe)[[col]], na.rm = TRUE)
          }
        }
        
        # Total combined outliers
        n_outliers <- sum(colData(spe)$local_outliers, na.rm = TRUE)
        total_spots <- ncol(spe)
        
        # Save results if output path provided
        if (!is.null(body$output_path)) {
          saveRDS(spe, body$output_path)
        }
        
        # Return comprehensive results
        success_response(response, list(
          n_outliers = n_outliers,
          total_spots = total_spots,
          outlier_percentage = round(n_outliers / total_spots * 100, 2),
          outlier_details = outlier_details,
          outlier_columns = outlier_columns,
          combined_column = "local_outliers",
          output_saved = body$output_path
        ))
        
      } else {
        # Original single metric mode
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
      }
      
    }, error = function(e) {
      error_response(response, e$message)
    })
  }
)

# Find artifacts endpoint
app$add_post(
  path = "/api/find-artifacts",
  FUN = function(request, response) {
    log_request(request)
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
    log_request(request)
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
      
      # # Detect and set gene symbols as rownames
      # spe <- detect_and_set_gene_symbols(spe)
      
      # Get parameters
      mito_string <- body$mito_string
      species <- if(is.null(body$species)) "auto" else body$species
      
      # Determine mito pattern if not provided
      if (is.null(mito_string)) {
        if (species == "human") {
          mito_string <- "^MT-"
        } else if (species == "mouse") {
          mito_string <- "^Mt-"
        } else if (species == "auto") {
          # Auto-detect based on gene names in rownames
          gene_names <- rownames(spe)
          if (!is.null(gene_names) && length(gene_names) > 0) {
            has_human_mito <- any(grepl("^MT-", gene_names))
            has_mouse_mito <- any(grepl("^Mt-", gene_names))
            
            if (has_human_mito && !has_mouse_mito) {
              mito_string <- "^MT-"
              cat("Auto-detected human mitochondrial genes (^MT-)\n")
            } else if (has_mouse_mito && !has_human_mito) {
              mito_string <- "^Mt-"
              cat("Auto-detected mouse mitochondrial genes (^Mt-)\n")
            } else if (has_human_mito && has_mouse_mito) {
              # Default to human if both patterns found
              mito_string <- "^MT-"
              cat("Both human and mouse patterns found, defaulting to human (^MT-)\n")
            } else {
              # Default to human if no mito genes found
              mito_string <- "^MT-"
              cat("No mitochondrial genes detected, defaulting to human pattern (^MT-)\n")
            }
          } else {
            # Default to human if no rownames
            mito_string <- "^MT-"
            cat("No gene names available, defaulting to human pattern (^MT-)\n")
          }
        } else {
          # Default to human
          mito_string <- "^MT-"
        }
      }
      
      # Calculate QC metrics using scuttle
      # Look for gene symbols directly in rowData columns
      gene_symbol_columns <- c(
        "symbol", "Symbol", "SYMBOL",
        "gene_name", "gene_symbol", "gene.name", "Gene.name",
        "feature_name", "feature", "gene",
        "hgnc_symbol", "mgi_symbol"
      )
      
      gene_names <- NULL
      gene_col_used <- NULL
      
      # First try rownames
      if (!is.null(rownames(spe)) && length(rownames(spe)) > 0 && 
          any(grepl("^MT-|^Mt-", rownames(spe)))) {
        gene_names <- rownames(spe)
        gene_col_used <- "rownames"
      } else if (!is.null(rowData(spe)) && ncol(rowData(spe)) > 0) {
        # Search for gene symbol column
        available_cols <- colnames(rowData(spe))
        for (col in gene_symbol_columns) {
          if (col %in% available_cols) {
            candidate_genes <- rowData(spe)[[col]]
            if (!is.null(candidate_genes) && !all(is.na(candidate_genes)) &&
                any(grepl("^MT-|^Mt-", candidate_genes))) {
              gene_names <- candidate_genes
              gene_col_used <- col
              cat(sprintf("Using gene symbols from column '%s' for mitochondrial detection\n", col))
              break
            }
          }
        }
      }
      
      if (!is.null(gene_names) && length(gene_names) > 0) {
        is_mito <- grepl(mito_string, gene_names)
        cat(sprintf("Found %d mitochondrial genes using pattern '%s'\n", sum(is_mito), mito_string))
      } else {
        warning("No gene names available for mitochondrial detection")
        is_mito <- rep(FALSE, nrow(spe))
      }
      spe <- scuttle::addPerCellQCMetrics(spe, subsets = list(mito = is_mito))
      
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
        mito_pattern_used = mito_string,
        gene_symbol_column = if(!is.null(gene_col_used)) gene_col_used else "none",
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
    log_request(request)
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
      
      # Detect and set gene symbols as rownames
      spe <- detect_and_set_gene_symbols(spe)
      
      # Step 1: Calculate QC metrics if not already present
      if (!"sum" %in% colnames(colData(spe))) {
        mito_string <- body$mito_string
        species <- if(is.null(body$species)) "auto" else body$species
        
        # Determine mito pattern if not provided
        if (is.null(mito_string)) {
          if (species == "human") {
            mito_string <- "^MT-"
          } else if (species == "mouse") {
            mito_string <- "^Mt-"
          } else if (species == "auto") {
            # Auto-detect based on gene names in rownames
            gene_names <- rownames(spe)
            if (!is.null(gene_names) && length(gene_names) > 0) {
              has_human_mito <- any(grepl("^MT-", gene_names))
              has_mouse_mito <- any(grepl("^Mt-", gene_names))
              
              if (has_human_mito && !has_mouse_mito) {
                mito_string <- "^MT-"
              } else if (has_mouse_mito && !has_human_mito) {
                mito_string <- "^Mt-"
              } else {
                # Default to human
                mito_string <- "^MT-"
              }
            } else {
              # Default to human if no rownames
              mito_string <- "^MT-"
            }
          } else {
            # Default to human
            mito_string <- "^MT-"
          }
        }
        
        # Look for gene symbols directly in rowData columns
        gene_symbol_columns <- c(
          "symbol", "Symbol", "SYMBOL",
          "gene_name", "gene_symbol", "gene.name", "Gene.name",
          "feature_name", "feature", "gene",
          "hgnc_symbol", "mgi_symbol"
        )
        
        gene_names <- NULL
        
        # First try rownames
        if (!is.null(rownames(spe)) && length(rownames(spe)) > 0 && 
            any(grepl("^MT-|^Mt-", rownames(spe)))) {
          gene_names <- rownames(spe)
        } else if (!is.null(rowData(spe)) && ncol(rowData(spe)) > 0) {
          # Search for gene symbol column
          available_cols <- colnames(rowData(spe))
          for (col in gene_symbol_columns) {
            if (col %in% available_cols) {
              candidate_genes <- rowData(spe)[[col]]
              if (!is.null(candidate_genes) && !all(is.na(candidate_genes)) &&
                  any(grepl("^MT-|^Mt-", candidate_genes))) {
                gene_names <- candidate_genes
                cat(sprintf("Using gene symbols from column '%s' for mitochondrial detection\n", col))
                break
              }
            }
          }
        }
        
        if (!is.null(gene_names) && length(gene_names) > 0) {
          is_mito <- grepl(mito_string, gene_names)
          cat(sprintf("Found %d mitochondrial genes using pattern '%s'\n", sum(is_mito), mito_string))
        } else {
          warning("No gene names available for mitochondrial detection")
          is_mito <- rep(FALSE, nrow(spe))
        }
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