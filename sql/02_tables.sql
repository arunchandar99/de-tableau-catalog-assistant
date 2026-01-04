-- ============================================
-- 02_tables.sql
-- Raw and Clean Table Creation + Data Loading
-- ============================================

USE DATABASE TABLEAU_CATALOG;
USE SCHEMA MAIN;

-- Create raw table (preserves original data + load metadata)
CREATE OR REPLACE TABLE RAW_TABLEAU_CATALOG (
    workbook_name STRING,
    dashboard_name STRING,
    project_folder STRING,
    tableau_site STRING,
    description STRING,
    business_owner STRING,
    technical_owner STRING,
    department STRING,
    status STRING,
    created_date STRING,
    last_reviewed STRING,
    refresh_frequency STRING,
    tableau_url STRING,
    _loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    _source_file STRING
);

-- Load data from stage
COPY INTO RAW_TABLEAU_CATALOG (
    workbook_name, dashboard_name, project_folder, tableau_site,
    description, business_owner, technical_owner, department,
    status, created_date, last_reviewed, refresh_frequency, 
    tableau_url, _source_file
)
FROM (
    SELECT 
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
        METADATA$FILENAME
    FROM @RAW_STAGE
)
FILE_FORMAT = 'CSV_WITH_QUOTES';

-- Verify raw data load
SELECT COUNT(*) AS raw_row_count FROM RAW_TABLEAU_CATALOG;

-- Create clean table with proper data types
CREATE OR REPLACE TABLE TABLEAU_CATALOG AS
SELECT
    workbook_name,
    dashboard_name,
    project_folder,
    tableau_site,
    description,
    business_owner,
    technical_owner,
    department,
    status,
    TRY_TO_DATE(created_date) AS created_date,
    TRY_TO_DATE(last_reviewed) AS last_reviewed,
    refresh_frequency,
    tableau_url,
    _loaded_at,
    _source_file
FROM RAW_TABLEAU_CATALOG;

-- Verify clean data
SELECT COUNT(*) AS clean_row_count FROM TABLEAU_CATALOG;
SELECT * FROM TABLEAU_CATALOG LIMIT 5;
