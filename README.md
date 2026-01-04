# Tableau Catalog Assistant

An AI-powered assistant that helps users discover Tableau reports using natural language questions. Built on Snowflake Cortex, it uses semantic search and LLM to understand what users are looking for — even when they don't know the exact report names.

---

## The Problem

Organizations with hundreds of Tableau reports face a common challenge:

- **Users don't know what reports exist** — They waste time searching or asking colleagues
- **Duplicate reports get created** — Because people can't find existing ones
- **Tribal knowledge required** — Only a few people know where everything is
- **Keyword search fails** — Users search "deal forecast" but the report is called "Pipeline Analysis"

---

## The Solution

A conversational AI assistant that:

- **Understands intent** — Users ask questions in plain English
- **Finds reports by meaning** — Not just keyword matching
- **Provides context** — Returns owner, department, status, and direct links
- **Lives in Snowflake** — No external APIs, data never leaves your environment

---

## Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACE                                 │
│                         (Streamlit Chat App)                                │
│                                                                             │
│    ┌─────────────────────────────────────────────────────────────────┐      │
│    │  "Do we have a report for tracking customer churn?"             │      │
│    └─────────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ORCHESTRATION LAYER                               │
│                      ASK_TABLEAU_CATALOG() Function                         │
│                                                                             │
│    1. Receives user question                                                │
│    2. Calls semantic search to find relevant reports                        │
│    3. Enriches results with metadata (owner, department, URL)               │
│    4. Sends context + question to LLM                                       │
│    5. Returns natural language response                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    ▼                                   ▼
┌─────────────────────────────────┐   ┌─────────────────────────────────────┐
│        SEMANTIC SEARCH          │   │         LLM GENERATION              │
│   SEARCH_TABLEAU_CATALOG()      │   │      SNOWFLAKE.CORTEX.COMPLETE      │
│                                 │   │                                     │
│  1. Convert question to vector  │   │  1. Receive relevant reports        │
│  2. Compare against all reports │   │  2. Receive user question           │
│  3. Return top matches by       │   │  3. Generate helpful response       │
│     similarity score            │   │  4. Include owner, links, etc.      │
└─────────────────────────────────┘   └─────────────────────────────────────┘
                    │                                   │
                    ▼                                   │
┌─────────────────────────────────┐                     │
│      VECTOR SIMILARITY          │                     │
│  VECTOR_COSINE_SIMILARITY()     │                     │
│                                 │                     │
│  Measures how "close" two       │                     │
│  vectors are in meaning         │                     │
└─────────────────────────────────┘                     │
                    │                                   │
                    ▼                                   │
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                     │
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  │
│  │  TABLEAU_CATALOG    │  │ TABLEAU_CATALOG_    │  │  RAW_TABLEAU_       │  │
│  │                     │  │ EMBEDDINGS          │  │  CATALOG            │  │
│  │  Clean data with    │  │                     │  │                     │  │
│  │  proper types       │  │  768-dimensional    │  │  Original data +    │  │
│  │                     │  │  vectors for each   │  │  load metadata      │  │
│  │  • workbook_name    │  │  report description │  │                     │  │
│  │  • dashboard_name   │  │                     │  │  • _loaded_at       │  │
│  │  • description      │  │                     │  │  • _source_file     │  │
│  │  • business_owner   │  │                     │  │                     │  │
│  │  • department       │  │                     │  │                     │  │
│  │  • tableau_url      │  │                     │  │                     │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Data Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │     │              │     │              │
│   CSV File   │────▶│  RAW_STAGE   │────▶│    RAW_      │────▶│   TABLEAU_   │────▶│  EMBEDDINGS  │
│              │     │              │     │   TABLEAU_   │     │   CATALOG    │     │    TABLE     │
│              │     │  (Landing    │     │   CATALOG    │     │              │     │              │
│  Source      │     │   Zone)      │     │              │     │  (Clean +    │     │  (Vectors    │
│  Data        │     │              │     │  (Raw +      │     │   Typed)     │     │   for AI)    │
│              │     │              │     │   Metadata)  │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                                                │                     │                    │
                                                ▼                     ▼                    ▼
                                          ┌─────────────────────────────────────────────────────┐
                                          │                TRANSFORMATIONS                      │
                                          │                                                     │
                                          │  • COPY INTO with METADATA$FILENAME                 │
                                          │  • TRY_TO_DATE for date parsing                     │
                                          │  • EMBED_TEXT_768 for vector generation             │
                                          └─────────────────────────────────────────────────────┘
```

**Step-by-step:**

| Step | What Happens | Why It Matters |
|------|--------------|----------------|
| 1. CSV Upload | File lands in `RAW_STAGE` | Staging allows re-processing if needed |
| 2. Raw Load | Data loaded to `RAW_TABLEAU_CATALOG` with `_loaded_at` and `_source_file` | Preserves lineage and audit trail |
| 3. Transform | Dates parsed, data cleaned into `TABLEAU_CATALOG` | Clean data for querying and joins |
| 4. Embed | Each description converted to 768-dim vector | Enables semantic (meaning-based) search |

---

### How Semantic Search Works

Traditional keyword search fails when users don't know exact terminology:

```
User searches: "deal forecasting"
Report name:   "Pipeline Analysis"
Description:   "...opportunities by stage and revenue forecasts..."

