#property strict
#property version "0.1"
#property description "Educational/demo MT5 EA. Live trading disabled by default."

#include <Trade/Trade.mqh>
CTrade trade;

input bool   LiveTrading = false;
input double RiskPercent = 0.25;
input double DailyLossLimitPercent = 1.0;
input double MaxDrawdownPercent = 5.0;
input int    MaxOpenPositions = 1;
input int    FastEMA = 9;
input int    SlowEMA = 21;
input int    RSIPeriod = 14;
input int    ATRPeriod = 14;
input double ATRStopMultiplier = 1.5;
input double RewardRisk = 1.5;
input int    MaxSpreadPoints = 40;
input ulong  MagicNumber = 20261005;

int fastHandle, slowHandle, rsiHandle, atrHandle;
double dayStartEquity = 0.0, peakEquity = 0.0;
datetime dayStamp = 0;

int OnInit()
{
   fastHandle = iMA(_Symbol, PERIOD_M1, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, PERIOD_M1, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle  = iRSI(_Symbol, PERIOD_M1, RSIPeriod, PRICE_CLOSE);
   atrHandle  = iATR(_Symbol, PERIOD_M1, ATRPeriod);

   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   peakEquity = dayStartEquity;
   dayStamp = TimeCurrent();

   trade.SetExpertMagicNumber(MagicNumber);
   return INIT_SUCCEEDED;
}

bool RiskLocked()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > peakEquity) peakEquity = equity;

   double dailyLoss = (dayStartEquity - equity) / dayStartEquity * 100.0;
   double drawdown = (peakEquity - equity) / peakEquity * 100.0;

   return dailyLoss >= DailyLossLimitPercent || drawdown >= MaxDrawdownPercent;
}

int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
         count++;
   }
   return count;
}

double NormalizeVolume(double volume)
{
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   volume = MathMax(minVol, MathMin(maxVol, volume));
   return MathFloor(volume / step) * step;
}

double PositionSize(double stopDistance)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0 || stopDistance <= 0) return 0.0;

   double lossPerLot = (stopDistance / tickSize) * tickValue;
   return NormalizeVolume(riskMoney / lossPerLot);
}

void OnTick()
{
   if(!LiveTrading) return; // hard demo gate
   if(RiskLocked()) return;
   if(CountOurPositions() >= MaxOpenPositions) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) return;

   double spreadPoints = (ask - bid) / point;
   if(spreadPoints > MaxSpreadPoints) return;

   double fast[2], slow[2], rsi[2], atr[2];
   if(CopyBuffer(fastHandle,0,0,2,fast) < 2) return;
   if(CopyBuffer(slowHandle,0,0,2,slow) < 2) return;
   if(CopyBuffer(rsiHandle,0,0,2,rsi) < 2) return;
   if(CopyBuffer(atrHandle,0,0,2,atr) < 2) return;

   double close0 = iClose(_Symbol, PERIOD_M1, 0);
   if(close0 <= 0 || atr[0] <= 0) return;

   bool buy = close0 > fast[0] && fast[0] > slow[0] && rsi[0] > 50 && rsi[0] < 70;
   bool sell = close0 < fast[0] && fast[0] < slow[0] && rsi[0] > 30 && rsi[0] < 50;
   if(!buy && !sell) return;

   double stopDistance = atr[0] * ATRStopMultiplier;
   double volume = PositionSize(stopDistance);
   if(volume <= 0) return;

   if(buy)
   {
      double sl = ask - stopDistance;
      double tp = ask + stopDistance * RewardRisk;
      trade.Buy(volume, _Symbol, ask, sl, tp, "AI-demo BUY");
   }
   else if(sell)
   {
      double sl = bid + stopDistance;
      double tp = bid - stopDistance * RewardRisk;
      trade.Sell(volume, _Symbol, bid, sl, tp, "AI-demo SELL");
   }
}
