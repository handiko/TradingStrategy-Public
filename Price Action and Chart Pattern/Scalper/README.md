# Scalper Trading Strategy
**This strategy is risky. The average TP is quite low. The real life results will highly dependant to the trading costs. To maximize the profit potential, only use this strategy on a low commission, low spread, and low slippage broker, otherwise, the trading cost will eat up the profits.**

## Concept
At every swing point, a liquidity zone is built-up. Liquidity is any pending stop order placed at any price. If an upward price move hit a buy-stop order (**buy-side liquidity grab**), the stop order execution will move the price up further (breakout). Likewise but the opposite in a downtrend. Sometimes, the breakout will continue to move in the same direction further, or quickly fading. 
At a swing point, there are tendencies of buy-stop order placed by a large number of market participant at relatively close price distance from one to another. Even though this is not always the case, we could utilize this liquidity into a scalping strategy. 
By placing a stop order at the exact swing point, any liquidity grab will put our trade into a floating profit condition, and by using a tight trailling-stop loss, we can lock-in our profit very quickly.

![](./concept.png)

## Rules for Entry
* __Long__
1. Find a high swing point. A high swing point is characterized as a high of a candle surrounded by a number of lower high of another candles. The minimum number of candle to make the high swing point is optimizable.
2. Check the time. If the time is in the low-spread period, place a buy-stop order at the exact high swing point. 
3. If the stop order is executed, and the trade is already profit by X point, move the stop-loss just several points (Y) below the current bid price. 
4. If the trade is run futher into more profit, keep moving the trailling stop-loss Y points just below the current bid price.
5. The tralling stop movement is calculated in tick-by-tick basis.
* __Short__
1. Find a low swing point. A low swing point is characterized as a low of a candle surrounded by a number of higher low of another candles. The minimum number of candle to make the low swing point is optimizable.
2. Check the time. If the time is in the low-spread period, place a sell-stop order at the exact low swing point. 
3. If the stop order is executed, and the trade is already profit by X point, move the stop-loss just several points (Y) above the current ask price. 
4. If the trade is run futher into more profit, keep moving the trailling stop-loss Y points just above the current ask price.
5. The tralling stop movement is calculated in tick-by-tick basis.

Each pending order is only live for Z hours before deleted/expired. If there is already a pending order or a trade still running, any subsequent signal to the same direction is ignored.

![](./Entry.png)

## Filter
X number of days (lookback) in the point 2 above become the entry filter. The premise is, after X number of days, any break of previous day's structure (high or low) to the opposite direction of the trend, become the sign of a trend exhaustion, and likely to be followed by a trend reversal. Thus, we catch the next trend quite early.

## Input Parameters
* __Magic__ : EA's magic number
* __Lots__ : Lot opened on each trade.
* __Timeframe__ : Timeframe of execution. Default is D1
* __lookback__ : number of days to look back. (Filter)
* __atrPeriod__ : ATR Period to calculate ATR-based stop loss distance.
* __atrMult__ : --> SL distance = ATR * atrMult.
* __slMode__ : SLMODE_ATR means the stop loss is calculated based on ATR. SLMODE_FIXED means the stop loss is a fixed value.
* __slPoint__ : SL distance in points. Used when SLMODE_FIXED is selected.
* __tpFactor__ : --> TP distance = SL distance * tpFactor. Used in either ATR and fixed SL.
* __pendingDistance__ : buffer distance in points away from the high/low or close price whichever farthest from the close price. Used to avoid false confirmation.
* __ExpirationHours__ : pending order expiration in hours.

## Test & Results 
### EURUSD Benchmark
EURUSD D1, 2013-01-01 until 2023-04-29, 10000 USD initial balance, 0.1 lot/trade. Risking 2350 points and 0.75 TP factor.
The set file used in the test is included.

* Net profit: 7749.72 USD. Which means 7749.72 pips of profit if using 0.1 lot/trade.
* Profit trades: 73.68%
* Total trades: 114
* Profit factor: 2.12
* Sharpe ratio: 1.82
* Max. consecutive losses: 2x
* Max. consecutive wins: 8x

![](./equityCurve.png)
![](./summary.png)

### Porfolio Mode
Portfolio consists of EURUSD,EURJPY,AUDUSD,AUDJPY, and GBPJPY. Test was done from 2015-01-01 until 2023-01-01, 10000 USD initial balance, pip calculation mode.
The set file for each pair is not included.

* Net profit: 26966.22 pips
* Profit trades: 64.61%
* Total trades: 356
* Profit factor: 1.83
* Max. consecutive losses: 4x
* Max. consecutive wins: 12x

![](./FivePairsEquityCurve.png)
![](./FivePairsSummary.png)

