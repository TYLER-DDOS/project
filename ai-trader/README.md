# AI Trader — Risk-Governed Demo

Educational/paper-trading prototype. **Live trading is intentionally disabled.**

Architecture:
- MT5 Expert Advisor: market structure + EMA/RSI/ATR signal generation, position sizing and hard risk guardrails.
- Python signal layer: optional AI analysis interface; it outputs a structured recommendation but does not hold broker credentials.
- Human-controlled MT5 account: no passwords, API keys, or 2FA are stored in this repository.

Default safety:
- Demo/paper mode only
- 0.25% risk per trade
- Maximum 1 open position
- Daily loss lock at 1.0%
- Maximum account drawdown lock at 5%
- No martingale
- No averaging down
- Spread filter
- ATR-based stop loss

Before any live deployment, independently test the strategy, verify the prop firm's rules, and replace demo execution only after extensive forward testing.
