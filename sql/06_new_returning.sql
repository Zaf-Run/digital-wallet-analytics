-- "New" = first day the account appears in the log (any role, customer C accounts). NOT a registration date.
WITH ok AS (SELECT * FROM txn WHERE is_fraud = 0),
appear AS (
  SELECT day_no, orig_id AS acct FROM ok
  UNION ALL SELECT day_no, dest_id FROM ok WHERE dest_id LIKE 'C%'
),
first_seen AS (SELECT acct, min(day_no) AS first_day FROM appear GROUP BY acct),
active AS (SELECT DISTINCT day_no, acct FROM appear)
SELECT a.day_no,
       count(*) FILTER (WHERE a.day_no = f.first_day) AS new_in_log,
       count(*) FILTER (WHERE a.day_no > f.first_day) AS returning,
       count(*)                                       AS active_any_role
FROM active a JOIN first_seen f USING (acct)
GROUP BY a.day_no ORDER BY a.day_no;
