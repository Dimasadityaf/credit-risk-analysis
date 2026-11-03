"""
Bersihkan credit_risk_dataset.csv

Input : data_raw/credit_risk_dataset.csv
Output: data/credit_risk_clean.csv  (untuk Google Sheets / Apps Script)
        data/credit_risk.db         (SQLite, tabel: credit_risk, untuk query SQL)

Jalankan dari folder utama proyek:  python scripts/clean_data.py
"""
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data_raw" / "credit_risk_dataset.csv"
OUT_CSV = ROOT / "data" / "credit_risk_clean.csv"
OUT_DB = ROOT / "data" / "credit_risk.db"

df = pd.read_csv(RAW)
rows_raw = len(df)

# 1. Hapus baris dobel
df = df.drop_duplicates()
dups = rows_raw - len(df)

# 2. Hapus nilai mustahil (umur > 100 tahun, masa kerja > 60 tahun)
impossible = (df["person_age"] > 100) | (df["person_emp_length"] > 60)
n_impossible = int(impossible.sum())
df = df[~impossible].copy()

# 3. Data kosong (loan_int_rate, person_emp_length) SENGAJA dibiarkan kosong.
#    Jangan diisi sembarangan; catat keputusan ini di README.

# 4. Kolom bantu untuk analisis dan dashboard
df["age_group"] = pd.cut(
    df["person_age"],
    bins=[19, 25, 30, 35, 45, 200],
    labels=["20-25", "26-30", "31-35", "36-45", "46+"],
).astype(str)
# right=False: batas bawah termasuk, batas atas tidak. Pendapatan tepat 30.000
# masuk "30-50k", bukan "<30k".
df["income_band"] = pd.cut(
    df["person_income"],
    bins=[0, 30000, 50000, 75000, 100000, float("inf")],
    labels=["<30k", "30-50k", "50-75k", "75-100k", "100k+"],
    right=False,
).astype(str)
df.insert(0, "loan_id", range(1, len(df) + 1))

# 5. Simpan
OUT_CSV.parent.mkdir(exist_ok=True)
df.to_csv(OUT_CSV, index=False, encoding="utf-8")
with sqlite3.connect(OUT_DB) as con:
    df.to_sql("credit_risk", con, if_exists="replace", index=False)

# 6. Ringkasan untuk diverifikasi
nulls = df.isna().sum()
print(f"Baris mentah           : {rows_raw}")
print(f"Baris dobel dihapus    : {dups}")
print(f"Baris mustahil dihapus : {n_impossible}")
print(f"Baris akhir            : {len(df)}")
print(f"Kolom akhir            : {df.shape[1]}")
print(f"Gagal bayar (%)        : {df['loan_status'].mean() * 100:.1f}")
print("Data kosong            :", nulls[nulls > 0].to_dict())
print(f"Rata-rata suku bunga   : {df['loan_int_rate'].mean():.2f}")
print("Jumlah per income_band :", df["income_band"].value_counts().sort_index().to_dict())
