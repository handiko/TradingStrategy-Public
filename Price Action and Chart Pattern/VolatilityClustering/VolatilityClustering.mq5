//+------------------------------------------------------------------+
//|                                         VolatilityClustering.mq5 |
//|                                   Copyright 2023, Handiko Gesang |
//|                                   https://www.github.com/handiko |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Handiko Gesang"
#property link      "https://www.github.com/handiko"
#property version   "1.00"

#define VERSION "1.00"
#define PROJECT_NAME MQLInfoString(MQL_PROGRAM_NAME)

#include <Trade/trade.mqh>

// INPUTS
static input int Magic = 12345;
static input double Lots = 0.1;
input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input int lookback = 4;
input int atrPeriod = 20;
input double atrMult = 2.1;
enum ENUM_SLMODE {
     SLMODE_ATR,
     SLMODE_FIXED
};
input ENUM_SLMODE slMode = SLMODE_FIXED;
input int slPoint = 2350;
input double tpFactor = 0.75;
input int pendingDistance = 210;
input int ExpirationHours = 23;

// GLOBAL VARIABLES
CTrade trade;
ulong buyPos, sellPos;
int totalBars;
double slDistance, tpDistance;
int atrHandle;
double atrBuffer[];
int tpPoint;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//---
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
                    if(pos.Magic() != Magic) continue;
                    if(pos.Symbol() != _Symbol) continue;
                    Print(__FUNCTION__, " > Found open position with ticket #", pos.Ticket(), "...");
                    if(pos.PositionType() == POSITION_TYPE_BUY) buyPos = pos.Ticket();
                    if(pos.PositionType() == POSITION_TYPE_SELL) sellPos = pos.Ticket();
               }
          }
          for(int i = OrdersTotal() - 1; i >= 0; i--) {
               COrderInfo order;
               if(order.SelectByIndex(i)) {
                    if(order.Magic() != Magic) continue;
                    if(order.Symbol() != _Symbol) continue;
                    Print(__FUNCTION__, " > Found pending order with ticket #", order.Ticket(), "...");
                    if(order.OrderType() == ORDER_TYPE_BUY_STOP) buyPos = order.Ticket();
                    if(order.OrderType() == ORDER_TYPE_SELL_STOP) sellPos = order.Ticket();
               }
          }
     }

     IndicatorInit();
