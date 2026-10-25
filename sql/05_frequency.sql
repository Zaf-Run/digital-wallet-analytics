-- Transactions per initiating account, and per receiving customer account (COMPLETED only).
WITH o AS (SELECT orig_id AS acct, count(*) AS n FROM txn WHERE is_fraud = 0 GROUP BY 1),
     d AS (SELECT dest_id AS acct, count(*) AS n FROM txn WHERE is_fraud = 0 AND dest_id LIKE 'C%' GROUP BY 1)
SELECT 'initiator' AS role, least(n,10) AS txn_count_bucket, count(*) AS accounts FROM o GROUP BY 1,2
UNION ALL
SELECT 'receiver', least(n,10), count(*) FROM d GROUP BY 1,2
ORDER BY 1,2;
