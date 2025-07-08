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

cat("\n9. Starting server...\n")
backend$start(app, http_port = API_PORT)