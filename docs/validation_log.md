# Validation log

Python results (python/analysis.py) were reconciled to MySQL results (sql/01 to 07). SQL was tested on MariaDB 10.11, which is compatible with the MySQL 8 syntax used.

Matched exactly:
Row count 6,362,620. Negative amounts 0. Zero amounts 16. Duplicate groups 0. Fraud rows 4,116 CASH_OUT and 4,097 TRANSFER. Flagged rows 16. Balance exceptions 3,601,595. Debits from zero balance 2,088,969. Debits above balance 3,601,543. DAU day 1 573,913 and day 2 454,879. MAU 6,345,122. New customers day 1 to 4: 573,913, 454,748, 760, 27,971. Repeat customers 9,270. Frequency 6,335,852 / 9,255 / 15. Segment sizes 63,451 / 571,061 / 2,538,049 / 3,172,561. Mean last balance 856,010.16 and share of zero balances 56.68%.

Matched within rounding:
Gross and net fee totals differ by about 175 and 117 units out of billions, because SQL rounds each fee to two decimals.

Differences explained:
Median last balance on reconciled rows is 207,837 in Python and 207,845 in SQL. Python takes each customer's last reconciled row. SQL takes customers whose last row reconciles. Only repeat customers differ.

Defect found and fixed:
The first SQL segment query divided row number by customer count. MySQL and MariaDB round that quotient to four decimals (div_precision_increment), which put 317 extra customers into the top 1%. The query now compares the row number with count x share.

Not tested in SQL: the fraud rule union query (sql/05) and the daily balance and revenue by day queries. They use the same logic as tested queries and the Python outputs give the reference values.

Excel check: the formula driven fee model gives net revenue 2.1% above the exact Python base case (3.548 billion against 3.473 billion). The gap comes from applying the per transaction cap to band averages. CASH_OUT is 3.4% high. Other types match.

Runtime on a 1 core, 3 GB sandbox: load 1 minute, build fact table 2 minutes, DAU 40 seconds, customer summary 3 minutes, last balance table 4 minutes, duplicate check 100 seconds.
