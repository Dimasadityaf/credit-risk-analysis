-- ============================================================================
-- LEVEL 1: DASAR RISIKO KREDIT (AGREGASI & FILTER)
-- File: sql/level1_dasar.sql
-- Deskripsi: Query dasar untuk mengetahui tingkat gagal bayar secara keseluruhan
--            dan per loan grade, serta tujuan pinjaman dengan risiko tertinggi.
-- ============================================================================

-- 1. Gagal Bayar Keseluruhan & Per Loan Grade
-- Pertanyaan: Berapa persentase gagal bayar pinjaman secara keseluruhan dan per loan grade?
SELECT
    loan_grade,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
FROM credit_risk
GROUP BY loan_grade
ORDER BY loan_grade;

-- Default rate keseluruhan (seluruh dataset)
SELECT
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_keseluruhan_persen
FROM credit_risk;

-- 2. Tujuan Pinjaman dengan Risiko Gagal Bayar Tertinggi
-- Pertanyaan: Tujuan pinjaman (loan intent) mana yang memiliki risiko gagal bayar paling tinggi?
SELECT
    loan_intent,
    COUNT(*) AS total_pinjaman,
    SUM(loan_status) AS jumlah_gagal_bayar,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate_persen
FROM credit_risk
GROUP BY loan_intent
ORDER BY default_rate_persen DESC;
