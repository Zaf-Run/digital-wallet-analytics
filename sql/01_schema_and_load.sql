-- 01_schema_and_load.sql
-- Creates the database and loads the raw PaySim file into a staging table.
-- Edit the file path in the LOAD DATA statement. Works on MySQL 8 and MariaDB 10.5+.
-- Start the client with: mysql --local-infile=1 -u root -p

CREATE DATABASE IF NOT EXISTS wallet_analytics;
USE wallet_analytics;

DROP TABLE IF EXISTS stg_paysim;
CREATE TABLE stg_paysim (
    row_id          INT AUTO_INCREMENT PRIMARY KEY,   -- keeps file order, used as the surrogate transaction id
    step            INT           NOT NULL,           -- one step = one hour of simulated time
    type            VARCHAR(10)   NOT NULL,
    amount          DECIMAL(16,2) NOT NULL,
    nameOrig        VARCHAR(15)   NOT NULL,
    oldbalanceOrg   DECIMAL(16,2) NOT NULL,
    newbalanceOrig  DECIMAL(16,2) NOT NULL,
    nameDest        VARCHAR(15)   NOT NULL,
    oldbalanceDest  DECIMAL(16,2) NOT NULL,
    newbalanceDest  DECIMAL(16,2) NOT NULL,
    isFraud         TINYINT       NOT NULL,
    isFlaggedFraud  TINYINT       NOT NULL
);

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE '/path/to/PS_20174392719_1491204439457_log.csv'
INTO TABLE stg_paysim
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(step, type, amount, nameOrig, oldbalanceOrg, newbalanceOrig,
 nameDest, oldbalanceDest, newbalanceDest, isFraud, isFlaggedFraud);

SELECT COUNT(*) AS rows_loaded FROM stg_paysim;   -- expect 6,362,620
