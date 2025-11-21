# Storage Setup Guide

## Overview

This deployment uses:
- **StorageClass**: `delta-storage` with OpenEBS hostpath configuration
- **Base Path**: `/srv/db/delta`
- **Reclaim Policy**: Retain (data persists after PVC deletion)

## Pre-requisites

1. Ensure the base directory exists on your Kubernetes nodes:

```bash
# On each node where pods might be scheduled
sudo mkdir -p /srv/db/delta
sudo chmod 777 /srv/db/delta
```

## Deployment Steps

### 1. Create StorageClass

```bash
kubectl apply -f kubernetes/storageclass.yaml
```

Verify:
```bash
kubectl get storageclass delta-storage
```

### 2. Create PersistentVolumes

```bash
kubectl apply -f kubernetes/persistent-volumes.yaml
```

Verify:
```bash
kubectl get pv
```

Expected output:
```
NAME                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      STORAGECLASS    
minio-pv               10Gi       RWO            Retain           Available   delta-storage
jupyter-notebooks-pv   5Gi        RWO            Retain           Available   delta-storage
jupyter-data-pv        5Gi        RWO            Retain           Available   delta-storage
```

### 3. Create Namespace

```bash
kubectl create namespace datalakehouse
```

### 4. Deploy Helm Chart

```bash
helm install my-lakehouse ./helm-chart -n datalakehouse
```

### 5. Verify PVC Binding

```bash
kubectl get pvc -n datalakehouse
```

All PVCs should show STATUS as `Bound`:
```
NAME                                    STATUS   VOLUME                 CAPACITY   STORAGECLASS
my-lakehouse-jupyter-data-pvc           Bound    jupyter-data-pv        5Gi        delta-storage
my-lakehouse-jupyter-notebooks-pvc      Bound    jupyter-notebooks-pv   5Gi        delta-storage
my-lakehouse-minio-pvc                  Bound    minio-pv               10Gi       delta-storage
```

### 6. Check Pods

```bash
kubectl get pods -n datalakehouse
```

All pods should be Running:
```
NAME                                          READY   STATUS      RESTARTS   AGE
my-lakehouse-jupyter-xxx                      1/1     Running     0          2m
my-lakehouse-minio-xxx                        1/1     Running     0          2m
my-lakehouse-spark-master-xxx                 1/1     Running     0          2m
my-lakehouse-spark-worker-xxx                 1/1     Running     0          2m
my-lakehouse-create-buckets-xxx               0/1     Completed   0          2m
```

## Storage Locations

Data will be stored on the host at:

- **MinIO Data**: `/srv/db/delta/minio/`
- **Jupyter Notebooks**: `/srv/db/delta/jupyter-notebooks/`
- **Jupyter Data**: `/srv/db/delta/jupyter-data/`

## Troubleshooting

### PVC Stuck in Pending

**Check PVC events:**
```bash
kubectl describe pvc <pvc-name> -n datalakehouse
```

**Common issues:**
1. PV not available
2. Storage size mismatch
3. Access mode mismatch
4. StorageClass not found

**Solution:**
```bash
# Check PVs
kubectl get pv

# Check StorageClass
kubectl get storageclass

# Ensure directory exists on node
sudo ls -la /srv/db/delta
```

### Permission Denied Errors

**Fix directory permissions:**
```bash
sudo chmod -R 777 /srv/db/delta
```

### Pod Can't Mount Volume

**Check pod events:**
```bash
kubectl describe pod <pod-name> -n datalakehouse
```

**Verify node has directory:**
```bash
# SSH to the node where pod is scheduled
kubectl get pod <pod-name> -n datalakehouse -o wide
# Then check the node
sudo ls -la /srv/db/delta
```

## Data Persistence

With `reclaimPolicy: Retain`:
- Data persists even after PVC deletion
- Data persists after pod restarts
- Data persists after Helm uninstall

**To clean up data manually:**
```bash
sudo rm -rf /srv/db/delta/*
```

## Cleanup

### Uninstall Helm Release
```bash
helm uninstall my-lakehouse -n datalakehouse
```

### Delete PVCs (optional)
```bash
kubectl delete pvc --all -n datalakehouse
```

### Delete PVs (optional)
```bash
kubectl delete pv minio-pv jupyter-notebooks-pv jupyter-data-pv
```

### Delete StorageClass (optional)
```bash
kubectl delete storageclass delta-storage
```

### Delete Data (optional)
```bash
sudo rm -rf /srv/db/delta
```

## Notes

- PVs use `hostPath`, so pods must be scheduled on nodes with the directory
- For multi-node clusters, consider using NFS or other shared storage
- For production, use dynamic provisioning with a proper storage provider
- Current setup is suitable for single-node or development clusters