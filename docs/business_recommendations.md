# Business recommendations

1. Fix data capture before building more reports. Add transaction status and failure reason, fee and partner fee records, registration date, channel, refund and chargeback tables, and daily balance snapshots. Without them, failure rate, net revenue and true balance trends cannot be reported.

2. Add a full balance drain rule to fraud screening and test it on real data. In this dataset, a transfer or cash out that empties the sender account flagged 8,018 transactions, all fraud, and captured 88% of fraud value. The existing system flag caught 16 of 8,213. Check false positives on live customers before use, because the simulator makes this pattern unusually clean.

3. Review overnight controls. In each hour from 02:00 to 05:59, fraud labelled rows are 10% to 22% of transactions, against under 0.1% in the main daytime hours. Options are step up checks, lower limits or tighter monitoring for large overnight transfers and cash outs.

4. Track fraud rate and fraud value together. Fraud count is steady near 265 a day while volume swings. The rate looks alarming on quiet days and mild on busy days. Report both, and report exposure against fee revenue.

5. Investigate the balance reconciliation failures. 56.6% of sender balance changes do not equal the amount. In a real ledger this points to timing, rejected transactions, or a data pipeline fault.

6. Report DAU/MAU only when customers repeat. Here the ratio equals 1/31 almost by construction. Use transactions per active customer, 7 day retention and cohort tables once registration dates exist.

7. Protect the types that earn. Under the assumed schedule CASH_OUT and TRANSFER give 95% of net revenue, while PAYMENT is a third of volume and 5% of net revenue. Review PAYMENT merchant fee levels and cash out agent costs against real fee data.

8. Treat revenue as a scenario until fee records exist. Use the Excel fee model to show how net revenue moves with each rate.
