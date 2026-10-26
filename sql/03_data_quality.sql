-- 03_data_quality.sql  Run these before any analysis. Each query should match validation_checks.csv.
USE wallet_analytics;

SELECT COUNT(*) AS row_count, MIN(step) AS min_step, MAX(step) AS max_step,
       COUNT(DISTINCT day_no) AS days FROM fact_transaction;

SELECT SUM(amount < 0) AS negative_amounts, SUM(amount = 0) AS zero_amounts FROM fact_transaction;

-- Duplicate check. No transaction id exists in the source, so duplicates are judged on business keys.
SELECT COUNT(*) AS duplicate_groups FROM (
    SELECT step, type_code, amount, customer_id, counterparty_id
    FROM fact_transaction
    GROUP BY step, type_code, amount, customer_id, counterparty_id
    HAVING COUNT(*) > 1) d;

-- Fraud labels and system flags by type
SELECT type_code, SUM(is_fraud) AS fraud_rows, SUM(is_flagged) AS flagged_rows
FROM fact_transaction GROUP BY type_code;

-- Merchants appear only on PAYMENT
SELECT type_code, counterparty_type, COUNT(*) AS txns
FROM fact_transaction GROUP BY type_code, counterparty_type;

-- Balance integrity: does the change in the sender balance equal the amount?
SELECT SUM(orig_recon_ok) AS reconciled, SUM(1 - orig_recon_ok) AS exceptions,
       ROUND(AVG(orig_recon_ok), 4) AS reconciled_share
FROM fact_transaction;

SELECT SUM(type_code <> 'CASH_IN' AND old_bal_orig = 0 AND amount > 0) AS debit_from_zero_balance,
       SUM(type_code <> 'CASH_IN' AND amount > old_bal_orig + 0.01)    AS amount_exceeds_balance
FROM fact_transaction;
