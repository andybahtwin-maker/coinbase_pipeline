import pandas as pd
import numpy as np
import streamlit as st

def color_value(val):
    if pd.isna(val):
        return ""
    if val > 0:
        return f"<span style='color:green'>{val:,.2f}</span>"
    if val < 0:
        return f"<span style='color:blue'>{val:,.2f}</span>"
    return f"{val:,.2f}"

def render_colored_table(df: pd.DataFrame, cols: list[str]):
    """
    Renders a dataframe with specified cols already containing HTML spans.
    """
    st.write(
        df.to_html(escape=False, index=False),
        unsafe_allow_html=True
    )
