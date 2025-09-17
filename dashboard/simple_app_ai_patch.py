# --- AI Summary Tab ---
with tab_ai:
    st.subheader("AI Summary")

    OPENAI_KEY = os.getenv("OPENAI_API_KEY")
    GROQ_KEY = os.getenv("GROQ_API_KEY")

    if not OPENAI_KEY and not GROQ_KEY:
        st.info("Set OPENAI_API_KEY or GROQ_API_KEY in .env to enable AI summaries.")
    else:
        snapshot = {
            "best_bid": (best_bid["exchange"], float(best_bid["bid"])) if best_bid is not None else None,
            "best_ask": (best_ask["exchange"], float(best_ask["ask"])) if best_ask is not None else None,
            "raw_spread": None if pd.isna(raw_spread) else float(raw_spread),
            "spread_pct": None if pd.isna(pct) else float(pct),
            "roundtrip_fee": None if pd.isna(roundtrip_fee) else float(roundtrip_fee),
            "net_edge": None if pd.isna(net_edge) else float(net_edge),
        }

        prompt = f"""
Summarize BTC cross-exchange spreads in 4–6 concise bullet points for a hiring manager or investor.
Be factual, clear, and professional. Data:
{json.dumps(snapshot, indent=2)}
"""

        if st.button("Generate AI Summary"):
            try:
                if OPENAI_KEY:
                    from openai import OpenAI
                    client = OpenAI(api_key=OPENAI_KEY)
                    resp = client.chat.completions.create(
                        model=os.getenv("OPENAI_MODEL","gpt-4o-mini"),
                        messages=[
                            {"role":"system","content":"Be concise, precise, professional."},
                            {"role":"user","content": prompt}
                        ],
                        temperature=0.3,
                        max_tokens=240
                    )
                    summary = resp.choices[0].message.content.strip()
                else:
                    from groq import Groq
                    client = Groq(api_key=GROQ_KEY)
                    model_name = os.getenv("GROQ_MODEL", "groq-llama-70b-v2")
                    resp = client.chat.completions.create(
                        model=model_name,
                        messages=[
                            {"role":"system","content":"Be concise, precise, professional."},
                            {"role":"user","content": prompt}
                        ],
                        temperature=0.3,
                        max_tokens=240
                    )
                    summary = resp.choices[0].message.content.strip()

                st.markdown(summary)
            except Exception as e:
                st.error(f"AI summary failed: {e}")
