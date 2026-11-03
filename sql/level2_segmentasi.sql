-- ============================================================================
-- LEVEL 2: SEGMENTASI PEMINJAM (HAVING & CASE WHEN)
-- File: sql/level2_segmentasi.sql
-- Deskripsi: Analisis korelasi status kepemilikan rumah, kelompok pendapatan,
--            dan kelompok umur terhadap tingkat gagal bayar.
-- ============================================================================

-- 3. Kepemilikan Rumah (Home Ownership) vs Risiko Gagal Bayar
-- Pertanyaan: Apakah status kepemilikan rumah berkorelasi dengan tingkat gagal bayar?
SELECT
    person_home_ownership,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
FROM credit_risk
GROUP BY person_home_ownership
HAVING COUNT(*) > 100
ORDER BY default_rate_persen DESC;

-- 4. Kelompok Pendapatan & Kelompok Umur Paling Berisiko
-- Pertanyaan: Kelompok pendapatan (income band) dan kelompok umur (age group) mana yang paling berisiko?
-- 4a. Berdasarkan income_band
SELECT
    income_band,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
FROM credit_risk
GROUP BY income_band
ORDER BY default_rate_persen DESC;

-- 4b. Berdasarkan age_group
SELECT
    age_group,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
FROM credit_risk
GROUP BY age_group
ORDER BY default_rate_persen DESC;

-- 4c. Kombinasi income_band dan age_group dengan CASE WHEN untuk menandai segmen risiko tinggi
SELECT
    income_band,
    age_group,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen,
    CASE
        WHEN AVG(loan_status) * 100 >= 40 THEN 'RISIKO TINGGI'
        WHEN AVG(loan_status) * 100 >= 20 THEN 'RISIKO SEDANG'
        ELSE 'RISIKO RENDAH'
    END AS kategori_risiko
FROM credit_risk
GROUP BY income_band, age_group
HAVING COUNT(*) >= 50
ORDER BY default_rate_persen DESC;
