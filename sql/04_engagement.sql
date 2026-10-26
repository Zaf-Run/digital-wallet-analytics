-- 04_engagement.sql
-- Active user = originating customer account with at least one NON FRAUD transaction in the period.
-- (Fraud labelled rows are unauthorised activity, not genuine engagement.)
USE wallet_analytics;

-- Daily Active Users
SELECT day_no, COUNT(DISTINCT customer_id) AS dau
FROM fact_transaction WHERE is_fraud = 0
GROUP BY day_no ORDER BY day_no;

-- Monthly Active Users (the file covers one 31 day window, so only one month exists)
SELECT COUNT(DISTINCT customer_id) AS mau FROM fact_transaction WHERE is_fraud = 0;

-- DAU/MAU: average DAU divided by MAU. Read the caveat in the README before using it.
SELECT ROUND(AVG(dau), 0) AS avg_dau, MAX(m.mau) AS mau, ROUND(AVG(dau) / MAX(m.mau), 4) AS dau_mau
FROM (SELECT day_no, COUNT(DISTINCT customer_id) AS dau
      FROM fact_transaction WHERE is_fraud = 0 GROUP BY day_no) d
CROSS JOIN (SELECT COUNT(DISTINCT customer_id) AS mau FROM fact_transaction WHERE is_fraud = 0) m;

-- Customer level table, reused by later scripts
DROP TABLE IF EXISTS customer_summary;
CREATE TABLE customer_summary AS
SELECT customer_id,
       MIN(day_no)   AS first_day,
       MAX(day_no)   AS last_day,
       COUNT(*)      AS txns,
       SUM(amount)   AS txn_value,
       SUM(gross_fee) AS gross_fee,
       SUM(net_fee)  AS net_fee
FROM fact_transaction WHERE is_fraud = 0
GROUP BY customer_id;
ALTER TABLE customer_summary ADD PRIMARY KEY (customer_id);

-- New versus returning, by day. New = first observed transaction. This is NOT a registration date.
SELECT a.day_no, a.dau,
       COALESCE(n.new_customers, 0)             AS new_customers,
       a.dau - COALESCE(n.new_customers, 0)     AS returning_customers
FROM (SELECT day_no, COUNT(DISTINCT customer_id) AS dau FROM fact_transaction WHERE is_fraud = 0 GROUP BY day_no) a
LEFT JOIN (SELECT first_day, COUNT(*) AS new_customers FROM customer_summary GROUP BY first_day) n
       ON n.first_day = a.day_no
ORDER BY a.day_no;

-- Transaction frequency per customer
SELECT txns AS txns_per_customer, COUNT(*) AS customers,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS share_of_customers
FROM customer_summary GROUP BY txns ORDER BY txns;

-- Customer value segments (top 1%, next 9%, next 40%, bottom 50% by value sent).
-- Row numbers are compared with cnt * share. Dividing integers first would round the
-- percentile to 4 decimals (div_precision_increment) and push extra customers into the top 1%.
DROP TABLE IF EXISTS customer_segment;
CREATE TABLE customer_segment AS
SELECT customer_id, txn_value, gross_fee, net_fee,
       CASE WHEN rn <= cnt * 0.01 THEN '1 Top 1% by value'
            WHEN rn <= cnt * 0.10 THEN '2 Next 9%'
            WHEN rn <= cnt * 0.50 THEN '3 Next 40%'
            ELSE '4 Bottom 50%' END AS segment
FROM (SELECT customer_id, txn_value, gross_fee, net_fee,
             ROW_NUMBER() OVER (ORDER BY txn_value DESC, customer_id) AS rn,
             COUNT(*) OVER () AS cnt
      FROM customer_summary) r;

SELECT segment, COUNT(*) AS customers, SUM(txn_value) AS value, SUM(gross_fee) AS gross_revenue,
       SUM(net_fee) AS net_revenue
FROM customer_segment GROUP BY segment ORDER BY segment;