Keyword search: ❌ No match (different words)
Semantic search: ✓ Match (same meaning)
```

**How it works:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SEMANTIC SEARCH PROCESS                             │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1: EMBED THE QUESTION
┌─────────────────────────┐          ┌─────────────────────────────────────┐
│                         │          │                                     │
│  "deal forecasting"     │  ──────▶ │  [0.023, -0.041, 0.156, ... ]       │
│                         │          │  (768 numbers representing meaning) │
│                         │          │                                     │
└─────────────────────────┘          └─────────────────────────────────────┘

Step 2: COMPARE TO ALL REPORT EMBEDDINGS
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Report 1: "Pipeline Analysis"        → Similarity: 0.89  ← HIGH MATCH      │
│  Report 2: "Sales Rep Scorecard"      → Similarity: 0.72                    │
│  Report 3: "Customer Health Overview" → Similarity: 0.45                    │ 
│  Report 4: "HR Attrition Analysis"    → Similarity: 0.23                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Step 3: RETURN TOP MATCHES
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Results:                                                                   │
│  1. Pipeline Analysis (89% match)                                           │
│  2. Sales Rep Scorecard (72% match)                                         │
│  3. Customer Health Overview (45% match)                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**The math behind it:**

Cosine similarity measures the angle between two vectors. Vectors pointing in similar directions (similar meanings) have scores close to 1.

```
Similarity = cos(θ) = (A · B) / (||A|| × ||B||)

Where:
- A = question embedding
- B = report description embedding
- Score ranges from -1 to 1 (higher = more similar)
```

---

### How RAG Works

This project implements **Retrieval-Augmented Generation (RAG)** — a pattern that makes LLMs more accurate by grounding them in real data.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              RAG PATTERN                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│             │     │             │     │             │     │             │
│  RETRIEVE   │────▶│   AUGMENT   │────▶│  GENERATE   │────▶│   RESPOND   │
│             │     │             │     │             │     │             │
│  Find       │     │  Add        │     │  LLM        │     │  Natural    │
│  relevant   │     │  metadata   │     │  creates    │     │  language   │
│  reports    │     │  context    │     │  answer     │     │  response   │
│             │     │             │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

**Why RAG?**

| Without RAG | With RAG |
|-------------|----------|
| LLM makes up answers | LLM answers based on real data |
| Can't know about your reports | Knows exactly what reports exist |
| Generic responses | Specific, actionable responses |
| May hallucinate | Grounded in facts |

**Example flow:**

```
User: "Who owns the customer churn dashboard?"

RETRIEVE:
  → Semantic search finds "Churn Analysis Dashboard"
  → Returns description + metadata

AUGMENT:
  → Adds: Owner: Sarah Chen
  → Adds: Department: Customer Success
  → Adds: URL: https://tableau.company.com/...

GENERATE:
  → LLM receives question + context
  → Creates response: "The customer churn dashboard is owned by 
     Sarah Chen in the Customer Success department. You can 
     access it here: [link]"
```

---

## Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Data Warehouse | Snowflake | Storage, compute, hosting |
| Embedding Model | e5-base-v2 (via Cortex) | Converts text to vectors |
| LLM | Claude 3.5 Sonnet (via Cortex) | Generates natural language responses |
| Vector Search | VECTOR_COSINE_SIMILARITY | Finds similar meanings |
| UI | Streamlit in Snowflake | Chat interface |
| Data Format | CSV | Source data |

### Snowflake Cortex Functions Used

| Function | What It Does |
|----------|--------------|
| `SNOWFLAKE.CORTEX.EMBED_TEXT_768()` | Converts text to 768-dimensional vector |
| `VECTOR_COSINE_SIMILARITY()` | Compares two vectors, returns similarity score |
| `SNOWFLAKE.CORTEX.COMPLETE()` | Sends prompt to LLM, returns response |

---

## Project Structure

```
de-tableau-catalog-assistant/
│
├── README.md                    # This file
├── .gitignore                   # Git ignore rules
│
├── sql/
│   ├── 01_setup.sql            # Database, schema, stage, file format
│   ├── 02_tables.sql           # Raw and clean table DDL + data loading
│   ├── 03_embeddings.sql       # Vector embeddings generation
│   └── 04_functions.sql        # Search and LLM functions
│
├── streamlit/
│   └── app.py                  # Chat UI application
│
└── data/
    └── tableau_catalog_sample.csv   # Sample dataset (100 reports)
