# Architecture Documentation

## System Overview

This tutorial implements a modern **Data Lakehouse** architecture combining:
- **Storage Layer**: MinIO (S3-compatible object storage)
- **Table Format**: Delta Lake (ACID transactions, time travel)
- **Processing Engine**: Apache Spark (PySpark)
- **Query Engine**: Dremio (SQL analytics)

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Network                           │
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐ │
│  │   Jupyter    │      │    MinIO     │      │    Dremio    │ │
│  │  (PySpark)   │      │  (Storage)   │      │   (Query)    │ │
│  │              │      │              │      │              │ │
│  │  Port: 8888  │      │ API:  9009   │      │ UI:   9047   │ │
│  │              │      │ Web:  9011   │      │ JDBC: 31010  │ │
│  └──────┬───────┘      └──────┬───────┘      └──────┬───────┘ │
│         │                     │                     │         │
│         │    Write Delta      │      Read Delta     │         │
│         └────────────────────►│◄────────────────────┘         │
│                               │                               │
│                    ┌──────────▼──────────┐                    │
│                    │  datalakehouse/     │                    │
│                    │    deltalake/       │                    │
│                    │      ├─ bronze/     │                    │
│                    │      ├─ silver/     │                    │
│                    │      └─ gold/       │                    │
│                    └─────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Ingestion (Bronze Layer)
```
[Source Data]
     │
     ▼
[PySpark DataFrame]
     │
     ▼
[Delta Write]
     │
     ▼
[MinIO: s3a://datalakehouse/deltalake/bronze/]
     │
     ├─ _delta_log/          (transaction log)
     ├─ part-00000.parquet   (data files)
     └─ part-00001.parquet
```

### 2. Transformation (Silver Layer)
```
[Bronze Delta Table]
     │
     ▼
[PySpark Transformation]
     │ (clean, enrich, dedupe)
     ▼
[Delta MERGE Operation]
     │
     ▼
[MinIO: s3a://datalakehouse/deltalake/silver/]
     │
     ├─ _delta_log/
     │   ├─ 00000.json       (version 0)
     │   └─ 00001.json       (version 1)
     └─ part-*.parquet
```

### 3. Aggregation (Gold Layer)
```
[Silver Delta Table]
     │
     ▼
[PySpark Aggregation]
     │ (group by, sum, count)
     ▼
[Delta Write]
     │
     ▼
[MinIO: s3a://datalakehouse/deltalake/gold/]
```

### 4. Query (Dremio)
```
[User SQL Query]
     │
     ▼
[Dremio Query Engine]
     │
     ├─ Parse Delta Log
     ├─ Read Parquet Files
     └─ Apply Optimizations
     │
     ▼
[Query Results]
```

## Technology Stack Details

### MinIO (Object Storage)
```yaml
Role: S3-compatible storage backend
Ports:
  - 9009: S3 API endpoint
  - 9011: Web console
Volume: ./minio-data:/data
Credentials:
  - Access Key: minio
  - Secret Key: password
Buckets:
  - datalakehouse/
```

### Jupyter + PySpark (Processing)
```yaml
Role: Data processing and pipeline execution
Base Image: jupyter/pyspark-notebook
Port: 8888
Packages:
  - delta-spark 3.2.0
  - hadoop-aws 3.3.4
  - aws-java-sdk-bundle 1.12.262
Volumes:
  - ./notebooks:/home/jovyan/work
  - ./data:/data
```

### Dremio (Query Engine)
```yaml
Role: SQL query interface for Delta tables
Image: dremio/dremio-oss:latest
Ports:
  - 9047:  Web UI
  - 31010: ODBC/JDBC
  - 32010: Arrow Flight
  - 45678: Inter-node communication
Volume: ./dremio-data:/opt/dremio/data
Features:
  - Delta Lake support
  - Query acceleration (Reflections)
  - Time travel queries
  - BI tool connectivity
```

## Delta Lake Format

### File Structure
```
deltalake/bronze/users/
├── _delta_log/
│   ├── 00000000000000000000.json    # Transaction log v0
│   ├── 00000000000000000001.json    # Transaction log v1
│   └── 00000000000000000002.json    # Transaction log v2
├── part-00000-xxx.snappy.parquet    # Data file 1
├── part-00001-xxx.snappy.parquet    # Data file 2
└── part-00002-xxx.snappy.parquet    # Data file 3
```

### Transaction Log Entry
```json
{
  "commitInfo": {
    "timestamp": 1705334400000,
    "operation": "WRITE",
    "operationParameters": {"mode": "Overwrite"},
    "readVersion": 0,
    "isBlindAppend": false
  },
  "add": {
    "path": "part-00000-xxx.snappy.parquet",
    "size": 1234,
    "modificationTime": 1705334400000,
    "dataChange": true,
    "stats": "{\"numRecords\":3}"
  }
}
```

## Network Configuration

### Internal Docker Network
```
Network Name: tutorial_default (auto-created)
Driver: bridge

Container Hostnames:
  - minio:9000      (S3 API - internal)
  - jupyter:8888    (Notebook server)
  - dremio:9047     (Web UI)

Note: Containers use internal hostnames (e.g., minio:9000)
      Host machine uses mapped ports (e.g., localhost:9009)
```

