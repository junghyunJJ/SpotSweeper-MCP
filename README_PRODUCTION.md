# SpotSweeper MCP - Production Deployment Guide

## Architecture Options

### 1. Native R MCP (Simple)
- Uses `mcpr` package for native R MCP implementation
- Best for: Simple deployments, R-centric teams
- Run: `Rscript spotseeker_native.R`

### 2. REST API Bridge (Recommended for Production)
- R API server (RestRserve) + Python MCP bridge
- Best for: High performance, scalability, language agnostic
- Benefits:
  - Parallel request handling
  - Better fault isolation
  - Standard HTTP monitoring
  - Horizontal scaling capability

### 3. Docker Deployment (Best for Production)
- Containerized deployment with both services
- Best for: Consistent environments, easy scaling
- Includes health checks and monitoring

## Quick Start

### Option 1: Local Development
```bash
# Terminal 1: Start R API server
Rscript api/spotseeker_api.R

# Terminal 2: Start MCP bridge
python spotseeker_bridge.py
```

### Option 2: Docker Deployment
```bash
# Build and start services
docker-compose up -d

# Check health
curl http://localhost:8080/health

# View logs
docker-compose logs -f
```

### Option 3: Native R MCP
```bash
# Install mcpr package
R -e "install.packages('mcpr')"

# Run native server
Rscript spotseeker_native.R
```

## Performance Comparison

| Method | Requests/sec | Memory Usage | Startup Time | Complexity |
|--------|-------------|--------------|--------------|------------|
| Native R (mcpr) | ~100-200 | Low | Fast | Low |
| rpy2 Bridge | ~200-300 | Medium | Medium | Low |
| REST API (Plumber) | ~100-500 | Medium | Medium | Medium |
| REST API (RestRserve) | ~500-2000 | Low | Fast | Medium |
| Docker + RestRserve | ~500-2000 | Isolated | Slow | High |

## Production Checklist

- [ ] Choose deployment method based on requirements
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure resource limits
- [ ] Set up logging aggregation
- [ ] Implement backup strategy
- [ ] Configure SSL/TLS for APIs
- [ ] Set up load balancing (if needed)
- [ ] Create health check endpoints
- [ ] Document API endpoints
- [ ] Set up CI/CD pipeline

## Monitoring

### Health Check Endpoints
- R API: `http://localhost:8080/health`
- MCP Status: Use `check_server_status` tool

### Recommended Monitoring Stack
1. **Prometheus**: Metrics collection
2. **Grafana**: Visualization
3. **Loki**: Log aggregation
4. **AlertManager**: Alert routing

## Scaling Strategies

### Vertical Scaling
- Increase R memory limits: `R_MAX_MEM_SIZE=8g`
- Use more CPU cores with RestRserve

### Horizontal Scaling
1. Deploy multiple containers
2. Use load balancer (nginx/HAProxy)
3. Share data via NFS/S3
4. Use Redis for session management

## Security Considerations

1. **API Authentication**: Add bearer tokens or API keys
2. **Rate Limiting**: Implement request throttling
3. **Input Validation**: Validate all file paths and parameters
4. **Network Security**: Use VPC/private networks
5. **Data Encryption**: Enable TLS for all communications

## Troubleshooting

### Common Issues

1. **R Package Installation**
   ```R
   # Manual installation
   install.packages("BiocManager")
   BiocManager::install("MicTott/SpotSweeper")
   ```

2. **Memory Issues**
   ```bash
   # Increase R memory
   export R_MAX_MEM_SIZE=8g
   ```

3. **Port Conflicts**
   - Change ports in configuration files
   - Check with: `lsof -i :8080`

4. **Docker Build Failures**
   - Use `--no-cache` flag
   - Check system dependencies

## Performance Optimization

1. **R Optimization**
   - Use data.table for large datasets
   - Enable parallel processing
   - Optimize memory usage

2. **API Optimization**
   - Enable response caching
   - Use connection pooling
   - Implement request batching

3. **Infrastructure**
   - Use SSD storage
   - Optimize network latency
   - Consider GPU acceleration

## Backup and Recovery

1. **Data Backup**
   - Regular snapshots of results
   - Version control for code
   - Database backups (if used)

2. **Disaster Recovery**
   - Document recovery procedures
   - Test restore processes
   - Maintain redundant systems