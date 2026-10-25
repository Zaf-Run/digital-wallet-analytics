-- Operational view of cancelled (fraud) transactions and the legacy rule flag.
SELECT
  txn_type,
  count(*) FILTER (WHERE is_fraud = 1)                                    AS fraud_txns,
  coalesce(sum(amount) FILTER (WHERE is_fraud = 1),0)                     AS fraud_value,
  count(*) FILTER (WHERE is_flagged = 1)                                  AS flagged_by_rule,
  count(*) FILTER (WHERE is_fraud = 1 AND is_flagged = 1)                 AS fraud_and_flagged,
  count(*) FILTER (WHERE is_fraud = 1 AND amount = orig_bal_before AND orig_bal_before > 0) AS account_drain_pattern,
  round(100.0 * count(*) FILTER (WHERE is_fraud = 1 AND is_flagged = 1)
        / nullif(count(*) FILTER (WHERE is_fraud = 1),0), 2)              AS rule_recall_pct
FROM txn GROUP BY txn_type ORDER BY fraud_txns DESC;
