"""
Tableau Catalog AI - Streamlit Chat Interface

A conversational interface for discovering Tableau reports
using natural language questions.

Deploy in Snowflake:
1. Go to Snowsight → Projects → Streamlit
2. Create new app named TABLEAU_CATALOG_AI
3. Set database to TABLEAU_CATALOG, schema to MAIN
4. Paste this code and run
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session

# Get Snowflake session
session = get_active_session()

# Page config
st.set_page_config(page_title="Tableau Catalog AI", page_icon="📊")

# Header
st.title("📊 Tableau Catalog AI")
st.caption("Ask questions about our Tableau reports in natural language")

# Initialize chat history
if "messages" not in st.session_state:
    st.session_state.messages = []

# Display chat history
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

# Chat input
if prompt := st.chat_input("Ask about Tableau reports..."):
    
    # Add user message to history
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)
    
    # Get AI response
    with st.chat_message("assistant"):
        with st.spinner("Searching catalog..."):
            # Escape single quotes in user input
            safe_prompt = prompt.replace("'", "''")
            query = f"SELECT ASK_TABLEAU_CATALOG('{safe_prompt}')"
            result = session.sql(query).collect()
            response = result[0][0]
            st.markdown(response)
    
    # Add assistant response to history
    st.session_state.messages.append({"role": "assistant", "content": response})

# Sidebar with example questions
with st.sidebar:
    st.header("Example Questions")
    st.markdown("""
    - What sales reports do we have?
    - Who owns the customer churn dashboard?
    - Is there a report for tracking marketing ROI?
    - What finance dashboards refresh daily?
    - Are there duplicate reports for pipeline?
    """)
    
    st.divider()
    
    st.header("About")
    st.markdown("""
    This app uses **semantic search** to find relevant 
    reports by meaning, not just keywords.
    
    Powered by:
    - Snowflake Cortex
    - Claude 3.5 Sonnet
    - e5-base-v2 embeddings
    """)
