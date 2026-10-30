-- ====================================================================
-- LEVEL 4: SQL LANJUTAN (WINDOW FUNCTIONS: RANK, DENSE_RANK, NTILE)
-- Dataset: credit_risk (SQLite)
-- Total baris terverifikasi: 32.409
-- ====================================================================

-- 1. Peringkat Tujuan Pinjaman Paling Berisiko di dalam Tiap Loan Grade menggunakan RANK()
-- Menjawab: Di tiap grade (A sampai G), tujuan pinjaman mana yang memiliki default rate tertinggi?
WITH grade_intent_summary AS (
    SELECT 
        loan_grade,
        loan_intent,
        COUNT(*) AS total_loans,
        SUM(loan_status) AS total_defaults,
        ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct
    FROM credit_risk
    GROUP BY loan_grade, loan_intent
)
SELECT 
    loan_grade,
    loan_intent,
    total_loans,
    total_defaults,
    default_rate_pct,
    RANK() OVER (
        PARTITION BY loan_grade 
        ORDER BY default_rate_pct DESC
    ) AS rank_within_grade
FROM grade_intent_summary
ORDER BY loan_grade, rank_within_grade;


-- 2. Segmentasi Kuartil Risiko menggunakan NTILE(4)
-- Membagi kombinasi Kepemilikan Rumah + Kelompok Pendapatan ke dalam 4 kuartil risiko:
-- Kuartil 1: Risiko Rendah
-- Kuartil 2: Risiko Menengah-Rendah
-- Kuartil 3: Risiko Menengah-Tinggi
-- Kuartil 4: Risiko Tertinggi
WITH home_income_summary AS (
    SELECT 
        person_home_ownership,
        income_band,
        COUNT(*) AS total_loans,
        SUM(loan_status) AS total_defaults,
        ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct
    FROM credit_risk
    GROUP BY person_home_ownership, income_band
)
SELECT 
    person_home_ownership,
    income_band,
    total_loans,
    total_defaults,
    default_rate_pct,
    NTILE(4) OVER (ORDER BY default_rate_pct ASC) AS risk_quartile,
    CASE NTILE(4) OVER (ORDER BY default_rate_pct ASC)
        WHEN 1 THEN 'Low Risk'
        WHEN 2 THEN 'Moderate-Low Risk'
        WHEN 3 THEN 'Moderate-High Risk'
        WHEN 4 THEN 'Highest Risk'
    END AS risk_category
FROM home_income_summary
ORDER BY default_rate_pct DESC;


-- 3. Pemeringkatan Nasional Segmen Terbesar menggunakan DENSE_RANK()
-- Memberi peringkat risiko gabungan untuk segmen dengan volume pinjaman > 300
WITH major_segments AS (
    SELECT 
        loan_intent,
        person_home_ownership,
        income_band,
        COUNT(*) AS total_loans,
        SUM(loan_status) AS total_defaults,
        ROUND(SUM(loan_status) * 100.0 / COUNT(*), 1) AS default_rate_pct
    FROM credit_risk
    GROUP BY loan_intent, person_home_ownership, income_band
    HAVING COUNT(*) > 300
)
SELECT 
    loan_intent,
    person_home_ownership,
    income_band,
    total_loans,
    total_defaults,
    default_rate_pct,
    DENSE_RANK() OVER (ORDER BY default_rate_pct DESC) AS national_risk_rank
FROM major_segments
ORDER BY national_risk_rank;
