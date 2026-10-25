-- Daily activity. Active user = distinct initiating account (orig_id) with >=1 COMPLETED txn that day.
-- dau_any_role also counts customer (C) accounts that only received money.
WITH ok AS (SELECT * FROM txn WHERE is_fraud = 0),
roles AS (
  SELECT day_no, orig_id AS acct FROM ok
  UNION
  SELECT day_no, dest_id FROM ok WHERE dest_id LIKE 'C%'
)
SELECT
  d.day_no, d.attempts, d.completed_count, d.cancelled_count,
  coalesce(d.completed_value,0) AS completed_value, coalesce(d.modelled_fee_revenue,0) AS modelled_fee_revenue, d.dau_initiators, coalesce(r.dau_any_role,0) AS dau_any_role
FROM (
  SELECT t.day_no,
         count(*)                                       AS attempts,
         count(*) FILTER (WHERE is_fraud = 0)           AS completed_count,
         count(*) FILTER (WHERE is_fraud = 1)           AS cancelled_count,
         sum(amount) FILTER (WHERE is_fraud = 0)        AS completed_value,
         sum(amount * f.fee_rate) FILTER (WHERE is_fraud = 0) AS modelled_fee_revenue,
         count(DISTINCT orig_id) FILTER (WHERE is_fraud = 0)  AS dau_initiators
  FROM txn t JOIN fee_assumptions f USING (txn_type)
  GROUP BY t.day_no
) d
LEFT JOIN (SELECT day_no, count(DISTINCT acct) AS dau_any_role FROM roles GROUP BY day_no) r USING (day_no)
ORDER BY d.day_no;
