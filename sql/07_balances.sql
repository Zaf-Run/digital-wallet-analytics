-- Last observed post transaction balance per customer (C) account, any role, COMPLETED txns only.
-- Cancelled fraud rows are excluded (dataset notes say balances on those rows are unreliable).
-- This is NOT an end of day snapshot. It is the balance after the account's most recent logged event.
WITH ev AS (
  SELECT step, txn_id, orig_id AS acct, orig_bal_after AS bal FROM txn WHERE is_fraud = 0
  UNION ALL
  SELECT step, txn_id, dest_id, dest_bal_after FROM txn WHERE is_fraud = 0 AND dest_id LIKE 'C%'
),
last_bal AS (
  SELECT acct, arg_max(bal, step * 10000000 + txn_id) AS closing_bal FROM ev GROUP BY acct
)
SELECT
  count(*)                                         AS accounts,
  round(avg(closing_bal),2)                        AS avg_closing,
  round(median(closing_bal),2)                     AS median_closing,
  round(quantile_cont(closing_bal, 0.25),2)        AS p25,
  round(quantile_cont(closing_bal, 0.75),2)        AS p75,
  round(quantile_cont(closing_bal, 0.90),2)        AS p90,
  round(quantile_cont(closing_bal, 0.99),2)        AS p99,
  round(100.0 * count(*) FILTER (WHERE closing_bal = 0) / count(*), 2) AS pct_zero_balance
FROM last_bal;
