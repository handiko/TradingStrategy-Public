//+------------------------------------------------------------------+
//|                                                      MACross.mq5 |
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

enum ENUM_SLMODE {
     SLMODE_FIXED,
     SLMODE_CANDLE
};
enum ENUM_TPMODE {
     TPMODE_FIXED,
     TPMODE_RATIO,
     TPMODE_BAILOUT,
     TPMODE_TRAILLING_STOP
};

input group  "Risk Management"
static input double Lots = 0.1;
input ENUM_TPMODE TpMode = TPMODE_RATIO;
input int TakeProfit = 260;                     // Take Profit (points)
input double TpFactor = 1.0;
input ENUM_SLMODE SlMode = SLMODE_CANDLE;
input int StopLoss = 100;                       // Stop Loss (points)
input int TraillingStop = 10;                   // Trailling Stop (points)
input int TraillingTrigger = 15;                // Trailling Stop Trigger (points)

input group "Technical Parameters"
input int Lookback = 35;                        // Lookback period (bars)
input int MaPeriodFast = 20;
input int MaPeriodMed = 50;
input int MaPeriodSlow = 100;
input ENUM_TIMEFRAMES Timeframe = PERIOD_M30;

input group "Time Parameters"
input int ExpirationHours = 2;                  // Expiration Hours
input bool useTimeFilter = false;                // Using Time Filter?
input int StartTradingTime = 14;                // Trading Start at Hour (server time)
input int StopTradingTime = 21;                 // Trading Stop at Hour (server time)

input group "Day of Week Filter"
input bool InpTradeMonday = true;
input bool InpTradeTuesday = true;
input bool InpTradeWednesday = true;
input bool InpTradeThursday = true;
input bool InpTradeFriday = true;

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

