-- ============================================================================
-- LEVEL 4: PERINGKAT RISIKO (WINDOW FUNCTIONS)
-- File: sql/level4_window_function.sql
-- Deskripsi: Peringkat risiko gagal bayar dalam setiap loan grade menggunakan RANK(),
--            dan identifikasi segmen paling berisiko menggunakan NTILE() / DENSE_RANK().
-- ============================================================================

-- 7. Peringkat dalam Setiap Loan Grade
-- Pertanyaan: Di dalam setiap loan grade, tujuan pinjaman mana yang peringkat gagal bayarnya tertinggi?
-- Menggunakan RANK() untuk menurunkan urutan berdasarkan default rate
WITH intent_per_grade AS (
    SELECT
        loan_grade,
        loan_intent,
        COUNT(*) AS total_pinjaman,
        SUM(loan_status) AS jumlah_gagal_bayar,
        ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
    FROM credit_risk
    GROUP BY loan_grade, loan_intent
)
SELECT
    loan_grade,
    loan_intent,
    total_pinjaman,
    jumlah_gagal_bayar,
    default_rate_persen,
    RANK() OVER (PARTITION BY loan_grade ORDER BY default_rate_persen DESC) AS peringkat_risiko_dalam_grade
FROM intent_per_grade
ORDER BY loan_grade, peringkat_risiko_dalam_grade;

-- 8. Segmen Paling Berisiko (Kombinasi Status Rumah & Kelompok Pendapatan)
-- Pertanyaan: Kombinasi status rumah dan kelompok pendapatan mana yang masuk dalam kelompok risiko tertinggi?
-- Menggunakan NTILE() dan DENSE_RANK() untuk membagi segmen menjadi kuartil risiko
WITH segmen_risiko AS (
    SELECT
        person_home_ownership,
        income_band,
        COUNT(*) AS total_pinjaman,
        SUM(loan_status) AS jumlah_gagal_bayar,
        ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
    FROM credit_risk
    GROUP BY person_home_ownership, income_band
    HAVING COUNT(*) >= 50
)
SELECT
    person_home_ownership,
    income_band,
    total_pinjaman,
    jumlah_gagal_bayar,
    default_rate_persen,
    DENSE_RANK() OVER (ORDER BY default_rate_persen DESC) AS dense_rank_risiko,
    NTILE(4) OVER (ORDER BY default_rate_persen DESC) AS kuartil_risiko  -- 1 = risiko tertinggi, 4 = terendah
FROM segmen_risiko
ORDER BY default_rate_persen DESC;

-- 8b. Top 5 segmen paling berisiko secara keseluruhan
WITH segmen_risiko AS (
    SELECT
        person_home_ownership,
        income_band,
        COUNT(*) AS total_pinjaman,
        SUM(loan_status) AS jumlah_gagal_bayar,
        ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
    FROM credit_risk
    GROUP BY person_home_ownership, income_band
    HAVING COUNT(*) >= 50
)
SELECT
    person_home_ownership,
    income_band,
    total_pinjaman,
    jumlah_gagal_bayar,
    default_rate_persen
FROM segmen_risiko
ORDER BY default_rate_persen DESC
LIMIT 5;
