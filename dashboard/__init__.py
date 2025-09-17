import streamlit as st

# Inject dark cockpit theme
def load_theme():
    with open("dashboard/theme.css") as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)
