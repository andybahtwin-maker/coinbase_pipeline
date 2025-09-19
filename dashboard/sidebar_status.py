import streamlit as st
def render_sidebar_status(has_coinbase: bool = False):
    with st.sidebar:
        st.header("Status")
        st.success("App loaded", icon="✅")
        if has_coinbase:
            st.success("Coinbase creds detected", icon="🔑")
        else:
            st.warning("Coinbase creds missing", icon="⚠️")
