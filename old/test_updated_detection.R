# Test updated gene symbol detection
library(SpatialExperiment)
library(scuttle)

# Updated detect_and_set_gene_symbols function
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
        
        # First, look for a gene symbol column for mitochondrial detection
        # This can have duplicates - we'll store it for mito detection
        for (col in gene_symbol_columns) {
            if (col %in% available_cols) {
                gene_symbols <- rowData(spe)[[col]]
                if (!is.null(gene_symbols) && !all(is.na(gene_symbols))) {
                    # Store the gene symbol column for mitochondrial detection
                    metadata(spe)$gene_symbol_column <- col
                    cat(sprintf("Found gene symbols in column '%s' for mitochondrial detection\n", col))
                    
                    # Only set as rownames if unique
                    if (length(unique(gene_symbols)) == length(gene_symbols)) {
                        rownames(spe) <- gene_symbols
                        cat(sprintf("Set gene symbols from column '%s' as rownames\n", col))
                        return(spe)
                    } else {
                        cat(sprintf("Column '%s' contains duplicates, keeping original rownames\n", col))
                        # Don't set as rownames, but keep the metadata for mito detection
                        return(spe)
                    }
                }
            }
        }
        
        # If no gene symbol column found, check for gene_id
        if ("gene_id" %in% available_cols || "ensembl_id" %in% available_cols) {
            id_col <- if("gene_id" %in% available_cols) "gene_id" else "ensembl_id"
            gene_ids <- rowData(spe)[[id_col]]
            if (!is.null(gene_ids) && !all(is.na(gene_ids)) && 
                length(unique(gene_ids)) == length(gene_ids)) {
                rownames(spe) <- gene_ids
                cat(sprintf("Set gene IDs from column '%s' as rownames\n", id_col))
            }
        }
        
        if (is.null(metadata(spe)$gene_symbol_column)) {
            cat("No gene symbol column found for mitochondrial detection\n")
        }
    }
    
    return(spe)
}

# Load test data
cat("Loading test data...\n")
spe <- readRDS("testdata_SpotSweeper2.rds")

cat("\n=== Before detection ===\n")
cat("First 5 rownames: ", head(rownames(spe), 5), "\n")
cat("rowData columns: ", colnames(rowData(spe)), "\n")

# Test gene symbol detection
cat("\n=== Running gene symbol detection ===\n")
spe_updated <- detect_and_set_gene_symbols(spe)

cat("\n=== After detection ===\n")
cat("First 5 rownames: ", head(rownames(spe_updated), 5), "\n")
cat("Gene symbol column stored: ", metadata(spe_updated)$gene_symbol_column, "\n")

# Test mitochondrial detection using the stored column
cat("\n=== Testing mitochondrial gene detection ===\n")
if (!is.null(metadata(spe_updated)$gene_symbol_column)) {
    gene_names <- rowData(spe_updated)[[metadata(spe_updated)$gene_symbol_column]]
    cat("Using gene names from column:", metadata(spe_updated)$gene_symbol_column, "\n")
} else {
    gene_names <- rownames(spe_updated)
    cat("Using rownames for gene detection\n")
}

# Check for mitochondrial genes
human_mito <- grep("^MT-", gene_names, value = TRUE)
mouse_mito <- grep("^Mt-", gene_names, value = TRUE)

cat("\nHuman mitochondrial genes (^MT-): ", length(human_mito), "\n")
if (length(human_mito) > 0) {
  cat("Examples: ", head(human_mito, 5), "\n")
}

# Test QC metrics calculation
cat("\n=== Testing QC metrics calculation ===\n")
mito_string <- "^MT-"
is_mito <- grepl(mito_string, gene_names)
cat("Number of mitochondrial genes identified: ", sum(is_mito), "\n")

# Add QC metrics
spe_updated <- scuttle::addPerCellQCMetrics(spe_updated, subsets = list(mito = is_mito))

# Check results
qc_data <- colData(spe_updated)
cat("\nMitochondrial percentage statistics:\n")
cat("Mean: ", round(mean(qc_data$subsets_mito_percent), 2), "%\n")
cat("Median: ", round(median(qc_data$subsets_mito_percent), 2), "%\n")
cat("Max: ", round(max(qc_data$subsets_mito_percent), 2), "%\n")