-- ============================================
-- 03_embeddings.sql
-- Vector Embeddings for Semantic Search
-- ============================================

USE DATABASE TABLEAU_CATALOG;
USE SCHEMA MAIN;

-- Create embeddings table using Snowflake Cortex
-- e5-base-v2 generates 768-dimensional vectors
CREATE OR REPLACE TABLE TABLEAU_CATALOG_EMBEDDINGS AS
SELECT
    workbook_name,
    dashboard_name,
    description,
    SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', description) AS embedding
FROM TABLEAU_CATALOG;

-- Verify embeddings
SELECT 
    workbook_name, 
    dashboard_name, 
    ARRAY_SIZE(embedding) AS embedding_dimensions
FROM TABLEAU_CATALOG_EMBEDDINGS
LIMIT 5;
