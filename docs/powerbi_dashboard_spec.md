# Power BI dashboard specification

Digital Wallet Analytics, three pages. Built on the aggregated files in outputs/, so it runs on a standard laptop. The full 6.36 million row table is not needed.

## Data model

Import these CSVs: daily_summary, daily_type_summary, type_summary, hourly_summary, txn_frequency, customer_value_segments, customer_lifecycle_segments, balance_summary, balance_distribution, counterparty_mix, fraud_rule_evaluation, kpi_summary, dim_date.

Relationships (one to many, single direction): dim_date[day] to daily_summary[day]; dim_date[day] to daily_type_summary[day]. Create DimType = DISTINCT(type_summary[type]) and relate it to daily_type_summary[type]. Counterparty_mix and type_summary can relate to DimType too.

Distinct counts cannot be rebuilt from daily tables. DAU is stored per day. MAU is a single value from kpi_summary. Label MAU as full window and not responsive to date slicers.

Day 31 has 23 hours and only fraud rows. Add a page level filter dim_date[is_full_day] = TRUE for trend visuals, and a note on the page.

## Measures

Transactions = SUM(daily_summary[txn_count])
Transaction Value = SUM(daily_summary[txn_value])
Avg Transaction Amount = DIVIDE([Transaction Value], [Transactions])
Billable Transactions = SUM(daily_summary[billable_count])
Fraud Labelled Txns = SUM(daily_summary[fraud_count])
Fraud Rate = DIVIDE([Fraud Labelled Txns], [Transactions])
Fraud Value = SUM(daily_summary[fraud_value])
Balance Exception Rate = DIVIDE(SUM(daily_summary[recon_exception]), [Transactions])
Avg DAU = AVERAGEX(VALUES(dim_date[day]), CALCULATE(SUM(daily_summary[dau])))
MAU = CALCULATE(MAX(kpi_summary[value]), kpi_summary[metric] = "mau_sender", ALL(dim_date))
DAU/MAU = DIVIDE([Avg DAU], [MAU])
New Customers = SUM(daily_summary[new_customers])
Returning Customers = SUM(daily_summary[returning_customers])
Gross Revenue (scenario) = SUM(daily_summary[gross_revenue])
Net Revenue (scenario) = SUM(daily_summary[net_revenue])
Avg Gross Fee per Billable Txn = DIVIDE([Gross Revenue (scenario)], [Billable Transactions])
Net Revenue Share = DIVIDE([Net Revenue (scenario)], CALCULATE([Net Revenue (scenario)], ALL(DimType)))

Name every revenue measure with "(scenario)" on the page so no one reads it as observed.

## Page 1: Executive Overview

Page filter: dim_date[is_full_day] = TRUE. Slicer: dim_date[day] range.

V1 Card, Avg DAU. Field: Avg DAU. Calculation: average of daily distinct non fraud senders. Interpretation: about 205,000 a day, but dominated by days 1 to 17. Read with V8.
V2 Card, MAU. Field: MAU. Calculation: distinct non fraud senders over the window, 6,345,122. No date filter. Interpretation: monthly reach.
V3 Card, DAU/MAU. Field: DAU/MAU, format 0.0%. Subtitle: "Near 1/31 because 99.85% of customers transact once". Interpretation: not a loyalty signal in this data.
V4 Card, Transaction Value. Field: Transaction Value. Filter: none. Interpretation: 1.14 trillion units moved. This is value, not revenue.
V5 Card, Billable Transactions. Field: Billable Transactions (not fraud labelled). Interpretation: 6.35 million processed non fraud transactions. Not a measure of "successful" because status is not in the data.
V6 Card, Exception Rate. Fields: Fraud Rate and Balance Exception Rate. Caption: "Fraud label rate, not payment failure rate". Interpretation: 0.13% fraud labelled, 56.6% balance mismatches.
V7 Card, Net Revenue (scenario). Field: Net Revenue (scenario). Caption: "Assumed fee schedule". Interpretation: 3.47 billion units; changes with the Excel fee model.
V8 Line and column chart, volume and customers over time. X: dim_date[day]. Columns: Transactions. Line: Avg DAU as SUM(dau) per day. Interpretation: both fall together after day 17, so volume is not driven by repeat users.
V9 Line chart, value and scenario net revenue by day. X: day. Y: Transaction Value, secondary Net Revenue (scenario). Interpretation: revenue follows value because fees are a share of value.

