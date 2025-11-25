# Dremio Integration Guide

## Overview
This guide explains how to use Dremio to query Delta Lake tables stored in MinIO object storage.

## Architecture
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   PySpark   │────▶│    MinIO    │◀────│   Dremio    │
│  (Jupyter)  │     │  (S3 Store) │     │ (Query Eng) │
└─────────────┘     └─────────────┘     └─────────────┘
      │                     │                   │
      └─────── Delta Lake Tables ───────────────┘
```

## Starting the Stack

1. **Start all services:**
   ```bash
   docker compose up --build -d
   ```

2. **Verify all containers are running:**
   ```bash
   docker ps
   ```
   You should see: `minio`, `jupyter`, `dremio`, and `create-buckets` (completed)

## Initial Setup

### Step 1: Create Delta Lake Tables (via Jupyter)

1. Access Jupyter at http://localhost:8888
2. Upload and run `notebooks/pipeline_example.ipynb`
3. This creates Delta tables in MinIO at:
   - Bronze: `s3a://datalakehouse/deltalake/bronze/users/`
   - Silver: `s3a://datalakehouse/deltalake/silver/users/`
   - Gold: `s3a://datalakehouse/deltalake/gold/user_summary/`

### Step 2: Configure Dremio

1. **Access Dremio Web UI:**
   - Navigate to http://localhost:9047
   - First time: Create an admin account (username/password of your choice)

2. **Add MinIO as a Data Source:**
   
   a. Click **"Add Source"** (+ icon in bottom left)
   
   b. Select **"Amazon S3"** (MinIO is S3-compatible)
   
   c. Configure the source with these settings:
   
   ```
   Name: MinIO-DataLakeHouse
   
   General Tab:
   ├─ Authentication: AWS Access Key
   ├─ AWS Access Key: minio
   ├─ AWS Access Secret: password
   ├─ Encrypt connection: ☐ (unchecked)
   
   Advanced Options Tab:
   ├─ Enable compatibility mode: ☑ (checked)
   ├─ Root Path: /datalakehouse
   ├─ Connection Properties:
   │  ├─ fs.s3a.path.style.access = true
   │  ├─ fs.s3a.endpoint = minio:9000
   │  └─ dremio.s3.compat = true
   
   Metadata Tab:
   ├─ Dataset Handling:
   │  └─ Enable Delta Lake format: ☑ (checked - IMPORTANT!)
   ```
   
   d. Click **"Save"**

### Step 3: Query Delta Lake Tables

1. **Navigate to the source:**
   - In the left panel, expand **"MinIO-DataLakeHouse"**
   - You should see the folder structure: `deltalake/bronze/`, `deltalake/silver/`, `deltalake/gold/`

2. **Query the tables:**
   
   **Bronze Layer (Raw Data):**
   ```sql
   SELECT * FROM "MinIO-DataLakeHouse".deltalake.bronze.users
   ```
   
   **Silver Layer (Cleaned Data):**
   ```sql
   SELECT * FROM "MinIO-DataLakeHouse".deltalake.silver.users
   ORDER BY id
   ```
   
   **Gold Layer (Aggregated Data):**
   ```sql
   SELECT * FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
   ORDER BY count DESC
   ```

3. **Create Virtual Datasets (Views):**
   - You can create views for commonly used queries
   - Example: Create a view that joins Silver and Gold layers
   ```sql
   SELECT 
     s.id,
     s.name,
     s.timestamp,
     g.count as total_records
   FROM "MinIO-DataLakeHouse".deltalake.silver.users s
   LEFT JOIN "MinIO-DataLakeHouse".deltalake.gold.user_summary g
     ON s.name = g.name
   ```

## Common Operations

### Refresh Metadata
After running the Jupyter pipeline and creating new data:
1. Go to Dremio
2. Navigate to the MinIO source
3. Click the **"⋮"** menu next to the folder/table
4. Select **"Refresh Metadata"**

### Query Performance Tips
1. **Use Reflections** (Dremio's acceleration feature):
   - Right-click on a frequently queried table
   - Select "Settings" → "Reflections"
   - Enable Raw or Aggregation reflections

2. **Partition Awareness**:
   - Dremio automatically detects Delta Lake partitions
   - Use partition columns in WHERE clauses for better performance

### Monitoring
- **Dremio Jobs**: http://localhost:9047/jobs - View query history and performance
- **MinIO Console**: http://localhost:9011 - View raw data files
- **Jupyter**: http://localhost:8888 - Run data pipelines

## Troubleshooting

### Issue: Dremio can't connect to MinIO
**Solution:**
- Verify MinIO is running: `docker ps | grep minio`
- Check network connectivity: `docker exec dremio ping minio`
- Ensure endpoint is set to `minio:9000` (not `localhost:9009`)

### Issue: Delta tables not showing up
**Solution:**
- Ensure "Enable Delta Lake format" is checked in source settings
- Verify tables exist in MinIO console at http://localhost:9011
- Refresh metadata in Dremio

### Issue: "Access Denied" errors
**Solution:**
- Verify credentials: `minio` / `password`
- Check that `fs.s3a.path.style.access = true` is set
- Ensure compatibility mode is enabled

### Issue: Dremio container won't start
**Solution:**
- Check port conflicts: `netstat -ano | findstr "9047"`
- View logs: `docker logs dremio`
- Ensure sufficient disk space for `./dremio-data/`

## Advanced: Delta Lake Time Travel in Dremio

Dremio supports querying historical versions of Delta tables:

```sql
-- Query a specific version
SELECT * FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
AT VERSION AS OF 1

-- Query as of a specific timestamp
SELECT * FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
AT TIMESTAMP AS OF '2025-01-15 10:00:00'
```

## Connecting BI Tools to Dremio

Dremio provides multiple connection methods:

1. **JDBC**: `jdbc:dremio:direct=localhost:31010`
2. **ODBC**: Configure using Dremio ODBC driver
3. **Arrow Flight**: Port 32010 for high-performance data transfer
4. **REST API**: http://localhost:9047/api

Example tools:
- Tableau
- Power BI
- Python (via JDBC/ODBC)
- Excel

## Shutting Down

```bash
# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes all data)
docker compose down -v
```

## References
- [Dremio Documentation](https://docs.dremio.com/)
- [Delta Lake with Dremio](https://docs.dremio.com/current/sonar/data-sources/delta-lake/)
- [S3-Compatible Sources](https://docs.dremio.com/current/sonar/data-sources/s3/)
</contents>