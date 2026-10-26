-- 06_balances.sql
-- Scope: the only balance data are pre and post transaction balances on each row.
-- There are no dated snapshots. The measure below is the sender's LAST OBSERVED post transaction
-- balance in the window. It is not an end of period ledger balance. Never average transaction amounts.
USE wallet_analytics;

DROP TABLE IF EXISTS customer_last_balance;
CREATE TABLE customer_last_balance AS
SELECT f.customer_id, f.day_no, f.new_bal_orig AS last_balance, f.orig_recon_ok
FROM fact_transaction f
JOIN (SELECT customer_id, MAX(txn_id) AS last_txn
      FROM fact_transaction WHERE is_fraud = 0 GROUP BY customer_id) x
  ON f.txn_id = x.last_txn;

-- Average and median, all customers
SELECT COUNT(*) AS customers, ROUND(AVG(last_balance), 2) AS mean_balance,
       SUM(last_balance = 0) / COUNT(*) AS share_zero FROM customer_last_balance;

SELECT ROUND(AVG(last_balance), 2) AS median_balance FROM (
    SELECT last_balance, ROW_NUMBER() OVER (ORDER BY last_balance) AS rn, COUNT(*) OVER () AS cnt
    FROM customer_last_balance) t
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2));

-- Same measures on rows whose balance reconciles to the amount (more reliable, but selective)
SELECT COUNT(*) AS customers, ROUND(AVG(last_balance), 2) AS mean_balance
FROM customer_last_balance WHERE orig_recon_ok = 1;

SELECT ROUND(AVG(last_balance), 2) AS median_balance_reconciled FROM (
    SELECT last_balance, ROW_NUMBER() OVER (ORDER BY last_balance) AS rn, COUNT(*) OVER () AS cnt
    FROM customer_last_balance WHERE orig_recon_ok = 1) t
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2));

-- Distribution by customer
SELECT CASE WHEN last_balance = 0 THEN '0 (empty)'
            WHEN last_balance <= 1000 THEN '0 to 1k'
            WHEN last_balance <= 10000 THEN '1k to 10k'
            WHEN last_balance <= 100000 THEN '10k to 100k'
            WHEN last_balance <= 1000000 THEN '100k to 1M'
            ELSE '1M and above' END AS balance_band,
       COUNT(*) AS customers, ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS share_of_customers
FROM customer_last_balance GROUP BY balance_band;

-- Daily average post transaction balance on reconciled rows (replaces a snapshot trend)
SELECT day_no, COUNT(*) AS reconciled_txns, ROUND(AVG(new_bal_orig), 2) AS avg_post_balance
FROM fact_transaction WHERE is_fraud = 0 AND orig_recon_ok = 1
GROUP BY day_no ORDER BY day_no;
