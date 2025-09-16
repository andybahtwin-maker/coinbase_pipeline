import pandas as pd
import numpy as np

def color_value(val):
    """Return HTML span with green/blue coloring depending on sign."""
    if pd.isna(val):
        return ""
    if val > 0:
        return f"<span style='color:green'>{val:,.2f}</span>"
    if val < 0:
        return f"<span style='color:blue'>{val:,.2f}</span>"
    return f"{val:,.2f}"
