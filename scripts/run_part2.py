"""Part 2: delivery performance vs reviews and repeat purchase.
Usage (from project root, with all 9 core CSVs in data/):  python scripts/run_part2.py
"""
import os
from pathlib import Path
import duckdb, numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from statsmodels.stats.proportion import proportions_ztest
from statsmodels.stats.contingency_tables import StratifiedTable

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
(ROOT / "reports").mkdir(exist_ok=True)
con = duckdb.connect(str(ROOT / "olist.duckdb"))


def run_file(name):
    text = (ROOT / "sql" / name).read_text()
    text = "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))
    out = []
    for stmt in filter(None, (s.strip() for s in text.split(";"))):
        r = con.execute(stmt)
        if stmt.upper().lstrip("( \n").startswith(("SELECT", "WITH")):
            out.append(r.df())
    return out


run_file("06_load_core_tables.sql")
reviews, repeat = run_file("07_delivery_vs_reviews.sql")
bad, monthly, state, scale = run_file("08_delay_hotspots.sql")
for name, df in [("07_reviews_by_delivery", reviews), ("07_repeat_by_delivery", repeat),
                 ("08_bad_review_share", bad), ("08_late_by_month", monthly),
                 ("08_late_by_state", state), ("08_order_value", scale)]:
    df.to_csv(ROOT / "reports" / f"{name}.csv", index=False)
    print(f"\n=== {name}\n{df.to_string(index=False)}")

# ---- Statistics for the repeat-purchase question (customer level, first delivered order)
cust = con.sql("""
    WITH d AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                                            ORDER BY order_purchase_timestamp) rn FROM delivered_orders),
    n AS (SELECT customer_unique_id, COUNT(*) n FROM delivered_orders GROUP BY 1)
    SELECT d.order_purchase_timestamp AS first_purchase,
           (d.delivery_bucket <> '1. On time or early')::INT AS late,
           (n.n > 1)::INT AS repeat
    FROM d JOIN n USING (customer_unique_id) WHERE rn = 1""").df()

g = cust.groupby("late")["repeat"].agg(["sum", "count"])
_, p_raw = proportions_ztest(g["sum"].values[::-1], g["count"].values[::-1])
print(f"\nRepeat rate on-time {100*g['sum'][0]/g['count'][0]:.2f}% vs late {100*g['sum'][1]/g['count'][1]:.2f}%  (unadjusted z-test p={p_raw:.4f})")

# Control for purchase month: later customers had less time to repeat, and late orders cluster in some months.
c = cust[(cust.first_purchase >= "2016-10-01") & (cust.first_purchase < "2018-09-01")].copy()
c["m"] = c.first_purchase.dt.to_period("M")
tabs = []
for _, grp in c.groupby("m"):
    t = np.array([[((grp.late == 1) & (grp.repeat == 1)).sum(), ((grp.late == 1) & (grp.repeat == 0)).sum()],
                  [((grp.late == 0) & (grp.repeat == 1)).sum(), ((grp.late == 0) & (grp.repeat == 0)).sum()]])
    if (t.sum(axis=0) > 0).all() and (t.sum(axis=1) > 0).all():
        tabs.append(t)
st = StratifiedTable(tabs)
lo, hi = st.oddsratio_pooled_confint()
print(f"Mantel-Haenszel (by purchase month): OR={st.oddsratio_pooled:.3f}, 95% CI [{lo:.3f}, {hi:.3f}], p={st.test_null_odds().pvalue:.4f}")

# ---- Charts
fig, ax = plt.subplots(figsize=(8, 4.5))
labels = [b[3:] for b in reviews.delivery_bucket]
bars = ax.bar(labels, reviews.pct_1_2_stars, color=["#4C78A8", "#F2B134", "#F58518", "#E45756"])
for b, s in zip(bars, reviews.avg_review):
    ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 1, f"avg {s}\u2605", ha="center", fontsize=9)
ax.set_ylabel("% of orders with a 1-2 star review"); ax.set_ylim(0, 92)
ax.set_title("Bad reviews rise sharply with delivery delay")
plt.tight_layout(); plt.savefig(ROOT / "reports" / "reviews_by_delivery.png", dpi=150); plt.close()

fig, ax = plt.subplots(figsize=(9, 4))
ax.plot(monthly.purchase_month, monthly.pct_late, marker="o", color="#E45756")
ax.set_ylabel("% of orders delivered late"); ax.set_title("Late-delivery share by purchase month")
plt.xticks(rotation=60, fontsize=8); plt.tight_layout()
plt.savefig(ROOT / "reports" / "late_by_month.png", dpi=150); plt.close()
print("\nCharts saved to reports/")
