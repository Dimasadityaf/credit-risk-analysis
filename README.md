# 💳 Credit Risk Analysis: Analisis Risiko Gagal Bayar Pinjaman

Proyek analisis data end-to-end untuk mengidentifikasi kelompok peminjam yang paling berisiko gagal bayar, menggunakan dataset **Credit Risk Dataset** (Kaggle) yang berisi 32.409 pinjaman setelah pembersihan.

* * *

## 📌 Latar Belakang Proyek

Bank dan perusahaan pembiayaan harus menyeimbangkan dua hal: menyalurkan pinjaman sebanyak mungkin dan menjaga agar pinjaman yang gagal bayar tetap rendah. Pinjaman yang gagal bayar menggerus keuntungan, sementara penolakan yang terlalu ketat membuat peluang bisnis hilang.

Proyek ini bertujuan memetakan tingkat gagal bayar berdasarkan *loan grade*, tujuan pinjaman, status kepemilikan rumah, rasio pinjaman terhadap pendapatan (*Loan-to-Income*), riwayat gagal bayar, serta kelompok pendapatan dan umur, sehingga kelompok berisiko tinggi dapat dikenali lebih awal.

> **Catatan:** hasil analisis menunjukkan **korelasi**, bukan hubungan sebab-akibat. Dataset ini juga tidak memiliki kolom tanggal, sehingga analisis berfokus pada segmentasi, bukan tren waktu.

* * *

## 🎯 Pertanyaan Bisnis (Business Questions)

Analisis dilakukan secara bertahap menggunakan SQL dalam 4 tingkatan kompleksitas:

### Level 1: Dasar Risiko Kredit (Agregasi & Filter)

1. **Gagal Bayar Keseluruhan**: Berapa persentase gagal bayar pinjaman secara keseluruhan dan per *loan grade*?
2. **Tujuan Pinjaman**: Tujuan pinjaman (*loan intent*) mana yang memiliki risiko gagal bayar paling tinggi?

### Level 2: Segmentasi Peminjam (HAVING & CASE WHEN)

3. **Kepemilikan Rumah**: Apakah status kepemilikan rumah (*home ownership*) berkorelasi dengan tingkat gagal bayar?
4. **Pendapatan & Umur**: Kelompok pendapatan (*income band*) dan kelompok umur (*age group*) mana yang paling berisiko?

### Level 3: Rasio Pinjaman terhadap Pendapatan & Riwayat Kredit (CTE & Subquery)

5. **Loan-to-Income (LTI)**: Bagaimana korelasi antara rasio pinjaman terhadap pendapatan tahunan (*loan percent income*) dengan risiko gagal bayar, dan di titik mana risikonya melonjak?
6. **Riwayat Gagal Bayar**: Apakah riwayat gagal bayar sebelumnya (*default on file*) memprediksi potensi gagal bayar saat ini?

### Level 4: Peringkat Risiko (Window Functions)

7. **Peringkat dalam Grade**: Di dalam tiap *loan grade*, tujuan pinjaman mana yang peringkat gagal bayarnya tertinggi? *(menggunakan `RANK()`)*
8. **Segmen Paling Berisiko**: Kombinasi status rumah dan kelompok pendapatan mana yang masuk dalam kelompok risiko tertinggi? *(menggunakan `NTILE()` atau `DENSE_RANK()`)*

* * *

## 📊 Kamus Data (15 Kolom)

Dataset mentah terdiri dari 32.581 baris dan 12 kolom. Setelah pembersihan menjadi 32.409 baris dan 15 kolom (3 kolom ditambahkan saat pembersihan). Kamus data lengkap tersedia di [`data/data_dictionary.csv`](data/data_dictionary.csv).

