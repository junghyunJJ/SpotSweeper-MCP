# Test gene symbol detection with testdata_SpotSweeper2.rds
library(SpatialExperiment)
library(scuttle)

# Test the detect_and_set_gene_symbols function
source("spotseeker_api.R", keep.source = TRUE)

# Load test data
cat("Loading test data...\n")
spe <- readRDS("testdata_SpotSweeper2.rds")

cat("\n=== Before detection ===\n")
cat("rownames: ", head(rownames(spe)), "\n")
cat("rowData columns: ", colnames(rowData(spe)), "\n")

# Test gene symbol detection
cat("\n=== Running gene symbol detection ===\n")
spe_updated <- detect_and_set_gene_symbols(spe)

cat("\n=== After detection ===\n")
cat("First 10 rownames: ")
print(head(rownames(spe_updated), 10))

cat("\nGene symbol column used: ", metadata(spe_updated)$gene_symbol_column, "\n")

# Check for mitochondrial genes
cat("\n=== Checking for mitochondrial genes ===\n")
gene_names <- rownames(spe_updated)
human_mito <- grep("^MT-", gene_names, value = TRUE)
mouse_mito <- grep("^Mt-", gene_names, value = TRUE)

cat("Human mitochondrial genes (^MT-): ", length(human_mito), "\n")
if (length(human_mito) > 0) {
  cat("Examples: ", head(human_mito, 5), "\n")
}

cat("Mouse mitochondrial genes (^Mt-): ", length(mouse_mito), "\n")
if (length(mouse_mito) > 0) {
  cat("Examples: ", head(mouse_mito, 5), "\n")
}

# Test QC metrics calculation
cat("\n=== Testing QC metrics calculation ===\n")
mito_string <- "^MT-"  # Assuming human
is_mito <- grepl(mito_string, gene_names)
cat("Number of mitochondrial genes identified: ", sum(is_mito), "\n")

# Add QC metrics
spe_updated <- scuttle::addPerCellQCMetrics(spe_updated, subsets = list(mito = is_mito))

# Check results
qc_data <- colData(spe_updated)
cat("\nMean mitochondrial percentage: ", round(mean(qc_data$subsets_mito_percent), 2), "%\n")
cat("Median mitochondrial percentage: ", round(median(qc_data$subsets_mito_percent), 2), "%\n")