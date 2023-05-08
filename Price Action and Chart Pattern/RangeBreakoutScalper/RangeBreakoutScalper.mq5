//+------------------------------------------------------------------+
//|                                       Range Breakout Scalper.mq5 |
//|                                   Copyright 2023, Handiko Gesang |
//|                                   https://www.github.com/handiko |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Handiko Gesang"
#property link      "https://www.github.com/handiko"
#property version   "1.00"

#define VERSION "1.0"
#property version VERSION

#define PROJECT_NAME MQLInfoString(MQL_PROGRAM_NAME)

#include <Trade/Trade.mqh>

input group  "Risk Management"
static input double Lots = 0.1;
input group "Technical Parameters"
input int Lookback = 29;                        // Lookback period (bars)
input int TakeProfit = 260;                     // Take Profit (points)
input int StopLoss = 100;                       // Stop Loss (points)
input int TraillingStop = 10;                   // Trailling Stop (points)
input int TraillingTrigger = 20;                // Trailling Stop Trigger (points)
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15;

input group "Time Parameters"
input int ExpirationHours = 2;                  // Expiration Hours
input bool useTimeFilter = true;                // Using Time Filter?
input int StartTradingTime = 14;                // Trading Start at Hour (server time)
input int StopTradingTime = 21;                 // Trading Stop at Hour (server time)

input group "General Settings"
input static int Magic = 1;                     // Magic Number

CTrade trade;

ulong buyPos, sellPos;
int totalBars;
string currentTime, startTime, stopTime;
bool tradingIsAllowed = false;
int BufferDist = 0;

