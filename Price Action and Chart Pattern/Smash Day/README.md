# Smash Day Trading Strategy
A modified version of larry William's Smash Day trading strategy. Working on Daily timeframe (D1).

## Concept
In an uptrend, a sell-stop pending order is placed just bellow yesterday's low. The premise is, if the uptrend is already happened for a long enough time, breaking yesterday's low often become a sign of exhausted trend. Therefore, a trend reversal is likely to come not long afterwards. Likewise but the opposite in a downtrend.

## Rules for Entry
All of the calculations are executed at today's candle open. The calculations ignore today's candle. Only looking from yesterday's candle and backward.
* __Long__
1. Yesterday's candle close must be lower than previous candle low.
2. Yesterday's low must be the lowest price in the last X days. X is a variable to be optimized.
3. Place a buy-stop order at the yesterday's high. This pending order must be executed in the next 48 hours. If not executed, delete it.
* __Short__
1. Yesterday's candle close must be higher than previous candle high.
2. Yesterday's high must be the highest price in the last X days. X is a variable to be optimized.
3. Place a sell-stop order at the yesterday's low. This pending order must be executed in the next 48 hours. If not executed, delete it.

