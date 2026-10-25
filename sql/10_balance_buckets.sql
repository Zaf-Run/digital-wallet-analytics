-- Distribution of last observed customer balances (same definition as 07_balances).
WITH ev AS (
  SELECT step, txn_id, orig_id AS acct, orig_bal_after AS bal FROM txn WHERE is_fraud = 0
  UNION ALL
  SELECT step, txn_id, dest_id, dest_bal_after FROM txn WHERE is_fraud = 0 AND dest_id LIKE 'C%'
),
lb AS (SELECT acct, arg_max(bal, step * 10000000 + txn_id) AS closing_bal FROM ev GROUP BY acct)
SELECT CASE WHEN closing_bal = 0 THEN '1 zero' WHEN closing_bal < 10000 THEN '2 under 10k'
            WHEN closing_bal < 100000 THEN '3 10k to 100k' WHEN closing_bal < 1000000 THEN '4 100k to 1M'
            ELSE '5 1M and above' END AS balance_band,
       count(*) AS accounts, round(sum(closing_bal),0) AS total_balance
FROM lb GROUP BY 1 ORDER BY 1;