| No | Kolom                        | Tipe Data | Deskripsi                                                              |
|:--:|:-----------------------------|:----------|:-----------------------------------------------------------------------|
| 1  | `loan_id`                    | INTEGER   | ID unik pinjaman (dibuat saat pembersihan, 1 sampai 32.409)            |
| 2  | `person_age`                 | INTEGER   | Umur peminjam dalam tahun                                              |
| 3  | `person_income`              | INTEGER   | Pendapatan tahunan peminjam (mata uang tidak disebutkan dataset)       |
| 4  | `person_home_ownership`      | TEXT      | Status kepemilikan rumah (RENT, MORTGAGE, OWN, OTHER)                  |
| 5  | `person_emp_length`          | REAL      | Masa kerja dalam tahun (887 baris kosong)                              |
| 6  | `loan_intent`                | TEXT      | Tujuan pinjaman (EDUCATION, MEDICAL, VENTURE, PERSONAL, DEBTCONSOLIDATION, HOMEIMPROVEMENT) |
| 7  | `loan_grade`                 | TEXT      | Grade pinjaman, A (terbaik) sampai G (terburuk)                        |
| 8  | `loan_amnt`                  | INTEGER   | Jumlah pinjaman                                                        |
| 9  | `loan_int_rate`              | REAL      | Suku bunga dalam persen (3.094 baris kosong)                           |
| 10 | `loan_status`                | INTEGER   | Status pinjaman (0 = lancar, 1 = gagal bayar)                          |
| 11 | `loan_percent_income`        | REAL      | Loan-to-Income (LTI): jumlah pinjaman dibagi pendapatan tahunan, bukan cicilan bulanan (0 sampai 0,83) |
| 12 | `cb_person_default_on_file`  | TEXT      | Pernah gagal bayar sebelumnya (Y / N)                                  |
| 13 | `cb_person_cred_hist_length` | INTEGER   | Lama riwayat kredit dalam tahun                                        |
| 14 | `age_group`                  | TEXT      | Kelompok umur (20-25, 26-30, 31-35, 36-45, 46+), dibuat saat pembersihan |
| 15 | `income_band`                | TEXT      | Kelompok pendapatan (<30k, 30-50k, 50-75k, 75-100k, 100k+), dibuat saat pembersihan |

### 🧹 Ringkasan Pembersihan Data

Skrip: [`scripts/clean_data.py`](scripts/clean_data.py)

| Langkah | Jumlah | Keputusan |
|:--------|-------:|:----------|
| Baris dobel | 165 | Dihapus |
| Nilai tidak masuk akal (umur di atas 100 tahun, masa kerja di atas 60 tahun) | 7 | Dihapus |
| `person_emp_length` kosong | 887 | Dibiarkan kosong, tidak diisi |
| `loan_int_rate` kosong | 3.094 | Dibiarkan kosong, tidak diisi (rata-rata suku bunga dihitung dari baris terisi: 11,02%) |
| Pendapatan di atas 1 juta | 9 | Dipertahankan, gunakan median untuk pendapatan |
| Kolom baru | 3 | `loan_id`, `age_group`, `income_band` (batas bawah termasuk: pendapatan tepat 30.000 masuk `30-50k`) |

Data kosong tidak diisi dengan rata-rata karena dapat menyesatkan hasil analisis, terutama pada suku bunga yang berkaitan langsung dengan *loan grade*.

* * *

## 🛠️ Alat & Teknologi

- **Bahasa Pemrograman & Pengolahan Data**: Python (Pandas)
- **Database & Query**: SQLite
- **Visualisasi & Dashboard**: Google Sheets & Google Apps Script
- **Version Control & Dokumentasi**: Git & GitHub

* * *

## 📁 Struktur Repositori

```
credit-risk-analysis/
├── README.md               # Ringkasan portofolio & temuan bisnis
├── .gitignore              # Konfigurasi proteksi data mentah & lokal
├── data/
│   ├── credit_risk_clean.csv   # Dataset bersih
│   └── data_dictionary.csv     # Kamus data format CSV
├── scripts/
│   └── clean_data.py       # Skrip pembersihan & pembentukan database SQLite
├── sql/
│   ├── level1_dasar.sql
│   ├── level2_segmentasi.sql
│   ├── level3_cte_subquery.sql
│   └── level4_window_function.sql
├── apps-script/
│   ├── Code.gs             # Logika server dashboard
│   └── index.html          # Tampilan dashboard
├── dashboard/
│   └── screenshot.png      # Tangkapan layar dashboard
└── docs/
    └── kesimpulan_bisnis.md# Laporan analitis & rekomendasi
```