## Page 2: Customer Engagement

Slicers: dim_date[day], DimType.

V1 Line chart, DAU trend. X: day. Y: SUM(dau). Interpretation: peak 573,913 on day 1. Dip on days 3 to 5 and fall after day 17.
V2 Card with note, MAU and alternative MAU. Fields: MAU (sender) 6,345,122 and mau_participant 6,912,642 from kpi_summary. Interpretation: counting receivers adds about 9%, still a one month view.
V3 Column chart, customers by transactions per customer. Axis: txn_frequency[txns_per_customer]. Value: customers. Log scale on Y. Interpretation: 6,335,852 customers have 1 transaction, 9,255 have 2, 15 have 3.
V4 Stacked column, new versus returning customers by day. X: day. Values: New Customers, Returning Customers. Filter: is_full_day. Interpretation: returning customers are under 1% of daily actives. "New" means first observed, not registered. Day 1 is all new by construction.
V5 Clustered bar, transaction mix by type. Axis: type_summary[type]. Values: count_share and value_share. Interpretation: PAYMENT is 34% of volume and 2.5% of value, TRANSFER is 8% of volume and 42% of value.
V6 Donut or bar, counterparty mix. Fields: counterparty_mix[counterparty], txn_count. Interpretation: merchants only appear on PAYMENT. This is the nearest view to channel.
V7 Column chart, hourly profile. X: hourly_summary[hour_of_day]. Y: txn_count. Interpretation: peak 17:00 to 19:00, trough 03:00.
V8 Bar chart, customer value segments. Axis: customer_value_segments[segment]. Values: customers_share, value_share, net_revenue_share. Interpretation: top 10% of customers send 52% of value and earn 40% of scenario net revenue.
V9 Table, lifecycle segments. Fields: customer_lifecycle_segments[segment], customers, txns. Interpretation: 99.85% single transaction customers. Inactive cannot be defined without a longer window.

## Page 3: Operations and Revenue

Slicers: dim_date[day], DimType.

V1 Column chart, fraud labelled transactions and rate by day. X: day. Columns: Fraud Labelled Txns. Line: Fraud Rate. Interpretation: count is steady near 265, so the rate jumps on quiet days.
V2 Column chart, fraud rate by hour. X: hour_of_day. Y: fraud_rate_count. Interpretation: 10% to 22% of rows between 02:00 and 05:59.
V3 Table, failure and exception reasons. Fields: type, fraud_count, fraud_rate_count, recon_exception_rate from type_summary. Caption: "Failure reasons are not in the data. Exceptions shown are proxies". Interpretation: fraud only in TRANSFER and CASH_OUT. Balance exceptions are 89% to 95% on CASH_OUT and TRANSFER.
V4 Gauge or card pair, processing share. Field: 1 minus Fraud Rate and 1 minus Balance Exception Rate. Interpretation: show as "not fraud labelled" and "balance reconciled", never as success rate.
V5 Bar chart, transaction value by type. Axis: type. Value: SUM(daily_type_summary[txn_value]). Interpretation: TRANSFER and CASH_OUT carry 77% of value.
V6 Bar chart, scenario net revenue by type. Axis: type. Value: Net Revenue (scenario). Interpretation: CASH_OUT 62%, TRANSFER 33%, PAYMENT 5%, CASH_IN 0 under the assumed schedule.
V7 Matrix, fraud rule evaluation. Fields: fraud_rule_evaluation[rule], flagged, true_fraud, precision, recall. Interpretation: system flag recall 0.2%, full balance drain rule recall 97.6% with no false positives. Likely optimistic because of the simulator.
V8 Column chart, balance distribution. Axis: balance_distribution[balance_band]. Value: share_of_customers. Legend: scope. Interpretation: 56.7% of senders end at a zero last observed balance across all rows. The reconciled view is skewed to higher balances.
V9 Cards, balances. Fields: balance_summary[mean] and [median] by scope. Caption: "Last observed post transaction balance, not a ledger snapshot". Interpretation: median 0 (all rows) and 207,837 (reconciled rows). Averages are indicative only.
V10 Line chart, daily average post transaction balance. X: day. Y: daily_summary[avg_post_balance] (reconciled rows only). Interpretation: replaces a snapshot trend. Lower and noisier after day 17.
