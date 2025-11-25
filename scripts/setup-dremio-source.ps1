# Dremio Auto-Configuration Script for Windows
# This script automatically adds MinIO as a data source in Dremio

$ErrorActionPreference = "Stop"

$DREMIO_URL = "http://localhost:9047"
$DREMIO_USER = "kbm"
$DREMIO_PASSWORD = "pass1234"
$SOURCE_NAME = "my-delta"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dremio Auto-Configuration Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Wait for Dremio to be ready
Write-Host "Waiting for Dremio to be ready..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$dremioReady = $false

while (-not $dremioReady -and $attempt -lt $maxAttempts) {
    $attempt++
    try {
        $response = Invoke-WebRequest -Uri "$DREMIO_URL/apiv2/server_status" -Method GET -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $dremioReady = $true
        }
    }
    catch {
        Write-Host "Attempt $attempt/$maxAttempts - Waiting for Dremio..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

if (-not $dremioReady) {
    Write-Host "ERROR: Dremio did not start within expected time" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Dremio is ready!" -ForegroundColor Green
Write-Host ""

# Try to login
Write-Host "Checking if admin user exists..." -ForegroundColor Yellow
$loginBody = @{
    userName = $DREMIO_USER
    password = $DREMIO_PASSWORD
} | ConvertTo-Json

$token = $null
try {
    $loginResponse = Invoke-RestMethod -Uri "$DREMIO_URL/apiv2/login" -Method POST -Body $loginBody -ContentType "application/json" -UseBasicParsing
    $token = $loginResponse.token
}
catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "Admin user not found. Creating first admin user..." -ForegroundColor Yellow
        
        $bootstrapBody = @{
            userName = $DREMIO_USER
            firstName = "Admin"
            lastName = "User"
            email = "admin@example.com"
            createdAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            password = $DREMIO_PASSWORD
        } | ConvertTo-Json
        
        try {
            $bootstrapResponse = Invoke-RestMethod -Uri "$DREMIO_URL/apiv2/bootstrap/firstuser" -Method PUT -Body $bootstrapBody -ContentType "application/json" -UseBasicParsing
            Write-Host "✓ Admin user created successfully" -ForegroundColor Green
            Write-Host "  Username: $DREMIO_USER" -ForegroundColor Gray
            Write-Host "  Password: $DREMIO_PASSWORD" -ForegroundColor Gray
            Write-Host ""
            Start-Sleep -Seconds 5
            
            $loginResponse = Invoke-RestMethod -Uri "$DREMIO_URL/apiv2/login" -Method POST -Body $loginBody -ContentType "application/json" -UseBasicParsing
            $token = $loginResponse.token
        }
        catch {
            Write-Host "ERROR: Failed to create admin user" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "ERROR: Failed to login to Dremio" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

if (-not $token) {
    Write-Host "ERROR: Failed to obtain authentication token" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Successfully logged in" -ForegroundColor Green
Write-Host ""

# Check if source already exists
Write-Host "Checking if source '$SOURCE_NAME' already exists..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "_dremio$token"
}

$sourceExists = $false
try {
    $existingSource = Invoke-RestMethod -Uri "$DREMIO_URL/apiv2/source/$SOURCE_NAME" -Method GET -Headers $headers -UseBasicParsing
    $sourceExists = $true
}
catch {
}

if ($sourceExists) {
    Write-Host "⚠ Source '$SOURCE_NAME' already exists" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Do you want to update it? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Skipping source creation" -ForegroundColor Gray
        exit 0
    }
    
    Write-Host "Deleting existing source..." -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri "$DREMIO_URL/apiv2/source/$($existingSource.id)" -Method DELETE -Headers $headers -UseBasicParsing | Out-Null
        Write-Host "✓ Existing source deleted" -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Warning: Could not delete existing source" -ForegroundColor Yellow
    }
}

# Create MinIO source
Write-Host "Creating MinIO data source..." -ForegroundColor Yellow

$sourceConfig = @{
    entityType = "source"
    name = $SOURCE_NAME
    type = "S3"
    config = @{
        credentialType = "ACCESS_KEY"
        accessKey = "minio"
        accessSecret = "password"
        secure = $false
        externalBucketList = @()
        enableAsync = $true
        compatibilityMode = $true
        rootPath = "/datalakehouse"
        propertyList = @(
            @{name = "fs.s3a.path.style.access"; value = "true"},
            @{name = "fs.s3a.endpoint"; value = "minio:9000"},
            @{name = "dremio.s3.compat"; value = "true"}
        )
        enableFileStatusCheck = $true
        isCachingEnabled = $true
        maxCacheSpacePct = 100
    }
    metadataPolicy = @{
        authTTLMs = 86400000
        namesRefreshMs = 3600000
        datasetRefreshAfterMs = 3600000
        datasetExpireAfterMs = 10800000
        datasetUpdateMode = "PREFETCH_QUERIED"
        deleteUnavailableDatasets = $true
        autoPromoteDatasets = $false
    }
    accelerationGracePeriodMs = 10800000
    accelerationRefreshPeriodMs = 3600000
    accelerationNeverExpire = $false
    accelerationNeverRefresh = $false
} | ConvertTo-Json -Depth 10

try {
    $createResponse = Invoke-RestMethod -Uri "$DREMIO_URL/api/v3/catalog" -Method POST -Headers $headers -Body $sourceConfig -ContentType "application/json" -UseBasicParsing
    
    Write-Host "✓ MinIO source created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Configuration Complete!" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Source Name: $SOURCE_NAME" -ForegroundColor White
    Write-Host "Dremio URL: $DREMIO_URL" -ForegroundColor White
    Write-Host "Username: $DREMIO_USER" -ForegroundColor White
    Write-Host "Password: $DREMIO_PASSWORD" -ForegroundColor White
    Write-Host ""
    Write-Host "You can now query your Delta Lake tables:" -ForegroundColor Green
    Write-Host "  SELECT * FROM `"$SOURCE_NAME`".deltalake.bronze.users" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "ERROR: Failed to create source" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}