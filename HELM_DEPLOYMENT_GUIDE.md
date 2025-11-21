# Helm Deployment Guide for Data Lake House

This guide provides step-by-step instructions for deploying the Data Lake House application using Helm on Kubernetes.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Deployment Options](#deployment-options)
4. [Post-Deployment](#post-deployment)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Migration from Docker Compose](#migration-from-docker-compose)

## Prerequisites

### Required Tools

```bash
# Check Kubernetes cluster access
kubectl cluster-info

# Check Helm installation
helm version

# Verify you have sufficient permissions
kubectl auth can-i create deployments --all-namespaces
```

### Minimum Cluster Requirements

- **Kubernetes Version**: 1.19+
- **Helm Version**: 3.0+
- **CPU**: 2 cores minimum (4 cores recommended)
- **Memory**: 4GB minimum (8GB recommended)
- **Storage**: 20GB available for PersistentVolumes

### Verify Storage Class

```bash
# List available storage classes
kubectl get storageclass

# If no storage class exists, create one (example for local development)
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
```

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd <repository-name>
```

### 2. Deploy with Default Settings

```bash
# Create namespace
kubectl create namespace datalakehouse

# Install the chart
helm install my-lakehouse ./helm-chart -n datalakehouse

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n datalakehouse --timeout=300s
```

### 3. Get Access URLs

```bash
# Get the NOTES output again
helm get notes my-lakehouse -n datalakehouse

# Or manually get the URLs
export NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}")
echo "Jupyter: http://$NODE_IP:30888"
echo "MinIO Console: http://$NODE_IP:30901"
```

## Deployment Options

### Option 1: Development Environment (Minimal Resources)

```bash
helm install my-lakehouse ./helm-chart \
  -n datalakehouse \
  -f helm-chart/values-dev.yaml
```

**Features:**
- No persistent storage (uses emptyDir)
- Minimal resource allocation
- NodePort services
- Fast startup

### Option 2: Production Environment (Full Features)

```bash
# Update values-prod.yaml with your domain and credentials
vim helm-chart/values-prod.yaml

# Install with production values
helm install my-lakehouse ./helm-chart \
  -n datalakehouse \
  -f helm-chart/values-prod.yaml
```

**Features:**
- Persistent storage with PVCs
- LoadBalancer services
- Ingress with TLS
- Higher resource limits
- Authentication enabled

### Option 3: Custom Configuration

```bash
# Create your custom values file
cat > my-custom-values.yaml <<EOF
minio:
  service:
    type: LoadBalancer
  persistence:
    size: 50Gi

jupyter:
  resources:
    requests:
      memory: "4Gi"
      cpu: "2000m"
EOF

# Install with custom values
helm install my-lakehouse ./helm-chart \
  -n datalakehouse \
  -f my-custom-values.yaml
```

### Option 4: Cloud-Specific Deployments

#### AWS EKS

```bash
cat > eks-values.yaml <<EOF
global:
  storageClass: "gp3"

minio:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"

jupyter:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
EOF

helm install my-lakehouse ./helm-chart -n datalakehouse -f eks-values.yaml
```

#### Google GKE

```bash
cat > gke-values.yaml <<EOF
global:
  storageClass: "standard-rwo"

minio:
  service:
    type: LoadBalancer

jupyter:
  service:
    type: LoadBalancer
EOF

helm install my-lakehouse ./helm-chart -n datalakehouse -f gke-values.yaml
```

#### Azure AKS

```bash
cat > aks-values.yaml <<EOF
global:
  storageClass: "managed-premium"

minio:
  service:
    type: LoadBalancer

jupyter:
  service:
    type: LoadBalancer
EOF

helm install my-lakehouse ./helm-chart -n datalakehouse -f aks-values.yaml
```

## Post-Deployment

### 1. Verify Deployment

```bash
# Check all resources
kubectl get all -n datalakehouse

# Check PVCs
kubectl get pvc -n datalakehouse

# Check ConfigMaps
kubectl get configmap -n datalakehouse
```

### 2. Access Services

#### Using NodePort (Default)

```bash
# Get Node IP
export NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}")

# Access Jupyter
open http://$NODE_IP:30888

# Access MinIO Console
open http://$NODE_IP:30901
```

#### Using LoadBalancer

```bash
# Get Jupyter LoadBalancer IP
kubectl get svc my-lakehouse-jupyter-service -n datalakehouse -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Get MinIO LoadBalancer IP
kubectl get svc my-lakehouse-minio-service -n datalakehouse -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

#### Using Port Forward

```bash
# Forward Jupyter
kubectl port-forward -n datalakehouse svc/my-lakehouse-jupyter-service 8888:8888 &

# Forward MinIO Console
kubectl port-forward -n datalakehouse svc/my-lakehouse-minio-service 9001:9001 &

# Access locally
open http://localhost:8888
open http://localhost:9001
```

### 3. Run the Pipeline

1. Access Jupyter Notebook
2. Open `pipeline_example.ipynb`
3. Run all cells
4. Verify data in MinIO Console at `datalakehouse/deltalake/`

## Verification

### Check Pod Status

```bash
# All pods should be Running
kubectl get pods -n datalakehouse

# Expected output:
# NAME                                    READY   STATUS      RESTARTS   AGE
# my-lakehouse-jupyter-xxx                1/1     Running     0          5m
# my-lakehouse-minio-xxx                  1/1     Running     0          5m
# my-lakehouse-create-buckets-xxx         0/1     Completed   0          5m
```

### Check Logs

```bash
# Jupyter logs
kubectl logs -n datalakehouse -l app.kubernetes.io/component=jupyter --tail=50

# MinIO logs
kubectl logs -n datalakehouse -l app.kubernetes.io/component=minio --tail=50

# Bucket creation job logs
kubectl logs -n datalakehouse job/my-lakehouse-create-buckets
```

### Test Connectivity

```bash
# Test MinIO from Jupyter pod
kubectl exec -n datalakehouse -it $(kubectl get pod -n datalakehouse -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}') -- curl -I http://my-lakehouse-minio-service:9000/minio/health/live
```

## Troubleshooting

### Issue: Pods Stuck in Pending

**Symptoms:**
```bash
kubectl get pods -n datalakehouse
# Shows pods in Pending state
```

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n datalakehouse
```

**Common Causes & Solutions:**

1. **Insufficient Resources**
   ```bash
   # Check node resources
   kubectl top nodes
   
   # Solution: Reduce resource requests or add nodes
   helm upgrade my-lakehouse ./helm-chart -n datalakehouse \
     --set jupyter.resources.requests.memory=1Gi \
     --set jupyter.resources.requests.cpu=500m
   ```

2. **PVC Not Bound**
   ```bash
   # Check PVC status
   kubectl get pvc -n datalakehouse
   
   # Solution: Check storage class
   kubectl get storageclass
   
   # Or disable persistence for testing
   helm upgrade my-lakehouse ./helm-chart -n datalakehouse \
     --set minio.persistence.enabled=false \
     --set jupyter.persistence.notebooks.enabled=false \
     --set jupyter.persistence.data.enabled=false
   ```

### Issue: MinIO Connection Failed

**Symptoms:**
- Jupyter can't connect to MinIO
- S3A errors in Spark

**Diagnosis:**
```bash
# Check MinIO service
kubectl get svc -n datalakehouse | grep minio

# Test from Jupyter pod
kubectl exec -n datalakehouse -it <jupyter-pod> -- curl http://my-lakehouse-minio-service:9000/minio/health/live
```

**Solution:**
```bash
# Verify environment variables
kubectl exec -n datalakehouse <jupyter-pod> -- env | grep MINIO

# Restart Jupyter pod
kubectl delete pod -n datalakehouse -l app.kubernetes.io/component=jupyter
```

### Issue: Bucket Not Created

**Symptoms:**
- MinIO console shows no buckets
- Pipeline fails with bucket not found

**Diagnosis:**
```bash
# Check job status
kubectl get jobs -n datalakehouse

