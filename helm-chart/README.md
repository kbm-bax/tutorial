# Data Lake House Helm Chart

A Helm chart for deploying a complete Data Lake House tutorial environment on Kubernetes, featuring Apache Spark (PySpark), Delta Lake, and MinIO.

## Overview

This Helm chart deploys:
- **Jupyter Notebook** with PySpark and Delta Lake support
- **MinIO** S3-compatible object storage
- **Automated bucket creation** for the data lakehouse
- **Pre-configured pipeline example** demonstrating Bronze/Silver/Gold architecture

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support in the underlying infrastructure (for persistent storage)
- At least 4GB of available memory in your cluster

## Installation

### Quick Start

```bash
# Add the repository (if published)
helm repo add datalakehouse <repository-url>
helm repo update

# Install the chart with default values
helm install my-datalakehouse datalakehouse/datalakehouse

# Or install from local directory
helm install my-datalakehouse ./helm-chart
```

### Install with Custom Values

```bash
# Create a custom values file
cat > my-values.yaml <<EOF
minio:
  service:
    type: LoadBalancer
  persistence:
    size: 20Gi

jupyter:
  service:
    type: LoadBalancer
  resources:
    requests:
      memory: "4Gi"
      cpu: "2000m"
EOF

# Install with custom values
helm install my-datalakehouse ./helm-chart -f my-values.yaml
```

### Install in a Specific Namespace

```bash
# Create namespace
kubectl create namespace datalakehouse

# Install in the namespace
helm install my-datalakehouse ./helm-chart -n datalakehouse
```

## Configuration

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|----------|
| `global.storageClass` | Global storage class for PVCs | `standard` |
| `minio.enabled` | Enable MinIO deployment | `true` |
| `minio.service.type` | MinIO service type (NodePort/LoadBalancer/ClusterIP) | `NodePort` |
| `minio.service.apiNodePort` | NodePort for MinIO S3 API | `30900` |
| `minio.service.consoleNodePort` | NodePort for MinIO Console | `30901` |
| `minio.auth.rootUser` | MinIO root username | `minio` |
| `minio.auth.rootPassword` | MinIO root password | `password` |
| `minio.persistence.enabled` | Enable persistent storage for MinIO | `true` |
| `minio.persistence.size` | Size of MinIO PVC | `10Gi` |
| `jupyter.enabled` | Enable Jupyter deployment | `true` |
| `jupyter.service.type` | Jupyter service type | `NodePort` |
| `jupyter.service.nodePort` | NodePort for Jupyter | `30888` |
| `jupyter.persistence.notebooks.enabled` | Enable persistent storage for notebooks | `true` |
| `jupyter.persistence.notebooks.size` | Size of notebooks PVC | `5Gi` |
| `jupyter.auth.enabled` | Enable Jupyter authentication | `false` |
| `jupyter.resources.requests.memory` | Jupyter memory request | `2Gi` |
| `jupyter.resources.requests.cpu` | Jupyter CPU request | `1000m` |
| `ingress.enabled` | Enable ingress | `false` |

### Example Configurations

#### Production Configuration with LoadBalancer

```yaml
global:
  storageClass: "gp3"  # AWS EBS gp3

minio:
  service:
    type: LoadBalancer
  persistence:
    size: 50Gi
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"

jupyter:
  service:
    type: LoadBalancer
  persistence:
    notebooks:
      size: 20Gi
    data:
      size: 50Gi
  resources:
    requests:
      memory: "4Gi"
      cpu: "2000m"
    limits:
      memory: "8Gi"
      cpu: "4000m"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    jupyter:
      host: jupyter.example.com
      paths:
        - path: /
          pathType: Prefix
    minio:
      host: minio.example.com
      paths:
        - path: /
          pathType: Prefix
```

#### Development Configuration (Minimal Resources)

```yaml
minio:
  persistence:
    enabled: false
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"

jupyter:
  persistence:
    notebooks:
      enabled: false
    data:
      enabled: false
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
```

## Accessing the Services

### NodePort (Default)

After installation, get the access URLs:

```bash
# Get Jupyter URL
export NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}")
echo "Jupyter: http://$NODE_IP:30888"

# Get MinIO Console URL
echo "MinIO Console: http://$NODE_IP:30901"
echo "Username: minio"
echo "Password: password"
```

### LoadBalancer

```bash
# Get Jupyter LoadBalancer IP
kubectl get svc my-datalakehouse-jupyter-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Get MinIO LoadBalancer IP
kubectl get svc my-datalakehouse-minio-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Port Forward (ClusterIP)

```bash
# Forward Jupyter
kubectl port-forward svc/my-datalakehouse-jupyter-service 8888:8888

