# Check gene names in detail
library(SpatialExperiment)

spe <- readRDS("testdata_SpotSweeper2.rds")

# Check gene_name column
gene_names <- rowData(spe)$gene_name
cat("Total genes:", length(gene_names), "\n")
cat("Unique gene names:", length(unique(gene_names)), "\n")
cat("NAs in gene names:", sum(is.na(gene_names)), "\n")

# Check duplicates
duplicated_names <- gene_names[duplicated(gene_names) & !is.na(gene_names)]
cat("\nNumber of duplicated gene names:", length(unique(duplicated_names)), "\n")

# Show some examples
cat("\nExamples of duplicated gene names:\n")
print(head(unique(duplicated_names), 10))

# Check mitochondrial genes in gene_name column
mito_genes <- gene_names[grep("^MT-", gene_names)]
cat("\nMitochondrial genes found in gene_name column:\n")
print(mito_genes)

# Since gene_name has duplicates, let's check if we can create unique IDs
# by combining gene_id and gene_name
cat("\n=== Creating unique identifiers ===\n")
gene_ids <- rowData(spe)$gene_id
unique_ids <- paste(gene_ids, gene_names, sep="_")
cat("Using gene_id_gene_name combination:\n")
cat("Total IDs:", length(unique_ids), "\n")
cat("Unique IDs:", length(unique(unique_ids)), "\n")

# Alternative: Use gene_name where available, fallback to gene_id
cat("\n=== Using gene_name with gene_id fallback ===\n")
final_names <- ifelse(!is.na(gene_names), gene_names, gene_ids)
cat("Total names:", length(final_names), "\n")
cat("Unique names:", length(unique(final_names)), "\n")

# Check for mito genes in final names
mito_final <- final_names[grep("^MT-", final_names)]
cat("\nMitochondrial genes in final names:", length(mito_final), "\n")
if (length(mito_final) > 0) {
  cat("Examples:\n")
  print(head(mito_final))