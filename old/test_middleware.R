library(RestRserve)

# Test different middleware approaches
cat("Testing middleware approaches...\n")

app <- Application$new()

# Approach 1: Direct function
cat("\nTrying approach 1: Direct functions\n")
tryCatch({
  app$add_middleware(
    process_request = function(request, response) {
      cat("Request middleware\n")
    },
    process_response = function(request, response) {
      cat("Response middleware\n")
    }
  )
  cat("✓ Approach 1 successful\n")
}, error = function(e) {
  cat("✗ Approach 1 failed:", e$message, "\n")
})

# Approach 2: Function that returns middleware
cat("\nTrying approach 2: Middleware function\n")
tryCatch({
  app2 <- Application$new()
  
  cors_middleware <- function() {
    list(
      process_request = function(request, response) {
        cat("Request middleware\n")
      },
      process_response = function(request, response) {
        response$set_header("Access-Control-Allow-Origin", "*")
      }
    )
  }
  
  app2$add_middleware(cors_middleware())
  cat("✓ Approach 2 successful\n")
}, error = function(e) {
  cat("✗ Approach 2 failed:", e$message, "\n")
})

# Approach 3: No middleware
cat("\nTrying approach 3: No middleware\n")
tryCatch({
  app3 <- Application$new()
  
  app3$add_get(
    path = "/test",
    FUN = function(request, response) {
      response$set_content_type("text/plain")
      response$set_body("Test")
    }
  )
  cat("✓ Approach 3 successful\n")
}, error = function(e) {
  cat("✗ Approach 3 failed:", e$message, "\n")
})