with tab_spreads:
    from dashboard.color_utils import color_value

    if not valid.empty:
        rows = []
        for sell in valid.itertuples():
            for buy in valid.itertuples():
                if sell.exchange == buy.exchange:
                    continue
                gross = sell.bid - buy.ask
                f = fee_usd(buy.ask, fees_map.get(buy.exchange, 15.0)) \
                  + fee_usd(sell.bid, fees_map.get(sell.exchange, 15.0))
                rows.append({
                    "sell@": sell.exchange,
                    "buy@": buy.exchange,
                    "gross_spread": gross,
                    "fees": f,
                    "net_after_fees": gross - f
                })
        opp = pd.DataFrame(rows).sort_values("net_after_fees", ascending=False)

        opp["gross_spread"] = opp["gross_spread"].map(color_value)
        opp["fees"]         = opp["fees"].map(lambda v: f"<span style='color:blue'>{v:,.2f}</span>")
        opp["net_after_fees"] = opp["net_after_fees"].map(color_value)

        # Render HTML so spans actually display as colored text
        import streamlit as st
        st.write(
            opp[["sell@","buy@","gross_spread","fees","net_after_fees"]].to_html(
                escape=False, index=False
            ),
            unsafe_allow_html=True
        )
    else:
        st.info("No valid price data yet (APIs may have timed out).")
