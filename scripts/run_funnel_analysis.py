"""Run the funnel SQL files in order, save result tables + charts to reports/.
Usage (from project root):  python scripts/run_funnel_analysis.py
"""
import re
from pathlib import Path
import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
con = duckdb.connect(str(ROOT / "olist.duckdb"))
(ROOT / "reports").mkdir(exist_ok=True)


def run_file(name):
    """Execute every statement in a .sql file; return the result of each SELECT."""
    text = (ROOT / "sql" / name).read_text()
    text = "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))
    results = []
    for stmt in filter(None, (s.strip() for s in text.split(";"))):
        out = con.execute(stmt)
        if stmt.upper().lstrip("( \n").startswith(("SELECT", "WITH")):
            results.append(out.df())
    return results


import os
os.chdir(ROOT)  # relative data/ paths in the load script
run_file("01_load_marketing_funnel.sql")

for f in ["02_data_quality_funnel.sql", "03_channel_conversion.sql",
          "04_time_to_close.sql", "05_monthly_cohorts.sql"]:
    for i, df in enumerate(run_file(f), 1):
        out = ROOT / "reports" / f"{f[:2]}_{f[3:-4]}_q{i}.csv"
        df.to_csv(out, index=False)
        print(f"\n=== {f} / result {i} -> {out.name}\n{df.to_string(index=False)}")

# ---- Chart 1: conversion by channel with 95% CI (cohort Jan-Apr 2018)
ch = run_file("03_channel_conversion.sql")[0].sort_values("conv_pct")
ch = ch[ch.leads >= 100]                        # drop tiny channels from the chart
fig, ax = plt.subplots(figsize=(8, 5))
xerr = [ch.conv_pct - ch.ci_low_pct, ch.ci_high_pct - ch.conv_pct]
ax.barh(ch.origin, ch.conv_pct, xerr=xerr, color="#4C78A8", capsize=3)
ax.set_xlabel("Lead-to-closed-deal conversion (%)  |  bars = 95% CI")
ax.set_title("Conversion by acquisition channel\n(leads first contacted Jan-Apr 2018, channels with 100+ leads)")
plt.tight_layout(); plt.savefig(ROOT / "reports" / "channel_conversion.png", dpi=150); plt.close()

# ---- Chart 2: monthly cohort conversion showing the 2017 truncation artifact
mc = run_file("05_monthly_cohorts.sql")[0]
fig, ax = plt.subplots(figsize=(8, 4.5))
ax.bar(mc.cohort_month.astype(str).str[:7], mc.conv_pct, color="#F58518")
ax.axvline(6.5, color="grey", ls="--")
ax.text(0, ax.get_ylim()[1] * 0.9, "closed_deals has no wins\nbefore 2017-12-05\n(understated)", fontsize=8)
ax.set_ylabel("Conversion (%)"); ax.set_title("Conversion by first-contact month")
plt.xticks(rotation=45); plt.tight_layout()
plt.savefig(ROOT / "reports" / "monthly_cohorts.png", dpi=150); plt.close()
print("\nCharts saved to reports/")
