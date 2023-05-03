//+------------------------------------------------------------------+
//|                                        ATR Explosion Scalper.mq5 |
//|                                   Copyright 2023, Handiko Gesang |
//|                                   https://www.github.com/handiko |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Handiko Gesang"
#property link      "https://www.github.com/handiko"
#property version   "1.00"

#define VERSION "1.00"
#define PROJECT_NAME MQLInfoString(MQL_PROGRAM_NAME)

#include <Trade/trade.mqh>

static input int InpMagic = 123;
static input double InpLots = 0.1;
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15;
input int InpBaselinePeriod = 200;
input int InpAtrBaselinePeriod = 50;
input int InpAtrSlowPeriod = 100;
input int InpAtrFastPeriod = 20;

input int InpSlPoint = 300;
input double InpTpFactor = 0.15;
input int InpExpirationHours = 4;

CTrade trade;
int totalBars;
ulong buyPos, sellPos;
int tpPoint;


int baselineHandle, atrBaselineHandle, atrFastHandle, atrSlowHandle;
double baseline[], atrBaseline[], atrFast[], atrSlow[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
     trade.SetExpertMagicNumber(InpMagic);
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
                    if(pos.Magic() != InpMagic) continue;
                    if(pos.Symbol() != _Symbol) continue;
                    Print(__FUNCTION__, " > Found open position with ticket #", pos.Ticket(), "...");
                    if(pos.PositionType() == POSITION_TYPE_BUY) buyPos = pos.Ticket();
                    if(pos.PositionType() == POSITION_TYPE_SELL) sellPos = pos.Ticket();
               }
          }
          for(int i = OrdersTotal() - 1; i >= 0; i--) {
               COrderInfo order;
               if(order.SelectByIndex(i)) {
                    if(order.Magic() != InpMagic) continue;
                    if(order.Symbol() != _Symbol) continue;
                    Print(__FUNCTION__, " > Found pending order with ticket #", order.Ticket(), "...");
                    if(order.OrderType() == ORDER_TYPE_BUY_STOP) buyPos = order.Ticket();
                    if(order.OrderType() == ORDER_TYPE_SELL_STOP) sellPos = order.Ticket();
               }
          }
     }

     IndicatorInit();

     return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
     IndicatorDeinit();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void IndicatorInit()
{
     baselineHandle = iMA(_Symbol, InpTimeframe, InpBaselinePeriod, 0, MODE_EMA, PRICE_CLOSE);
     atrBaselineHandle = iATR(_Symbol, InpTimeframe, InpAtrBaselinePeriod);
     atrFastHandle = iATR(_Symbol, InpTimeframe, InpAtrFastPeriod);
     atrSlowHandle = iATR(_Symbol, InpTimeframe, InpAtrSlowPeriod);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void IndicatorDeinit()
{
     IndicatorRelease(baselineHandle);
     IndicatorRelease(atrBaselineHandle);
     IndicatorRelease(atrFastHandle);
     IndicatorRelease(atrSlowHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
     int bars = iBars(_Symbol, InpTimeframe);
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
     ArraySetAsSeries(baseline, true);
     ArraySetAsSeries(atrBaseline, true);
     ArraySetAsSeries(atrFast, true);
     ArraySetAsSeries(atrSlow, true);

     CopyBuffer(baselineHandle, 0, 1, 1, baseline);
     CopyBuffer(atrBaselineHandle, 0, 1, 1, atrBaseline);
     CopyBuffer(atrFastHandle, 0, 1, 2, atrFast);
     CopyBuffer(atrSlowHandle, 0, 1, 2, atrSlow);
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
double findBuySignal()
{
     double open = iOpen(_Symbol, InpTimeframe, 1);
     double high = iHigh(_Symbol, InpTimeframe, 1);
     double low = iLow(_Symbol, InpTimeframe, 1);
     double close = iClose(_Symbol, InpTimeframe, 1);

     double openBefore = iOpen(_Symbol, InpTimeframe, 2);
     double highBefore = iHigh(_Symbol, InpTimeframe, 2);
     double lowBefore = iLow(_Symbol, InpTimeframe, 2);
     double closeBefore = iClose(_Symbol, InpTimeframe, 2);

     open = NormalizeDouble(open, _Digits);
     high = NormalizeDouble(high, _Digits);
     low = NormalizeDouble(low, _Digits);
     close = NormalizeDouble(close, _Digits);

     openBefore = NormalizeDouble(openBefore, _Digits);
     highBefore = NormalizeDouble(highBefore, _Digits);
     lowBefore = NormalizeDouble(lowBefore, _Digits);
     closeBefore = NormalizeDouble(closeBefore, _Digits);

     double baselineAtrUpperBand = baseline[0] + atrBaseline[0];
     double baselineAtrLowerBand = baseline[0] - atrBaseline[0];

     //candle is bullish
     bool condition1 = close > open;

     //candle is above the atrUpperBand
     bool condition2 = ((close > baselineAtrUpperBand) && (low > baselineAtrLowerBand));

     //atr breakout
     bool condition3 = ((atrFast[0] > atrSlow[0]) && (atrFast[1] < atrSlow[1]));

     double price = NormalizeDouble(high, _Digits);
     if(condition1 && condition2 && condition3) {
          return price;
     }

     return 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double findSellSignal()
{
     double open = iOpen(_Symbol, InpTimeframe, 1);
     double high = iHigh(_Symbol, InpTimeframe, 1);
     double low = iLow(_Symbol, InpTimeframe, 1);
     double close = iClose(_Symbol, InpTimeframe, 1);

     double openBefore = iOpen(_Symbol, InpTimeframe, 2);
     double highBefore = iHigh(_Symbol, InpTimeframe, 2);
     double lowBefore = iLow(_Symbol, InpTimeframe, 2);
     double closeBefore = iClose(_Symbol, InpTimeframe, 2);

     open = NormalizeDouble(open, _Digits);
     high = NormalizeDouble(high, _Digits);
     low = NormalizeDouble(low, _Digits);
     close = NormalizeDouble(close, _Digits);

     openBefore = NormalizeDouble(openBefore, _Digits);
     highBefore = NormalizeDouble(highBefore, _Digits);
     lowBefore = NormalizeDouble(lowBefore, _Digits);
     closeBefore = NormalizeDouble(closeBefore, _Digits);

     double baselineAtrUpperBand = baseline[0] + atrBaseline[0];
     double baselineAtrLowerBand = baseline[0] - atrBaseline[0];

     //candle is bearish
     bool condition1 = close < open;

     //candle is bellow the atrLowerBand
     bool condition2 = ((close < baselineAtrLowerBand) && (high < baselineAtrUpperBand));

     //atr breakout
     bool condition3 = atrFast[0] > atrSlow[0];

     double price = NormalizeDouble(high, _Digits);
     if(condition1 && condition2 && condition3) {
          return price;
     }

     return 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void executeBuy(double entry)
{
     entry = NormalizeDouble(entry, _Digits);

     tpPoint = (int)(InpSlPoint * InpTpFactor);

     double tp = entry + tpPoint * _Point;
     double sl = entry - InpSlPoint * _Point;

     tp = NormalizeDouble(tp, _Digits);
     sl = NormalizeDouble(sl, _Digits);

     datetime expiration = iTime(_Symbol, InpTimeframe, 0) + InpExpirationHours * PeriodSeconds(PERIOD_H1);

     trade.BuyStop(InpLots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
     buyPos = trade.ResultOrder();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void executeSell(double entry)
{

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
               if(order.Magic() == InpMagic) {
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
