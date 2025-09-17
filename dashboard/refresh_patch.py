# Replace the sidebar refresh control in simple_app.py with this:

with st.sidebar:
    st.markdown("### Controls")
    auto_refresh = st.checkbox("Auto-refresh", value=True)
    # Default = 15s, Max = 300s (5 min)
    interval = st.number_input(
        "Refresh interval (seconds)",
        min_value=5,
        max_value=300,
        value=15,
        step=5
    )
    st.markdown("### Diagnostics")
    diag_box = st.empty()
