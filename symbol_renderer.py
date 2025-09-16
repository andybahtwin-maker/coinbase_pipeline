import streamlit as st

def render_symbol(sym, data, trade_usd, role, taker_pct, maker_pct):
    stamp = data['sources']['bitstamp']
    finex = data['sources']['bitfinex']
    diff_abs = data['diff_abs']
    diff_pct = data['diff_pct']

    # Fee estimates prepared by caller's est_fees in main file
    # (We recompute here to be self-contained.)
    def _est(price, pct):
        qty = trade_usd / price if price > 0 else 0.0
        return qty * price * (pct/100.0)

    f_stamp = _est(stamp, taker_pct if role=="taker" else maker_pct)
    f_finex = _est(finex, taker_pct if role=="taker" else maker_pct)

    top_left, top_right = st.columns(2)
    with top_left:
        st.metric(f"{sym} — Bitstamp", f"${stamp:,.2f}")
        st.caption(f"{role} fee @ {(taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_stamp:,.2f}")
    with top_right:
        st.metric(f"{sym} — Bitfinex", f"${finex:,.2f}")
        st.caption(f"{role} fee @ {(taker_pct if role=='taker' else maker_pct):.2f}% ≈ ${f_finex:,.2f}")

    roundtrip_fee = f_stamp + f_finex

    bottom_left, bottom_right = st.columns(2)
    with bottom_left:
        st.metric("Spread ($)", f"{diff_abs:+,.2f}")
        st.caption(f"Spread (%) {diff_pct:+.4f}%")
    with bottom_right:
        st.metric("2-leg fee est.", f"${roundtrip_fee:,.2f}")
        st.caption("Sum of one-leg fees across both venues")
