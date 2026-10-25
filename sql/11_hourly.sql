-- Hour of day profile. Hour is simulated, not local clock time.
SELECT hour_of_day, count(*) AS attempts,
       count(*) FILTER (WHERE is_fraud = 1) AS cancelled_count,
       round(100.0 * count(*) FILTER (WHERE is_fraud = 1) / count(*), 3) AS cancellation_rate_pct
FROM txn GROUP BY hour_of_day ORDER BY hour_of_day;
