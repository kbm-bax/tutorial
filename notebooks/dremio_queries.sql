-- Dremio SQL Query Examples for Delta Lake Tables
-- Use these queries in Dremio Web UI (http://localhost:9047)

-- ============================================
-- BASIC QUERIES
-- ============================================

-- Query Bronze Layer (Raw Data)
SELECT * 
FROM "MinIO-DataLakeHouse".deltalake.bronze.users
ORDER BY id;

-- Query Silver Layer (Cleaned Data)
SELECT * 
FROM "MinIO-DataLakeHouse".deltalake.silver.users
ORDER BY id;

-- Query Gold Layer (Aggregated Data)
SELECT * 
FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
ORDER BY count DESC;


-- ============================================
-- ANALYTICAL QUERIES
-- ============================================

-- Count records by layer
SELECT 'Bronze' as layer, COUNT(*) as record_count
FROM "MinIO-DataLakeHouse".deltalake.bronze.users
UNION ALL
SELECT 'Silver' as layer, COUNT(*) as record_count
FROM "MinIO-DataLakeHouse".deltalake.silver.users;

-- Join Silver and Gold layers
SELECT 
    s.id,
    s.name,
    s.timestamp,
    g.count as aggregated_count
FROM "MinIO-DataLakeHouse".deltalake.silver.users s
LEFT JOIN "MinIO-DataLakeHouse".deltalake.gold.user_summary g
    ON s.name = g.name
ORDER BY s.id;

-- Filter by date
SELECT *
FROM "MinIO-DataLakeHouse".deltalake.bronze.users
WHERE timestamp >= '2025-01-02'
ORDER BY timestamp;


-- ============================================
-- TIME TRAVEL QUERIES (Delta Lake Feature)
-- ============================================

-- Query a specific version of the table
SELECT * 
FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
AT VERSION AS OF 0;

-- Query as of a specific timestamp
SELECT * 
FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
AT TIMESTAMP AS OF '2025-01-15 10:00:00';

-- Compare current vs previous version
SELECT 
    'Current' as version,
    name,
    count
FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
UNION ALL
SELECT 
    'Previous' as version,
    name,
    count
FROM "MinIO-DataLakeHouse".deltalake.gold.user_summary
AT VERSION AS OF 0;


-- ============================================
-- AGGREGATIONS AND ANALYTICS
-- ============================================

-- Count users by name prefix
SELECT 
    SUBSTRING(name, 1, 1) as first_letter,
    COUNT(*) as user_count
FROM "MinIO-DataLakeHouse".deltalake.silver.users
GROUP BY SUBSTRING(name, 1, 1)
ORDER BY first_letter;

-- Date-based aggregations
SELECT 
    timestamp,
    COUNT(*) as records_per_day
FROM "MinIO-DataLakeHouse".deltalake.bronze.users
GROUP BY timestamp
ORDER BY timestamp;


-- ============================================
-- DATA QUALITY CHECKS
-- ============================================

-- Check for null values
SELECT 
    COUNT(*) as total_records,
    COUNT(id) as non_null_ids,
    COUNT(name) as non_null_names,
    COUNT(timestamp) as non_null_timestamps
FROM "MinIO-DataLakeHouse".deltalake.silver.users;

-- Find duplicate IDs
SELECT 
    id,
    COUNT(*) as occurrence_count
FROM "MinIO-DataLakeHouse".deltalake.silver.users
GROUP BY id
HAVING COUNT(*) > 1;


-- ============================================
-- CREATING VIRTUAL DATASETS (VIEWS)
-- ============================================

-- Create a view combining all layers
-- (Execute this in Dremio UI, then save as a Virtual Dataset)
SELECT 
    b.id,
    b.name,
    b.location as original_location,
    b.timestamp as ingestion_time,
    s.timestamp as processed_time,
    g.count as summary_count
FROM "MinIO-DataLakeHouse".deltalake.bronze.users b
LEFT JOIN "MinIO-DataLakeHouse".deltalake.silver.users s
    ON b.id = s.id
LEFT JOIN "MinIO-DataLakeHouse".deltalake.gold.user_summary g
    ON b.name = g.name
ORDER BY b.id;


-- ============================================
-- PERFORMANCE OPTIMIZATION
-- ============================================

-- Use EXPLAIN to see query execution plan
EXPLAIN PLAN FOR
SELECT * 
FROM "MinIO-DataLakeHouse".deltalake.silver.users
WHERE id > 1;

-- Limit results for testing
SELECT * 
FROM "MinIO-DataLakeHouse".deltalake.bronze.users
LIMIT 10;


-- ============================================
-- NOTES
-- ============================================
-- 1. Always refresh metadata after running PySpark pipelines
-- 2. Use reflections for frequently queried tables
-- 3. Delta Lake format must be enabled in source settings
-- 4. Time travel queries require Delta Lake history to exist
</contents>