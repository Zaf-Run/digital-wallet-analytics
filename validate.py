"""Independent pandas cross check of the SQL results, plus data quality tests."""
import pandas as pd, numpy as np
df = pd.read_csv("data/raw/paysim.csv", dtype={"step":"int16","type":"category","isFraud":"int8","isFlaggedFraud":"int8","amount":"float64"})
df["day"] = (df.step - 1)//24 + 1
ok = df[df.isFraud == 0]
res = {}
res["rows"] = len(df)
res["completed_count"] = len(ok)
res["completed_value"] = ok.amount.sum()
res["cancelled_value"] = df[df.isFraud==1].amount.sum()
res["mau_initiators"] = ok.nameOrig.nunique()
res["avg_dau"] = ok.groupby("day").nameOrig.nunique().mean()
rate = {"CASH_IN":0,"CASH_OUT":.01,"TRANSFER":.005,"PAYMENT":.008,"DEBIT":0}
res["modelled_fee_revenue"] = (ok.amount * ok.type.map(rate)).sum()
# closing balance, last event per C account
a = ok[["step","nameOrig","newbalanceOrig"]].rename(columns={"nameOrig":"acct","newbalanceOrig":"bal"}); a["role"]="orig"
b = ok[ok.nameDest.str.startswith("C")][["step","nameDest","newbalanceDest"]].rename(columns={"nameDest":"acct","newbalanceDest":"bal"}); b["role"]="dest"
ev = pd.concat([a.assign(i=np.arange(len(a))), b.assign(i=np.arange(len(b))+len(a))])
ev = ev.sort_values(["step","i"])
last = ev.groupby("acct").tail(1)
res["accounts_with_balance"] = len(last)
res["avg_closing"] = last.bal.mean(); res["median_closing"] = last.bal.median()
res["pct_zero"] = (last.bal==0).mean()*100
res["zero_share_last_role_orig"] = (last[last.role=="orig"].bal==0).mean()*100
res["zero_share_last_role_dest"] = (last[last.role=="dest"].bal==0).mean()*100
for k,v in res.items(): print(f"{k}: {v:,.2f}")
del a,b,ev,last,ok
import gc; gc.collect()

print("\n-- Data quality checks")
print("exact duplicate rows:", df.duplicated().sum())
print("zero amount rows:", (df.amount==0).sum())
print("negative values:", (df[["amount","oldbalanceOrg","newbalanceOrig","oldbalanceDest","newbalanceDest"]]<0).any().any())
d31 = df[df.day==31]; print("day 31 rows:", len(d31), "fraud share:", d31.isFraud.mean())
exp = np.where(df.type=="CASH_IN", df.oldbalanceOrg+df.amount, df.oldbalanceOrg-df.amount)
df["orig_ok"] = np.isclose(exp, df.newbalanceOrig, atol=0.01)
print("origin balance arithmetic holds, by type:"); print(df.groupby("type").orig_ok.mean().round(3))
over = (df.type.isin(["PAYMENT","TRANSFER","CASH_OUT","DEBIT"]) & (df.amount > df.oldbalanceOrg))
print("debit style txns where amount > opening balance:", over.sum(), f"({over.mean()*100:.1f}% of all)")
mer = df[df.nameDest.str.startswith("M")]; print("merchant dest balance always 0:", (mer.oldbalanceDest==0).all() and (mer.newbalanceDest==0).all())
cd = df[df.type=="CASH_OUT"]; print("CASH_OUT dest balance unchanged share:", (cd.oldbalanceDest==cd.newbalanceDest).mean().round(3))
fr = df[df.isFraud==1]
print("fraud rows where amount == opening balance:", (fr.amount==fr.oldbalanceOrg).mean().round(3))
print("fraud median amount:", fr.amount.median(), " legit median amount (TRANSFER/CASH_OUT):", df[(df.isFraud==0)&df.type.isin(['TRANSFER','CASH_OUT'])].amount.median())
print("flagged rule min amount:", df[df.isFlaggedFraud==1].amount.min())
print("TRANSFER >200k completed legit:", ((df.type=='TRANSFER')&(df.amount>200000)&(df.isFraud==0)).sum())
print("fraud TRANSFER >200k:", ((df.type=='TRANSFER')&(df.amount>200000)&(df.isFraud==1)).sum())