### Port Mapping
```
Host Port → Container Port → Service
─────────────────────────────────────
8888      → 8888            → Jupyter Notebook
9009      → 9000            → MinIO S3 API
9011      → 9001            → MinIO Web Console
9047      → 9047            → Dremio Web UI
31010     → 31010           → Dremio JDBC/ODBC
32010     → 32010           → Dremio Arrow Flight
45678     → 45678           → Dremio Inter-node
```

## Data Lakehouse Layers

### Bronze Layer (Raw)
```
Purpose: Store raw, unprocessed data
Schema: Original source schema
Operations: INSERT, APPEND
Retention: Long-term (historical record)
Example:
  - id: 1
  - name: "Alice"
  - location: "New York"
  - timestamp: "2025-01-01"
```

### Silver Layer (Cleaned)
```
Purpose: Cleaned, validated, enriched data
Schema: Standardized business schema
Operations: MERGE (upsert), UPDATE
Retention: Medium-term (active data)
Example:
  - id: 1
  - name: "Alice"
  - timestamp: "2025-01-01"
  (location removed during cleaning)
```

### Gold Layer (Aggregated)
```
Purpose: Business-level aggregations
Schema: Denormalized for analytics
Operations: OVERWRITE, APPEND
Retention: Short-term (can be regenerated)
Example:
  - name: "Alice"
  - count: 1
  (aggregated from Silver layer)
```

## Query Execution Flow

```
1. User submits SQL in Dremio UI
   ↓
2. Dremio parses query and identifies Delta tables
   ↓
3. Dremio reads _delta_log/ from MinIO
   ↓
4. Dremio determines which Parquet files to read
   ↓
5. Dremio reads Parquet files from MinIO (S3A)
   ↓
6. Dremio applies filters, joins, aggregations
   ↓
7. Dremio returns results to user
   ↓
8. (Optional) Dremio caches results in Reflection
```

## Security Considerations

### Current Setup (Development)
```
⚠️  No authentication on Jupyter
⚠️  Simple credentials (minio/password)
⚠️  No TLS/SSL encryption
⚠️  All services on localhost
```

### Production Recommendations
```
✅ Enable Jupyter authentication
✅ Use strong, unique credentials
✅ Enable TLS/SSL on all endpoints
✅ Implement network segmentation
✅ Use IAM roles instead of access keys
✅ Enable audit logging
✅ Implement data encryption at rest
```

## Scalability Considerations

### Current Setup
```
Mode: Single-node, local development
Limitations:
  - Single Spark executor
  - Single Dremio coordinator
  - Local storage only
  - No high availability
```

### Production Scaling
```
Spark:
  - Deploy on Kubernetes/YARN
  - Multiple executors
  - Dynamic resource allocation

Dremio:
  - Add executor nodes
  - Enable query queueing
  - Configure reflections

MinIO:
  - Distributed mode (4+ nodes)
  - Erasure coding
  - Replication

Storage:
  - Use cloud object storage (S3, Azure Blob)
  - Implement lifecycle policies
  - Enable versioning
```

## Monitoring and Observability

### Available Interfaces
```
Jupyter:
  - Notebook execution logs
  - Spark UI (when job running)

MinIO:
  - Web console metrics
  - Bucket statistics
  - Access logs

Dremio:
  - Jobs page (query history)
  - Reflection status
  - System metrics

Docker:
  - Container logs: docker logs <container>
  - Resource usage: docker stats
```

## Backup and Recovery

### Data Persistence
```
MinIO Data:
  Location: ./minio-data/
  Backup: Copy directory or use MinIO replication

Dremio Metadata:
  Location: ./dremio-data/
  Backup: Copy directory or export metadata

Notebooks:
  Location: ./notebooks/
  Backup: Git repository (already tracked)
```

### Recovery Procedure
```bash
# Stop services
docker compose down

# Restore data directories
cp -r backup/minio-data ./
cp -r backup/dremio-data ./

# Restart services
docker compose up -d
```

## Performance Optimization

### PySpark
```python
# Partition data for better performance
df.write.format("delta") \
  .partitionBy("date") \
  .save(path)

# Optimize Delta tables
from delta.tables import DeltaTable
DeltaTable.forPath(spark, path).optimize().executeCompaction()
```

### Dremio
```sql
-- Create reflections for frequently queried tables
-- UI: Right-click table → Settings → Reflections

-- Use query hints
SELECT /*+ NO_REFLECTIONS */ * FROM table
```

### MinIO
```bash
# Enable bucket versioning
mc version enable myminio/datalakehouse

# Set lifecycle policies
mc ilm add --expiry-days 90 myminio/datalakehouse/archive
```

## References

- [Delta Lake Protocol](https://github.com/delta-io/delta/blob/master/PROTOCOL.md)
- [Dremio Architecture](https://docs.dremio.com/current/reference/architecture/)
- [MinIO Architecture](https://min.io/docs/minio/linux/operations/concepts.html)
- [Spark on Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html)