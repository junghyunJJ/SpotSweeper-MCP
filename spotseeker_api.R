# SpotSeeker REST API Server for MCP Bridge
# Provides SpotSweeper functionality through RestRserve

# Fix for macOS fork() error with graphics devices
Sys.setenv(OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES")

library(RestRserve)
library(jsonlite)
library(SpotSweeper)
library(SpatialExperiment)
library(scuttle)
library(SingleCellExperiment)
library(ggplot2)
library(cowplot)
library(reticulate)
library(anndata)

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

#######################################################
### Inner Analysis Functions ##########################
#######################################################

# Inner function for calculate-qc-metrics
.inner_calculate_qc_metrics <- function(spe, species = "auto") {
  
  # Look for gene symbols
  gene_symbol_columns <- c(
    "symbol", "Symbol", "SYMBOL",
    "gene_name", "gene_symbol", "gene.name", "Gene.name",
    "feature_name", "feature", "gene",
    "hgnc_symbol", "mgi_symbol"
  )
  
  gene_names <- NULL
  gene_col_used <- NULL

  # 1. Determine the gene syombol column
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
  
  
  # 2. Determine species for Mitochondria detection
  if (species == "human") {
    mito_string <- "^MT-"
  } else if (species == "mouse") {
    mito_string <- "^Mt-"
  } else if (species == "auto") {
    # Auto-detect based on gene names in rownames
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
        mito_string <- "^MT-"
        cat("Both human and mouse patterns found, defaulting to human (^MT-)\n")
      } else {
        mito_string <- "^MT-"
        cat("No mitochondrial genes detected, defaulting to human pattern (^MT-)\n")
      }
    } else {
      mito_string <- "^MT-"
      cat("No gene names available, defaulting to human pattern (^MT-)\n")
    }
  } else {
    mito_string <- "^MT-"
  }
  
  
  # 3. Calculate mitochondrial genes
  if (!is.null(gene_names) && length(gene_names) > 0) {
    is_mito <- grepl(mito_string, gene_names)
    cat(sprintf("Found %d mitochondrial genes using pattern '%s'\n", sum(is_mito), mito_string))
  } else {
    warning("No gene names available for mitochondrial detection")
    is_mito <- rep(FALSE, nrow(spe))
  }
  
  # Add QC metrics
  spe <- scuttle::addPerCellQCMetrics(spe, subsets = list(mito = is_mito))
  
  # Get summary statistics
  qc_data <- colData(spe)
  
  # Return results
  return(list(
    spe = spe,
    results = list(
      total_spots = ncol(spe),
      mean_umi_count = mean(qc_data$sum),
      median_umi_count = median(qc_data$sum),
      mean_gene_count = mean(qc_data$detected),
      median_gene_count = median(qc_data$detected),
      mean_mito_percent = mean(qc_data$subsets_mito_percent),
      median_mito_percent = median(qc_data$subsets_mito_percent),
      qc_columns_added = c("sum", "detected", "subsets_mito_percent", "subsets_mito_sum"),
      mito_pattern_used = mito_string,
      gene_symbol_column = if(!is.null(gene_col_used)) gene_col_used else "none"
    )
  ))
}

# Inner function for local-outliers
.inner_local_outliers <- function(spe) {
  
  # Run all 3 metrics
    
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
    spe <- localOutliers(spe,
      metric = "subsets_mito_percent",
      direction = "higher",
      log = FALSE
    )
    
    # Combine all outliers
    spe$local_outliers <- as.logical(spe$sum_outliers) |
      as.logical(spe$detected_outliers) |
      as.logical(spe$subsets_mito_percent_outliers)
    
    
    # Get detailed results
    outlier_details <- list()
    outlier_columns <- c("sum_outliers", "detected_outliers", "subsets_mito_percent_outliers")
    for (col in outlier_columns) {
      if (col %in% colnames(colData(spe))) {
        outlier_details[[col]] <- sum(colData(spe)[[col]], na.rm = TRUE)
      }
    }
    
    # Total combined outliers
    n_outliers <- sum(colData(spe)$local_outliers, na.rm = TRUE)
    total_spots <- ncol(spe)
    
    return(list(
      spe = spe,
      results = list(
        n_outliers = n_outliers,
        total_spots = total_spots,
        outlier_percentage = round(n_outliers / total_spots * 100, 2),
        outlier_details = outlier_details,
        outlier_columns = outlier_columns,
        combined_column = "local_outliers"
      )
    ))
}

