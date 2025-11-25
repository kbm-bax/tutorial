# Dremio Auto-Configuration Scripts

These scripts automatically configure Dremio with the MinIO data source.

## Automatic Setup (via Docker Compose)

The easiest way is to let Docker Compose run the setup automatically:

```powershell
# Start all services (including auto-setup)
docker compose up -d

# The setup-dremio container will automatically:
# 1. Wait for Dremio to be ready
# 2. Create admin user (username: admin, password: admin123)
# 3. Add MinIO as a data source
# 4. Configure Delta Lake support
```

After a few minutes, you can access:
- **Dremio UI**: http://localhost:9047
- **Login**: admin / admin123
- **Query**: `SELECT * FROM "MinIO-DataLakeHouse".deltalake.bronze.users`

## Manual Setup (Windows)

If you prefer to run the setup manually or need to reconfigure:

```powershell
# Make sure Dremio is running
docker ps | grep dremio

# Run the PowerShell script
.\scripts\setup-dremio-source.ps1
```

## Manual Setup (Linux/Mac)

```bash
# Make sure Dremio is running
docker ps | grep dremio

# Make script executable
chmod +x scripts/setup-dremio-source.sh

# Run the script
./scripts/setup-dremio-source.sh
```

## Configuration Details

The scripts create a MinIO source with these settings:

```yaml
Source Name: MinIO-DataLakeHouse
Type: Amazon S3
Credentials:
  Access Key: minio
  Secret Key: password
Configuration:
  Endpoint: minio:9000
  Root Path: /datalakehouse
  Path Style Access: true
  Compatibility Mode: true
Delta Lake: Enabled (via connection properties)
```

## Default Admin Credentials

```
Username: admin
Password: admin123
```

⚠️ **Security Note**: Change these credentials in production!

To change the default credentials, edit the variables at the top of the script:
- `setup-dremio-source.ps1` (Windows)
- `setup-dremio-source.sh` (Linux/Mac)

## Troubleshooting

### Script fails with "Dremio not ready"

**Solution**: Dremio takes 1-2 minutes to start. Wait and try again:
```powershell
# Check Dremio logs
docker logs dremio

# Wait for "Dremio Daemon Started" message
# Then run the script again
```

### "Source already exists" error

**Solution**: The script will prompt you to update the existing source. Choose 'y' to update or 'n' to skip.

### "Failed to create admin user"

**Solution**: Admin user might already exist. Try logging in manually at http://localhost:9047

### Script runs but source not visible in Dremio

**Solution**:
1. Refresh the Dremio UI (F5)
2. Check the left sidebar under "Sources"
3. If still not visible, run the script again

## Verifying the Setup

1. **Check if setup container ran successfully:**
   ```powershell
   docker logs setup-dremio
   ```
   You should see: "✓ MinIO source created successfully!"

2. **Login to Dremio:**
   - URL: http://localhost:9047
   - Username: admin
   - Password: admin123

3. **Verify source exists:**
   - Look for "MinIO-DataLakeHouse" in the left sidebar
   - Expand it to see: deltalake → bronze/silver/gold

4. **Run a test query:**
   ```sql
   SELECT * FROM "MinIO-DataLakeHouse".deltalake.bronze.users
   ```

## Re-running the Setup

If you need to reconfigure:

```powershell
# Option 1: Restart the setup container
docker compose restart setup-dremio
docker logs -f setup-dremio

# Option 2: Run the script manually
.\scripts\setup-dremio-source.ps1

# Option 3: Complete reset
docker compose down
docker volume rm tutorial_dremio-data
docker compose up -d
```

## Customization

You can customize the configuration by editing the script variables:

```powershell
# In setup-dremio-source.ps1 or .sh
$DREMIO_USER = "admin"              # Change admin username
$DREMIO_PASSWORD = "admin123"       # Change admin password
$SOURCE_NAME = "MinIO-DataLakeHouse" # Change source name
```

After editing, re-run the script or restart the setup container.

## Integration with CI/CD

You can use these scripts in automated deployments:

```yaml
# Example: GitHub Actions
- name: Setup Dremio
  run: |
    docker compose up -d
    docker logs -f setup-dremio
```

## API Reference

The scripts use Dremio's REST API v2:
- **Login**: `POST /apiv2/login`
- **Bootstrap**: `PUT /apiv2/bootstrap/firstuser`
- **Create Source**: `POST /apiv2/source/{name}`
- **Server Status**: `GET /apiv2/server_status`

For more details: https://docs.dremio.com/software/rest-api/