# Forward MinIO Console
kubectl port-forward svc/my-datalakehouse-minio-service 9001:9001
```

## Using the Data Lake House

1. **Access Jupyter Notebook** at the URL obtained above
2. **Open `pipeline_example.ipynb`** - it's pre-loaded in the work directory
3. **Run the notebook cells** to execute the Delta Lake pipeline
4. **View results in MinIO Console**:
   - Navigate to the `datalakehouse` bucket
   - Explore the `deltalake/bronze`, `deltalake/silver`, and `deltalake/gold` folders

## Architecture

The chart implements a **Medallion Architecture**:

- **Bronze Layer**: Raw data ingestion
- **Silver Layer**: Cleaned and enriched data with MERGE operations
- **Gold Layer**: Aggregated data ready for analytics

### Components

```
┌─────────────────┐
│  Jupyter        │
│  (PySpark +     │
│   Delta Lake)   │
└────────┬────────┘
         │
         │ S3A Protocol
         │
         ▼
┌─────────────────┐
│  MinIO          │
│  (S3-compatible │
│   Storage)      │
└─────────────────┘
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l "app.kubernetes.io/instance=my-datalakehouse"
```

### View Logs

```bash
# Jupyter logs
kubectl logs -l "app.kubernetes.io/component=jupyter" -f

# MinIO logs
kubectl logs -l "app.kubernetes.io/component=minio" -f

# Bucket creation job logs
kubectl logs job/my-datalakehouse-create-buckets
```

### Common Issues

#### Pods in Pending State

**Cause**: Insufficient resources or PVC not bound

```bash
# Check PVC status
kubectl get pvc

# Describe pod for more details
kubectl describe pod <pod-name>
```

**Solution**: 
- Ensure your cluster has enough resources
- Check if StorageClass is available: `kubectl get storageclass`
- Adjust resource requests in values.yaml

#### MinIO Connection Issues

**Cause**: MinIO service not ready or incorrect configuration

```bash
# Check MinIO service
kubectl get svc my-datalakehouse-minio-service

# Test connectivity from Jupyter pod
kubectl exec -it <jupyter-pod> -- curl http://my-datalakehouse-minio-service:9000/minio/health/live
```

#### Jupyter Can't Access MinIO

**Cause**: Network policy or service name mismatch

**Solution**: Verify the MINIO_HOST environment variable matches the service name:
```bash
kubectl get svc | grep minio
```

## Upgrading

```bash
# Upgrade with new values
helm upgrade my-datalakehouse ./helm-chart -f my-values.yaml

# Upgrade and wait for completion
helm upgrade my-datalakehouse ./helm-chart --wait --timeout 10m
```

## Uninstallation

```bash
# Uninstall the release
helm uninstall my-datalakehouse

# Delete PVCs (if needed)
kubectl delete pvc -l "app.kubernetes.io/instance=my-datalakehouse"

# Delete namespace (if created)
kubectl delete namespace datalakehouse
```

## Advanced Usage

### Using Custom Docker Images

If you've built a custom Jupyter image with pre-installed dependencies:

```yaml
jupyter:
  customImage:
    enabled: true
    repository: myregistry/datalakehouse-jupyter
    tag: v1.0.0
  initContainer:
    enabled: false  # Disable init container if dependencies are in custom image
```

### Adding Additional Buckets

```yaml
minioClient:
  buckets:
    - name: datalakehouse
      policy: none
    - name: raw-data
      policy: download
    - name: processed-data
      policy: none
```

### Enabling Ingress with TLS

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    jupyter:
      host: jupyter.example.com
      paths:
        - path: /
          pathType: Prefix
    minio:
      host: minio.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: datalakehouse-tls
      hosts:
        - jupyter.example.com
        - minio.example.com
```

## Security Considerations

⚠️ **Important**: This chart is designed for tutorial/development purposes.

For production use:

1. **Change default credentials**:
   ```yaml
   minio:
     auth:
       rootUser: <strong-username>
       rootPassword: <strong-password>
   ```

2. **Enable Jupyter authentication**:
   ```yaml
   jupyter:
     auth:
       enabled: true
       token: <secure-token>
   ```

3. **Use secrets instead of plain text**:
   ```bash
   kubectl create secret generic minio-credentials \
     --from-literal=rootUser=admin \
     --from-literal=rootPassword=<strong-password>
   ```

4. **Enable network policies**
5. **Use TLS/SSL for all communications**
6. **Implement RBAC policies**

## Contributing

Contributions are welcome! Please submit issues and pull requests.

## License

This chart is provided as-is for educational purposes.

## References

- [Delta Lake Documentation](https://delta.io/)
- [MinIO Documentation](https://min.io/docs/)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
- [Helm Documentation](https://helm.sh/docs/)