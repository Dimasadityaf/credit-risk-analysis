-- ============================================================================
-- LEVEL 3: RASIO PINJAMAN TERHADAP PENDAPATAN & RIIWAYAT KREDIT (CTE & SUBQUERY)
-- File: sql/level3_cte_subquery.sql
-- Deskripsi: Analisis korelasi Loan-to-Income (LTI) dengan risiko gagal bayar,
--            serta apakah riwayat gagal bayar sebelumnya memprediksi gagal bayar saat ini.
-- ============================================================================

-- 5. Loan-to-Income (LTI) vs Risiko Gagal Bayar
-- Pertanyaan: Bagaimana korelasi antara rasio pinjaman terhadap pendapatan tahunan
--             dengan risiko gagal bayar, dan di titik mana risikonya melonjak?
-- Menggunakan CTE untuk membagi LTI menjadi interval (bucket)
WITH lti_bucket AS (
    SELECT
        loan_status,
        loan_percent_income,
        CASE
            WHEN loan_percent_income < 0.10 THEN '<10%'
            WHEN loan_percent_income < 0.20 THEN '10-20%'
            WHEN loan_percent_income < 0.30 THEN '20-30%'
            WHEN loan_percent_income < 0.40 THEN '30-40%'
            WHEN loan_percent_income < 0.50 THEN '40-50%'
            ELSE '>=50%'
        END AS lti_group
    FROM credit_risk
    WHERE loan_percent_income IS NOT NULL
)
SELECT
    lti_group,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
FROM lti_bucket
GROUP BY lti_group
ORDER BY
    CASE lti_group
        WHEN '<10%' THEN 1
        WHEN '10-20%' THEN 2
        WHEN '20-30%' THEN 3
        WHEN '30-40%' THEN 4
        WHEN '40-50%' THEN 5
        ELSE 6
    END;

-- 5b. Titik di mana risiko melonjak (default rate per 0.05 increment LTI)
WITH lti_fine AS (
    SELECT
        loan_status,
        ROUND(loan_percent_income / 0.05) * 0.05 AS lti_bin
    FROM credit_risk
    WHERE loan_percent_income IS NOT NULL
)
SELECT
    lti_bin,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
FROM lti_fine
GROUP BY lti_bin
ORDER BY lti_bin;

-- 6. Riwayat Gagal Bayar Sebelumnya (cb_person_default_on_file)
-- Pertanyaan: Apakah riwayat gagal bayar sebelumnya memprediksi potensi gagal bayar saat ini?
-- Menggunakan subquery untuk membandingkan default rate antara yang pernah dan tidak pernah gagal
SELECT
    cb_person_default_on_file,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen,
    -- Selisih default rate terhadap kelompok yang tidak pernah gagal bayar (N)
    ROUND(
        AVG(loan_status) * 100 -
        (SELECT AVG(loan_status) * 100 FROM credit_risk WHERE cb_person_default_on_file = 'N')
    , 2) AS selisih_vs_tidak_pernah_gagal_persen
FROM credit_risk
GROUP BY cb_person_default_on_file
ORDER BY default_rate_persen DESC;

-- 6b. Kombinasi riwayat gagal dan loan grade (subquery dalam WHERE)
SELECT
    c.loan_grade,
    c.cb_person_default_on_file,
    COUNT(*) AS total_pinjaman,
    ROUND(AVG(c.loan_status) * 100, 2) AS default_rate_persen
FROM credit_risk c
WHERE c.cb_person_default_on_file IN (
    SELECT DISTINCT cb_person_default_on_file FROM credit_risk
)
GROUP BY c.loan_grade, c.cb_person_default_on_file
ORDER BY c.loan_grade, default_rate_persen DESC;
