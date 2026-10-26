-- 05_performance.sql
-- Terms: transaction volume = count of transactions. Transaction value = sum of amounts.
-- The file has no status or failure field, so a true failure rate cannot be calculated.
-- Measurable proxies: fraud label rate and balance reconciliation exception rate.
USE wallet_analytics;

SELECT COUNT(*) AS txn_count, SUM(amount) AS txn_value, ROUND(AVG(amount), 2) AS avg_amount,
       SUM(is_fraud) AS fraud_count, SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END) AS fraud_value,
       ROUND(SUM(is_fraud) / COUNT(*), 5) AS fraud_rate_count
FROM fact_transaction;

-- Mix by type
SELECT type_code, COUNT(*) AS txn_count, ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS count_share,
       SUM(amount) AS txn_value, ROUND(SUM(amount) / SUM(SUM(amount)) OVER (), 4) AS value_share,
       ROUND(AVG(amount), 2) AS avg_amount, SUM(is_fraud) AS fraud_count,
       ROUND(SUM(1 - orig_recon_ok) / COUNT(*), 4) AS recon_exception_rate
FROM fact_transaction GROUP BY type_code ORDER BY txn_count DESC;

-- Daily trend with fraud rate
SELECT day_no, COUNT(*) AS txn_count, SUM(amount) AS txn_value, SUM(is_fraud) AS fraud_count,
       ROUND(SUM(is_fraud) / COUNT(*), 5) AS fraud_rate_count
FROM fact_transaction GROUP BY day_no ORDER BY day_no;

-- Hour of day profile
SELECT hour_of_day, COUNT(*) AS txn_count, SUM(amount) AS txn_value, SUM(is_fraud) AS fraud_count
FROM fact_transaction GROUP BY hour_of_day ORDER BY hour_of_day;

-- Screening rule evaluation against the fraud label
SELECT 'R0 System flag' AS rule, SUM(is_flagged = 1) AS flagged,
       SUM(is_flagged = 1 AND is_fraud = 1) AS true_fraud FROM fact_transaction
UNION ALL
SELECT 'R1 TRANSFER above 200000', SUM(type_code = 'TRANSFER' AND amount > 200000),
       SUM(type_code = 'TRANSFER' AND amount > 200000 AND is_fraud = 1) FROM fact_transaction
UNION ALL
SELECT 'R2 TRANSFER or CASH_OUT', SUM(type_code IN ('TRANSFER', 'CASH_OUT')),
       SUM(type_code IN ('TRANSFER', 'CASH_OUT') AND is_fraud = 1) FROM fact_transaction
UNION ALL
SELECT 'R3 full balance drain', SUM(type_code IN ('TRANSFER', 'CASH_OUT') AND old_bal_orig > 0 AND ABS(amount - old_bal_orig) <= 0.01),
       SUM(type_code IN ('TRANSFER', 'CASH_OUT') AND old_bal_orig > 0 AND ABS(amount - old_bal_orig) <= 0.01 AND is_fraud = 1)
FROM fact_transaction;
