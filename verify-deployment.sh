#!/bin/bash

echo "=== Verifying Data Lake House Deployment ==="
echo ""

NAMESPACE="datalakehouse"
RELEASE="my-lakehouse"

echo "1. Checking Pods Status:"
kubectl get pods -n $NAMESPACE
echo ""

echo "2. Checking Services:"
kubectl get svc -n $NAMESPACE
echo ""

echo "3. Checking PVCs:"
kubectl get pvc -n $NAMESPACE
echo ""

echo "4. Checking Spark Master Environment Variables:"
SPARK_MASTER_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/component=spark-master -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $SPARK_MASTER_POD"
kubectl exec -n $NAMESPACE $SPARK_MASTER_POD -- env | grep -E "AWS_|SPARK_|MINIO"
echo ""

echo "5. Checking Spark Worker Environment Variables:"
SPARK_WORKER_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/component=spark-worker -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $SPARK_WORKER_POD"
kubectl exec -n $NAMESPACE $SPARK_WORKER_POD -- env | grep -E "AWS_|SPARK_|MINIO"
echo ""

echo "6. Checking Jupyter Environment Variables:"
JUPYTER_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $JUPYTER_POD"
kubectl exec -n $NAMESPACE $JUPYTER_POD -- env | grep -E "AWS_|SPARK_|MINIO"
echo ""

echo "7. Checking Spark Configuration:"
kubectl exec -n $NAMESPACE $SPARK_MASTER_POD -- cat /opt/bitnami/spark/conf/spark-defaults.conf
echo ""

echo "8. Testing MinIO Connectivity from Jupyter:"
kubectl exec -n $NAMESPACE $JUPYTER_POD -- curl -I http://$RELEASE-minio-service:9000/minio/health/live
echo ""

echo "9. Checking MinIO Bucket:"
kubectl run -n $NAMESPACE minio-test --rm -it --image=minio/mc --restart=Never -- \
  /bin/sh -c "mc alias set myminio http://$RELEASE-minio-service:9000 minio password && mc ls myminio"
echo ""

echo "10. Checking Spark Master UI:"
echo "Access Spark Master UI at: http://$(kubectl get svc -n $NAMESPACE $RELEASE-spark-master-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"
echo ""

echo "=== Verification Complete ==="