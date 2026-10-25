# Power BI Dashboard Specification

Three pages. Built from the CSVs in `outputs/`. No live database needed.

## Data model

Load these files with Get Data, Text/CSV. Keep each as its own table.

| Table | Source file | Grain |
|---|---|---|
| Daily | 03_daily.csv | one row per day (31 rows) |
| ByType | 02_by_type.csv | one row per transaction type (5 rows) |
| Frequency | 05_frequency.csv | role and transaction count bucket |
| NewReturning | 06_new_returning.csv | one row per day (30 rows, day 31 has no active accounts) |
| Balances | 07_balances.csv | one row of summary statistics |
| BalanceBands | 10_balance_buckets.csv | one row per balance band |
| Hourly | 11_hourly.csv | one row per hour of day |
| Bands | 09_amount_bands.csv | one row per amount band |
| Fraud | 08_fraud_rules.csv | one row per type |
| Kpi | 01_kpis.csv, 04_mau_stickiness.csv | one row each |
| Fees | fee_assumptions.csv | one row per type |

Relationships: Daily[day_no] to NewReturning[day_no], one to one. ByType[txn_type] to Fees[txn_type], one to one. Other tables stand alone.

Add a calendar note on every page: "Day 1 to 31 are simulated days. No calendar date exists in the source."

Label on every revenue visual: "Modelled revenue. Illustrative tariff. Not observed."

## DAX measures

```
Attempts = SUM(Daily[attempts])
Completed Txns = SUM(Daily[completed_count])
Cancelled Txns = SUM(Daily[cancelled_count])
Completed Value = SUM(Daily[completed_value])
Cancellation Rate = DIVIDE([Cancelled Txns], [Attempts])
Success Rate = 1 - [Cancellation Rate]
Avg DAU = AVERAGEX(FILTER(Daily, Daily[dau_initiators] > 0), Daily[dau_initiators])
MAU = MAX(Kpi[mau])
DAU MAU Ratio = DIVIDE([Avg DAU], [MAU])
Modelled Revenue = SUM(Daily[modelled_fee_revenue])
Revenue per Completed Txn = DIVIDE([Modelled Revenue], [Completed Txns])
Avg Closing Balance = MAX(Balances[avg_closing])
Median Closing Balance = MAX(Balances[median_closing])
Returning Share = DIVIDE(SUM(NewReturning[returning]), SUM(NewReturning[active_any_role]))
```

Note on MAU: the file holds one month, so MAU is a single stored value. Do not recompute it with DISTINCTCOUNT by slicing on day, because distinct counts do not add across days.

## Page 1: Executive Overview

| Visual | Type | Fields | Calculation | Filters | Interpretation |
|---|---|---|---|---|---|
| DAU | Card | Avg DAU | Average of daily initiating accounts with a completed transaction | None | Typical daily active base. 211,795. |
| MAU | Card | MAU | Distinct initiating accounts with a completed transaction in the month | None | 6,345,122. |
| DAU/MAU | Card | DAU MAU Ratio | Avg DAU divided by MAU | None | 3.34%. Add a tooltip: near unique accounts in PaySim make this a simulator artefact. |
| Transaction value | Card | Completed Value | Sum of completed amounts | None | 1,132.34 billion. Not revenue. |
| Successful transactions | Card | Completed Txns | Count where is_fraud = 0 | None | 6,354,407. |
| Failure rate | Card | Cancellation Rate | Cancelled divided by attempts | None | 0.129%. Label as "cancelled for fraud". |
| Revenue | Card | Modelled Revenue | Completed value times assumed rate | None | 6.51 billion. Label as modelled. |
| Activity trend | Combo, columns plus line | X: Daily[day_no]. Columns: Completed Txns. Line: Avg DAU per day (dau_initiators) | As defined | None | Shows the two high activity blocks (days 1 to 2 and 6 to 17) and the quiet periods. Matches `chart_daily_activity.png`. |
| Value trend | Line | X: day_no. Y: Completed Value | Sum | None | Day 13 spike: large tickets, not more customers. |

## Page 2: Customer Engagement

