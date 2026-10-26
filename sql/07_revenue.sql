-- 07_revenue.sql
-- Revenue here is a SCENARIO built from dim_fee_schedule. It is not observed revenue.
-- Gross fee = fee charged. Partner cost = paid to agents, processors, banks. Net = gross minus partner.
-- Fees on fraud labelled rows are set to zero (assumed reversed). Refunds and chargebacks are not in the data.
USE wallet_analytics;

SELECT ROUND(SUM(gross_fee), 2) AS gross_revenue, ROUND(SUM(partner_cost), 2) AS partner_cost,
       ROUND(SUM(net_fee), 2) AS net_revenue,
       ROUND(SUM(gross_fee) / SUM(is_fraud = 0), 2) AS avg_gross_fee_per_billable_txn
FROM fact_transaction;

SELECT type_code, SUM(is_fraud = 0) AS billable_txns, ROUND(SUM(gross_fee), 2) AS gross_revenue,
       ROUND(SUM(net_fee), 2) AS net_revenue,
       ROUND(SUM(net_fee) / SUM(SUM(net_fee)) OVER (), 4) AS net_revenue_share,
       ROUND(SUM(gross_fee) / SUM(is_fraud = 0), 2) AS avg_gross_fee_per_billable_txn
FROM fact_transaction GROUP BY type_code ORDER BY net_revenue DESC;

SELECT day_no, ROUND(SUM(gross_fee), 2) AS gross_revenue, ROUND(SUM(net_fee), 2) AS net_revenue
FROM fact_transaction GROUP BY day_no ORDER BY day_no;

-- Concentration by customer value segment
SELECT segment, COUNT(*) AS customers,
       ROUND(SUM(net_fee), 2) AS net_revenue,
       ROUND(SUM(net_fee) / SUM(SUM(net_fee)) OVER (), 4) AS net_revenue_share
FROM customer_segment GROUP BY segment ORDER BY segment;

-- Fraud value against scenario net revenue
SELECT ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 2) AS fraud_value,
       ROUND(SUM(net_fee), 2) AS net_revenue,
       ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END) / SUM(net_fee), 2) AS fraud_value_to_net_revenue
FROM fact_transaction;
