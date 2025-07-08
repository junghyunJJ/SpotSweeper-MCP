library(RestRserve)
library(jsonlite)

# Create application
app <- Application$new()

# Health check endpoint
app$add_get(
  path = "/health",
  FUN = function(request, response) {
    response$set_content_type("application/json")
    response$set_body(toJSON(list(
      status = "healthy",
      timestamp = as.character(Sys.time())
    ), auto_unbox = TRUE))
  }
)

# Create backend and start server
backend <- BackendRserve$new()
cat("Starting simple test server on port 8082...\n")
backend$start(app, http_port = 8082)