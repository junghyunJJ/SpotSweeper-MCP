# Check the characteristics of testdata_SpotSweeper.rds
library(SpatialExperiment)
library(scuttle)

# Load the test data
spe <- readRDS("testdata_SpotSweeper.rds")

cat("=== Test Data Characteristics ===\n")
cat("Class:", class(spe), "\n")
cat("Dimensions:", dim(spe), "\n")
cat("Number of spots:", ncol(spe), "\n")
cat("Number of genes:", nrow(spe), "\n")

# Check if it has QC metrics
cat("\n=== QC Metrics Present ===\n")
col_names <- colnames(colData(spe))
cat("colData columns:", paste(col_names[1:min(10, length(col_names))], collapse=", "), 
    if(length(col_names) > 10) "..." else "", "\n")

# Check for mitochondrial genes
cat("\n=== Mitochondrial Genes ===\n")
if ("symbol" %in% colnames(rowData(spe))) {
  mito_genes <- grep("^MT-", rowData(spe)$symbol, value = TRUE)
  cat("Number of MT- genes:", length(mito_genes), "\n")
  if (length(mito_genes) > 0) {
    cat("First few:", paste(head(mito_genes, 5), collapse=", "), "\n")
  }
} else {
  cat("No 'symbol' column in rowData\n")
}

# Check if QC metrics are already calculated
if ("sum" %in% col_names) {
  cat("\n=== Existing QC Metrics Summary ===\n")
  cat("Mean UMI count:", mean(colData(spe)$sum), "\n")
  cat("Mean gene count:", mean(colData(spe)$detected), "\n")
  
  if ("subsets_mito_percent" %in% col_names) {
    cat("Mean mito %:", mean(colData(spe)$subsets_mito_percent), "\n")
    cat("Max mito %:", max(colData(spe)$subsets_mito_percent), "\n")
  }
}

# Check spatial coordinates
cat("\n=== Spatial Coordinates ===\n")
if (ncol(spatialCoords(spe)) > 0) {
  cat("Spatial dimensions:", ncol(spatialCoords(spe)), "\n")
  cat("Coordinate columns:", paste(colnames(spatialCoords(spe)), collapse=", "), "\n")
} else {
  cat("No spatial coordinates found\n")
}

# Check for variability in the data
cat("\n=== Data Variability ===\n")
if ("sum" %in% col_names) {
  cat("UMI count range:", range(colData(spe)$sum), "\n")
  cat("UMI count SD:", sd(colData(spe)$sum), "\n")
  cat("Coefficient of variation:", sd(colData(spe)$sum) / mean(colData(spe)$sum), "\n")
}