int MaFasthandle, MaMedhandle, MaSlowhandle;
double MaFast[], MaMed[], MaSlow[];

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

     IndicatorInit();

     StringConcatenate(startTime, IntegerToString(StartTradingTime, 2, '0'), ":00");
     StringConcatenate(stopTime, IntegerToString(StopTradingTime, 2, '0'), ":30");

     return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
     //IndicatorDeinit();
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

     processIndicatorOnNewBar();

     processPos(buyPos);
     processPos(sellPos);

     int bars = iBars(_Symbol, Timeframe);
     if(totalBars != bars) {
          totalBars = bars;

          if(buyPos <= 0) {
               double high = findBuySignal();
               if(high > 0) {
                    //if(tradingIsAllowed) {
                    executeBuy(high);
                    //}
               }
          } else {
               if(!tradingIsAllowed) {
                    deletePendingOrder(buyPos);
               }
          }

          if(sellPos <= 0) {
               double low = findSellSignal();
               if(low > 0) {
                    //if(tradingIsAllowed) {
                    //executeSell(low);
                    //}
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

     MaFasthandle = iMA(_Symbol, Timeframe, MaPeriodFast, 0, MODE_SMA, PRICE_CLOSE);
     MaMedhandle = iMA(_Symbol, Timeframe, MaPeriodMed, 0, MODE_SMA, PRICE_CLOSE);
     MaSlowhandle = iMA(_Symbol, Timeframe, MaPeriodSlow, 0, MODE_SMA, PRICE_CLOSE);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void IndicatorDeinit()
{
     IndicatorRelease(atrHandle);

     IndicatorRelease(MaFasthandle);
     IndicatorRelease(MaMedhandle);
     IndicatorRelease(MaSlowhandle);
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

     MqlDateTime stime;
     datetime time_current = TimeCurrent();

     TimeToStruct(time_current, stime);

     switch(stime.day_of_week) {
     case 1:
          if(!InpTradeMonday) {
               tradingIsAllowed = false;
               break;
          }
     case 2:
          if(!InpTradeTuesday) {
               tradingIsAllowed = false;
               break;
          }
     case 3:
          if(!InpTradeWednesday) {
               tradingIsAllowed = false;
               break;
          }
     case 4:
          if(!InpTradeThursday) {
               tradingIsAllowed = false;
               break;
          }
     case 5:
          if(!InpTradeFriday) {
               tradingIsAllowed = false;
               break;
          }
     default:
          break;
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
void processIndicatorOnNewBar()
{
     ArraySetAsSeries(MaFast, true);
     ArraySetAsSeries(MaMed, true);
     ArraySetAsSeries(MaSlow, true);

     CopyBuffer(MaFasthandle, 0, 1, 2, MaFast);
     CopyBuffer(MaMedhandle, 0, 1, 2, MaMed);
     CopyBuffer(MaSlowhandle, 0, 1, 2, MaSlow);
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
               /*
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

               if(bid > pos.PriceOpen() + TraillingTrigger * _Point) {
                    double sl = bid - TraillingStop * _Point;
                    sl = NormalizeDouble(sl, _Digits);

                    if(sl > pos.StopLoss()) {
                         trade.PositionModify(pos.Ticket(), sl, pos.TakeProfit());
                    }
               }
               */
          } else if(pos.PositionType() == POSITION_TYPE_SELL) {
               /*
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

               if(ask < pos.PriceOpen() - TraillingTrigger * _Point) {
                    double sl = ask + TraillingStop * _Point;
                    sl = NormalizeDouble(sl, _Digits);

                    if(sl < pos.StopLoss() || pos.StopLoss() == 0) {
                         trade.PositionModify(pos.Ticket(), sl, pos.TakeProfit());
                    }
               }
               */
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

     double tp, sl;

     tp = entry + TakeProfit * _Point;
     sl = entry - StopLoss * _Point;

     if(SlMode == SLMODE_CANDLE) {
          sl = iLow(_Symbol, Timeframe, 1) - 10 * _Point;
     }

     if(TpMode == TPMODE_RATIO) {
          tp = entry + TpFactor * (entry - sl);
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
double findBuySignal()
{
     //double open = iOpen(_Symbol, Timeframe, 1);
     double high = iHigh(_Symbol, Timeframe, 1);
     //double low = iLow(_Symbol, Timeframe, 1);
     double close = iClose(_Symbol, Timeframe, 1);

     //double openBefore = iOpen(_Symbol, Timeframe, 1);
     //double highBefore = iHigh(_Symbol, Timeframe, 1);
     //double lowBefore = iLow(_Symbol, Timeframe, 1);
     //double closeBefore = iClose(_Symbol, Timeframe, 1);

     bool maFastCrossUpMed = (MaFast[0] > MaMed[0]) && (MaFast[1] < MaMed[1]);
     bool maFastCrossUpSlow = (MaFast[0] > MaSlow[0]) && (MaFast[1] < MaSlow[1]);
     bool maMedCrossUpSlow = (MaMed[0] > MaSlow[0]) && (MaMed[1] < MaSlow[1]);
     bool priceAboveMaFast = close > MaFast[0];
     bool priceAboveMaMed = close > MaMed[0];
     bool priceIsTrend = close > iClose(_Symbol, Timeframe, 1 + Lookback);

     bool condition1 = maFastCrossUpMed && priceAboveMaFast && priceIsTrend;
     bool condition2 = false;
     bool condition3 = false;
     //bool condition2 = maFastCrossUpSlow && priceAboveMaFast && priceIsTrend;
     //bool condition3 = maMedCrossUpSlow && priceAboveMaMed && priceIsTrend;

     double price = NormalizeDouble(iHigh(_Symbol, Timeframe, 1), _Digits);
     if(condition1 || condition2 || condition3) {
          return price;
     }

     return -1;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double findSellSignal()
{
     //double open = iOpen(_Symbol, Timeframe, 1);
     double high = iHigh(_Symbol, Timeframe, 1);
     //double low = iLow(_Symbol, Timeframe, 1);
     double close = iClose(_Symbol, Timeframe, 1);

     //double openBefore = iOpen(_Symbol, Timeframe, 1);
     //double highBefore = iHigh(_Symbol, Timeframe, 1);
     //double lowBefore = iLow(_Symbol, Timeframe, 1);
     //double closeBefore = iClose(_Symbol, Timeframe, 1);

     bool maFastCrossDnMed = (MaFast[0] < MaMed[0]) && (MaFast[1] > MaMed[1]);
     bool maFastCrossDnSlow = (MaFast[0] < MaSlow[0]) && (MaFast[1] > MaSlow[1]);
     bool maMedCrossDnSlow = (MaMed[0] < MaSlow[0]) && (MaMed[1] > MaSlow[1]);
     bool priceBellowMaFast = close < MaFast[0];
     bool priceBellowMaMed = close < MaMed[0];
     bool priceIsTrend = close < iClose(_Symbol, Timeframe, 1 + Lookback);

     bool condition1 = maFastCrossDnMed && priceBellowMaFast && priceIsTrend;
     bool condition2 = maFastCrossDnSlow && priceBellowMaFast && priceIsTrend;
     bool condition3 = maMedCrossDnSlow && priceBellowMaMed && priceIsTrend;

     double price = NormalizeDouble(iLow(_Symbol, Timeframe, 1), _Digits);
     if(condition1 || condition2 || condition3) {
          return price;
     }

     return -1;
}
//+------------------------------------------------------------------+
