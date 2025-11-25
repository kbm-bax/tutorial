# Troubleshooting Guide

## Quick Diagnostics

### Check All Services Status
```powershell
docker ps
```
Expected containers: `minio`, `jupyter`, `dremio`, `create-buckets` (exited)

### View Container Logs
```powershell
# MinIO logs
docker logs minio

# Jupyter logs
docker logs jupyter

# Dremio logs
docker logs dremio
```

## Common Issues

### 1. Port Conflicts

**Symptoms:**
- Container fails to start
- Error: "port is already allocated"

**Solution:**
```powershell
# Check which process is using the port
netstat -ano | findstr "9047"   # Dremio
netstat -ano | findstr "8888"   # Jupyter
netstat -ano | findstr "9009"   # MinIO API
netstat -ano | findstr "9011"   # MinIO Console

# Kill the process or change ports in docker-compose.yml
```

**Alternative Ports (edit docker-compose.yml):**
```yaml
dremio:
  ports:
    - "9048:9047"   # Change host port to 9048
```

### 2. Dremio Cannot Connect to MinIO

**Symptoms:**
- "Connection refused" in Dremio
- Cannot see MinIO source data

**Checklist:**
- [ ] MinIO container is running: `docker ps | grep minio`
- [ ] Network connectivity: `docker exec dremio ping minio`
- [ ] Endpoint uses internal name: `minio:9000` (NOT `localhost:9009`)
- [ ] Path style access enabled: `fs.s3a.path.style.access = true`
- [ ] Credentials correct: `minio` / `password`

**Test Connection:**
```powershell
# From Dremio container
docker exec -it dremio curl http://minio:9000/minio/health/live
```

### 3. Delta Tables Not Visible in Dremio

**Symptoms:**
- Folders show up but no tables
- Empty result sets

**Solutions:**

1. **Enable Delta Lake Format:**
   - Go to Dremio → Sources → MinIO-DataLakeHouse → Settings
   - Check "Enable Delta Lake format" under Dataset Handling
   - Save and refresh metadata

2. **Verify Tables Exist:**
   - Check MinIO console: http://localhost:9011
   - Navigate to `datalakehouse/deltalake/`
   - Look for `_delta_log` folders

3. **Refresh Metadata:**
   - In Dremio, right-click the folder
   - Select "Refresh Metadata"

4. **Run Pipeline First:**
   - Execute `notebooks/pipeline_example.ipynb` in Jupyter
   - Wait for completion before querying in Dremio

### 4. Jupyter Notebook Issues

**Symptoms:**
- Cannot access http://localhost:8888
- Kernel errors

**Solutions:**

1. **Check Container Status:**
```powershell
docker logs jupyter
```

2. **Restart Jupyter:**
```powershell
docker restart jupyter
```

3. **Clear Browser Cache:**
   - Hard refresh: Ctrl+Shift+R
   - Or use incognito mode

4. **Verify PySpark Configuration:**
```python
# In notebook, check Spark session
spark.version  # Should show Spark version
```

### 5. MinIO Access Issues

**Symptoms:**
- "Access Denied" errors
- Cannot view buckets

**Solutions:**

1. **Verify Credentials:**
   - Username: `minio`
   - Password: `password`

2. **Check Bucket Creation:**
```powershell
docker logs create-buckets
```
Should show: "Bucket created successfully"

3. **Recreate Buckets:**
```powershell
docker exec -it minio mc alias set myminio http://localhost:9000 minio password
docker exec -it minio mc mb myminio/datalakehouse
```

### 6. Docker Compose Issues

**Symptoms:**
- Services won't start
- Dependency errors

**Solutions:**

1. **Clean Restart:**
```powershell
docker compose down
docker compose up --build -d
```

2. **Remove Volumes (WARNING: Deletes data):**
```powershell
docker compose down -v
docker compose up --build -d
```

3. **Check Docker Desktop:**
   - Ensure Docker Desktop is running
   - Check available resources (CPU, Memory, Disk)

### 7. Performance Issues

**Symptoms:**
- Slow queries in Dremio
- High memory usage

**Solutions:**

1. **Increase Docker Resources:**
   - Docker Desktop → Settings → Resources
   - Increase Memory to 8GB+
   - Increase CPUs to 4+

2. **Enable Dremio Reflections:**
   - Right-click table in Dremio
   - Settings → Reflections
   - Enable Raw or Aggregation reflections

3. **Optimize Queries:**
   - Use WHERE clauses to filter data
   - Limit result sets during testing
   - Use EXPLAIN PLAN to analyze queries

### 8. Data Persistence Issues

**Symptoms:**
- Data disappears after restart
- Tables not found

**Solutions:**

1. **Check Volume Mounts:**
```powershell
docker inspect minio | findstr Mounts
docker inspect dremio | findstr Mounts
```

2. **Verify Local Directories:**
   - `./minio-data/` should exist
   - `./dremio-data/` should exist
   - Check permissions

3. **Don't Use `-v` Flag:**
   - `docker compose down` (keeps data)
   - NOT `docker compose down -v` (deletes data)

## Network Diagnostics

### Test Inter-Container Communication
```powershell
# From Jupyter to MinIO
docker exec jupyter curl http://minio:9000/minio/health/live

# From Dremio to MinIO
docker exec dremio curl http://minio:9000/minio/health/live

# Check DNS resolution
docker exec dremio nslookup minio
```

### View Docker Network
```powershell
docker network ls
docker network inspect tutorial_default
```

## Reset Everything

If all else fails, complete reset:

```powershell
# Stop and remove everything
docker compose down -v

# Remove local data directories
Remove-Item -Recurse -Force minio-data
Remove-Item -Recurse -Force dremio-data

# Rebuild and restart
docker compose up --build -d

# Wait for services to be healthy
docker ps

# Re-run pipeline in Jupyter
# Re-configure Dremio source
```

## Getting Help

### Collect Diagnostic Information
```powershell
# Save all logs
docker logs minio > minio.log 2>&1
docker logs jupyter > jupyter.log 2>&1
docker logs dremio > dremio.log 2>&1

# Check versions
docker compose version
docker version
```

### Useful Commands
```powershell
# View resource usage
docker stats

# Inspect container
docker inspect <container_name>

# Execute commands in container
docker exec -it <container_name> /bin/bash

# View container filesystem
docker exec <container_name> ls -la /path/to/dir
```

## Prevention Tips

1. **Always check logs first:** `docker logs <container>`
2. **Use internal container names:** `minio:9000` not `localhost:9009`
3. **Refresh metadata in Dremio** after pipeline runs
4. **Don't mix host and container networking**
5. **Keep Docker Desktop updated**
6. **Allocate sufficient resources** (8GB+ RAM recommended)

## Still Having Issues?

Check the official documentation:
- [Dremio Docs](https://docs.dremio.com/)
- [Delta Lake Docs](https://docs.delta.io/)
- [MinIO Docs](https://min.io/docs/)
- [Docker Compose Docs](https://docs.docker.com/compose/)