<!--
==============================================================
TAMBAHKAN BAGIAN INI SETELAH FASE 4 (DASHBOARD SELESAI).
Hapus tanda komentar di awal dan akhir, lalu isi sesuai angka yang sudah cocok dengan SQL.
==============================================================

* * *

## 🖥️ Dashboard Interaktif (Google Apps Script)

Dashboard dipublikasikan sebagai web app dan dapat diakses publik melalui tautan berikut: 🔗 [**Live Interactive Dashboard**](ISI_TAUTAN_VIEW_DI_SINI)

> Halaman pertama dapat memuat beberapa detik, dan Google menampilkan banner peringatan standar untuk web app Apps Script.

[![Credit Risk Dashboard](dashboard/screenshot.png)](dashboard/screenshot.png)

### 📌 Ringkasan KPI Utama

- **Total Pinjaman**: 32.409
- **Total Nilai Pinjaman**: ISI_SETELAH_DIHITUNG
- **Gagal Bayar**: ISI_SETELAH_DIHITUNG
- **Rata-rata Suku Bunga**: ISI_SETELAH_DIHITUNG

### 🔍 Komponen Visualisasi & Temuan Kunci

1. **Gagal Bayar per Loan Grade** - ISI_TEMUAN
2. **Gagal Bayar per Tujuan Pinjaman** - ISI_TEMUAN
3. **Gagal Bayar per Kelompok Pendapatan** - ISI_TEMUAN
4. **Gagal Bayar per Status Rumah** - ISI_TEMUAN
-->

<!--
==============================================================
TAMBAHKAN BAGIAN INI SETELAH FASE 5 (KESIMPULAN BISNIS SELESAI).
==============================================================

* * *

## 📑 Sintesis Analitis & Rekomendasi Bisnis

Laporan lengkap: 👉 [**Kesimpulan Bisnis & Rekomendasi (docs/kesimpulan_bisnis.md)**](docs/kesimpulan_bisnis.md)

- **Temuan 1**: ISI (temuan, angka, rekomendasi)
- **Temuan 2**: ISI
- **Temuan 3**: ISI
- **Temuan 4**: ISI
- **Temuan 5**: ISI
-->

* * *

## 🚀 Cara Menjalankan Proyek Secara Lokal (Reproducibility)

1. **Clone Repositori**:

   ```
   git clone https://github.com/Dimasadityaf/credit-risk-analysis.git
   cd credit-risk-analysis
   ```

2. **Siapkan Dataset Mentah**: unduh *Credit Risk Dataset* dari Kaggle, lalu simpan sebagai `data_raw/credit_risk_dataset.csv` (folder `data_raw/` tidak disertakan di repositori).

3. **Jalankan Pembersihan Data & Pembuatan Database**:

   ```
   pip install pandas
   python scripts/clean_data.py
   ```

   *Skrip ini menghasilkan `data/credit_risk_clean.csv` dan database `data/credit_risk.db` dengan tabel `credit_risk`. Keluaran yang benar: baris akhir 32.409.*

4. **Jalankan Query SQL**: gunakan CLI SQLite atau ekstensi DB Browser/DBeaver untuk menjalankan skrip di folder `sql/`:

   - `sql/level1_dasar.sql`
   - `sql/level2_segmentasi.sql`
   - `sql/level3_cte_subquery.sql`
   - `sql/level4_window_function.sql`

* * *

## 📈 Alur Kerja Proyek

- ✅ **Fase 0: Persiapan Proyek & Repositori Git**
- ✅ **Fase 1: Pemahaman Data & Rumusan Masalah Bisnis**
- ✅ **Fase 2: Pembersihan Data & Pembuatan Database SQLite (Python)**
- ⬜ **Fase 3: Eksplorasi & Analisis Data Menggunakan SQL (Level 1-4)**
- ⬜ **Fase 4: Perancangan Dashboard Interaktif (Google Apps Script)**
- ⬜ **Fase 5: Sintesis Temuan & Rekomendasi Bisnis**
- ⬜ **Fase 6: Finalisasi & Publikasi Portofolio**
