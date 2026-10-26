"""
Digital Wallet Analytics: reproducible analysis pipeline.

Input : PaySim mobile money log (PS_20174392719_1491204439457_log.csv)
Output: summary CSVs in ../outputs used by Excel, Power BI and the README.

Run   : python analysis.py --input path/to/PS_..._log.csv --out ../outputs
Needs : pandas, numpy. About 2 GB free RAM.
"""
import argparse
import os

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Illustrative fee schedule. The dataset has NO fee records, so every revenue
# figure below is a scenario, not an observation. Edit here and re run.
# gross_rate   : fee charged to the customer or merchant, share of amount
# partner_rate : cost paid to agents, processors or banks, share of amount
# cap          : maximum gross fee per transaction, in simulated currency units
# ---------------------------------------------------------------------------
FEE_SCHEDULE = pd.DataFrame(
    [
        ("CASH_IN", 0.000, 0.000, 5000.0),
        ("CASH_OUT", 0.015, 0.009, 5000.0),
        ("TRANSFER", 0.005, 0.001, 5000.0),
        ("PAYMENT", 0.010, 0.004, 5000.0),
        ("DEBIT", 0.005, 0.002, 5000.0),
    ],
    columns=["type", "gross_rate", "partner_rate", "cap"],
)
SCENARIOS = {"low": 0.5, "base": 1.0, "high": 1.5}  # multipliers on gross rate
BALANCE_BANDS = [-0.01, 0, 1_000, 10_000, 100_000, 1_000_000, np.inf]
BALANCE_LABELS = ["0 (empty)", "0 to 1k", "1k to 10k", "10k to 100k", "100k to 1M", "1M and above"]
AMOUNT_BANDS = [-0.01, 1_000, 5_000, 10_000, 50_000, 100_000, 250_000, 500_000, 1_000_000, 5_000_000, np.inf]
AMOUNT_LABELS = ["a_0_1k", "b_1k_5k", "c_5k_10k", "d_10k_50k", "e_50k_100k", "f_100k_250k",
                 "g_250k_500k", "h_500k_1M", "i_1M_5M", "j_5M_plus"]
DEBIT_TYPES = ["PAYMENT", "TRANSFER", "CASH_OUT", "DEBIT"]


