-- ====================================================================
-- LEVEL 3: SQL MENENGAH (CTE & SUBQUERY)
-- Dataset: credit_risk (SQLite)
-- Total baris terverifikasi: 32.409
-- ====================================================================

-- 1. Menggunakan Subquery: Menghitung Selisih Gagal Bayar Tiap Grade terhadap Rata-rata Portofolio (21,9%)
-- Subquery di bagian SELECT digunakan untuk mengambil metrik acuan portofolio tanpa hardcoding.
SELECT 
    loan_grade,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS grade_default_pct,
    ROUND((SELECT SUM(loan_status) * 100.0 / COUNT(*) FROM credit_risk), 1) AS overall_default_pct,
    ROUND(
        (SUM(loan_status) * 100.0 / COUNT(*)) - 
        (SELECT SUM(loan_status) * 100.0 / COUNT(*) FROM credit_risk), 
        1
    ) AS difference_from_avg_pct
FROM credit_risk
GROUP BY loan_grade
ORDER BY loan_grade;


-- 2. Menggunakan CTE (Common Table Expression): Analisis Beban Cicilan (DTI) & Kontribusi Risiko
-- Memetakan distribusi pinjaman dan proporsi gagal bayar pada masing-masing bucket rasio cicilan.
-- Target verifikasi: DTI > 30% memiliki default rate 70,4%
WITH dti_segmented AS (
    SELECT 
        loan_id,
        loan_status,
        loan_amnt,
        CASE 
            WHEN loan_percent_income <= 0.10 THEN '1. <= 10%'
            WHEN loan_percent_income <= 0.20 THEN '2. 10-20%'
            WHEN loan_percent_income <= 0.30 THEN '3. 20-30%'
            ELSE '4. > 30%'
        END AS dti_band
    FROM credit_risk
)
SELECT 
    dti_band,
    COUNT(*) AS total_loans,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM credit_risk), 1) AS pct_of_portfolio,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct,
    ROUND(SUM(loan_status) * 100.0 / (SELECT SUM(loan_status) FROM credit_risk), 1) AS pct_of_all_defaults
FROM dti_segmented
GROUP BY dti_band
ORDER BY dti_band;


-- 3. Menggunakan Multi-CTE: Interaksi Riwayat Gagal Bayar dan Kelompok Pendapatan
-- Menggabungkan dua faktor penentu untuk melihat debitur berisiko tinggi.
-- Target verifikasi: Prior default = Y (37,9%), Pendapatan <30k (45,6%)
WITH base_segment AS (
    SELECT 
        income_band,
        cb_person_default_on_file AS prior_default,
        loan_status,
        loan_amnt
    FROM credit_risk
),
aggregated_segment AS (
    SELECT 
        income_band,
        prior_default,
        COUNT(*) AS total_loans,
        SUM(loan_status) AS total_defaults,
        ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct,
        ROUND(AVG(loan_amnt), 0) AS avg_loan_amount
    FROM base_segment
    GROUP BY income_band, prior_default
)
SELECT 
    income_band,
    prior_default,
    total_loans,
    total_defaults,
    default_rate_pct,
    avg_loan_amount
FROM aggregated_segment
ORDER BY default_rate_pct DESC;
