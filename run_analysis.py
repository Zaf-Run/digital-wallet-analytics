"""Run every SQL file in /sql against the PaySim CSV with DuckDB and save results to /outputs.
Usage: python run_analysis.py   (needs: pip install duckdb)
Works on a laptop with 4GB RAM. No server needed."""
import duckdb, glob, os, time

os.makedirs("outputs", exist_ok=True)
con = duckdb.connect("data/processed/wallet.duckdb")
con.execute("SET memory_limit='1800MB'; SET threads=1; SET temp_directory='data/processed/tmp';")

con.execute(open("sql/00_load.sql").read())
print("rows loaded:", con.execute("select count(*) from txn").fetchone()[0])

for f in [p for p in sorted(glob.glob("sql/[01][0-9]_*.sql")) if not p.endswith("00_load.sql")]:
    name = os.path.basename(f)[:-4]
    t = time.time()
    df = con.execute(open(f).read()).fetchdf()
    df.to_csv(f"outputs/{name}.csv", index=False)
    print(f"{name}: {len(df)} rows in {time.time()-t:.1f}s")
con.execute("select * from fee_assumptions").fetchdf().to_csv("outputs/fee_assumptions.csv", index=False)
