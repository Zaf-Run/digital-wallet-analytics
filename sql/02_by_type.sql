SELECT
  t.txn_type,
  any_value(channel_proxy)                              AS channel_proxy,
  count(*)                                              AS attempts,
  count(*) FILTER (WHERE is_fraud = 0)                  AS completed_count,
  count(*) FILTER (WHERE is_fraud = 1)                  AS cancelled_count,
  round(100.0 * count(*) FILTER (WHERE is_fraud = 1) / count(*), 4) AS cancellation_rate_pct,
  sum(amount)                                           AS attempted_value,
  sum(amount) FILTER (WHERE is_fraud = 0)               AS completed_value,
  round(avg(amount),2)                                  AS avg_amount,
  round(median(amount),2)                               AS median_amount,
  round(sum(amount) FILTER (WHERE is_fraud = 0) * any_value(f.fee_rate), 2) AS modelled_fee_revenue
FROM txn t JOIN fee_assumptions f USING (txn_type)
GROUP BY t.txn_type
ORDER BY attempted_value DESC;