| Visual | Type | Fields | Calculation | Filters | Interpretation |
|---|---|---|---|---|---|
| Daily active users | Line | day_no, dau_initiators, dau_any_role | Two lines for the two definitions | Exclude day 31 (no completed activity) | Any role is higher because recipients are counted. |
| Monthly active users | Card | MAU | As above | None | Single month only. State that a monthly trend is not possible. |
| Transaction frequency | Column | Frequency[txn_count_bucket], accounts | Accounts by number of completed transactions | Slicer on role (initiator, receiver). Bucket 10 means 10 or more | Initiators: 99.85% transact once. Receivers: a long tail, 146,418 accounts with 10 or more. |
| New versus returning | Stacked column | NewReturning[day_no], new_in_log, returning | New means first appearance in the log, not registration | None | Returning share climbs over the month. Tooltip: this is reappearance in the log, not retention. |
| Returning share | Line | day_no, Returning Share | Measure above | None | 9% (day 2) to about 33% (day 29). |
| Transaction types | Donut or bar | ByType[txn_type], attempts | Share of count | None | Cash out and payment each about one third of count. |
| Channel preference (proxy) | Bar | ByType[channel_proxy], completed_count | Group types into Agent, Merchant, P2P, Other | None | Agent channel carries most transactions. Label as proxy. |
| Activity segments | Table or bar | Frequency buckets grouped as: single use, repeat (2 to 3), heavy receiver (10 or more) | Count accounts per segment | Role slicer | Segmentation is limited because initiators are almost all single use. Say so on the page. |

## Page 3: Operations and Revenue

| Visual | Type | Fields | Calculation | Filters | Interpretation |
|---|---|---|---|---|---|
| Cancellations by type | Clustered bar | ByType[txn_type], cancelled_count, cancellation_rate_pct | As in table | None | Only TRANSFER (0.77%) and CASH_OUT (0.18%) are affected. |
| Failure reasons | Not available | None | Replace with a text box: "Reason codes are not in the source data." Add the fraud pattern card below instead | None | Avoid inventing reasons. |
| Drain pattern card | Card | Fraud[account_drain_pattern] total, divided by Fraud[fraud_txns] total | 8,018 of 8,213 | None | 97.6% of cancelled transactions empty the sender balance. |
| Rule recall card | Card | Fraud[fraud_and_flagged] total divided by fraud_txns total | 16 of 8,213 | None | Legacy flag recall 0.19%. |
| Success rate by day | Column, log axis | Daily[day_no], Success Rate or Cancellation Rate | As defined | None | Spikes on low volume days (day 3: 29%). Matches `chart_cancel_rate_daily.png`. |
| Cancellation by hour | Column | Hourly[hour_of_day], cancellation_rate_pct | As in file | None | Rate looks high at hours 2 to 4 only because volume is low. Fraud count per hour is flat. |
| Value by type | Bar | ByType[txn_type], completed_value | Sum | None | Transfer and cash out carry 77% of value. |
| Revenue by type | Bar | ByType[txn_type], modelled_fee_revenue | As in file | None | Cash out 60%, transfer 37%. Assumption driven. |
| Revenue by ticket size | Column | Bands[band], revenue_share_pct | As in file | None | 100k to 1M: 65%. 1M and above: 25%. |
| Average wallet balance | Card pair | Avg Closing Balance, Median Closing Balance | From 07_balances | None | Mean 905,775, median 0. Add a tooltip with the definition: last observed balance, not an end of day snapshot. |
| Balance distribution | Column | BalanceBands[balance_band], accounts | Count per band | None | 53% zero. Accounts of 1M and above hold 92.8% of balance. Add second axis for total_balance. |

## Design rules

- One accent colour for volume, one for value, one for risk. Keep it consistent across pages.
- Every card has a one line definition in its tooltip.
- A footer text box on each page lists the dataset, its synthetic status and the two largest limitations.
- Slicers: transaction type on pages 1 and 3, role on page 2. Sync them.

## Checks before publishing

1. Completed Value card equals 1,132,336,529,331.87.
2. Completed Txns equals 6,354,407. Cancelled Txns equals 8,213.
3. Avg DAU equals 211,795 (rounded).
4. Sum of modelled revenue by type equals the card.
