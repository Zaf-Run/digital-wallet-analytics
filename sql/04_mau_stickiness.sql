-- Only one calendar month exists, so there is exactly one MAU per definition.
WITH ok AS (SELECT * FROM txn WHERE is_fraud = 0),
daily AS (SELECT day_no, count(DISTINCT orig_id) AS dau FROM ok GROUP BY day_no),
mau AS (SELECT count(DISTINCT orig_id) AS mau FROM ok)
SELECT
  round(avg(dau),0)                         AS avg_dau,
  (SELECT mau FROM mau)                     AS mau,
  round(100.0 * avg(dau) / (SELECT mau FROM mau), 2) AS dau_mau_pct
FROM daily;
