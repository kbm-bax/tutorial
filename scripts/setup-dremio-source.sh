#!/bin/bash

# Dremio Auto-Configuration Script
# This script automatically adds MinIO as a data source in Dremio

set -e

DREMIO_URL="http://localhost:9047"
DREMIO_USER="kbm"
DREMIO_PASSWORD="pass1234"
SOURCE_NAME="my-delta"

echo "========================================"
echo "Dremio Auto-Configuration Script"
echo "========================================"
echo ""

# Wait for Dremio to be ready
echo "Waiting for Dremio to be ready..."
max_attempts=30
attempt=0
until curl -s -f "${DREMIO_URL}/apiv2/server_status" > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "ERROR: Dremio did not start within expected time"
        exit 1
    fi
    echo "Attempt $attempt/$max_attempts - Waiting for Dremio..."
    sleep 10
done

echo "✓ Dremio is ready!"
echo ""

# Check if this is first-time setup (no admin user exists)
echo "Checking if admin user exists..."
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${DREMIO_URL}/apiv2/login" \
  -H "Content-Type: application/json" \
  -d '{"userName":"'"${DREMIO_USER}"'","password":"'"${DREMIO_PASSWORD}"'"}' 2>/dev/null || echo "000")

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "000" ]; then
    echo "Admin user not found. Creating first admin user..."
    
    # Create first admin user
    BOOTSTRAP_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${DREMIO_URL}/apiv2/bootstrap/firstuser" \
      -H "Content-Type: application/json" \
      -d '{
        "userName": "'"${DREMIO_USER}"'",
        "firstName": "Admin",
        "lastName": "User",
        "email": "admin@example.com",
        "createdAt": '$(date +%s000)',
        "password": "'"${DREMIO_PASSWORD}"'"
      }')
    
    BOOTSTRAP_HTTP_CODE=$(echo "$BOOTSTRAP_RESPONSE" | tail -n1)
    
    if [ "$BOOTSTRAP_HTTP_CODE" = "200" ]; then
        echo "✓ Admin user created successfully"
        echo "  Username: ${DREMIO_USER}"
        echo "  Password: ${DREMIO_PASSWORD}"
        echo ""
        sleep 5
    else
        echo "ERROR: Failed to create admin user"
        echo "Response: $BOOTSTRAP_RESPONSE"
        exit 1
    fi
fi

# Login to get token
echo "Logging in to Dremio..."
LOGIN_RESPONSE=$(curl -s -X POST "${DREMIO_URL}/apiv2/login" \
  -H "Content-Type: application/json" \
  -d '{"userName":"'"${DREMIO_USER}"'","password":"'"${DREMIO_PASSWORD}"'"}')

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to login to Dremio"
    echo "Response: $LOGIN_RESPONSE"
    echo ""
    echo "Please ensure:"
    echo "1. Dremio is running: docker ps | grep dremio"
    echo "2. You can access: ${DREMIO_URL}"
    echo "3. Credentials are correct: ${DREMIO_USER} / ${DREMIO_PASSWORD}"
    exit 1
fi

echo "✓ Successfully logged in"
echo ""

# Check if source already exists
echo "Checking if source '${SOURCE_NAME}' already exists..."
EXISTING_SOURCE=$(curl -s -X GET "${DREMIO_URL}/apiv2/source/${SOURCE_NAME}" \
  -H "Authorization: _dremio${TOKEN}" 2>/dev/null || echo "")

if echo "$EXISTING_SOURCE" | grep -q '"name"'; then
    echo "⚠ Source '${SOURCE_NAME}' already exists"
    echo ""
    read -p "Do you want to update it? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping source creation"
        exit 0
    fi
    
    # Delete existing source
    echo "Deleting existing source..."
    SOURCE_ID=$(echo $EXISTING_SOURCE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    curl -s -X DELETE "${DREMIO_URL}/apiv2/source/${SOURCE_ID}" \
      -H "Authorization: _dremio${TOKEN}" > /dev/null
    echo "✓ Existing source deleted"
    sleep 2
fi

# Create MinIO source
echo "Creating MinIO data source..."
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${DREMIO_URL}/api/v3/catalog" \
  -H "Authorization: _dremio${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "entityType": "source",
    "name": "'"${SOURCE_NAME}"'",
    "type": "S3",
    "config": {
      "credentialType": "ACCESS_KEY",
      "accessKey": "minio",
      "accessSecret": "password",
      "secure": false,
      "externalBucketList": [],
      "enableAsync": true,
      "compatibilityMode": true,
      "rootPath": "/datalakehouse",
      "propertyList": [
        {"name": "fs.s3a.path.style.access", "value": "true"},
        {"name": "fs.s3a.endpoint", "value": "minio:9000"},
        {"name": "dremio.s3.compat", "value": "true"}
      ],
      "enableFileStatusCheck": true,
      "isCachingEnabled": true,
      "maxCacheSpacePct": 100
    },
    "metadataPolicy": {
      "authTTLMs": 86400000,
      "namesRefreshMs": 3600000,
      "datasetRefreshAfterMs": 3600000,
      "datasetExpireAfterMs": 10800000,
      "datasetUpdateMode": "PREFETCH_QUERIED",
      "deleteUnavailableDatasets": true,
      "autoPromoteDatasets": false
    },
    "accelerationGracePeriodMs": 10800000,
    "accelerationRefreshPeriodMs": 3600000,
    "accelerationNeverExpire": false,
    "accelerationNeverRefresh": false
  }')

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✓ MinIO source created successfully!"
    echo ""
    echo "========================================"
    echo "Configuration Complete!"
    echo "========================================"
    echo ""
    echo "Source Name: ${SOURCE_NAME}"
    echo "Dremio URL: ${DREMIO_URL}"
    echo "Username: ${DREMIO_USER}"
    echo "Password: ${DREMIO_PASSWORD}"
    echo ""
    echo "You can now query your Delta Lake tables:"
    echo "  SELECT * FROM \"${SOURCE_NAME}\".deltalake.bronze.users"
    echo ""
else
    echo "ERROR: Failed to create source"
    echo "HTTP Code: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi