# Debug script to find the exact error

cat("Starting debug script...\n")

cat("\n1. Loading libraries...\n")
library(RestRserve)
library(jsonlite)
library(SpotSweeper)
library(SpatialExperiment)
library(scuttle)
library(SingleCellExperiment)
cat("✓ All libraries loaded\n")

cat("\n2. Setting configuration...\n")
API_PORT <- 8081
API_VERSION <- "1.0.0"
SERVICE_NAME <- "SpotSeeker R API"
cat("✓ Configuration set\n")

cat("\n3. Defining helper functions...\n")
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
cat("✓ Helper functions defined\n")

cat("\n4. Creating application...\n")
app <- Application$new()
cat("✓ Application created\n")

cat("\n5. Adding middleware...\n")
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
cat("✓ Middleware added\n")

cat("\n6. Adding health endpoint...\n")
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
cat("✓ Health endpoint added\n")

cat("\n7. Creating backend...\n")
backend <- BackendRserve$new()
cat("✓ Backend created\n")

cat("\n8. Printing server info...\n")
cat(sprintf("Starting %s on port %s...\n", SERVICE_NAME, API_PORT))
cat(sprintf("R version: %s\n", R.version.string))
cat(sprintf("SpotSweeper version: %s\n", as.character(packageVersion("SpotSweeper"))))

cat("\n9. Defining inner analysis functions...\n")

#######################################################
### Inner Analysis Functions ##########################
#######################################################

# Inner function for calculate-qc-metrics
_inner_calculate_qc_metrics <- function(spe, mito_string = NULL, species = "auto") {
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
  }
  
  # Look for gene symbols
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
  
  # Calculate mitochondrial genes
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
_inner_local_outliers <- function(spe, run_all_metrics = TRUE, 
                                 metric = "sum", direction = "lower", 
                                 log_transform = TRUE) {
  
  if (run_all_metrics) {
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
    
    # Combine all outliers
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
    
  } else {
    # Single metric mode
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
    
    return(list(
      spe = spe,
      results = list(
        n_outliers = n_outliers,
        total_spots = total_spots,
        outlier_percentage = round(n_outliers / total_spots * 100, 2),
        metric_used = metric,
        direction_used = direction,
        log_transform = log_transform,
        outlier_column = outlier_col
      )
    ))
  }
}

# Inner function for find-artifacts
_inner_find_artifacts <- function(spe, mito_percent = "subsets_mito_percent",
                                 mito_sum = "subsets_mito_sum", 
                                 n_order = 5, name = "artifacts") {
  
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
  
  return(list(
    spe = spe,
    results = list(
      n_artifacts = n_artifacts,
      total_spots = total_spots,
      artifact_percentage = round(n_artifacts / total_spots * 100, 2),
      mito_percent_col = mito_percent,
      mito_sum_col = mito_sum,
      n_order = n_order,
      artifact_column = name
    )
  ))
}

cat("✓ Inner analysis functions defined\n")

cat("\n10. Starting server...\n")
backend$start(app, http_port = API_PORT)