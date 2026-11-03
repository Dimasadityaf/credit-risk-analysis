# 📝 Kesimpulan Bisnis & Rekomendasi — Analisis Risiko Kredit

> **Fase 5: Sintesis Temuan & Rekomendasi Bisnis**
> Sumber data: `data/credit_risk.db` (tabel `credit_risk`, 32.409 pinjaman)
> Query: [`sql/level1_dasar.sql`](../sql/level1_dasar.sql) – [`sql/level4_window_function.sql`](../sql/level4_window_function.sql)
> Dashboard: [Live Interactive Dashboard](https://script.google.com/macros/s/AKfycbwSGJd_832tYZGm54wd8xQxUyfNdPzLAdk5XQUvCJAqzAyEFAvOEM24zw1tQFHDLPn7/exec)

* * *

## 1. Ringkasan Eksekutif

| KPI | Nilai |
|:----|------:|
| Total pinjaman | 32.409 |
| Total nilai pinjaman | $310,9 jt |
| Gagal bayar | 7.088 (**21,87%**) |
| Rata-rata suku bunga | 11,02% |
| Nilai pinjaman gagal bayar | $76,9 jt (**24,7%** nilai portofolio) |
| Rata-rata suku bunga pinjaman lancar vs gagal bayar | 10,44% vs 13,07% |

**Tiga pesan utama:**

1. **Risiko tidak terdistribusi merata** — separuh portofolio terkonsentrasi pada segmen yang secara struktural aman, sementara **15% pinjaman (grade D–G) menghasilkan 42,2% dari seluruh gagal bayar** (2.991 dari 7.088).
2. **Tiga faktor prediktif terkuat** adalah *loan grade* (dari 9,96% → 98,44%), **rasio pinjaman terhadap pendapatan (LTI)**, dan **riwayat gagal bayar sebelumnya** (selisih 2x lipat).
3. **Suku bunga belum mengkompensasi risiko** — grade D–G membebankan bunga 15–20% tetapi default rate-nya 59–98%, sehingga kenaikan bunga tidak menutup probabilitas rugi.

* * *

## 2. Temuan Kunci

### 2.1 Level 1 — Risiko Dasar: Grade adalah Pemisah Terkuat

| Loan Grade | Pinjaman | Gagal Bayar | Default Rate | Suku Bunga Rata-rata |
|:--|--:|--:|--:|--:|
| A | 10.702 | 1.066 | 9,96% | 7,33% |
| B | 10.384 | 1.695 | 16,32% | 11,00% |
| C | 6.436 | 1.336 | 20,76% | 13,46% |
| D | 3.619 | 2.137 | **59,05%** | 15,36% |
| E | 963 | 621 | 64,49% | 17,01% |
| F | 241 | 170 | 70,54% | 18,61% |
| G | 64 | 63 | **98,44%** | 20,25% |

- **Terdapat "tepi jurang" (cliff) antara grade C dan D**: default rate melompat dari 20,76% ke 59,05% (+38,3 poin), jauh lebih besar daripada lonjakan antar grade lainnya.
- **Grade G praktis pasti gagal bayar**: 63 dari 64 pinjaman (98,44%).
- Grade D–G hanya 4.887 pinjaman (15,1% portofolio) tetapi menyumbang **42,2% seluruh gagal bayar** dan memikul bunga tertinggi.

**Tujuan pinjaman (loan intent):**

| Loan Intent | Pinjaman | Default Rate |
|:--|--:|--:|
| DEBTCONSOLIDATION | 5.189 | **28,68%** |
| MEDICAL | 6.042 | 26,76% |
| HOMEIMPROVEMENT | 3.594 | 26,15% |
| PERSONAL | 5.496 | 19,89% |
| EDUCATION | 6.409 | 17,26% |
| VENTURE | 5.679 | 14,86% |

- *Debt consolidation* — yang notabene melunasi utang lama — justru paling berisiko (28,68%), diikuti pinjaman medis dan renovasi rumah.
- *Venture* (modal usaha) dan *education* paling aman.

### 2.2 Level 2 — Segmen Peminjam: Rumah, Pendapatan, Umur

**Status kepemilikan rumah:**

| Status | Pinjaman | Default Rate |
|:--|--:|--:|
| RENT (menyewa) | 16.374 | **31,61%** |
| OTHER | 106 | 31,13% |
| MORTGAGE | 13.366 | 12,62% |
| OWN (milik sendiri) | 2.563 | **7,49%** |

Peminjam penyewa gagal bayar **4,2x lebih sering** daripada pemilik rumah.

**Kelompok pendapatan:**

| Income Band | Pinjaman | Default Rate |
|:--|--:|--:|
| <30k | 3.642 | **47,20%** |
| 30-50k | 9.585 | 28,21% |
| 50-75k | 9.779 | 17,65% |
| 75-100k | 4.856 | 10,96% |
| 100k+ | 4.547 | **8,95%** |

Risiko turun konsisten seiring naiknya pendapatan — peminjam <30k berisiko **5,3x** lipat dibanding 100k+.

**Kelompok umur:** relatif datar (20–23% di semua kelompok), sehingga **umur bukan pembeda risiko yang kuat**. Namun volume terbesar ada pada usia 20–25 tahun (15.243 pinjaman, 23,13% default) — segmen muda dengan risiko sedikit di atas rata-rata.

**Segmen kombinasi (income × umur):** semua kombinasi dengan default rate ≥40% didominasi kelompok pendapatan **<30k** di semua umur — **pendapatan menengahkan pengaruh umur**.

### 2.3 Level 3 — Loan-to-Income & Riwayat Kredit

**LTI (loan_percent_income) vs risiko:**

| LTI Bucket | Pinjaman | Default Rate |
|:--|--:|--:|
| <10% | 8.904 | 11,59% |
| 10-20% | 12.455 | 14,74% |
| 20-30% | 6.784 | 20,98% |
| 30-40% | 2.934 | **61,93%** |
| 40-50% | 998 | 72,55% |
| ≥50% | 334 | 76,65% |

- **Titik melonjaknya risiko: LTI ≈ 30%.** Pada inkrement 0,05 (bin 0,25 → 0,30) default rate melonjak dari **21,56% → 39,52%**, lalu 68,49% pada bin 0,35.
- Di bawah 30%, risiko masih terkendali (11–21%); di atas 30%, mayoritas pinjaman gagal bayar.

**Riwayat gagal bayar sebelumnya:**

| Pernah Gagal Bayar | Pinjaman | Default Rate | Selisih |
|:--|--:|--:|--:|
| Y (ya) | 5.729 | **37,86%** | +19,42 poin |
| N (tidak) | 26.680 | 18,44% | — |

Riwayat gagal bayar **melipatgandakan risiko ~2x lipat** — dan berlaku di semua grade (terdeteksi via subquery per grade).

**Masa kerja & riwayat kredit (temuan tambahan):**

- Masa kerja <1 tahun: 27,97% vs ≥10 tahun: 16,38% — semakin lama bekerja, semakin stabil.
- Data masa kerja yang **kosong justru paling berisiko (31,68%)** — kekosongan data sendiri adalah sinyal risiko.
- Lama riwayat kredit berpengaruh kecil (20,7%–22,8%).

### 2.4 Level 4 — Peringkat Risiko

**Top 5 segmen paling berisiko (status rumah × pendapatan, n ≥ 50):**

| Peringkat | Segmen | Pinjaman | Default Rate |
|:--:|:--|--:|--:|
| 1 | RENT + <30k | 2.585 | **54,39%** |
| 2 | RENT + 30-50k | 6.030 | 36,80% |
| 3 | MORTGAGE + <30k | 479 | 30,69% |
| 4 | OWN + <30k | 566 | 27,92% |
| 5 | RENT + 50-75k | 4.738 | 23,47% |

**Peringkat dalam grade (RANK per loan grade):**
- Di **semua grade A–G**, tujuan **DEBTCONSOLIDATION / MEDICAL / HOMEIMPROVEMENT** konsisten menempati peringkat risiko tertinggi dalam gradenya; **VENTURE / EDUCATION** konsisten terendah.
- Pada grade D–G, *debt consolidation* mencapai **92,8%–100% default** — praktis tidak layak didanai.

* * *

## 3. Rekomendasi Bisnis

### Prioritas 1 — Kebijakan Penyaluran (Underwriting)

| # | Rekomendasi | Dasar Analisis | Dampak Estimasi |
|:--:|:--|:--|:--|
| 1 | **Tegakkan batas LTI maksimal 30%** (idealnya 25%) — atas 30% wajib penjaminan/agunan tambahan | Risiko melonjak 21,56% → 39,52% pada titik 30% | Menyaring ~3.932 pinjaman berisiko ≥62% |
| 2 | **Tinjau ulang penyaluran grade D–G**, terutama grade G (98,44%) — hentikan atau wajibkan agunan | 15% portofolio = 42% gagal bayar | Menghilangkan ~2.991 dari 7.088 gagal bayar |
| 3 | **Perlakukan "data kosong masa kerja" sebagai flag risiko tambahan** (31,68%), bukan nilai netral | Kekosongan data informatif | Meningkatkan deteksi tanpa tambahan kolom |
| 4 | **Wajibkan verifikasi ekstra untuk segmen RENT + pendapatan <30k** (54,39%) | Segmen risiko #1 | Menekan default di 2.585 pinjaman terberisiko |

### Prioritas 2 — Risk-Based Pricing & Produk

| # | Rekomendasi | Dasar Analisis |
|:--:|:--|:--|
| 5 | **Gunakan skor risiko gabungan** (grade + riwayat gagal + LTI) untuk harga bunga, bukan grade saja — bunga 15–20% tidak mengkompensasi default 59–98% | Selisih bunga lancar/gagal hanya 2,6 poin vs selisih risiko puluhan poin |
| 6 | **Prioritaskan akuisisi segmen rendah risiko**: *venture*, *education*, pemilik rumah, pendapatan ≥75k, LTI <20% — default 8–15% | Portofolio aman yang besar menurunkan rata-rata rugi |
| 7 | **Waspadai produk *debt consolidation***: perlu fitur uji kelayakan (ratio utang-lama/baru) karena menjadi pemicu risiko #1 di hampir semua grade | 28,68% overall; 92,8–100% pada grade D–G |

### Prioritas 3 — Pemantauan (Monitoring)

| # | Rekomendasi | Dasar Analisis |
|:--:|:--|:--|
| 8 | Pantau **portofolio RENT + <50k** secara bulanan (9.615 pinjaman, 40% portofolio) | Dua segmen teratas daftar risiko |
| 9 | Bangun *early-warning* berbasis **kenaikan LTI dan riwayat gagal** pada saat *restructuring* | Kedua faktor paling prediktif |

* * *

## 4. Keterbatasan Analisis

1. **Bukan model kausal** — semua temuan adalah korelasi; tidak ada bukti bahwa menurunkan LTI/menyewa rumah *menyebabkan* perubahan risiko.
2. **Dataset statis tanpa dimensi waktu** — tidak ada tanggal vintage, tenor, atau jadwal cicilan, sehingga tidak bisa menghitung *loss given default* (LGD), ECL, atau kurva kohort.
3. **Mata uang tidak dispesifikasikan** dataset sumber, sehingga nilai pinjaman ditampilkan sebagai angka absolut ($).
4. **Rasio LTI dihitung terhadap total pinjaman/pendapatan tahunan**, bukan cicilan bulanan/pendapatan — angka lebih tinggi daripada definisi industri (DTI).
5. **Suku bunga kosong pada 3.094 baris dan masa kerja kosong pada 887 baris** sengaja tidak diimputasi; hasil rata-rata dihitung dari baris terisi.
6. **Belum ada validasi data luar** — temuan perlu diuji pada portofolio baru sebelum dijadikan kebijakan produksi.

**Langkah lanjutan (Fase 6 — selesai):** uji stabilitas temuan dengan *train/test split* 70/30 dilakukan di [`scripts/stability_check.py`](../scripts/stability_check.py) — **14 dari 15 metrik kunci terbukti stabil** (hanya grade E yang menyimpang karena sampel kecil). Hasil lengkap: [`docs/uji_stabilitas.md`](uji_stabilitas.md). Laporan ini juga sudah didokumentasikan di README dan portofolio dipublikasikan.

* * *

## 5. Referensi

| Artefak | Lokasi |
|:--|:--|
| Query Level 1 — Dasar | [`sql/level1_dasar.sql`](../sql/level1_dasar.sql) |
| Query Level 2 — Segmentasi | [`sql/level2_segmentasi.sql`](../sql/level2_segmentasi.sql) |
| Query Level 3 — CTE & Subquery | [`sql/level3_cte_subquery.sql`](../sql/level3_cte_subquery.sql) |
| Query Level 4 — Window Functions | [`sql/level4_window_function.sql`](../sql/level4_window_function.sql) |
| Dashboard Interaktif | [Live Dashboard (Google Apps Script)](https://script.google.com/macros/s/AKfycbwSGJd_832tYZGm54wd8xQxUyfNdPzLAdk5XQUvCJAqzAyEFAvOEM24zw1tQFHDLPn7/exec) |
| Skrip Pembersihan | [`scripts/clean_data.py`](../scripts/clean_data.py) |
