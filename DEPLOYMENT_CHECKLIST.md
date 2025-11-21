# Deployment Checklist for Helm-based Data Lake House

## Pre-Deployment Checks

- [ ] Kubernetes cluster is running and accessible
- [ ] kubectl is configured and can access the cluster
- [ ] Helm 3.x is installed
- [ ] MetalLB is installed and configured (for LoadBalancer services)
- [ ] Sufficient cluster resources available:
  - [ ] CPU: Minimum 8 cores (Recommended: 12+ cores)
  - [ ] Memory: Minimum 16GB (Recommended: 32GB+)
  - [ ] Storage: 50GB+ available

## Deployment Steps

### 1. Create Namespace
```bash
kubectl create namespace datalakehouse
```

### 2. Install Helm Chart
```bash
helm install my-lakehouse ./helm-chart -n datalakehouse
```

### 3. Wait for Pods to be Ready
```bash
kubectl wait --for=condition=ready pod --all -n datalakehouse --timeout=600s
```

### 4. Verify Deployments

#### Check All Pods
```bash
kubectl get pods -n datalakehouse
```

Expected pods:
- [ ] `my-lakehouse-minio-xxx` - Running
- [ ] `my-lakehouse-spark-master-xxx` - Running
- [ ] `my-lakehouse-spark-worker-xxx` (multiple) - Running
- [ ] `my-lakehouse-jupyter-xxx` - Running
- [ ] `my-lakehouse-create-buckets-xxx` - Completed

#### Check Services
```bash
kubectl get svc -n datalakehouse
```

Expected services with LoadBalancer type:
- [ ] `my-lakehouse-minio-service` - LoadBalancer (ports 9999, 9991)
- [ ] `my-lakehouse-spark-master-service` - LoadBalancer (ports 7077, 8080)
- [ ] `my-lakehouse-jupyter-service` - LoadBalancer (port 8888)
- [ ] `my-lakehouse-spark-worker-service` - ClusterIP (headless)

#### Check PVCs
```bash
kubectl get pvc -n datalakehouse
```

Expected PVCs (if persistence enabled):
- [ ] `my-lakehouse-minio-pvc` - Bound
- [ ] `my-lakehouse-jupyter-notebooks-pvc` - Bound
- [ ] `my-lakehouse-jupyter-data-pvc` - Bound

### 5. Get Service IPs

#### Get LoadBalancer IPs
```bash
# Jupyter
kubectl get svc my-lakehouse-jupyter-service -n datalakehouse -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# MinIO Console
kubectl get svc my-lakehouse-minio-service -n datalakehouse -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Spark Master UI
kubectl get svc my-lakehouse-spark-master-service -n datalakehouse -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 6. Access URLs

Replace `<LOADBALANCER_IP>` with the actual IPs from step 5:

- [ ] Jupyter Notebook: `http://<JUPYTER_IP>:8888`
- [ ] MinIO Console: `http://<MINIO_IP>:9991` (user: minio, pass: password)
- [ ] MinIO S3 API: `http://<MINIO_IP>:9999`
- [ ] Spark Master UI: `http://<SPARK_MASTER_IP>:8080`

## Post-Deployment Verification

### 1. Check Spark Cluster

- [ ] Access Spark Master UI
- [ ] Verify worker nodes are connected
- [ ] Check worker count matches configuration (default: 2)

### 2. Check MinIO

- [ ] Login to MinIO Console
- [ ] Verify `datalakehouse` bucket exists
- [ ] Check bucket is accessible

### 3. Test Jupyter Connection

- [ ] Access Jupyter Notebook
- [ ] Open `pipeline_example.ipynb`
- [ ] Run first cell to verify Spark connection
- [ ] Check output shows: "Connected to Spark Master: spark://..."

### 4. Run Complete Pipeline

- [ ] Execute all cells in `pipeline_example.ipynb`
- [ ] Verify Bronze layer data created
- [ ] Verify Silver layer data created
- [ ] Verify Gold layer data created
- [ ] Check data in MinIO Console under `datalakehouse/deltalake/`

### 5. Verify Distributed Processing

- [ ] Check Spark Master UI during job execution
- [ ] Verify tasks are distributed across workers
- [ ] Check worker logs for task execution

## Troubleshooting Commands

### View Logs
```bash
# Jupyter logs
kubectl logs -n datalakehouse -l app.kubernetes.io/component=jupyter --tail=100

# Spark Master logs
kubectl logs -n datalakehouse -l app.kubernetes.io/component=spark-master --tail=100

# Spark Worker logs
kubectl logs -n datalakehouse -l app.kubernetes.io/component=spark-worker --tail=100

# MinIO logs
kubectl logs -n datalakehouse -l app.kubernetes.io/component=minio --tail=100

# Bucket creation job logs
kubectl logs -n datalakehouse job/my-lakehouse-create-buckets
```

### Describe Resources
```bash
# Describe pods
kubectl describe pod -n datalakehouse <pod-name>

# Describe services
kubectl describe svc -n datalakehouse <service-name>

# Check events
kubectl get events -n datalakehouse --sort-by='.lastTimestamp'
```

### Test Connectivity
```bash
# Test MinIO from Jupyter
kubectl exec -n datalakehouse -it <jupyter-pod> -- curl -I http://my-lakehouse-minio-service:9000/minio/health/live

# Test Spark Master from Jupyter
kubectl exec -n datalakehouse -it <jupyter-pod> -- nc -zv my-lakehouse-spark-master-service 7077
```

## Common Issues

### Issue: Pods Stuck in Pending
- Check: `kubectl describe pod <pod-name> -n datalakehouse`
- Possible causes:
  - Insufficient cluster resources
  - PVC not bound
  - Node selector/affinity issues

### Issue: LoadBalancer IP Pending
- Check: MetalLB is installed and configured
- Verify: IP pool is available in MetalLB config
- Check: `kubectl get ipaddresspool -n metallb-system`

### Issue: Spark Workers Not Connecting
- Check: Spark Master is running
- Verify: Network connectivity between pods
- Check: Worker logs for connection errors

### Issue: Jupyter Can't Connect to Spark
- Verify: SPARK_MASTER_URL environment variable
- Check: Spark Master service is accessible
- Test: `kubectl exec -it <jupyter-pod> -- nc -zv my-lakehouse-spark-master-service 7077`

### Issue: MinIO Connection Failed
- Verify: MinIO service is running
- Check: MINIO_HOST environment variable
- Test: Curl MinIO health endpoint

## Cleanup

### Uninstall Release
```bash
helm uninstall my-lakehouse -n datalakehouse
```

### Delete PVCs (Optional - This deletes all data!)
```bash
kubectl delete pvc --all -n datalakehouse
```

### Delete Namespace
```bash
kubectl delete namespace datalakehouse
```

## Notes

- Default credentials: minio/password (Change in production!)
- Jupyter has no authentication by default (Enable in production!)
- All services use MetalLB shared IP with annotation: `metallb.universe.tf/allow-shared-ip: mdap`
- Spark cluster runs in standalone mode
- Default worker count: 2 (configurable via values.yaml)
