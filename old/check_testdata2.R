# Check the characteristics of testdata_SpotSweeper2.rds
library(SpatialExperiment)

# Load the test data
spe <- readRDS("testdata_SpotSweeper2.rds")

cat("=== Test Data 2 Characteristics ===\n")
cat("Class:", class(spe), "\n")
cat("Dimensions:", dim(spe), "\n")

# Check rowData columns
cat("\n=== rowData columns ===\n")
row_cols <- colnames(rowData(spe))
cat("Available columns:", paste(row_cols, collapse=", "), "\n")

# Check if there's a gene_name column
if ("gene_name" %in% row_cols) {
  cat("\n✓ Found 'gene_name' column!\n")
  
  # Check for mitochondrial genes in gene_name column
  gene_names <- rowData(spe)$gene_name
  human_mito <- grep("^MT-", gene_names, value = TRUE)
  mouse_mito <- grep("^Mt-", gene_names, value = TRUE)
  
  cat("\nMitochondrial genes in gene_name column:\n")
  cat("- Human pattern (^MT-):", length(human_mito), "genes\n")
  if (length(human_mito) > 0) {
    cat("  Examples:", paste(head(human_mito, 5), collapse=", "), "\n")
  }
  
  cat("- Mouse pattern (^Mt-):", length(mouse_mito), "genes\n")
  if (length(mouse_mito) > 0) {
    cat("  Examples:", paste(head(mouse_mito, 5), collapse=", "), "\n")
  }
}

# Check if there's a symbol column
if ("symbol" %in% row_cols) {
  cat("\n✓ Found 'symbol' column!\n")
  
  # Check for mitochondrial genes in symbol column
  symbols <- rowData(spe)$symbol
  human_mito_sym <- grep("^MT-", symbols, value = TRUE)
  mouse_mito_sym <- grep("^Mt-", symbols, value = TRUE)
  
  cat("\nMitochondrial genes in symbol column:\n")
  cat("- Human pattern (^MT-):", length(human_mito_sym), "genes\n")
  cat("- Mouse pattern (^Mt-):", length(mouse_mito_sym), "genes\n")
}

# Show first few entries of both columns if they exist
cat("\n=== Sample gene identifiers ===\n")
if ("gene_name" %in% row_cols) {
  cat("First 10 gene_name entries:\n")
  print(head(rowData(spe)$gene_name, 10))
}

if ("symbol" %in% row_cols) {
  cat("\nFirst 10 symbol entries:\n")
  print(head(rowData(spe)$symbol, 10))
}