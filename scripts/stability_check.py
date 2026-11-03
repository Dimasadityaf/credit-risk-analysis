"""
Uji stabilitas temuan analisis (Fase 6).
------------------------------------------
Membagi dataset menjadi dua sub-kelompok acak (train 70% / test 30%) dengan
seed tetap, lalu membandingkan metrik kunci di kedua kelompok. Temuan dianggap
STABIL bila seluruh metrik tetap dalam rentang yang sama di kedua kelompok.

Keluaran: tabel perbandingan di stdout (markdown) + data/ stability_check.json
"""

import json
import sqlite3
from pathlib import Path

import pandas as pd

DB_PATH = Path("data/credit_risk.db")
SPLIT_SEED = 42
TRAIN_RATIO = 0.70
# Toleransi selisih (poin persentase) yang masih dianggap stabil
TOL_OVERALL = 1.0   # default rate keseluruhan
TOL_GRADE = 5.0     # default rate per grade
TOL_SEGMENT = 5.0   # segmen risiko (LTI, RENT+<30k, riwayat gagal)


def load() -> pd.DataFrame:
    con = sqlite3.connect(DB_PATH)
    df = pd.read_sql_query("SELECT * FROM credit_risk", con)
    con.close()
    return df


def default_rate(df: pd.DataFrame) -> float:
    return df["loan_status"].mean() * 100


def metrics(df: pd.DataFrame) -> dict:
    """Metrik kunci yang diklaim di README/dokumen laporan."""
    m = {}
    m["n"] = len(df)
    m["default_rate"] = default_rate(df)

    # 1. Default rate per grade
    m["per_grade"] = (
        df.groupby("loan_grade")["loan_status"].mean().mul(100).round(2).to_dict()
    )

    # 2. LTI: band <30% vs >=30% (klaim: risiko melonjak di titik 30%)
    low = df[df["loan_percent_income"] < 0.30]
    high = df[df["loan_percent_income"] >= 0.30]
    m["lti_below_30"] = round(default_rate(low), 2)
    m["lti_at_or_above_30"] = round(default_rate(high), 2)

    # 3. Segmen RENT + pendapatan <30k (klaim: segmen #1)
    seg = df[(df["person_home_ownership"] == "RENT") & (df["person_income"] < 30000)]
    m["rent_low_income_rate"] = round(default_rate(seg), 2)
    m["rent_low_income_n"] = len(seg)

    # 4. Riwayat gagal bayar (klaim: ~2x lipat)
    m["prior_default_Y"] = round(
        default_rate(df[df["cb_person_default_on_file"] == "Y"]), 2
    )
    m["prior_default_N"] = round(
        default_rate(df[df["cb_person_default_on_file"] == "N"]), 2
    )

    # 5. Grade D-G (klaim: ~15% portofolio, ~42% gagal bayar)
    dg = df[df["loan_grade"].isin(list("DEFG"))]
    m["deg_share_portfolio"] = round(len(dg) / len(df) * 100, 2)
    m["deg_share_defaults"] = round(
        dg["loan_status"].sum() / df["loan_status"].sum() * 100, 2
    )
    return m


def main() -> None:
    df = load()
    train = df.sample(frac=TRAIN_RATIO, random_state=SPLIT_SEED)
    test = df.drop(train.index)

    m_tr, m_te = metrics(train), metrics(test)

    rows = []
    rows.append(("Total baris", m_tr["n"], m_te["n"], "-", "OK"))
    rows.append((
        "Default rate keseluruhan (%)",
        m_tr["default_rate"], m_te["default_rate"],
        f"±{TOL_OVERALL}",
        "STABIL" if abs(m_tr["default_rate"] - m_te["default_rate"]) <= TOL_OVERALL
        else "TIDAK STABIL",
    ))

    grades = sorted(set(m_tr["per_grade"]) | set(m_te["per_grade"]))
    worst_grade = 0.0
    grade_rows = []
    for g in grades:
        a = m_tr["per_grade"].get(g)
        b = m_te["per_grade"].get(g)
        if a is None or b is None:
            continue
        diff = abs(a - b)
        worst_grade = max(worst_grade, diff)
        # Uji z dua proporsi (pooled): selisih dibagi error baku selisihnya
        n1 = int((train["loan_grade"] == g).sum())
        n2 = int((test["loan_grade"] == g).sum())
        p = (a * n1 + b * n2) / (100 * (n1 + n2)) if (n1 + n2) else 0.5
        se_diff = ((p * (1 - p) * (1 / max(n1, 1) + 1 / max(n2, 1))) ** 0.5) * 100
        tol = max(TOL_GRADE, 2 * se_diff)
        grade_rows.append((g, a, b, diff, n2, tol, diff <= tol))
    for g, a, b, diff, n_te, tol, ok in grade_rows:
        rows.append((
            f"Default rate grade {g} (%)",
            a, b, f"+/- {tol:.1f}",
            "STABIL" if ok else "TIDAK STABIL",
        ))
    unstable_grades = [r[0] for r in grade_rows if not r[6]]
    rows.append((
        "Selisih terbesar antar grade (poin)",
        f"{worst_grade:.2f}", "", f"<= {TOL_GRADE} (atau 2 sigma)",
        "STABIL" if not unstable_grades else "grade " + ", ".join(unstable_grades),
    ))

    for label, key in [
        ("LTI < 30% (%)", "lti_below_30"),
        ("LTI >= 30% (%)", "lti_at_or_above_30"),
        ("RENT + income <30k (%)", "rent_low_income_rate"),
        ("Riwayat gagal Y (%)", "prior_default_Y"),
        ("Riwayat gagal N (%)", "prior_default_N"),
        ("Grade D-G: % portofolio", "deg_share_portfolio"),
        ("Grade D-G: % dari gagal bayar", "deg_share_defaults"),
    ]:
        a, b = m_tr[key], m_te[key]
        rows.append((
            label, a, b, f"±{TOL_SEGMENT}",
            "STABIL" if abs(a - b) <= TOL_SEGMENT else "TIDAK STABIL",
        ))

    # Cetak tabel markdown
    print("| Metrik | Train (70%) | Test (30%) | Toleransi | Status |")
    print("|:--|--:|--:|:--:|:--:|")
    for r in rows:
        a = f"{r[1]:,.2f}" if isinstance(r[1], float) else str(r[1])
        b = f"{r[2]:,.2f}" if isinstance(r[2], float) else str(r[2])
        print(f"| {r[0]} | {a} | {b} | {r[3]} | {r[4]} |")

    verdicts = [(r[0], r[4]) for r in rows if r[4] in ("STABIL", "TIDAK STABIL")]
    failed = [name for name, v in verdicts if v == "TIDAK STABIL"]
    if not failed:
        print(f"\nKESIMPULAN: semua metrik kunci STABIL di kedua sub-kelompok "
              f"(seed={SPLIT_SEED}, split={int(TRAIN_RATIO*100)}/{int((1-TRAIN_RATIO)*100)})")
    else:
        print(f"\nKESIMPULAN: {len(verdicts) - len(failed)}/{len(verdicts)} metrik kunci "
              f"STABIL. Tidak stabil: {'; '.join(failed)} "
              f"(seed={SPLIT_SEED}, split={int(TRAIN_RATIO*100)}/{int((1-TRAIN_RATIO)*100)})")

    out = {
        "seed": SPLIT_SEED,
        "train_rows": int(len(train)),
        "test_rows": int(len(test)),
        "train": m_tr,
        "test": m_te,
        "verdict": "STABIL" if not failed else "TIDAK STABIL",
        "unstable_metrics": failed,
    }
    Path("data/stability_check.json").write_text(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
