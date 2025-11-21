I'll help you apply the suggested edit to the troubleshooting documentation. However, I notice that the suggested code snippet appears to be a configuration fragment rather than an edit to the troubleshooting document itself.

Let me clarify what you might want:

## Option 1: Add Resource Configuration to the Troubleshooting Doc

If you want to add this as a solution or configuration example in the troubleshooting guide:

Look for S3A or AWS credential errors.

### Solution 5: Test with Spark Shell
Test S3A access directly from Spark:

```bash
# Access Spark Master pod
kubectl exec -n datalakehouse -it $(kubectl get pod -n datalakehouse -l app.kubernetes.io/component=spark-master -o jsonpath='{.items[0].metadata.name}') -- bash

# Inside the pod, run spark-shell
/opt/bitnami/spark/bin/spark-shell \
  --conf spark.hadoop.fs.s3a.endpoint=http://my-lakehouse-minio-service:9000 \
  --conf spark.hadoop.fs.s3a.access.key=minio \
  --conf spark.hadoop.fs.s3a.secret.key=password \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.hadoop.fs.s3a.aws.credentials.provider=org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider

# In spark-shell, test:
val df = spark.range(10)
df.write.format("parquet").mode("overwrite").save("s3a://datalakehouse/test/")
```

## Common Issues

### Issue 1: Environment Variables Not Set
**Symptom**: `AWS_ACCESS_KEY_ID` not found in worker pods

**Fix**: Ensure spark-worker-deployment.yaml has:
```yaml
env:
  - name: AWS_ACCESS_KEY_ID
    value: {{ .Values.minio.auth.rootUser | quote }}
  - name: AWS_SECRET_ACCESS_KEY
    value: {{ .Values.minio.auth.rootPassword | quote }}
```

### Issue 2: Wrong MinIO Service Name
**Symptom**: Connection refused or unknown host

**Fix**: Verify service name:
```bash
kubectl get svc -n datalakehouse | grep minio
```

Should be: `my-lakehouse-minio-service` (or `<release-name>-minio-service`)

### Issue 3: Wrong Port
**Symptom**: Connection timeout or refused

**Fix**: Use port 9000 for internal cluster communication, not 9999

### Issue 4: Credentials Mismatch
**Symptom**: 403 Forbidden

**Fix**: Verify credentials:
```bash
# Check MinIO credentials
kubectl get secret -n datalakehouse

# Check what's configured in values
helm get values my-lakehouse -n datalakehouse
```

### Issue 5: Bucket Doesn't Exist
**Symptom**: NoSuchBucket error

**Fix**: Check bucket creation job:
```bash
kubectl logs -n datalakehouse job/my-lakehouse-create-buckets
```

## Prevention

To avoid this issue in the future:

1. ✅ Always set AWS credentials as environment variables in Spark workers
2. ✅ Use spark-defaults.conf for cluster-wide S3A configuration
3. ✅ Test MinIO connectivity before running Spark jobs
4. ✅ Verify bucket exists before writing data
5. ✅ Use consistent credentials across all components

## Still Not Working?

Run the verification script:
```bash
bash verify-deployment.sh
```

Collect logs:
```bash
# All pod logs
kubectl logs -n datalakehouse --all-containers=true --prefix=true > all-logs.txt

# Describe all resources
kubectl describe all -n datalakehouse > describe-all.txt
```

Check the logs for specific error messages and search for solutions.