def load(path):
    df = pd.read_csv(path)
    n_raw = len(df)
    df.insert(0, "txn_id", np.arange(1, n_raw + 1, dtype=np.int64))  # surrogate key, file has none
    df["customer_id"] = df.pop("nameOrig").str[1:].astype(np.int64)  # all originators are C accounts
    dest = df.pop("nameDest")
    df["dest_is_merchant"] = dest.str.startswith("M")
    df["dest_id"] = dest.str[1:].astype(np.int64)
    df = df.rename(columns={"oldbalanceOrg": "old_bal_orig", "newbalanceOrig": "new_bal_orig",
                            "oldbalanceDest": "old_bal_dest", "newbalanceDest": "new_bal_dest",
                            "isFraud": "is_fraud", "isFlaggedFraud": "is_flagged"})
    df["type"] = df["type"].astype("category")
    df["day"] = ((df["step"] - 1) // 24 + 1).astype(np.int16)
    df["hour_of_day"] = ((df["step"] - 1) % 24).astype(np.int8)
    debit = df["type"].isin(DEBIT_TYPES).to_numpy()
    expected = np.where(debit, df["old_bal_orig"] - df["amount"], df["old_bal_orig"] + df["amount"])
    df["orig_recon_ok"] = np.abs(expected - df["new_bal_orig"].to_numpy()) <= 0.0100001  # cent level tolerance
    df["billable"] = df["is_fraud"].eq(0)  # fraud labelled rows assumed reversed, no fee earned
    return df


def add_fees(df, mult=1.0, capped=True):
    f = FEE_SCHEDULE.set_index("type")
    rate = df["type"].map(f["gross_rate"]).astype(float).to_numpy() * mult
    cap = df["type"].map(f["cap"]).astype(float).to_numpy()
    share = (f["partner_rate"] / f["gross_rate"].replace(0, np.nan)).fillna(0)
    share = df["type"].map(share).astype(float).to_numpy()
    gross = df["amount"].to_numpy() * rate
    if capped:
        gross = np.minimum(gross, cap)
    gross = np.where(df["billable"].to_numpy(), gross, 0.0)
    return gross, gross * share, gross * (1 - share)


def validation(df, n_file_rows):
    rows = []

    def add(check, result, expected, note=""):
        status = "PASS" if str(result) == str(expected) else "REVIEW"
        rows.append((check, result, expected, status, note))

    add("Row count equals file data lines", len(df), n_file_rows)
    add("Null values across all columns", int(df.isna().sum().sum()), 0)
    add("Negative amounts", int((df["amount"] < 0).sum()), 0)
    add("Zero amounts", int((df["amount"] == 0).sum()), 0, "Zero value rows are all fraud labelled cash outs")
    dup = df.duplicated(subset=["step", "type", "amount", "customer_id", "dest_id"]).sum()
    add("Duplicate rows on step, type, amount, customer, destination", int(dup), 0, "No retries or duplicates detectable")
    add("File sorted by step (needed for last observation logic)", bool(df["step"].is_monotonic_increasing), True)
    add("Distinct hourly steps", int(df["step"].nunique()), 743)
    add("Calendar days covered (step / 24)", int(df["day"].nunique()), 31, "Day 31 holds 23 hours only")
    add("Distinct transaction types", int(df["type"].nunique()), 5)
    add("Fraud labelled rows only in TRANSFER and CASH_OUT",
        bool(df.loc[df.is_fraud == 1, "type"].isin(["TRANSFER", "CASH_OUT"]).all()), True)
    add("Flagged rows are all fraud labelled", bool((df.loc[df.is_flagged == 1, "is_fraud"] == 1).all()), True)
    add("Merchant destinations only on PAYMENT", bool(df.loc[df.dest_is_merchant, "type"].eq("PAYMENT").all()), True)
    ok = df["orig_recon_ok"]
    add("Originator balance reconciles to amount", f"{ok.mean():.4f}", "1.0000",
        "Pre and post balances reconcile for a minority of rows; see balance section")
    zero_old = ((df.old_bal_orig == 0) & (df.amount > 0) & df.type.isin(DEBIT_TYPES)).sum()
    add("Debit rows from an account with zero opening balance", int(zero_old), 0, "Not possible in a live ledger")
    over = ((df.amount > df.old_bal_orig + 0.01) & df.type.isin(DEBIT_TYPES)).sum()
    add("Debit rows where amount exceeds opening balance", int(over), 0, "Overdraft or unreliable balance field")
    cust_dest = df[~df.dest_is_merchant]
    d_ok = ((cust_dest.old_bal_dest + cust_dest.amount - cust_dest.new_bal_dest).abs() <= 0.0100001).mean()
    add("Customer destination balance reconciles to amount", f"{d_ok:.4f}", "1.0000", "Destination balances not usable")
    return pd.DataFrame(rows, columns=["check", "result", "expected", "status", "note"])


def main(path, out):
    os.makedirs(out, exist_ok=True)
    with open(path, "rb") as fh:
        n_file_rows = sum(1 for _ in fh) - 1
    df = load(path)
    g, p, n = add_fees(df)
    df["fee_gross"], df["fee_partner"], df["fee_net"] = g, p, n

    validation(df, n_file_rows).to_csv(f"{out}/validation_checks.csv", index=False)

    act = df[df.billable]  # qualifying activity: non fraud transactions
    days = pd.DataFrame({"day": np.arange(1, 32)})
    days["hours_covered"] = np.where(days.day == 31, 23, 24)
    days["is_full_day"] = days.hours_covered.eq(24)

    # ---------------- engagement ----------------
    dau = act.groupby("day").customer_id.nunique().rename("dau")
    first_day = act.groupby("customer_id").day.min()
    new_c = first_day.value_counts().rename("new_customers")
    daily = df.groupby("day").agg(txn_count=("txn_id", "size"), txn_value=("amount", "sum"),
                                  fraud_count=("is_fraud", "sum"), flagged_count=("is_flagged", "sum"))
    daily["recon_exception"] = (~df.orig_recon_ok).groupby(df.day).sum()
    daily["fraud_value"] = df[df.is_fraud == 1].groupby("day").amount.sum()
    b = act.groupby("day").agg(billable_count=("txn_id", "size"), billable_value=("amount", "sum"),
                               gross_revenue=("fee_gross", "sum"), partner_cost=("fee_partner", "sum"),
                               net_revenue=("fee_net", "sum"))
    daily = days.set_index("day").join([daily, b, dau, new_c]).fillna(0).reset_index()
    daily["returning_customers"] = daily.dau - daily.new_customers
    daily["avg_amount"] = daily.txn_value / daily.txn_count.replace(0, np.nan)
    daily["fraud_rate_count"] = daily.fraud_count / daily.txn_count.replace(0, np.nan)
    daily["recon_exception_rate"] = daily.recon_exception / daily.txn_count.replace(0, np.nan)
    daily["high_volume_day"] = daily.txn_count >= 100_000
    rec = act[act.orig_recon_ok].groupby("day").new_bal_orig.agg(avg_post_balance="mean", median_post_balance="median",
                                                                  recon_txn="size").reset_index()
    daily = daily.merge(rec, on="day", how="left")
    daily.to_csv(f"{out}/daily_summary.csv", index=False)
    days.merge(daily[["day", "txn_count", "high_volume_day"]], on="day").to_csv(f"{out}/dim_date.csv", index=False)

    mau = int(act.customer_id.nunique())
    full = daily[daily.is_full_day]
    freq = act.groupby("customer_id").size()
    freq_t = freq.value_counts().sort_index().rename_axis("txns_per_customer").reset_index(name="customers")
    freq_t["share_of_customers"] = freq_t.customers / freq_t.customers.sum()
    freq_t.to_csv(f"{out}/txn_frequency.csv", index=False)

    # alternative definition: customer account appears as sender or as receiver
    s = act[["day", "customer_id"]].rename(columns={"customer_id": "acct"})
    r = act.loc[~act.dest_is_merchant, ["day", "dest_id"]].rename(columns={"dest_id": "acct"})
    part = pd.concat([s, r]).drop_duplicates()
    dau_alt = part.groupby("day").acct.nunique().rename("dau_participant")
    mau_alt = int(part.acct.nunique())
    alt = days.set_index("day").join(dau_alt).reset_index()
    alt["dau_sender"] = alt.day.map(dau)
    alt.to_csv(f"{out}/engagement_alt_definition.csv", index=False)
    del part, s, r

    last_day = act.groupby("customer_id").day.max()
    recency = (31 - last_day).value_counts().sort_index().rename_axis("days_before_window_end").reset_index(name="customers")
    recency.to_csv(f"{out}/customer_recency.csv", index=False)

    # ---------------- value segments ----------------
    cust = act.groupby("customer_id").agg(txns=("txn_id", "size"), value=("amount", "sum"), revenue=("fee_gross", "sum"),
                                          net=("fee_net", "sum"))
    pct = cust.value.rank(pct=True, ascending=False, method="first")
    cust["segment"] = np.select([pct <= 0.01, pct <= 0.10, pct <= 0.50],
                                ["1 Top 1% by value", "2 Next 9%", "3 Next 40%"], "4 Bottom 50%")
    seg = cust.groupby("segment").agg(customers=("txns", "size"), txns=("txns", "sum"), value=("value", "sum"),
                                      gross_revenue=("revenue", "sum"), net_revenue=("net", "sum")).reset_index()
    for c in ["customers", "value", "gross_revenue", "net_revenue"]:
        seg[f"{c}_share"] = seg[c] / seg[c].sum()
    seg.to_csv(f"{out}/customer_value_segments.csv", index=False)
    life = pd.DataFrame({"segment": ["Single transaction", "Repeat (2 or more)"],
                         "customers": [int((freq == 1).sum()), int((freq >= 2).sum())],
                         "txns": [int(freq[freq == 1].sum()), int(freq[freq >= 2].sum())]})
    life.to_csv(f"{out}/customer_lifecycle_segments.csv", index=False)
    del cust, pct

    # ---------------- performance ----------------
    t = df.groupby("type", observed=True).agg(txn_count=("txn_id", "size"), txn_value=("amount", "sum"),
                                              avg_amount=("amount", "mean"), median_amount=("amount", "median"),
                                              fraud_count=("is_fraud", "sum"))
    t["recon_exception"] = (~df.orig_recon_ok).groupby(df.type, observed=True).sum()
    t["fraud_value"] = df[df.is_fraud == 1].groupby("type", observed=True).amount.sum()
    t = t.join(act.groupby("type", observed=True).agg(billable_count=("txn_id", "size"), billable_value=("amount", "sum"),
                                                      gross_revenue=("fee_gross", "sum"), partner_cost=("fee_partner", "sum"),
                                                      net_revenue=("fee_net", "sum")))
    t = t.fillna(0).reset_index()
    t["count_share"] = t.txn_count / t.txn_count.sum()
    t["value_share"] = t.txn_value / t.txn_value.sum()
    t["fraud_rate_count"] = t.fraud_count / t.txn_count
    t["fraud_rate_value"] = t.fraud_value / t.txn_value
    t["recon_exception_rate"] = t.recon_exception / t.txn_count
    t["avg_gross_fee_per_billable_txn"] = t.gross_revenue / t.billable_count
    t["gross_fee_pct_of_billable_value"] = t.gross_revenue / t.billable_value
    t.to_csv(f"{out}/type_summary.csv", index=False)

    cp = df.groupby(["type", "dest_is_merchant"], observed=True).agg(txn_count=("txn_id", "size"), txn_value=("amount", "sum")).reset_index()
    cp["counterparty"] = np.where(cp.dest_is_merchant, "Merchant", "Customer account")
    cp.drop(columns="dest_is_merchant").to_csv(f"{out}/counterparty_mix.csv", index=False)

    dt = df.groupby(["day", "type"], observed=True).agg(txn_count=("txn_id", "size"), txn_value=("amount", "sum"),
                                                        fraud_count=("is_fraud", "sum")).reset_index()
    dt = dt.merge(act.groupby(["day", "type"], observed=True).agg(gross_revenue=("fee_gross", "sum"), net_revenue=("fee_net", "sum")).reset_index(),
                  on=["day", "type"], how="left").fillna(0)
    dt.to_csv(f"{out}/daily_type_summary.csv", index=False)

    h = df.groupby("hour_of_day").agg(txn_count=("txn_id", "size"), txn_value=("amount", "sum"), fraud_count=("is_fraud", "sum")).reset_index()
    h["fraud_rate_count"] = h.fraud_count / h.txn_count
    h.to_csv(f"{out}/hourly_summary.csv", index=False)

    # fraud screening rules (the only exception data in the file)
    fr = df.is_fraud == 1
    rules = {
        "R0 System flag (isFlaggedFraud)": df.is_flagged == 1,
        "R1 TRANSFER above 200,000": (df.type == "TRANSFER") & (df.amount > 200_000),
        "R2 TRANSFER or CASH_OUT": df.type.isin(["TRANSFER", "CASH_OUT"]),
        "R3 TRANSFER or CASH_OUT draining the full opening balance":
            df.type.isin(["TRANSFER", "CASH_OUT"]) & (df.old_bal_orig > 0) & ((df.amount - df.old_bal_orig).abs() <= 0.0100001),
    }
    ev = []
    for k, m in rules.items():
        tp = int((m & fr).sum()); fl = int(m.sum())
        pr = tp / fl if fl else np.nan; rc = tp / int(fr.sum())
        ev.append((k, fl, tp, pr, rc, 2 * pr * rc / (pr + rc) if tp else 0.0, float(df.loc[m & fr, "amount"].sum() / df.loc[fr, "amount"].sum())))
    pd.DataFrame(ev, columns=["rule", "flagged", "true_fraud", "precision", "recall", "f1", "fraud_value_captured_share"]).to_csv(
        f"{out}/fraud_rule_evaluation.csv", index=False)

    # ---------------- balances ----------------
    last_all = act.drop_duplicates("customer_id", keep="last")
    last_ok = act[act.orig_recon_ok].drop_duplicates("customer_id", keep="last")
    rows, dist = [], []
    for name, d in [("All customers, last post transaction balance", last_all),
                    ("Reconciled rows only, last post transaction balance", last_ok)]:
        x = d.new_bal_orig
        rows.append((name, len(d), x.mean(), x.median(), x.quantile(.25), x.quantile(.75), x.quantile(.90), x.quantile(.99), (x == 0).mean()))
        band = pd.cut(x, BALANCE_BANDS, labels=BALANCE_LABELS, right=True)
        vc = band.value_counts().reindex(BALANCE_LABELS).fillna(0).astype(int)
        for lab, c in vc.items():
            dist.append((name, lab, c, c / vc.sum(), x[band == lab].sum()))
    pd.DataFrame(rows, columns=["scope", "customers", "mean", "median", "p25", "p75", "p90", "p99", "share_zero"]).to_csv(
        f"{out}/balance_summary.csv", index=False)
    pd.DataFrame(dist, columns=["scope", "balance_band", "customers", "share_of_customers", "balance_sum"]).to_csv(
        f"{out}/balance_distribution.csv", index=False)

    # ---------------- fee model inputs and scenarios ----------------
    ab = act.assign(amount_band=pd.cut(act.amount, AMOUNT_BANDS, labels=AMOUNT_LABELS))
    fb = ab.groupby(["type", "amount_band"], observed=True).agg(txn_count=("txn_id", "size"), value=("amount", "sum")).reset_index()
    fb.to_csv(f"{out}/fee_model_inputs.csv", index=False)
    FEE_SCHEDULE.to_csv(f"{out}/fee_assumptions.csv", index=False)
    sc = []
    for name, m in SCENARIOS.items():
        for capped in (True, False):
            gg, pp, nn = add_fees(df, m, capped)
            tmp = pd.DataFrame({"type": df.type, "g": gg, "p": pp, "n": nn}).groupby("type", observed=True).sum().reset_index()
            tmp.insert(0, "scenario", name); tmp.insert(1, "fee_cap_applied", capped)
            sc.append(tmp)
    pd.concat(sc).rename(columns={"g": "gross_revenue", "p": "partner_cost", "n": "net_revenue"}).to_csv(
        f"{out}/revenue_scenarios.csv", index=False)

    # ---------------- KPI summary ----------------
    fraud_val = float(df.loc[fr, "amount"].sum())
    kpi = {
        "rows_total": len(df), "window_hours": int(df.step.max()), "calendar_days": 31, "full_days": int(full.shape[0]),
        "txn_count": len(df), "txn_value": float(df.amount.sum()), "avg_amount": float(df.amount.mean()),
        "median_amount": float(df.amount.median()),
        "billable_txn_count": len(act), "billable_txn_value": float(act.amount.sum()),
        "fraud_count": int(fr.sum()), "fraud_value": fraud_val, "fraud_rate_count": float(fr.mean()),
        "fraud_rate_value": fraud_val / float(df.amount.sum()),
        "flagged_count": int(df.is_flagged.sum()),
        "recon_exception_count": int((~df.orig_recon_ok).sum()), "recon_exception_rate": float((~df.orig_recon_ok).mean()),
        "mau_sender": mau, "avg_dau_sender_31d": float(daily.dau.mean()), "avg_dau_sender_full_days": float(full.dau.mean()),
        "dau_mau_sender_31d": float(daily.dau.mean() / mau), "dau_mau_sender_full_days": float(full.dau.mean() / mau),
        "peak_dau": int(daily.dau.max()), "peak_dau_day": int(daily.loc[daily.dau.idxmax(), "day"]),
        "mau_participant": mau_alt, "avg_dau_participant_31d": float(dau_alt.mean()),
        "dau_mau_participant_31d": float(dau_alt.mean() / mau_alt),
        "customers_single_txn": int((freq == 1).sum()), "customers_repeat": int((freq >= 2).sum()),
        "repeat_share": float((freq >= 2).mean()), "max_txns_per_customer": int(freq.max()),
        "merchants_distinct": int(df.loc[df.dest_is_merchant, "dest_id"].nunique()),
        "gross_revenue_base": float(act.fee_gross.sum()), "partner_cost_base": float(act.fee_partner.sum()),
        "net_revenue_base": float(act.fee_net.sum()),
        "avg_gross_fee_per_billable_txn": float(act.fee_gross.sum() / len(act)),
        "fraud_value_to_net_revenue_base": fraud_val / float(act.fee_net.sum()),
        "high_volume_days": int(daily.high_volume_day.sum()),
        "share_txns_in_high_volume_days": float(daily.loc[daily.high_volume_day, "txn_count"].sum() / len(df)),
        "median_balance_last_all": float(last_all.new_bal_orig.median()), "mean_balance_last_all": float(last_all.new_bal_orig.mean()),
        "median_balance_last_reconciled": float(last_ok.new_bal_orig.median()), "mean_balance_last_reconciled": float(last_ok.new_bal_orig.mean()),
    }
    pd.DataFrame({"metric": list(kpi), "value": list(kpi.values())}).to_csv(f"{out}/kpi_summary.csv", index=False)
    print("done", len(kpi), "kpis")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", default="../outputs")
    a = ap.parse_args()
    main(a.input, a.out)