//---
     return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
     IndicatorDeinit();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void IndicatorInit()
{
     atrHandle = iATR(_Symbol, Timeframe, atrPeriod);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void IndicatorDeinit()
{
     IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
     int bars = iBars(_Symbol, Timeframe);
     if(totalBars != bars) {
          totalBars = bars;

          ProcessIndicatorOnNewBar();

          processPos(buyPos);
          processPos(sellPos);

          if(buyPos <= 0) {
               double buyPrice = findBuySignal();
               buyPrice = NormalizeDouble(buyPrice, _Digits);
               if(buyPrice > 0) {
                    executeBuy(buyPrice);
               }
          }

          if(sellPos <= 0) {
               double sellPrice = findSellSignal();
               sellPrice = NormalizeDouble(sellPrice, _Digits);
               if(sellPrice > 0) {
                    executeSell(sellPrice);
               }
          }
     }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessIndicatorOnNewBar()
{
     ArraySetAsSeries(atrBuffer, true);
     CopyBuffer(atrHandle, 0, 1, 1, atrBuffer);
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

          } else if(pos.PositionType() == POSITION_TYPE_SELL) {

          }
     }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double TrueRange(int length, int shift)
{
     double maxHigh = 0;
     for(int i = shift; i <= (shift + length + 1); i++) {
          double _high = iHigh(_Symbol, Timeframe, i);
          if(_high > maxHigh) {
               maxHigh = _high;
          }
     }

     double minLow = DBL_MAX;
     for(int i = shift; i <= (shift + length + 1); i++) {
          double _low = iLow(_Symbol, Timeframe, i);
          if(_low < minLow) {
               minLow = _low;
          }
     }

     double trueHigh = MathMax(iClose(_Symbol, Timeframe, shift + length), maxHigh);
     double trueLow = MathMin(iClose(_Symbol, Timeframe, shift + length), minLow);

     return trueHigh - trueLow;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double findBuySignal()
{
     // Today's Prices
     double openToday = iOpen(_Symbol, Timeframe, 1);
     double highToday = iHigh(_Symbol, Timeframe, 1);
     double lowToday = iLow(_Symbol, Timeframe, 1);
     double closeToday = iClose(_Symbol, Timeframe, 1);

     openToday = NormalizeDouble(openToday, _Digits);
     highToday = NormalizeDouble(highToday, _Digits);
     lowToday = NormalizeDouble(lowToday, _Digits);
     closeToday = NormalizeDouble(closeToday, _Digits);

     // Yesterday's Prices
     double openBefore = iOpen(_Symbol, Timeframe, 2);
     double highBefore = iHigh(_Symbol, Timeframe, 2);
     double lowBefore = iLow(_Symbol, Timeframe, 2);
     double closeBefore = iClose(_Symbol, Timeframe, 2);

     openBefore = NormalizeDouble(openBefore, _Digits);
     highBefore = NormalizeDouble(highBefore, _Digits);
     lowBefore = NormalizeDouble(lowBefore, _Digits);
     closeBefore = NormalizeDouble(closeBefore, _Digits);

     // Auxiliary Variables
     // Lowest low
     double lowestLookback = DBL_MAX;
     for(int i = 1; i < (lookback + 2); i++) {
          double _low = iLow(_Symbol, Timeframe, i);
          if(_low < lowestLookback) {
               lowestLookback = _low;
          }
     }
     lowestLookback = NormalizeDouble(lowestLookback, _Digits);

     // Highest high
     double highestLookback = 0;
     for(int i = 1; i < (lookback + 2); i++) {
          double _high = iHigh(_Symbol, Timeframe, i);
          if(_high > highestLookback) {
               highestLookback = _high;
          }
     }
     highestLookback = NormalizeDouble(highestLookback, _Digits);


     double closePlusBuffer = closeToday + pendingDistance * _Point;

     double price = highToday;
     if(closePlusBuffer > highToday) {
          price = closePlusBuffer;
     }

     price = NormalizeDouble(price, _Digits);

     bool condition1 = closeToday < lowBefore;
     bool condition2 = lowToday < lowestLookback;
     bool condition3 = true;

     if(condition1 && condition2 && condition3)
          return price;

     return 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double findSellSignal()
{
     //Today's Prices
     double openToday = iOpen(_Symbol, Timeframe, 1);
     double highToday = iHigh(_Symbol, Timeframe, 1);
     double lowToday = iLow(_Symbol, Timeframe, 1);
     double closeToday = iClose(_Symbol, Timeframe, 1);

     openToday = NormalizeDouble(openToday, _Digits);
     highToday = NormalizeDouble(highToday, _Digits);
     lowToday = NormalizeDouble(lowToday, _Digits);
     closeToday = NormalizeDouble(closeToday, _Digits);

     // Yesterday's Prices
     double openBefore = iOpen(_Symbol, Timeframe, 2);
     double highBefore = iHigh(_Symbol, Timeframe, 2);
     double lowBefore = iLow(_Symbol, Timeframe, 2);
     double closeBefore = iClose(_Symbol, Timeframe, 2);

     openBefore = NormalizeDouble(openBefore, _Digits);
     highBefore = NormalizeDouble(highBefore, _Digits);
     lowBefore = NormalizeDouble(lowBefore, _Digits);
     closeBefore = NormalizeDouble(closeBefore, _Digits);

     double highestLookback = 0;
     for(int i = 0; i < lookback; i++) {
          double _high = iHigh(_Symbol, Timeframe, 2 + i);
          if(_high > highestLookback) {
               highestLookback = _high;
          }
     }

     highestLookback = NormalizeDouble(highestLookback, _Digits);

     double closeMinusBuffer = closeToday - (pendingDistance * _Point);

     double price = lowToday;
     if(closeMinusBuffer < lowToday) {
          price = closeMinusBuffer;
     }

     price = NormalizeDouble(price, _Digits);

     bool condition1 = closeToday > highBefore;
     bool condition2 = highToday > highestLookback;
     bool condition3 = true;

     if(condition1 && condition2 && condition3)
          return price;

     return 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void executeBuy(double entry)
{
     entry = NormalizeDouble(entry, _Digits);

     slDistance = NormalizeDouble(atrBuffer[0] * atrMult, _Digits);
     tpDistance = slDistance * tpFactor;

     tpPoint = (int)(slPoint * tpFactor);

     double tp;
     double sl;
     if(slMode == SLMODE_ATR) {
          tp = entry + tpDistance;
          sl = entry - slDistance;
     } else {
          tp = entry + tpPoint * _Point;
          sl = entry - slPoint * _Point;
     }

     tp = NormalizeDouble(tp, _Digits);
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

     slDistance = NormalizeDouble(atrBuffer[0] * atrMult, _Digits);
     tpDistance = slDistance * tpFactor;

     tpPoint = (int)(slPoint * tpFactor);

     double tp;
     double sl;
     if(slMode == SLMODE_ATR) {
          tp = entry - tpDistance;
          sl = entry + slDistance;
     } else {
          tp = entry - tpPoint * _Point;
          sl = entry + slPoint * _Point;
     }

     tp = NormalizeDouble(tp, _Digits);
     sl = NormalizeDouble(sl, _Digits);

     datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpirationHours * PeriodSeconds(PERIOD_H1);

     trade.SellStop(Lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
     sellPos = trade.ResultOrder();
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
//+------------------------------------------------------------------+
