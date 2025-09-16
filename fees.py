from __future__ import annotations
import json
from dataclasses import dataclass
from pathlib import Path

DEFAULT_CFG = {
    "defaults": {"usd_trade_size": 100.0, "assume_role": "taker"},
    "exchanges": {
        "kraken":   {"maker": 0.0020, "taker": 0.0035},
        "bitfinex": {"maker": 0.0010, "taker": 0.0020},
        "bitstamp": {"maker": 0.0010, "taker": 0.0020},
        "coinbase": {"maker": 0.0040, "taker": 0.0060},
    },
}

@dataclass
class TradeLeg:
    exchange: str
    price: float
    role: str  # "maker" or "taker"

@dataclass
class TradeAssumptions:
    usd_size: float
    include_fees: bool = True
    role: str = "taker"

class FeeBook:
    def __init__(self, path: str = "fees_config.json"):
        self.cfg = DEFAULT_CFG
        p = Path(path)
        if p.exists():
            try:
                data = json.loads(p.read_text())
                if isinstance(data, dict) and "exchanges" in data and "defaults" in data:
                    self.cfg = data
            except Exception:
                self.cfg = DEFAULT_CFG

    def fee_pct(self, exchange: str, role: str) -> float:
        exch_table = self.cfg.get("exchanges") or DEFAULT_CFG["exchanges"]
        exch = (exchange or "").lower()
        role = role if role in ("maker", "taker") else "taker"
        return float(exch_table.get(exch, {"taker": 0.002}).get(role, 0.002))

    def default_usd(self) -> float:
        defaults = self.cfg.get("defaults") or DEFAULT_CFG["defaults"]
        return float(defaults.get("usd_trade_size", 100.0))

def compute_dollars(buy: TradeLeg, sell: TradeLeg, a: TradeAssumptions) -> dict:
    usd = float(a.usd_size)
    qty = usd / float(buy.price)
    gross_sell = qty * float(sell.price)
    gross_spread_usd = gross_sell - usd
    if not a.include_fees:
        return {
            "usd_size": usd,
            "gross_spread_usd": gross_spread_usd,
            "buy_fee_usd": 0.0,
            "sell_fee_usd": 0.0,
            "net_profit_usd": gross_spread_usd,
        }
    fb = FeeBook()
    buy_fee = usd * fb.fee_pct(buy.exchange, a.role)
    sell_fee = gross_sell * fb.fee_pct(sell.exchange, a.role)
    net = gross_spread_usd - buy_fee - sell_fee
    return {
        "usd_size": usd,
        "gross_spread_usd": gross_spread_usd,
        "buy_fee_usd": buy_fee,
        "sell_fee_usd": sell_fee,
        "net_profit_usd": net,
    }

# --- tiny renderer for Streamlit cards ---
import streamlit as st
def render_opportunity_detail(buy_ex, buy_px, sell_ex, sell_px, usd_size, include_fees, role):
    buy_leg = TradeLeg(buy_ex, buy_px, role)
    sell_leg = TradeLeg(sell_ex, sell_px, role)
    res = compute_dollars(buy_leg, sell_leg,
                          TradeAssumptions(usd_size=float(usd_size),
                                           include_fees=bool(include_fees),
                                           role=role))
    st.markdown(
        f"💵 For ${res['usd_size']:.0f}: "
        f"Gross {res['gross_spread_usd']:+.2f} | "
        f"Fees: {res['buy_fee_usd']:.2f} + {res['sell_fee_usd']:.2f} → "
        f"**Net {res['net_profit_usd']:+.2f}**"
    )
