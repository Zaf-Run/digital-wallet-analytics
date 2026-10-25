-- Build the base ledger. PaySim has no transaction_id, so one is created from row order.
-- step = 1 hour of simulated time (1..743). day_no = 1..31. No calendar date exists in the source.
CREATE OR REPLACE TABLE txn AS
SELECT
  row_number() OVER ()                              AS txn_id,
  step,
  ((step - 1) // 24) + 1                            AS day_no,
  ((step - 1) % 24)                                 AS hour_of_day,
  type                                              AS txn_type,
  amount,
  nameOrig                                          AS orig_id,
  oldbalanceOrg                                     AS orig_bal_before,
  newbalanceOrig                                    AS orig_bal_after,
  nameDest                                          AS dest_id,
  oldbalanceDest                                    AS dest_bal_before,
  newbalanceDest                                    AS dest_bal_after,
  isFraud                                           AS is_fraud,
  isFlaggedFraud                                    AS is_flagged,
  CASE WHEN isFraud = 1 THEN 'CANCELLED_FRAUD' ELSE 'COMPLETED' END AS status_proxy,
  CASE type WHEN 'CASH_IN' THEN 'Agent' WHEN 'CASH_OUT' THEN 'Agent'
            WHEN 'PAYMENT' THEN 'Merchant' WHEN 'TRANSFER' THEN 'P2P'
            ELSE 'Other' END                        AS channel_proxy
FROM read_csv_auto('data/raw/paysim.csv');

-- ILLUSTRATIVE fee schedule. NOT observed in the data. Edit the rates to test scenarios.
CREATE OR REPLACE TABLE fee_assumptions AS
SELECT * FROM (VALUES
  ('CASH_IN',  0.000, 'Customer deposits at agent, no customer fee assumed'),
  ('CASH_OUT', 0.010, 'Agent withdrawal, 1.0% customer fee assumed'),
  ('TRANSFER', 0.005, 'P2P transfer, 0.5% customer fee assumed'),
  ('PAYMENT',  0.008, 'Merchant discount rate, 0.8% assumed'),
  ('DEBIT',    0.000, 'Debit to bank, no fee assumed')
) t(txn_type, fee_rate, note);
