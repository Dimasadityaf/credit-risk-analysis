-- ====================================================================
-- LEVEL 2: SEGMENTASI PEMINJAM (CASE WHEN & HAVING)
-- Dataset: credit_risk (SQLite)
-- Total baris terverifikasi: 32.409
-- ====================================================================

-- 1. Pertanyaan Bisnis 4: Korelasi Rasio Cicilan terhadap Pendapatan (Loan Percent Income) dengan Gagal Bayar
-- Rasio ini mengukur beban cicilan terhadap total penghasilan tahunan peminjam.
-- Target angka terverifikasi:
-- <= 10%: 11,8% | 10-20%: 15,1% | 20-30%: 22,0% | > 30%: 70,4%
SELECT 
    CASE 
        WHEN loan_percent_income <= 0.10 THEN '1. <= 10%'
        WHEN loan_percent_income <= 0.20 THEN '2. 10-20%'
        WHEN loan_percent_income <= 0.30 THEN '3. 20-30%'
        ELSE '4. > 30%'
    END AS dti_band,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct
FROM credit_risk
GROUP BY dti_band
ORDER BY dti_band;


-- 2. Pertanyaan Bisnis 5: Prediksi Gagal Bayar dari Riwayat Sebelumnya (Default on File)
-- Membandingkan tingkat gagal bayar antara debitur yang pernah tercatat macet (Y) vs lancar (N).
-- Target angka terverifikasi:
-- Y: 37,9% (5.729 pinjaman) | N: 18,4% (26.680 pinjaman)
SELECT 
    cb_person_default_on_file AS prior_default,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct
FROM credit_risk
GROUP BY cb_person_default_on_file
ORDER BY default_rate_pct DESC;


-- 3. Pertanyaan Bisnis 6a: Persentase Gagal Bayar per Kelompok Pendapatan (Income Band)
-- Target angka terverifikasi:
-- <30k: 45,6% | 30-50k: 25,7% | 50-75k: 17,6% | 75-100k: 11,0% | 100k+: 9,6%
SELECT 
    income_band,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct
FROM credit_risk
GROUP BY income_band
ORDER BY default_rate_pct DESC;


-- 4. Pertanyaan Bisnis 6b: Persentase Gagal Bayar per Kelompok Umur (Age Group)
-- Menilai apakah faktor usia memiliki korelasi yang signifikan terhadap risiko.
-- Target angka terverifikasi:
-- 20-25: 23,1% | 26-30: 20,9% | 31-35: 20,2% | 36-45: 20,7% | 46+: 22,3%
-- Catatan analisis: Umur hampir tidak membedakan risiko secara signifikan (~20-23%).
SELECT 
    age_group,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct
FROM credit_risk
GROUP BY age_group
ORDER BY age_group;


-- 5. Analisis Kombinasi Risiko Tinggi dengan HAVING
-- Memfilter hanya segmen tujuan pinjaman + status rumah dengan volume signifikan (> 500 pinjaman)
-- untuk melihat segmen mana yang paling rentan gagal bayar.
SELECT 
    loan_intent,
    person_home_ownership,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct
FROM credit_risk
GROUP BY loan_intent, person_home_ownership
HAVING COUNT(*) > 500
ORDER BY default_rate_pct DESC;