-- 02_build_model.sql
-- Builds dimension tables and the transaction fact table.
-- The source has NO fee records. dim_fee_schedule holds an ILLUSTRATIVE schedule
-- (assumption, not observation). Change the numbers and rebuild to test scenarios.
USE wallet_analytics;

DROP TABLE IF EXISTS dim_fee_schedule;
CREATE TABLE dim_fee_schedule (
    type_code     VARCHAR(10) PRIMARY KEY,
    direction     VARCHAR(20) NOT NULL,       -- effect on the sender's wallet
    gross_rate    DECIMAL(6,4) NOT NULL,      -- share of amount charged
    partner_rate  DECIMAL(6,4) NOT NULL,      -- share of amount paid to agents, processors, banks
    fee_cap       DECIMAL(12,2) NOT NULL      -- maximum gross fee per transaction
);
INSERT INTO dim_fee_schedule VALUES
 ('CASH_IN',  'credit', 0.0000, 0.0000, 5000),
 ('CASH_OUT', 'debit',  0.0150, 0.0090, 5000),
 ('TRANSFER', 'debit',  0.0050, 0.0010, 5000),
 ('PAYMENT',  'debit',  0.0100, 0.0040, 5000),
 ('DEBIT',    'debit',  0.0050, 0.0020, 5000);

DROP TABLE IF EXISTS fact_transaction;
CREATE TABLE fact_transaction (
    txn_id            INT PRIMARY KEY,
    step              INT NOT NULL,
    day_no            SMALLINT NOT NULL,       -- day 1 = steps 1 to 24, day 31 holds 23 hours
    hour_of_day       TINYINT NOT NULL,
    customer_id       VARCHAR(15) NOT NULL,    -- originating customer account
    counterparty_id   VARCHAR(15) NOT NULL,
    counterparty_type VARCHAR(10) NOT NULL,    -- MERCHANT or CUSTOMER
    type_code         VARCHAR(10) NOT NULL,
    amount            DECIMAL(16,2) NOT NULL,
    old_bal_orig      DECIMAL(16,2) NOT NULL,
    new_bal_orig      DECIMAL(16,2) NOT NULL,
    old_bal_dest      DECIMAL(16,2) NOT NULL,
    new_bal_dest      DECIMAL(16,2) NOT NULL,
    is_fraud          TINYINT NOT NULL,
    is_flagged        TINYINT NOT NULL,
    orig_recon_ok     TINYINT NOT NULL,        -- 1 when the balance change equals the amount
    gross_fee         DECIMAL(14,2) NOT NULL,  -- scenario fee, zero on fraud labelled rows
    partner_cost      DECIMAL(14,2) NOT NULL,
    net_fee           DECIMAL(14,2) NOT NULL
);

INSERT INTO fact_transaction
SELECT s.row_id,
       s.step,
       FLOOR((s.step - 1) / 24) + 1,
       MOD(s.step - 1, 24),
       s.nameOrig,
       s.nameDest,
       CASE WHEN s.nameDest LIKE 'M%' THEN 'MERCHANT' ELSE 'CUSTOMER' END,
       s.type,
       s.amount, s.oldbalanceOrg, s.newbalanceOrig, s.oldbalanceDest, s.newbalanceDest,
       s.isFraud, s.isFlaggedFraud,
       CASE WHEN ABS((CASE WHEN s.type = 'CASH_IN' THEN s.oldbalanceOrg + s.amount
                           ELSE s.oldbalanceOrg - s.amount END) - s.newbalanceOrig) <= 0.01 THEN 1 ELSE 0 END,
       CASE WHEN s.isFraud = 1 THEN 0 ELSE LEAST(s.amount * f.gross_rate, f.fee_cap) END,
       CASE WHEN s.isFraud = 1 OR f.gross_rate = 0 THEN 0
            ELSE LEAST(s.amount * f.gross_rate, f.fee_cap) * f.partner_rate / f.gross_rate END,
       0
FROM stg_paysim s
JOIN dim_fee_schedule f ON f.type_code = s.type;

UPDATE fact_transaction SET net_fee = gross_fee - partner_cost;

CREATE INDEX ix_fact_day      ON fact_transaction (day_no);
CREATE INDEX ix_fact_customer ON fact_transaction (customer_id);
CREATE INDEX ix_fact_type     ON fact_transaction (type_code);
