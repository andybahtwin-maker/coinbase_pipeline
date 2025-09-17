import os
import streamlit as st
from dashboard.tab_env_health import render_env_health
from dashboard.sidebar_status import render_sidebar_status

st.set_page_config(page_title="Coinbase Pipeline", layout="wide")

# Sidebar status light (always visible)
render_sidebar_status()

# Main tabs
tabs = st.tabs(["Dashboard", "Balances", "AI Summary", "Env Health Check"])

with tabs[0]:
    st.subheader("Dashboard")
    st.write("🚀 Your trading dashboard content goes here.")

with tabs[1]:
    st.subheader("Balances")
    st.write("💰 Coinbase balances / multi-exchange balances here.")

with tabs[2]:
    st.subheader("AI Summary")
    st.write("🤖 AI-generated analysis (hooked to OpenAI/Groq).")

with tabs[3]:
    render_env_health()
