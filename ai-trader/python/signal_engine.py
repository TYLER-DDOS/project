"""
AI-assisted signal scoring prototype.
This module deliberately does NOT connect to a broker or place orders.
Feed it candle data and use the returned decision for paper trading/backtesting.
"""

from dataclasses import dataclass
from typing import Literal

Side = Literal["BUY", "SELL", "FLAT"]

@dataclass
class Signal:
    side: Side
    score: float
    reason: str

def score_signal(close: float, ema_fast: float, ema_slow: float,
                 rsi: float, atr: float, min_atr: float = 0.0) -> Signal:
    if atr <= min_atr:
        return Signal("FLAT", 0.0, "Volatility filter failed")

    score = 0.0
    reasons = []

    if close > ema_fast > ema_slow:
        score += 0.45
        reasons.append("bullish EMA alignment")
    elif close < ema_fast < ema_slow:
        score -= 0.45
        reasons.append("bearish EMA alignment")

    if 50 < rsi < 70:
        score += 0.25
        reasons.append("bullish RSI regime")
    elif 30 < rsi < 50:
        score -= 0.25
        reasons.append("bearish RSI regime")
    elif rsi >= 70 or rsi <= 30:
        return Signal("FLAT", 0.0, "RSI exhaustion filter")

    if score >= 0.60:
        return Signal("BUY", score, ", ".join(reasons))
    if score <= -0.60:
        return Signal("SELL", abs(score), ", ".join(reasons))
    return Signal("FLAT", abs(score), ", ".join(reasons) or "No alignment")