# Check job logs
kubectl logs -n datalakehouse job/my-lakehouse-create-buckets
```

**Solution:**
```bash
# Manually create bucket
kubectl run -n datalakehouse minio-mc --rm -it --image=minio/mc --restart=Never -- \
  /bin/sh -c "mc alias set myminio http://my-lakehouse-minio-service:9000 minio password && mc mb myminio/datalakehouse"
```

### Issue: Out of Memory

**Symptoms:**
- Pods getting OOMKilled
- Spark jobs failing

**Solution:**
```bash
# Increase memory limits
helm upgrade my-lakehouse ./helm-chart -n datalakehouse \
  --set jupyter.resources.limits.memory=8Gi \
  --set jupyter.resources.requests.memory=4Gi
```

## Migration from Docker Compose

### Key Differences

| Aspect | Docker Compose | Kubernetes/Helm |
|--------|----------------|-----------------|
| Service Discovery | Container names | Service DNS names |
| Storage | Local volumes | PersistentVolumes |
| Networking | Bridge network | ClusterIP/NodePort/LoadBalancer |
| Configuration | Environment variables | ConfigMaps/Secrets |
| Scaling | Manual | Automatic with replicas |

### Migration Steps

1. **Export Data from Docker Compose**
   ```bash
   # Backup MinIO data
   docker cp minio:/data ./minio-backup
   ```

2. **Deploy Helm Chart**
   ```bash
   helm install my-lakehouse ./helm-chart -n datalakehouse
   ```

3. **Import Data to Kubernetes**
   ```bash
   # Copy data to MinIO pod
   kubectl cp ./minio-backup datalakehouse/<minio-pod>:/data
   ```

4. **Update Connection Strings**
   - Docker: `http://minio:9000`
   - Kubernetes: `http://my-lakehouse-minio-service:9000`

## Upgrading

### Upgrade to New Version

```bash
# Pull latest changes
git pull

# Upgrade release
helm upgrade my-lakehouse ./helm-chart -n datalakehouse

# Or with custom values
helm upgrade my-lakehouse ./helm-chart -n datalakehouse -f my-values.yaml
```

### Rollback

```bash
# List revisions
helm history my-lakehouse -n datalakehouse

# Rollback to previous version
helm rollback my-lakehouse -n datalakehouse

# Rollback to specific revision
helm rollback my-lakehouse 2 -n datalakehouse
```

## Uninstallation

```bash
# Uninstall the release
helm uninstall my-lakehouse -n datalakehouse

# Delete PVCs (optional - this will delete all data!)
kubectl delete pvc -n datalakehouse --all

# Delete namespace
kubectl delete namespace datalakehouse
```

## Best Practices

1. **Use Secrets for Credentials**
   ```bash
   kubectl create secret generic minio-creds \
     --from-literal=rootUser=admin \
     --from-literal=rootPassword=SecurePass123! \
     -n datalakehouse
   ```

2. **Enable Resource Quotas**
   ```bash
   kubectl create quota lakehouse-quota \
     --hard=cpu=4,memory=16Gi,persistentvolumeclaims=10 \
     -n datalakehouse
   ```

3. **Set Up Monitoring**
   ```bash
   # Add Prometheus annotations
   helm upgrade my-lakehouse ./helm-chart -n datalakehouse \
     --set podAnnotations."prometheus\.io/scrape"="true" \
     --set podAnnotations."prometheus\.io/port"="8888"
   ```

4. **Regular Backups**
   ```bash
   # Backup MinIO data
   kubectl exec -n datalakehouse <minio-pod> -- \
     tar czf /tmp/backup.tar.gz /data
   
   kubectl cp datalakehouse/<minio-pod>:/tmp/backup.tar.gz ./backup.tar.gz
   ```

## Support

For issues and questions:
- Check the [README](helm-chart/README.md)
- Review [Troubleshooting](#troubleshooting) section
- Check Kubernetes events: `kubectl get events -n datalakehouse --sort-by='.lastTimestamp'`
- Review pod logs: `kubectl logs -n datalakehouse <pod-name>`

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Delta Lake Documentation](https://delta.io/)
- [MinIO Kubernetes Documentation](https://min.io/docs/minio/kubernetes/)