```

---

## Setup Instructions

### Prerequisites

- Snowflake account with Cortex enabled
- Warehouse with sufficient compute
- Basic SQL knowledge

### Step 1: Create Database and Schema

```sql
CREATE DATABASE TABLEAU_CATALOG;
CREATE SCHEMA TABLEAU_CATALOG.MAIN;
USE DATABASE TABLEAU_CATALOG;
USE SCHEMA MAIN;
```

### Step 2: Run Setup Script

Run `sql/01_setup.sql` to create:
- Stage for file uploads
- File format for CSV parsing

### Step 3: Upload Sample Data

1. Go to Snowsight → Data → Databases → TABLEAU_CATALOG → MAIN → Stages
2. Click on `RAW_STAGE`
3. Click "+ Files" and upload `data/tableau_catalog_sample.csv`

### Step 4: Create Tables and Load Data

Run `sql/02_tables.sql` to:
- Create raw table with audit columns
- Load data from stage
- Create clean table with proper data types

### Step 5: Generate Embeddings

Run `sql/03_embeddings.sql` to:
- Create embeddings table
- Generate 768-dimensional vectors for each report description

### Step 6: Create Functions

Run `sql/04_functions.sql` to create:
- `SEARCH_TABLEAU_CATALOG()` — Returns matching reports
- `ASK_TABLEAU_CATALOG()` — Returns natural language answers

### Step 7: Deploy Streamlit App

1. Go to Snowsight → Projects → Streamlit
2. Click "+ Streamlit App"
3. Name: `TABLEAU_CATALOG_ASSISTANT`
4. Database: `TABLEAU_CATALOG`
5. Schema: `MAIN`
6. Paste code from `streamlit/app.py`
7. Click "Run"

---

## Usage

### Option 1: SQL Queries

```sql
-- Semantic search (returns matching reports)
SELECT * FROM TABLE(SEARCH_TABLEAU_CATALOG('sales pipeline'));

-- Natural language question (returns conversational answer)
SELECT ASK_TABLEAU_CATALOG('Who owns the customer churn dashboard?');

-- More examples
SELECT ASK_TABLEAU_CATALOG('What reports refresh daily?');
SELECT ASK_TABLEAU_CATALOG('Do we have any marketing ROI dashboards?');
SELECT ASK_TABLEAU_CATALOG('Are there duplicate reports for pipeline analysis?');
```

### Option 2: Streamlit Chat UI

Open the deployed Streamlit app and ask questions like:
- "What sales reports do we have?"
- "Who owns the customer churn dashboard?"
- "Is there a report for tracking marketing ROI?"
- "What finance dashboards refresh daily?"

---

## Sample Questions

| Question Type | Example |
|---------------|---------|
| Discovery | "What reports do we have for sales?" |
| Ownership | "Who owns the pipeline dashboard?" |
| Existence | "Do we have a customer churn report?" |
| Duplicates | "Are there similar reports for revenue tracking?" |
| Metadata | "What reports refresh daily?" |
| Location | "Where can I find marketing campaign data?" |

---

## Data Model

### RAW_TABLEAU_CATALOG

| Column | Type | Description |
|--------|------|-------------|
| workbook_name | STRING | Tableau workbook name |
| dashboard_name | STRING | Dashboard name within workbook |
| project_folder | STRING | Folder path in Tableau |
| tableau_site | STRING | Tableau site (Production/Development) |
| description | STRING | Human-written description of the report |
| business_owner | STRING | Business stakeholder |
| technical_owner | STRING | Technical maintainer |
| department | STRING | Owning department |
| status | STRING | active/deprecated/draft |
| created_date | STRING | When report was created |
| last_reviewed | STRING | Last review date |
| refresh_frequency | STRING | daily/weekly/monthly/quarterly |
| tableau_url | STRING | Direct link to report |
| _loaded_at | TIMESTAMP | When row was loaded |
| _source_file | STRING | Source file name |

### TABLEAU_CATALOG

Same as above but with:
- `created_date` as DATE type
- `last_reviewed` as DATE type

### TABLEAU_CATALOG_EMBEDDINGS

| Column | Type | Description |
|--------|------|-------------|
| workbook_name | STRING | Tableau workbook name |
| dashboard_name | STRING | Dashboard name |
| description | STRING | Report description |
| embedding | VECTOR(768) | 768-dimensional vector |

---

## Key Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Embedding model | e5-base-v2 | Good balance of quality and speed |
| LLM | Claude 3.5 Sonnet | High quality responses |
| Vector dimensions | 768 | Standard size, good accuracy |
| Top K results | 5 for search, 3 for LLM | Balance relevance and context |
| Data storage | Single schema | MVP simplicity |

---

## Future Enhancements

- [ ] Automated sync with Tableau Metadata API
- [ ] Usage analytics (track popular searches)
- [ ] Feedback loop to improve results
- [ ] Slack integration
- [ ] Multi-field search (combine description + name + tags)
- [ ] Caching for common queries

---

## Lessons Learned

1. **Semantic search beats keyword search** — Users don't know exact terminology
2. **RAG grounds LLMs** — Prevents hallucination, provides accurate answers
3. **Staging layer matters** — Even for simple projects, enables re-processing
4. **Description quality is key** — Garbage in, garbage out for embeddings
5. **Cortex simplifies AI** — No external APIs, data stays in Snowflake

---

## License

MIT
