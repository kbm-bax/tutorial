# Quick Start Guide - Dremio + Delta Lake + MinIO

## Prerequisites
- ✅ Docker Desktop installed and running
- ✅ Git installed
- ✅ At least 8GB RAM available for Docker
- ✅ Ports available: 8888, 9009, 9011, 9047, 31010, 32010, 45678

## 5-Minute Setup

### Step 1: Start the Stack (2 min)
```powershell
# Clone and navigate to the project
cd path/to/tutorial

# Start all services
docker compose up --build -d

# Wait for services to be ready (check status)
docker ps
```

**Expected Output:**
```
CONTAINER ID   IMAGE                    STATUS         PORTS
xxxxxxxxx      jupyter/pyspark-notebook Up             0.0.0.0:8888->8888/tcp
xxxxxxxxx      minio/minio:latest       Up (healthy)   0.0.0.0:9009->9000/tcp, 0.0.0.0:9011->9001/tcp
xxxxxxxxx      dremio/dremio-oss:latest Up             0.0.0.0:9047->9047/tcp, ...
```

### Step 2: Create Delta Lake Tables (1 min)

1. Open Jupyter: http://localhost:8888
2. Upload `notebooks/pipeline_example.ipynb`
3. Click "Run" → "Run All Cells"
4. Wait for completion (you'll see "Gold table created/updated")

### Step 3: Configure Dremio (2 min)

1. Open Dremio: http://localhost:9047
2. **First time only:** Create admin account
3. Click **"+ Add Source"** → Select **"Amazon S3"**
4. Fill in the form:

```
Name: MinIO-DataLakeHouse

[General Tab]
Authentication: AWS Access Key
AWS Access Key: minio
AWS Access Secret: password
Encrypt connection: ☐ (unchecked)

[Advanced Options Tab]
Enable compatibility mode: ☑ (checked)
Root Path: /datalakehouse

Connection Properties (click "Add Property" for each):
  fs.s3a.path.style.access = true
  fs.s3a.endpoint = minio:9000
  dremio.s3.compat = true

[Metadata Tab]
Dataset Handling:
  Enable Delta Lake format: ☑ (CRITICAL - must be checked!)
```

5. Click **"Save"**

### Step 4: Query Your Data (30 sec)

1. In Dremio, expand **"MinIO-DataLakeHouse"** in left panel
2. Navigate to: `deltalake` → `gold` → `user_summary`
3. Click the table name
4. Run this query:

```sql
SELECT * FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
ORDER BY count DESC
```

**Expected Result:**
```
name     | count
---------|------
Alice    | 1
Bob      | 1
Charlie  | 1
```

🎉 **Success!** You're now querying Delta Lake tables with Dremio!

---

## Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **Jupyter** | http://localhost:8888 | None (no auth) |
| **Dremio** | http://localhost:9047 | Your admin account |
| **MinIO Console** | http://localhost:9011 | minio / password |

---

## What's Next?

### Explore the Data Layers

**Bronze Layer (Raw):**
```sql
SELECT * FROM "MinIO-DataLakeHouse".deltalake.bronze.users
```

**Silver Layer (Cleaned):**
```sql
SELECT * FROM "MinIO-DataLakeHouse".deltalake.silver.users
```

**Gold Layer (Aggregated):**
```sql
SELECT * FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
```

### Try Time Travel
```sql
-- View previous version
SELECT * FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
AT VERSION AS OF 0
```

### Modify the Pipeline

1. Edit `notebooks/pipeline_example.ipynb`
2. Add more data or transformations
3. Re-run the notebook
4. In Dremio: Right-click folder → "Refresh Metadata"
5. Query the updated data

---

## Common First-Time Issues

### ❌ "Cannot connect to MinIO"
**Fix:** Use `minio:9000` (not `localhost:9009`) in Dremio settings

### ❌ "Tables not showing in Dremio"
**Fix:** Enable "Delta Lake format" in source settings (Metadata tab)

### ❌ "Port already in use"
**Fix:** Change ports in `docker-compose.yml` or stop conflicting services

### ❌ "Dremio shows folders but no tables"
**Fix:** 
1. Run the Jupyter pipeline first
2. Refresh metadata in Dremio
3. Verify Delta Lake format is enabled

---

## Stopping the Stack

```powershell
# Stop services (keeps data)
docker compose down

# Stop and remove all data (clean slate)
docker compose down -v
```

---

## Learning Path

1. ✅ **You are here:** Basic setup and queries
2. 📖 Read: [DREMIO_SETUP_GUIDE.md](DREMIO_SETUP_GUIDE.md) - Detailed configuration
3. 💻 Practice: [notebooks/dremio_queries.sql](notebooks/dremio_queries.sql) - Sample queries
4. 🔧 Troubleshoot: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
5. 🚀 Advanced: Create reflections, virtual datasets, and BI connections

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Your Workflow                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. PySpark (Jupyter) → Writes Delta Tables → MinIO    │
│                                                         │
│  2. Dremio → Reads Delta Tables ← MinIO                │
│                                                         │
│  3. BI Tools → Query via Dremio → Get Results          │
│                                                         │
└─────────────────────────────────────────────────────────┘

        Data Flow:
        
   [Raw Data] 
       ↓
   [Bronze Layer] ← PySpark ingestion
       ↓
   [Silver Layer] ← PySpark transformation
       ↓
   [Gold Layer]   ← PySpark aggregation
       ↓
   [MinIO Storage] (Delta format)
       ↓
   [Dremio Queries] (SQL interface)
       ↓
   [Analytics/BI]
```

---

## Need Help?

- 📚 **Detailed Guide:** [DREMIO_SETUP_GUIDE.md](DREMIO_SETUP_GUIDE.md)
- 🔍 **Troubleshooting:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- 💡 **SQL Examples:** [notebooks/dremio_queries.sql](notebooks/dremio_queries.sql)
- 📖 **Main README:** [README.md](README.md)

---

**Happy querying! 🚀**