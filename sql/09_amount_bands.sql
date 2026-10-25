-- Revenue concentration by amount band (customer level concentration is not possible, 99.7% of initiators transact once).
WITH b AS (
  SELECT t.*, f.fee_rate,
    CASE WHEN amount < 1000 THEN '1 <1k' WHEN amount < 10000 THEN '2 1k-10k'
         WHEN amount < 100000 THEN '3 10k-100k' WHEN amount < 1000000 THEN '4 100k-1M'
         ELSE '5 >=1M' END AS band
  FROM txn t JOIN fee_assumptions f USING (txn_type) WHERE is_fraud = 0)
SELECT band, count(*) AS txns, round(sum(amount),0) AS value,
       round(sum(amount*fee_rate),0) AS modelled_fee_revenue,
       round(100.0*sum(amount*fee_rate)/sum(sum(amount*fee_rate)) OVER (),2) AS revenue_share_pct
FROM b GROUP BY band ORDER BY band;