# Inner function for find-artifacts
.inner_find_artifacts <- function(spe, n_order = 5) {
  
  # Find artifacts
  spe <- findArtifacts(
    spe = spe,
    mito_percent = "subsets_mito_percent",
    mito_sum = "subsets_mito_sum",
    n_order = n_order,
    name = "artifact"
  )
  
  # Get artifact results
  artifact_status <- colData(spe)[["artifact"]]
  n_artifacts <- sum(artifact_status, na.rm = TRUE)  # TRUE indicates artifact
  total_spots <- length(artifact_status)
  
  return(list(
    spe = spe,
    results = list(
      n_artifacts = n_artifacts,
      total_spots = total_spots,
      artifact_percentage = round(n_artifacts / total_spots * 100, 2),
      mito_percent_col = "subsets_mito_percent",
      mito_sum_col = "subsets_mito_sum",
      n_order = n_order,
      artifact_column = "artifact"
    )
  ))
}

.inner_res_plot <- function(spe) {
  gg1 <- plotQCmetrics(spe,
    metric = "subsets_mito_percent",
    outliers = NULL, point_size = 1.1
  ) +
    ggtitle("Mitochondrial Percent")

  # all local outliers
  gg2 <- plotQCmetrics(spe,
    metric = "sum_log", outliers = "local_outliers",
    point_size = 1.1
  ) +
    ggtitle("Local Outliers")


  gg3 <- plotQCmetrics(spe,
    metric = "subsets_mito_percent",
    outliers = "artifact", point_size = 1.1
  ) +
    ggtitle("Artifact")

  cowplot::plot_grid(gg1, gg2, gg3, ncol = 3)
}

#######################################################
### Set Functions #####################################
#######################################################

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
      
      # Get parameters
      species <- if(is.null(body$species)) "auto" else body$species
      
      # Call inner function
      result <- .inner_calculate_qc_metrics(
        spe = spe,
        species = species
      )
      
      # Update spe
      spe <- result$spe
      
      # Save if requested
      if (!is.null(body$output_path)) {
        saveRDS(spe, body$output_path)
      }
      
      # Return results
      success_response(response, c(result$results, list(output_saved = body$output_path)))
      
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
      
      # Get parameters
      species <- if(is.null(body$species)) "auto" else body$species
      
      # Step 1: Calculate QC metrics
      res_qc <- .inner_calculate_qc_metrics(spe = spe, species = species)
      spe <- res_qc$spe
  
      # Step 2: Run local outlier detection for multiple metrics
      res_local_outliers <- .inner_local_outliers(spe = spe)
      spe <- res_local_outliers$spe

      # Step 3: Find artifacts if requested
      res_find_artifacts <- .inner_find_artifacts(spe = spe)
      spe <- res_find_artifacts$spe

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
        local_outliers = list(
          n_local_outliers = res_local_outliers$results$n_outliers,
          outlier_percentage = res_local_outliers$results$outlier_percentage
        ),
        artifacts = list(
          n_artifacts = res_find_artifacts$results$n_artifacts,
          artifact_percentage = res_find_artifacts$results$artifact_percentage
        )
      )
   
      saveRDS(qc_summary, file.path(body$output_dir, "qc_summary.rds"))

      # Calculate filtered data (for summary stats)
      f_spe <- spe[,(colData(spe)$local_outliers + colData(spe)$artifact) == 0]
      # Optionally save clean data
      # saveRDS(f_spe, file.path(body$output_dir, "clean_data.rds"))

      # Convert to AnnData and save as h5ad
      adata <- anndata::AnnData(
        X = t(assay(spe)),  # Transpose to have cells as rows
        obs = as.data.frame(colData(spe)),
        var = as.data.frame(rowData(spe))
      )
      anndata::write_h5ad(adata, file.path(body$output_dir, "qc_results.h5ad"))
      # # Create plot (disabled due to macOS fork issues)
      # # Uncomment the following lines if you want to generate plots
      # # Note: This may cause fork() errors on macOS
      # gg_plot <- .inner_res_plot(spe)
      # 
      # png(filename = file.path(body$output_dir, "res_plot.png"),
      #     width = 12, 
      #     height = 4, 
      #     units = "in", 
      #     res = 300)
      # print(gg_plot)  # Fixed: added print()
      # dev.off()

      # Return summary
      success_response(response, list(
        total_spots = qc_summary$total_spots,
        filtered_local_outliers = qc_summary$local_outliers$n_local_outliers,
        filtered_artifacts = qc_summary$artifacts$n_artifacts,
        tot_filtered_spot = ncol(spe) - ncol(f_spe),
        output_directory = body$output_dir,
        files_created = c("qc_results.rds", "qc_summary.rds", "qc_results.h5ad")
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