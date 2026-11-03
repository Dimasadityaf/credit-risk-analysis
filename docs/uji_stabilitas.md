# 🧪 Uji Stabilitas Temuan (Fase 6)

> **Metode:** pembagian acak *train/test split* 70/30 (seed = 42) pada 32.409 pinjaman
> **Skrip:** [`scripts/stability_check.py`](../scripts/stability_check.py)
> **Database:** `data/credit_risk.db` (tabel `credit_risk`)

Temuan analisis diuji dengan membagi data menjadi dua sub-kelompok acak, lalu membandingkan metrik kunci di keduanya. Sebuah temuan dianggap **STABIL** bila selisihnya masih dalam toleransi — untuk metrik agregat toleransi 5 poin persentase, untuk per-grade diganti **uji z dua-proporsi** (selisih harus ≤ 2× error baku selisihnya) supaya sampel kecil (grade F, G) tidak dihakimi secara tidak adil.

* * *

## Hasil

| Metrik | Train (70%) | Test (30%) | Toleransi | Status |
|:--|--:|--:|:--:|:--:|
| Total baris | 22.686 | 9.723 | – | OK |
| Default rate keseluruhan (%) | 21,81 | 22,02 | ±1,0 | ✅ STABIL |
| Default rate grade A (%) | 9,76 | 10,42 | ±5,0 | ✅ STABIL |
| Default rate grade B (%) | 16,28 | 16,43 | ±5,0 | ✅ STABIL |
| Default rate grade C (%) | 21,06 | 20,09 | ±5,0 | ✅ STABIL |
| Default rate grade D (%) | 58,37 | 60,68 | ±5,0 | ✅ STABIL |
| Default rate grade E (%) | 62,24 | 70,04 | ±6,8 | ❌ TIDAK STABIL |
| Default rate grade F (%) | 72,00 | 66,67 | ±13,2 | ✅ STABIL |
| Default rate grade G (%) | 100,00 | 92,31 | ±7,7 | ✅ STABIL |
| LTI < 30% (%) | 15,30 | 15,11 | ±5,0 | ✅ STABIL |
| LTI ≥ 30% (%) | 65,35 | 66,03 | ±5,0 | ✅ STABIL |
| RENT + income < 30k (%) | 53,59 | 56,20 | ±5,0 | ✅ STABIL |
| Riwayat gagal Y (%) | 38,09 | 37,34 | ±5,0 | ✅ STABIL |
| Riwayat gagal N (%) | 18,35 | 18,64 | ±5,0 | ✅ STABIL |
| Grade D–G: % portofolio | 15,29 | 14,59 | ±5,0 | ✅ STABIL |
| Grade D–G: % dari gagal bayar | 42,37 | 41,80 | ±5,0 | ✅ STABIL |

**Kesimpulan: 14 dari 15 metrik kunci STABIL.**

* * *

## Interpretasi

### ✅ Temuan utama bertahan

Seluruh **klaim inti laporan** terbukti konsisten di kedua sub-kelompok:

1. **Grade adalah pemisah terkuat** — urutan risiko A → G terjaga penuh, dan "tepi jurang" grade C→D tetap ada (20,09% → 60,68% di test).
2. **Titik melonjak LTI tetap di 30%** — selisih LTI < 30% vs ≥ 30% sebesar **50,3 poin** di train dan **50,9 poin** di test. Ini temuan paling kuat dan paling stabil.
3. **Segmen RENT + <30k tetap #1** — 53,59% vs 56,20%, selisih hanya 2,6 poin.
4. **Riwayat gagal bayar melipatgandakan risiko ~2x** — 38,09/18,35 = 2,08x (train) dan 37,34/18,64 = 2,01x (test). Sangat konsisten.
5. **Grade D–G menyumbang ~42% gagal bayar** dari ~15% portofolio — 42,37% vs 41,80%.

### ⚠️ Satu temuan tidak stabil: grade E

Default rate grade E berbeda **7,8 poin** (62,24% vs 70,04%) — melewati toleransi uji z (±6,8).

**Penyebab: sampel kecil.** Grade E hanya memiliki **963 pinjaman** (3,0% portofolio), sehingga sub-kelompok test berisi ±289 pinjaman. Pada ukuran sampel itu, selisih 7,8 poin masih mungkin terjadi secara acak.

**Dampak pada kesimpulan bisnis: tidak material.**
- Rekomendasi **tidak** menyasar angka pasti grade E — rekomendasi menyarankan meninjau ulang seluruh grade D–G secara bersamaan, dan agregat D–gabungan justru **stabil** (42,37% vs 41,80%).
- Posisi grade E sebagai "berisiko tinggi" (62–70%) tetap jelas di kedua kelompok; yang berubah hanya angka pastinya.

**Rekomendasi:** bila analisis ini dijadikan kebijakan produksi, grade E perlu dianalisis dengan seluruh data (bukan split) atau digabung dengan grade F–G agar sampelnya cukup.

* * *

## Cara Mengulang

```bash
python scripts/stability_check.py
```

Skrip memuat `data/credit_risk.db` (hasil `python scripts/clean_data.py`), membagi data dengan seed tetap, mencetak tabel perbandingan, dan menyimpan hasil mentah ke `data/stability_check.json`.

Ubah hasil pembagian dengan mengganti `SPLIT_SEED` di bagian atas skrip; ubah ambang ketegasan lewat `TOL_*`.

* * *

## Keterbatasan

1. Split acak **bukan** validasi deret waktu — dataset tidak punya kolom tanggal, sehingga tidak ada uji *out-of-time* (vintage/roll rate).
2. Uji ini mengukur **konsistensi antar sampel**, bukan kausalitas atau performa model prediktif.
3. Satu seed (42) digunakan agar hasil dapat direproduksi; seed lain dapat menggeser angka grade kecil (E, F, G) karena ukuran sampelnya yang terbatas.
