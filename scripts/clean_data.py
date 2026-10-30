import sqlite3
import pandas as pd

# 1. Baca data mentah
raw_path = "data_raw/credit_risk_dataset.csv"
df = pd.read_csv(raw_path)

# 2. Hapus baris duplikat (165 baris)
df = df.drop_duplicates()

# 3. Hapus baris anomali yang mustahil (7 baris)
# Umur di atas 100 tahun dan masa kerja di atas 60 tahun
df = df[(df["person_age"] <= 100) & (df["person_emp_length"].isna() | (df["person_emp_length"] <= 60))]

# 4. Tambahkan kolom loan_id sebagai primary key unik (1 sampai N)
df.reset_index(drop=True, inplace=True)
df.insert(0, "loan_id", df.index + 1)

# 5. Buat fitur segmentasi: age_group
def get_age_group(age):
    if age <= 25:
        return "20-25"
    elif age <= 30:
        return "26-30"
    elif age <= 35:
        return "31-35"
    elif age <= 45:
        return "36-45"
    else:
        return "46+"

df["age_group"] = df["person_age"].apply(get_age_group)

# 6. Buat fitur segmentasi: income_band
def get_income_band(income):
    if income < 30000:
        return "<30k"
    elif income <= 50000:
        return "30-50k"
    elif income <= 75000:
        return "50-75k"
    elif income <= 100000:
        return "75-100k"
    else:
        return "100k+"

df["income_band"] = df["person_income"].apply(get_income_band)

# 7. Simpan ke CSV bersih
csv_clean_path = "data/credit_risk_clean.csv"
df.to_csv(csv_clean_path, index=False)

# 8. Simpan ke SQLite database
db_path = "data/credit_risk.db"
conn = sqlite3.connect(db_path)
df.to_sql("credit_risk", conn, if_exists="replace", index=False)
conn.close()

print(f"Pembersihan selesai!")
print(f"Total baris akhir: {len(df)}")
print(f"Total kolom: {len(df.columns)}")
