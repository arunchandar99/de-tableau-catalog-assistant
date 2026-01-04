-- ============================================
-- 01_setup.sql
-- Database, Schema, Stage, and File Format
-- ============================================

-- Create database
CREATE DATABASE TABLEAU_CATALOG;

-- Create schema
CREATE SCHEMA TABLEAU_CATALOG.MAIN;

-- Set context
USE DATABASE TABLEAU_CATALOG;
USE SCHEMA MAIN;

-- Create stage for raw files
CREATE OR REPLACE STAGE RAW_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Raw files for Tableau catalog';

-- Create file format to handle commas in text fields
CREATE OR REPLACE FILE FORMAT CSV_WITH_QUOTES
    TYPE = 'CSV'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n';

-- ============================================
-- Next Steps:
-- 1. Upload tableau_catalog_sample.csv to RAW_STAGE via Snowsight
--    (Data → Databases → TABLEAU_CATALOG → MAIN → Stages → RAW_STAGE → + Files)
-- 2. Run 02_tables.sql
-- ============================================
