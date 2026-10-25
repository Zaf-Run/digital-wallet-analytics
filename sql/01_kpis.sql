-- Transaction performance. "Successful" = COMPLETED (not cancelled for fraud).
SELECT
  count(*)                                              AS attempts,
  sum(amount)                                           AS attempted_value,
  avg(amount)                                           AS avg_amount,
  count(*) FILTER (WHERE is_fraud = 0)                  AS completed_count,
  sum(amount) FILTER (WHERE is_fraud = 0)               AS completed_value,
  count(*) FILTER (WHERE is_fraud = 1)                  AS cancelled_count,
  coalesce(sum(amount) FILTER (WHERE is_fraud = 1),0)   AS cancelled_value,
  round(100.0 * count(*) FILTER (WHERE is_fraud = 1) / count(*), 4) AS cancellation_rate_pct
FROM txn;
