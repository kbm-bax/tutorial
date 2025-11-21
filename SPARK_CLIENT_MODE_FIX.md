# Fix for Hanging Spark Jobs

## Problem
Spark jobs hang when writing data because executors can't communicate back to the driver (Jupyter).

## Root Cause
In cluster mode, Spark executors need to connect back to the driver on specific ports, but Kubernetes pod networking may block this.

## Solution 1: Use Spark in Client Deploy Mode (Recommended)

Instead of using the remote Spark cluster, run Spark locally in the Jupyter pod with access to more resources:

```python
# In notebook, change master to local mode with more resources
spark = SparkSession.builder \
    .appName("Delta Lake Pipeline") \
    .master("local[*]") \
    .config("spark.driver.memory", "2g") \
    .config("spark.executor.memory", "2g") \
    # ... rest of configs
```

## Solution 2: Fix Network Configuration

The driver needs to be accessible from executors. We added:
- `spark.driver.host` - Driver's IP address
- `spark.driver.bindAddress` - Bind to all interfaces
- `spark.driver.port` - Port for driver
- `spark.blockManager.port` - Port for block manager

## Solution 3: Use Spark Submit Instead

Instead of running from Jupyter, submit jobs to Spark:

```bash
kubectl exec -n lakehouse-data-platform <spark-master-pod> -- \
  /opt/bitnami/spark/bin/spark-submit \
  --master spark://localhost:7077 \
  --conf spark.hadoop.fs.s3a.endpoint=http://dataplatform-datalakehouse-minio-service:9000 \
  --conf spark.hadoop.fs.s3a.access.key=minio \
  --conf spark.hadoop.fs.s3a.secret.key=password \
  /path/to/script.py
```

## Debugging Steps

### 1. Check if executors are registered
```bash
# Access Spark Master UI
kubectl port-forward -n lakehouse-data-platform svc/dataplatform-datalakehouse-spark-master-service 8080:8080
# Open http://localhost:8080
```

### 2. Check executor logs during job execution
```bash
kubectl logs -n lakehouse-data-platform -l app.kubernetes.io/component=spark-worker -f
```

### 3. Check driver logs
```bash
kubectl logs -n lakehouse-data-platform -l app.kubernetes.io/component=jupyter -f
```

### 4. Test network connectivity
```bash
# From worker to Jupyter
kubectl exec -n lakehouse-data-platform <worker-pod> -- \
  nc -zv <jupyter-pod-ip> 7077
```

## Quick Fix: Switch to Local Mode

For immediate testing, modify the notebook to use local mode:

```python
spark = SparkSession.builder \
    .appName("Delta Lake Pipeline") \
    .master("local[4]") \  # Use 4 local threads
    .config("spark.driver.memory", "3g") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.hadoop.fs.s3a.endpoint", MINIO_HOST) \
    .config("spark.hadoop.fs.s3a.access.key", AWS_ACCESS_KEY_ID) \
    .config("spark.hadoop.fs.s3a.secret.key", AWS_SECRET_ACCESS_KEY) \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider") \
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
    .getOrCreate()
```

This will work immediately but won't use the distributed Spark cluster.