int atrHandle;
double atrVal[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
     trade.SetExpertMagicNumber(Magic);
     if(!trade.SetTypeFillingBySymbol(_Symbol)) {
          trade.SetTypeFilling(ORDER_FILLING_RETURN);
     }

     static bool isInit = false;
     if(!isInit) {
          isInit = true;
          Print(__FUNCTION__, " > EA (re)start...");
          Print(__FUNCTION__, " > EA version ", VERSION, "...");

          for(int i = PositionsTotal() - 1; i >= 0; i--) {
               CPositionInfo pos;
               if(pos.SelectByIndex(i)) {
                    if(pos.Magic() != Magic)
                         continue;
                    if(pos.Symbol() != _Symbol)
                         continue;

                    Print(__FUNCTION__, " > Found open position with ticket #", pos.Ticket(), "...");
                    if(pos.PositionType() == POSITION_TYPE_BUY)
                         buyPos = pos.Ticket();
                    if(pos.PositionType() == POSITION_TYPE_SELL)
                         sellPos = pos.Ticket();
               }
          }

          for(int i = OrdersTotal() - 1; i >= 0; i--) {
               COrderInfo order;
               if(order.SelectByIndex(i)) {
                    if(order.Magic() != Magic)
                         continue;
                    if(order.Symbol() != _Symbol)
                         continue;

                    Print(__FUNCTION__, " > Found pending order with ticket #", order.Ticket(), "...");
                    if(order.OrderType() == ORDER_TYPE_BUY_STOP)
                         buyPos = order.Ticket();
                    if(order.OrderType() == ORDER_TYPE_SELL_STOP)
                         sellPos = order.Ticket();
               }
          }
     }

     StringConcatenate(startTime, IntegerToString(StartTradingTime, 2, '0'), ":00");
     StringConcatenate(stopTime, IntegerToString(StopTradingTime, 2, '0'), ":30");

     return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
     IndicatorDeinit();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
{
     datetime time = TimeCurrent();
     currentTime = TimeToString(time, TIME_MINUTES);
     if(useTimeFilter) {
          tradingIsAllowed = CheckTradingTime();
     } else {
          tradingIsAllowed = true;
     }

     processPos(buyPos);
     processPos(sellPos);

     int bars = iBars(_Symbol, Timeframe);
     if(totalBars != bars) {
          totalBars = bars;

          if(buyPos <= 0) {
               double high = findHigh();
               if(high > 0) {
                    if(tradingIsAllowed) {
                         executeBuy(high);
                    }
               }
          } else {
               if(!tradingIsAllowed) {
                    deletePendingOrder(buyPos);
               }
          }

          if(sellPos <= 0) {
               double low = findLow();
               if(low > 0) {
                    if(tradingIsAllowed) {
                         executeSell(low);
                    }
               }
          } else {
               if(!tradingIsAllowed) {
                    deletePendingOrder(sellPos);
               }
          }
     }

     Comment("Scalper V1 \n",
             "Handiko Gesang \n",
             "\n",
             "Using Time Filter? ", useTimeFilter, "\n",
             "Trading is allowed = ", tradingIsAllowed, "\n",
             "Current Time = ", currentTime, "\n",
             "Start trading time = ", startTime, "\n",
             "Stop trading time = ", stopTime);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void IndicatorInit()
{
     atrHandle = iATR(_Symbol, Timeframe, 14);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void IndicatorDeinit()
{
     IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckTradingTime()
{
     if(StringSubstr(currentTime, 0, 5) == startTime) {
          tradingIsAllowed = true;
     }

     if(StringSubstr(currentTime, 0, 5) == stopTime) {
          tradingIsAllowed = false;
     }

     return tradingIsAllowed;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void deletePendingOrder(ulong & posTicket)
{
     trade.OrderDelete(posTicket);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  OnTradeTransaction(
     const MqlTradeTransaction&    trans,
     const MqlTradeRequest&        request,
     const MqlTradeResult&         result
)
{

     if(trans.type == TRADE_TRANSACTION_ORDER_ADD) {
          COrderInfo order;
          if(order.Select(trans.order)) {
               if(order.Magic() == Magic) {
                    if(order.OrderType() == ORDER_TYPE_BUY_STOP) {
                         buyPos = order.Ticket();
                    } else if(order.OrderType() == ORDER_TYPE_SELL_STOP) {
                         sellPos = order.Ticket();
                    }
               }
          }
     }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void processPos(ulong &posTicket)
{
     if(posTicket <= 0)
          return;
     if(OrderSelect(posTicket))
          return;

     CPositionInfo pos;
     if(!pos.SelectByTicket(posTicket)) {
          posTicket = 0;
          return;
     } else {
          if(pos.PositionType() == POSITION_TYPE_BUY) {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

               if(bid > pos.PriceOpen() + TraillingTrigger * _Point) {
                    double sl = bid - TraillingStop * _Point;
                    sl = NormalizeDouble(sl, _Digits);

                    if(sl > pos.StopLoss()) {
                         trade.PositionModify(pos.Ticket(), sl, pos.TakeProfit());
                    }
               }
          } else if(pos.PositionType() == POSITION_TYPE_SELL) {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

               if(ask < pos.PriceOpen() - TraillingTrigger * _Point) {
                    double sl = ask + TraillingStop * _Point;
                    sl = NormalizeDouble(sl, _Digits);

                    if(sl < pos.StopLoss() || pos.StopLoss() == 0) {
                         trade.PositionModify(pos.Ticket(), sl, pos.TakeProfit());
                    }
               }
          }
     }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void executeBuy(double entry)
{
     entry = NormalizeDouble(entry, _Digits);

     double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     if(ask > entry - BufferDist * _Point)
          return;

     double tp = entry + TakeProfit * _Point;
     tp = NormalizeDouble(tp, _Digits);

     double sl = entry - StopLoss * _Point;
     sl = NormalizeDouble(sl, _Digits);

     datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpirationHours * PeriodSeconds(PERIOD_H1);

     trade.BuyStop(Lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);

     buyPos = trade.ResultOrder();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void executeSell(double entry)
{
     entry = NormalizeDouble(entry, _Digits);

     double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     if(bid < entry + BufferDist * _Point)
          return;

     double tp = entry - TakeProfit * _Point;
     tp = NormalizeDouble(tp, _Digits);

     double sl = entry + StopLoss * _Point;
     sl = NormalizeDouble(sl, _Digits);

     datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpirationHours * PeriodSeconds(PERIOD_H1);

     trade.SellStop(Lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);

     sellPos = trade.ResultOrder();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double findHigh()
{
     /*
     double highestHigh = 0;
     for(int i = 0; i < SearchDepth; i++) {
          double high = iHigh(_Symbol, Timeframe, i);
          if(i > NumBars && iHighest(_Symbol, Timeframe, MODE_HIGH, NumBars * 2 + 1, i - NumBars) == i) {
               if(high > highestHigh) {
                    return high;
               }
          }
          highestHigh = MathMax(high, highestHigh);
     }
     return -1;
     */

     double highestLookback = 0;
     for(int i = 0; i < Lookback; i++) {
          double tmp = iHigh(_Symbol, Timeframe, i + 1);
          if(tmp > highestLookback) {
               highestLookback = tmp;
          }
     }

     double lowestLookback = DBL_MAX;
     for(int i = 0; i < Lookback; i++) {
          double tmp = iLow(_Symbol, Timeframe, i + 1);
          if(tmp < lowestLookback) {
               lowestLookback = tmp;
          }
     }

     double close = iClose(_Symbol, Timeframe, 1);
     double range = highestLookback - lowestLookback;
     if(close < (0.5 * range + lowestLookback)) {
          return highestLookback;
     }

     return -1;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double findLow()
{
     /*
     double lowestLow = DBL_MAX;
     for(int i = 0; i < SearchDepth; i++) {
          double low = iLow(_Symbol, Timeframe, i);
          if(i > NumBars && iLowest(_Symbol, Timeframe, MODE_LOW, NumBars * 2 + 1, i - NumBars) == i) {
               if(low < lowestLow) {
                    return low;
               }
          }
          lowestLow = MathMin(low, lowestLow);
     }
     return -1;
     */

     double highestLookback = 0;
     for(int i = 0; i < Lookback; i++) {
          double tmp = iHigh(_Symbol, Timeframe, i + 1);
          if(tmp > highestLookback) {
               highestLookback = tmp;
          }
     }

     double lowestLookback = DBL_MAX;
     for(int i = 0; i < Lookback; i++) {
          double tmp = iLow(_Symbol, Timeframe, i + 1);
          if(tmp < lowestLookback) {
               lowestLookback = tmp;
          }
     }

     double close = iClose(_Symbol, Timeframe, 1);
     double range = highestLookback - lowestLookback;
     if(close > (0.5 * range + lowestLookback)) {
          return lowestLookback;
     }

     return -1;
}
//+------------------------------------------------------------------+
