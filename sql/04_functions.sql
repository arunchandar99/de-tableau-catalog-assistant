-- ============================================
-- 04_functions.sql
-- Semantic Search and LLM Functions
-- ============================================

USE DATABASE TABLEAU_CATALOG;
USE SCHEMA MAIN;

-- ============================================
-- Function 1: Semantic Search
-- Returns matching reports ranked by similarity
-- ============================================

CREATE OR REPLACE FUNCTION SEARCH_TABLEAU_CATALOG(query STRING)
RETURNS TABLE (
    workbook_name STRING,
    dashboard_name STRING,
    description STRING,
    similarity FLOAT
)
AS
$$
    SELECT
        workbook_name,
        dashboard_name,
        description,
        VECTOR_COSINE_SIMILARITY(
            embedding,
            SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', query)
        ) AS similarity
    FROM TABLEAU_CATALOG_EMBEDDINGS
    ORDER BY similarity DESC
    LIMIT 5
$$;

-- Test semantic search
SELECT * FROM TABLE(SEARCH_TABLEAU_CATALOG('sales pipeline'));
SELECT * FROM TABLE(SEARCH_TABLEAU_CATALOG('how are deals progressing'));
SELECT * FROM TABLE(SEARCH_TABLEAU_CATALOG('employee turnover'));


-- ============================================
-- Function 2: LLM-Powered Natural Language Answers
-- Returns conversational response with context
-- ============================================

CREATE OR REPLACE FUNCTION ASK_TABLEAU_CATALOG(user_question STRING)
RETURNS STRING
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'claude-3-5-sonnet',
        CONCAT(
            'You are a helpful assistant that answers questions about our Tableau reports catalog. ',
            'Based on the following reports from our catalog, answer the user question. ',
            'If no relevant reports exist, say so. Be concise. ',
            'Include relevant details like owner, department, and link when helpful.',
            '\n\n## Relevant Reports:\n',
            (
                SELECT LISTAGG(
                    CONCAT(
                        '**', e.workbook_name, ' > ', e.dashboard_name, '**\n',
                        'Department: ', c.department, '\n',
                        'Business Owner: ', c.business_owner, '\n',
                        'Technical Owner: ', c.technical_owner, '\n',
                        'Status: ', c.status, '\n',
                        'Refresh: ', c.refresh_frequency, '\n',
                        'URL: ', c.tableau_url, '\n',
                        'Description: ', e.description, '\n\n'
                    ), ''
                )
                FROM (
                    SELECT workbook_name, dashboard_name, description
                    FROM TABLE(SEARCH_TABLEAU_CATALOG(user_question))
                    LIMIT 3
                ) e
                JOIN TABLEAU_CATALOG c 
                    ON e.workbook_name = c.workbook_name 
                    AND e.dashboard_name = c.dashboard_name
            ),
            '\n\n## User Question:\n',
            user_question
        )
    )
$$;

-- Test LLM function
SELECT ASK_TABLEAU_CATALOG('Do we have any reports for tracking sales performance by region?');
SELECT ASK_TABLEAU_CATALOG('Who owns the customer churn dashboard?');
SELECT ASK_TABLEAU_CATALOG('What finance reports refresh daily?');
