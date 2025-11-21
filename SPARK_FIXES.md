# Spark Deployment Fixes Applied

## Issues Fixed

1. **wget command not found** - Bitnami image doesn't include wget
2. **Wrong Spark paths** - Bitnami uses `/opt/bitnami/spark` instead of `/usr/local/spark`
3. **Missing startup script** - Need to use bitnami's run.sh script

## Changes Made

### Spark Master Deployment
- Changed from `wget` to `curl` for downloading JARs
- Updated JAR download path to `/opt/bitnami/spark/jars/`
- Added Delta Storage JAR (required dependency)
- Changed startup command to `/opt/bitnami/scripts/spark/run.sh`
- Updated config mount path to `/opt/bitnami/spark/conf/`
- Added bitnami-specific environment variables

### Spark Worker Deployment
- Same JAR download fixes as master
- Changed master readiness check from `nc` to `curl`
- Updated startup to use bitnami run.sh script
- Updated config mount path
- Added bitnami-specific environment variables

## JARs Downloaded

1. hadoop-aws-3.3.4.jar
2. aws-java-sdk-bundle-1.12.262.jar
3. delta-spark_2.12-3.2.0.jar
4. delta-storage-3.2.0.jar

## Test Again

After these fixes, redeploy:

```bash
helm uninstall my-lakehouse -n datalakehouse
helm install my-lakehouse ./helm-chart -n datalakehouse
```

Check logs:
```bash
kubectl logs -n datalakehouse -l app.kubernetes.io/component=spark-master -f
kubectl logs -n datalakehouse -l app.kubernetes.io/component=spark-worker -f
```