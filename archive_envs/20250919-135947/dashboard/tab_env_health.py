import os
import smtplib
import streamlit as st
from dotenv import load_dotenv

load_dotenv()

def check_key(name):
    return bool(os.getenv(name))

def check_smtp():
    host = os.getenv("SMTP_HOST")
    user = os.getenv("SMTP_USER")
    pwd  = os.getenv("SMTP_PASS") or os.getenv("SMTP_PASSWORD")
    if not host or not user or not pwd:
        return False
    try:
        with smtplib.SMTP(host, int(os.getenv("SMTP_PORT", 587)), timeout=5) as server:
            server.starttls()
            server.login(user, pwd)
        return True
    except Exception:
        return False

def check_coinbase():
    return any([
        os.getenv("CB_API_KEY"),
        os.getenv("CDP_API_KEY_FILE"),
        os.getenv("COINBASE_API_KEY_ID"),
    ])

def check_ai():
    return bool(os.getenv("OPENAI_API_KEY") or os.getenv("GROQ_API_KEY"))

def render_env_health():
    st.subheader("Environment Health Check")

    checks = {
        "Coinbase API": check_coinbase(),
        "Email (SMTP)": check_smtp(),
        "AI Provider (OpenAI/Groq)": check_ai(),
        "Notion": check_key("NOTION_TOKEN"),
        "Reddit": check_key("REDDIT_CLIENT_ID") and check_key("REDDIT_CLIENT_SECRET"),
    }

    for label, ok in checks.items():
        if ok:
            st.success(f"{label}: ✅ Configured")
        else:
            st.error(f"{label}: ❌ Missing or invalid")

    st.caption("This tab auto-detects your environment variables and highlights integration readiness.")
