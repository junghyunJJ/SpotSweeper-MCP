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
